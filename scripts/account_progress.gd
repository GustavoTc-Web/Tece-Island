class_name AccountProgress
extends RefCounted
var uid := ""
var root_path := "user://"
var error := ""
var store := SaveStore.new()
var native_only := false
var world_id := ""
var observed := false
var expected: Variant = null
var blocked := false
var sync_state := {}
var io_busy := false
var local_conflict := false

func configure(owner: String, folder: String = "user://", selected_world: String = "") -> void:
	uid = owner
	root_path = folder
	world_id = selected_world
	store.path = folder.path_join("accounts").path_join(uid.sha256_text()).path_join("solo-progress.json")
	if not world_id.is_empty(): store.path = folder.path_join("accounts").path_join(uid.sha256_text()).path_join("worlds").path_join(world_id).path_join("progress.json")

func browser() -> bool: return OS.has_feature("web") and not native_only
func browser_key() -> String: return "account/" + uid.sha256_text() + ("/world/" + world_id if not world_id.is_empty() else "")
func legacy_path() -> String: return root_path.path_join("solo-progress.json")

func read(tree: SceneTree) -> Dictionary:
	while io_busy: await tree.process_frame
	io_busy = true
	var result := await _read(tree)
	io_busy = false
	return result

func _read(tree: SceneTree) -> Dictionary:
	error = ""
	blocked = true
	observed = true
	if not world_id.is_empty() and not SaveStore.safe_world_id(world_id):
		error = "ID de mundo inválido. Original preservado."
		return {}
	if uid.is_empty():
		error = "Conta indisponível. Entre novamente."
		return {}
	var data := {}
	if browser():
		var result: Dictionary = await tree.root.get_node("BrowserPersistence").request("read", browser_key())
		if not result.get("ok", false):
			error = str(result.get("error", "Falha ao carregar progresso local."))
			blocked = true
			return {}
		expected = result.get("value")
		if result.get("value") == null:
			blocked = false
			return {}
		var parser := JSON.new()
		if parser.parse(str(result.value)) != OK or not parser.data is Dictionary:
			error = "Progresso inválido: original preservado."
			return {}
		data = parser.data
	else:
		expected = FileAccess.get_file_as_string(store.path) if FileAccess.file_exists(store.path) else null
		data = store.read()
		error = store.error
	if not data.is_empty() and str(data.get("owner_uid", "")) != uid:
		error = "Este progresso pertence a outra conta. Arquivo preservado."
		return {}
	if not data.is_empty() and not world_id.is_empty() and str(data.get("world_id", "")) != world_id:
		error = "Progresso pertence a outro mundo. Arquivo preservado."
		return {}
	if not data.is_empty() and (not data.get("inventory") is Dictionary or int(data.get("version", -1)) < 0 or int(data.get("version", -1)) > SaveStore.VERSION):
		error = "Progresso incompatível: original preservado."
		return {}
	if not data.is_empty() and not SaveValidation.valid(data, uid, world_id):
		error = "Progresso incompatível: original preservado. Use a recuperação de backup."
		data = {}
	blocked = error != ""
	if not blocked: sync_state = data.get("_sync", {}).duplicate(true)
	return data

func write(data: Dictionary, tree: SceneTree) -> bool:
	while io_busy: await tree.process_frame
	if not observed: await read(tree)
	io_busy = true
	var ok := await _write(data.duplicate(true), tree)
	io_busy = false
	return ok

func _write(data: Dictionary, tree: SceneTree) -> bool:
	error = ""
	if local_conflict:
		error = "Outra sessão alterou o mundo. Salve sua partida como uma cópia para continuar."
		return false
	if blocked:
		error = "Carregamento falhou. Gravação bloqueada para preservar o original."
		return false
	if not world_id.is_empty() and not SaveStore.safe_world_id(world_id):
		error = "ID de mundo inválido. Original preservado."
		return false
	if uid.is_empty() or str(data.get("owner_uid", "")) != uid:
		error = "Conta do progresso inválida. Entre novamente."
		return false
	if not world_id.is_empty() and str(data.get("world_id", "")) != world_id:
		error = "Mundo do progresso inválido. Arquivo preservado."
		return false
	if not SaveValidation.valid(data, uid, world_id):
		error = "Progresso inválido. Gravação cancelada."
		return false
	if int(data.get("_sync", {}).get("revision", 0)) < int(sync_state.get("revision", 0)):
		data._sync = sync_state.duplicate(true)
	elif int(data.get("_sync", {}).get("revision", 0)) == int(sync_state.get("revision", 0)) and sync_state.has("intent") and not data.get("_sync", {}).has("intent"):
		data._sync = sync_state.duplicate(true)
	var content := JSON.stringify(data)
	if browser():
		var result: Dictionary = await tree.root.get_node("BrowserPersistence").request("write", browser_key(), content, JSON.stringify({"expected": expected}))
		if not result.get("ok", false): error = str(result.get("error", "Falha ao salvar. Tente novamente."))
		else:
			expected = content
			sync_state = data.get("_sync", {}).duplicate(true)
		if result.get("conflict", false): local_conflict = true
		return bool(result.get("ok", false))
	if DirAccess.make_dir_recursive_absolute(store.path.get_base_dir()) != OK:
		error = "Não foi possível preparar o armazenamento local. Tente novamente."
		return false
	# The directory lock serializes compare-and-replace across native processes.
	if not SaveStore.acquire_lock(store.path):
		error = "Outra sessão está gravando. Tente novamente."
		return false
	var current: Variant = FileAccess.get_file_as_string(store.path) if FileAccess.file_exists(store.path) else null
	if current != expected:
		local_conflict = true
		var archived := store.preserve(content, "conflict") != ""
		SaveStore.release_lock(store.path)
		error = "Outra sessão alterou este mundo. Sua versão foi preservada como backup; reabra o lobby." if archived else "Outra sessão alterou o mundo e a cópia de segurança falhou. Mantenha a partida aberta e tente novamente."
		return false
	var ok := store.write(data)
	SaveStore.release_lock(store.path)
	error = store.error
	if ok:
		expected = content
		sync_state = data.get("_sync", {}).duplicate(true)
	return ok

