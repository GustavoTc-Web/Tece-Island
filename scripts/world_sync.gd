extends Node

signal state_changed(uid: String, id: String, text: String, retry: bool)
var client: Node
var config := {}
var busy := {}
var retry_at := {}
var failures := {}
var conflicts := {}
var states := {}
var attempted_at := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://config/world-sync.json"))
	config = parsed if parsed is Dictionary else {}
	client = FirestoreClient.new()
	add_child(client)

func enabled(uid: String) -> bool:
	return uid != "" and config.get("enabled", false) == true and (config.get("allowed_uids", []).is_empty() or uid in config.get("allowed_uids", []))

func key(account: AccountProgress) -> String: return account.uid + ":" + account.world_id

func status(account: AccountProgress, text: String, retry: bool = false) -> void:
	states[key(account)] = {"text": text, "retry": retry}
	state_changed.emit(account.uid, account.world_id, text, retry)

func interval() -> int: return maxi(120, int(config.get("interval_seconds", 120)))

func base(head: Dictionary) -> Dictionary:
	return {"revision": int(head.revision), "hash": head.hash, "update_time": head.update_time}

static func decision(local: Dictionary, remote: Dictionary) -> String:
	if local.is_empty(): return "download"
	var previous: Dictionary = local.get("_sync", {})
	if int(previous.get("revision", 0)) > int(remote.revision): return "conflict"
	if int(previous.get("revision", 0)) == int(remote.revision) and previous.get("hash", "") != remote.hash: return "conflict"
	if CloudCodec.hash_state(local) == remote.hash: return "equal"
	var intent: Dictionary = previous.get("intent", {})
	if intent.get("hash", "") == remote.hash and int(intent.get("revision", 0)) == int(remote.revision): return "accepted"
	if int(previous.get("revision", 0)) == int(remote.revision) and previous.get("hash", "") == remote.hash: return "upload"
	if int(previous.get("revision", 0)) > 0 and CloudCodec.hash_state(local) == previous.get("hash", ""): return "download"
	return "conflict"

func refresh_library(library: WorldLibrary, force: bool = false) -> Dictionary:
	if not enabled(library.uid): return {"ok": true}
	var result: Dictionary = await client.list_worlds(library.uid)
	if not result.get("ok", false): return result
	for head in result.worlds:
		var stamp := str(head.get("update_time", ""))
		var access := int(Time.get_unix_time_from_datetime_string(stamp.left(19))) if RegEx.create_from_string("^[0-9]{4}-[0-9]{2}-[0-9]{2}T").search(stamp) != null else 0
		if not await library.register_world(head.world_id, head.name, get_tree(), access): return {"ok": false, "error": library.error}
	var errors := []
	var pending := false
	# Migrate/sync all saved worlds, including inactive worlds and conflict copies.
	# Process sequentially to batch progress without flooding the free quota.
	for entry in library.data.worlds.duplicate(true):
		var account := library.account(entry.id)
		if busy.has(key(account)): continue
		var local := await account.read(get_tree())
		if account.error != "":
			status(account, "Falha ao carregar · Recuperar cópia", true)
			errors.append(account.error)
			continue
		if local.is_empty():
			var available := false
			for head in result.worlds:
				if head.world_id == entry.id: available = true
			status(account, "Disponível na nuvem" if available else "Save ausente · Recuperar cópia", true)
			continue # Remote-only worlds are downloaded when opened.
		var remote_name := ""
		for head in result.worlds:
			if head.world_id == entry.id: remote_name = head.name
		var saved_name := str(local.get("world_name", entry.name))
		if remote_name != "" and entry.name == saved_name and remote_name != entry.name:
			if not await library.rename_world(entry.id, remote_name, get_tree()): return {"ok": false, "error": library.error}
		elif entry.name != saved_name or not local.has("world_name"):
			local.world_name = entry.name
			if not await account.write(local, get_tree()): errors.append(account.error); continue
		var prepared := await prepare(account, library)
		if not prepared.get("ok", false): errors.append(str(prepared.get("error", "Sincronização pendente."))); continue
		local = prepared.data
		if CloudCodec.hash_state(local) == local.get("_sync", {}).get("hash", "") and not local.get("_sync", {}).has("intent"): continue
		var now := Time.get_ticks_msec()
		if now < int(attempted_at.get(key(account), -10000)) + 10000 or (not force and now < int(retry_at.get(key(account), 0))):
			pending = true
			continue
		var synced := await sync(account, library, local)
		if not synced.get("ok", false): errors.append(str(synced.get("error", "Há versões diferentes. Abra o mundo para resolver.")))
	if not errors.is_empty(): return {"ok": false, "error": errors[0]}
	return {"ok": true, "pending": pending}

func new_allowed(library: WorldLibrary, id: String) -> bool:
	return library.entry(id).get("uninitialized", false) == true