func sync_metadata(next: Dictionary, tree: SceneTree) -> bool:
	while io_busy: await tree.process_frame
	if expected == null or blocked:
		error = "Não há cópia local válida para confirmar a sincronização."
		return false
	var current: Variant = JSON.parse_string(str(expected))
	if not SaveValidation.valid(current, uid, world_id): return false
	current._sync = next.duplicate(true)
	# Keep the newest progress already written by THIS session. Never re-observe
	# another session's file and accidentally authorize overwriting it.
	return await write(current, tree)

func preserve(tree: SceneTree, reason: String = "before-cloud") -> bool:
	if browser():
		var result: Dictionary = await tree.root.get_node("BrowserPersistence").request("preserve", browser_key(), "", reason)
		error = str(result.get("error", ""))
		return result.get("ok", false)
	if not FileAccess.file_exists(store.path): return true
	if reason == "before-cloud":
		var destination := store.path + ".before-cloud.json"
		if FileAccess.file_exists(destination): return true
		var ok := DirAccess.copy_absolute(store.path, destination) == OK
		if not ok: error = "Falha no backup antes da nuvem. Envio cancelado."
		return ok
	var preserved := store.preserve(FileAccess.get_file_as_string(store.path), reason) != ""
	if not preserved: error = store.error
	return preserved

func recovery_candidates(tree: SceneTree) -> Array:
	var entries := []
	if browser():
		var result: Dictionary = await tree.root.get_node("BrowserPersistence").request("scan", browser_key() + ":")
		if not result.get("ok", false):
			error = str(result.get("error", "Falha ao procurar backups."))
			return []
		entries = result.get("value", [])
	else:
		var directory := DirAccess.open(store.path.get_base_dir())
		if directory != null:
			for file in directory.get_files():
				if file.begins_with(store.path.get_file() + ".") and not file.ends_with(".lock"):
					var source := store.path.get_base_dir().path_join(file)
					entries.append({"key": source, "value": FileAccess.get_file_as_string(source)})
	var valid := []
	for entry in entries:
		var candidate: Variant = SaveStore.parse(str(entry.value))
		if SaveValidation.valid(candidate, uid, world_id): valid.append({"source": entry.key, "data": candidate})
	return valid

func recover(source: String, tree: SceneTree) -> bool:
	# Only explicit recovery may replace an unreadable current file.
	for candidate in await recovery_candidates(tree):
		if candidate.source != source: continue
		if not await preserve(tree, "recovery-original"): return false
		await read(tree)
		blocked = false
		local_conflict = false
		sync_state = {}
		return await write(candidate.data, tree)
	error = "Backup inválido ou indisponível. Original preservado."
	return false

func recover_data(candidate: Dictionary, tree: SceneTree) -> bool:
	if not SaveValidation.valid(candidate, uid, world_id):
		error = "Cópia incompatível. Original preservado."
		return false
	if not await preserve(tree, "recovery-original"): return false
	await read(tree)
	blocked = false
	local_conflict = false
	sync_state = {}
	return await write(candidate, tree)

func legacy_available(tree: SceneTree) -> bool:
	if not FileAccess.file_exists(legacy_path()): return false
	if browser():
		var result: Dictionary = await tree.root.get_node("BrowserPersistence").request("read", "legacy-import-v4")
		return result.get("ok", false) and result.get("value") == null
	return not DirAccess.dir_exists_absolute(root_path.path_join("legacy-import-v4"))

func import_legacy(tree: SceneTree) -> bool:
	error = ""
	var existing := await read(tree)
	if error != "" or not existing.is_empty():
		if error == "": error = "Esta conta já possui progresso. Importação cancelada."
		return false
	var legacy := SaveStore.new()
	legacy.path = legacy_path()
	var data := legacy.read()
	if data.is_empty() or legacy.error != "":
		error = legacy.error if legacy.error != "" else "Nenhum progresso antigo disponível."
		return false
	if data.has("owner_uid") and str(data.owner_uid) != uid:
		error = "Save antigo vinculado a outra conta: importação bloqueada."
		return false
	data.owner_uid = uid
	data.version = SaveStore.VERSION
	if browser():
		var result: Dictionary = await tree.root.get_node("BrowserPersistence").request("import", browser_key(), JSON.stringify(data), JSON.stringify({"uid_hash": uid.sha256_text(), "original": FileAccess.get_file_as_string(legacy_path())}))
		if not result.get("ok", false): error = str(result.get("error", "Importação não concluída."))
		return bool(result.get("ok", false))
	var claim := root_path.path_join("legacy-import-v4")
	if DirAccess.make_dir_absolute(claim) != OK:
		error = "O save antigo já foi importado ou está reservado. Arquivos preservados."
		return false
	var marker := FileAccess.open(claim.path_join("owner.txt"), FileAccess.WRITE)
	if marker == null:
		error = "Falha ao reservar importação. Save antigo preservado."
		DirAccess.remove_absolute(claim)
		return false
	marker.store_string(uid.sha256_text())
	marker.close()
	var ok := await write(data, tree)
	if not ok:
		DirAccess.remove_absolute(claim.path_join("owner.txt"))
		DirAccess.remove_absolute(claim)
	return ok