func prepare(account: AccountProgress, library: WorldLibrary) -> Dictionary:
	var deadline := Time.get_ticks_msec() + 45000
	while busy.has(key(account)):
		if Time.get_ticks_msec() >= deadline: return {"ok": false, "error": "Ainda há um envio em andamento. Aguarde e tente novamente."}
		await get_tree().create_timer(0.05, true).timeout
	var local := await account.read(get_tree())
	if account.error != "": return {"ok": false, "recovery": true, "error": account.error}
	if local.is_empty() and not (await account.recovery_candidates(get_tree())).is_empty():
		return {"ok": false, "recovery": true, "error": "O save principal está ausente, mas há backups. Escolha uma cópia para recuperar."}
	if not enabled(account.uid):
		if local.is_empty() and not new_allowed(library, account.world_id): return {"ok": false, "recovery": true, "error": "Este mundo não tem save disponível neste aparelho. Originais preservados."}
		return {"ok": true, "data": local}
	status(account, "Sincronizando")
	var response: Dictionary = await client.head(account.uid, account.world_id)
	if not response.get("ok", false):
		status(account, "Sincronização pendente · Tentar novamente", true)
		if local.is_empty() and not new_allowed(library, account.world_id): return response
		return {"ok": true, "data": local, "warning": response.get("error", "Sincronização pendente.")}
	if response.get("missing", false):
		if int(local.get("_sync", {}).get("revision", 0)) > 0: return {"ok": false, "error": "A versão remota esperada está ausente. Cópia local preservada; verifique a conta e o serviço."}
		if local.is_empty() and not new_allowed(library, account.world_id): return {"ok": false, "recovery": true, "error": "Save ausente neste aparelho e na nuvem. Procure no navegador usado na última partida."}
		status(account, "Salvo neste aparelho · Sincronização pendente", true)
		return {"ok": true, "data": local}
	var head: Dictionary = response.head
	var action := decision(local, head)
	if action == "conflict": return await conflict(account, library, local, head)
	if action == "accepted":
		var confirmed := await acknowledge(account, local, head)
		if not confirmed.get("ok", false): return confirmed
		local = JSON.parse_string(str(account.expected))
	if action == "download":
		var downloaded: Dictionary = await client.download(account.uid, account.world_id, head)
		if not downloaded.get("ok", false):
			status(account, "Sincronização pendente · Tentar novamente", true)
			# Never continue a blank or stale world after an incomplete remote load.
			return downloaded
		local = downloaded.data
		local._sync = base(head)
		if not await account.preserve(get_tree()) or not await account.write(local, get_tree()): return {"ok": false, "error": account.error}
		status(account, "Sincronizado")
	elif action == "equal":
		local._sync = base(head)
		if not await account.write(local, get_tree()): return {"ok": false, "error": account.error}
		status(account, "Sincronizado")
	elif action == "upload": status(account, "Salvo neste aparelho · Sincronização pendente", true)
	return {"ok": true, "data": local}

func conflict(account: AccountProgress, library: WorldLibrary, local: Dictionary, head: Dictionary) -> Dictionary:
	if not conflicts.has(key(account)) and not await account.preserve(get_tree(), "conflict-original"):
		return {"ok": false, "error": account.error}
	conflicts[key(account)] = {"account": account, "library": library, "local": local.duplicate(true), "head": head}
	status(account, "Versões diferentes · Resolver no lobby", true)
	return {"ok": false, "conflict": true, "error": "Há progresso diferente neste aparelho e na nuvem. As duas versões serão preservadas."}

func local_saved(account: AccountProgress, library: WorldLibrary, state: Dictionary, force: bool = false) -> void:
	if not enabled(account.uid):
		status(account, "Salvo neste aparelho")
		return
	if conflicts.has(key(account)):
		status(account, "Versões diferentes · Resolver no lobby", true)
		return
	if busy.has(key(account)): return
	status(account, "Salvo neste aparelho · Sincronização pendente", true)
	var now := Time.get_ticks_msec()
	if now < int(attempted_at.get(key(account), -10000)) + 10000: return
	if force or now >= int(retry_at.get(key(account), 0)):
		sync(account, library, state)

func sync(account: AccountProgress, library: WorldLibrary, snapshot: Dictionary) -> Dictionary:
	var id := key(account)
	if busy.has(id): return {"ok": false, "error": "Sincronização em andamento."}
	busy[id] = true
	attempted_at[id] = Time.get_ticks_msec()
	status(account, "Sincronizando")
	var result := await synchronize(account, library, snapshot)
	busy.erase(id)
	if result.get("ok", false):
		failures[id] = 0
		retry_at[id] = Time.get_ticks_msec() + interval() * 1000
		if result.get("published", false): client.prune(account.uid, account.world_id)
	else:
		failures[id] = int(failures.get(id, 0)) + 1
		retry_at[id] = Time.get_ticks_msec() + mini(900, interval() * int(pow(2, mini(3, failures[id] - 1)))) * 1000
		if not result.get("conflict", false): status(account, "Sincronização pendente · Tentar novamente", true)
	return result

func synchronize(account: AccountProgress, library: WorldLibrary, snapshot: Dictionary) -> Dictionary:
	# Read remote before EVERY publish, including retries after ambiguous timeouts.
	var response: Dictionary = await client.head(account.uid, account.world_id)
	if not response.get("ok", false): return response
	var previous: Dictionary = response.get("head", {})
	if previous.is_empty() and int(snapshot.get("_sync", {}).get("revision", 0)) > 0: return {"ok": false, "error": "Versão remota esperada ausente. Cópia local preservada."}
	if not previous.is_empty():
		var action := decision(snapshot, previous)
		if action == "conflict" or action == "download":
			# A running simulation may have advanced since the snapshot; resolve at lobby.
			return await conflict(account, library, snapshot, previous)
		if action == "equal": return await acknowledge(account, snapshot, previous)
		if action == "accepted": return await acknowledge(account, snapshot, previous)
	var title := str(library.entry(account.world_id).get("name", snapshot.get("world_name", "Meu mundo")))
	if snapshot.get("_sync", {}).is_empty() and not await account.preserve(get_tree()): return {"ok": false, "error": account.error}
	# A durable intent disambiguates a commit whose HTTP acknowledgement is lost.
	# It survives reload, while progress continues to be saved locally.
	var metadata := account.sync_state.duplicate(true)
	metadata.intent = {"hash": CloudCodec.hash_state(snapshot), "revision": int(previous.get("revision", 0)) + 1}
	if not await account.sync_metadata(metadata, get_tree()): return {"ok": false, "error": account.error}
	var result: Dictionary = await client.publish(account.uid, account.world_id, snapshot, previous, title)
	if not result.get("ok", false):
		if result.get("conflict", false):
			var latest: Dictionary = await client.head(account.uid, account.world_id)
			if latest.get("ok", false) and latest.has("head"): return await conflict(account, library, snapshot, latest.head)
		return result
	var confirmed := await acknowledge(account, snapshot, result.head)
	confirmed.published = true
	return confirmed

func acknowledge(account: AccountProgress, snapshot: Dictionary, head: Dictionary) -> Dictionary:
	# Persist the new base WITH the newest local progress, never the old upload body.
	# Do not advance the base if another session has changed it meanwhile.
	if not await account.sync_metadata(base(head), get_tree()): return {"ok": false, "error": account.error}
	var current: Dictionary = JSON.parse_string(str(account.expected))
	var complete: bool = CloudCodec.hash_state(current) == head.hash
	status(account, "Sincronizado" if complete else "Salvo neste aparelho · Sincronização pendente", not complete)
	return {"ok": true, "base": current._sync, "complete": complete}

func resolve(account: AccountProgress, library: WorldLibrary, choose_local: bool) -> Dictionary:
	if library.uid != account.uid: return {"ok": false, "error": "A conta mudou. Operação cancelada."}
	if not conflicts.has(key(account)): return {"ok": false, "error": "Reabra o mundo para consultar as versões."}
	# Re-read both sides. The user never approves a stale remote overwrite.
	var local := await account.read(get_tree())
	if account.error != "" or local.is_empty(): return {"ok": false, "error": account.error}
	var response: Dictionary = await client.head(account.uid, account.world_id)
	if not response.get("ok", false) or not response.has("head"): return {"ok": false, "error": response.get("error", "Nuvem indisponível. Tente novamente.")}
	var downloaded: Dictionary = await client.download(account.uid, account.world_id, response.head)
	if not downloaded.get("ok", false): return downloaded
	var new_id := "copy-" + Crypto.new().generate_random_bytes(12).hex_encode()
	var title := (str(library.entry(account.world_id).get("name", "Meu mundo")).left(22) + " · cópia do aparelho").left(40)
	var copy := library.account(new_id)
	var preserved := CloudCodec.payload(local)
	preserved.world_id = new_id
	preserved.world_name = title
	if not await copy.write(preserved, get_tree()) or not await library.register_world(new_id, title, get_tree()): return {"ok": false, "error": "Não foi possível preservar as duas versões. Originais mantidos."}
	if not await account.preserve(get_tree(), "resolved-original"): return {"ok": false, "error": account.error}
	var remote: Dictionary = downloaded.data
	remote._sync = base(response.head)
	if not await account.write(remote, get_tree()): return {"ok": false, "error": account.error}
	conflicts.erase(key(account))
	status(account, "Sincronizado")
	# Confirm/upload the preserved branch as well, so the other device can see it.
	var copy_result := await sync(copy, library, preserved)
	return {"ok": true, "world_id": new_id if choose_local else account.world_id, "copy_id": new_id, "copy_synced": copy_result.get("ok", false)}
