extends SceneTree
var checks := 0
var failures := 0
class MemoryService extends Node:
	var documents := {}
	var reads_fail := false
	var lost_ack := false
	var publishes := 0
	var bump_before_commit := false
	func location(uid: String, id: String) -> String: return uid + ":" + id
	func head(uid: String, id: String) -> Dictionary:
		if reads_fail: return {"ok": false, "error": "offline"}
		var doc: Dictionary = documents.get(location(uid, id), {})
		return {"ok": true, "missing": true} if doc.is_empty() else {"ok": true, "head": doc.head.duplicate(true)}
	func list_worlds(uid: String) -> Dictionary:
		var worlds := []
		for doc in documents.values():
			if doc.head.owner_uid == uid: worlds.append(doc.head.duplicate(true))
		return {"ok": true, "worlds": worlds}
	func download(uid: String, id: String, metadata: Dictionary) -> Dictionary:
		var doc: Dictionary = documents.get(location(uid, id), {})
		return CloudCodec.decode(metadata, doc.get("chunks", []), uid, id)
	func publish(uid: String, id: String, state: Dictionary, previous: Dictionary, title: String) -> Dictionary:
		publishes += 1
		var current: Dictionary = documents.get(location(uid, id), {}).get("head", {})
		if bump_before_commit:
			bump_before_commit = false
			current.revision += 1
			current.update_time = "server-%d" % current.revision
		if current.get("update_time", "") != previous.get("update_time", ""): return {"ok": false, "conflict": true}
		var encoded := CloudCodec.encode(state)
		var metadata := {"schema": 1, "owner_uid": uid, "world_id": id, "name": title, "revision": int(previous.get("revision", 0)) + 1, "snapshot": "v-%d" % publishes, "previous_snapshot": previous.get("snapshot", ""), "hash": encoded.hash, "raw_bytes": encoded.raw_bytes, "encoded_bytes": encoded.encoded_bytes, "chunk_count": encoded.chunks.size(), "update_time": "server-%d" % publishes}
		documents[location(uid, id)] = {"head": metadata, "chunks": encoded.chunks}
		if lost_ack:
			lost_ack = false
			return {"ok": false, "error": "ack lost"}
		return {"ok": true, "head": metadata}
	func prune(_uid: String, _id: String) -> void: pass
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS: " if ok else "FAIL: ", label)
func run() -> void:
	print("TEST: Transporte de fixture, arquivos próprios; não é autenticação Firebase real")
	var sync := root.get_node("WorldSync")
	var actual: Node = sync.client
	var service := MemoryService.new()
	root.add_child(service)
	sync.client = service
	sync.config = {"enabled": true, "allowed_uids": [], "interval_seconds": 120}
	var folder := "res://.tools/sync-fixture-%d" % Time.get_ticks_usec()
	var phone := WorldLibrary.new()
	phone.configure("sync-fixture-uid", folder + "/phone")
	phone.native_only = true
	var pc := WorldLibrary.new()
	pc.configure(phone.uid, folder + "/pc")
	pc.native_only = true
	await phone.load_index(self)
	await pc.load_index(self)
	var id := await phone.create_world("Ilha compartilhada", self)
	var inv := ResourceInventory.new()
	inv.reset()
	inv.add_resource("madeira", 17)
	var state := {"version": 5, "owner_uid": phone.uid, "world_id": id, "world_name": "Ilha compartilhada", "inventory": inv.network_state(), "world_seed": 719, "structures": [], "player": {"health": 67, "position": [512, 640]}, "journal": {"discovered": ["arrival"], "unread": {}}, "objectives": {}}
	inv.free()
	var a := phone.account(id)
	await a.write(state, self)
	check((await sync.sync(a, phone, state)).ok, "Celular confirma revisão inicial na nuvem")
	check(a.sync_state.revision == 1 and FileAccess.file_exists(a.store.path + ".before-cloud.json"), "Primeiro envio preserva backup e grava base confirmada")
	check((await sync.refresh_library(pc)).ok and not pc.entry(id).is_empty(), "PC descobre o mesmo ID na lista da conta")
	var b := pc.account(id)
	var prepared: Dictionary = await sync.prepare(b, pc)
	check(prepared.ok and prepared.data.inventory == JSON.parse_string(JSON.stringify(state.inventory)) and prepared.data.player.health == 67 and prepared.data.journal.discovered == ["arrival"], "PC continua inventário/personagem/diário do celular")
	var changed: Dictionary = prepared.data.duplicate(true)
	changed.player.health = 88
	changed.version = SaveStore.VERSION
	var campaign := SoloCampaign.new()
	campaign.discovered = true
	campaign.map_found = true
	campaign.temples.lens.started = true
	campaign.temples.lens.cleared = CampaignEncounters.enemy_ids("lens")
	campaign.collect("lens")
	changed.campaign = campaign.capture()
	campaign.free()
	await b.write(changed, self)
	check((await sync.sync(b, pc, changed)).ok and b.sync_state.revision == 2, "PC envia revisão seguinte sem usar relógio do aparelho")
	prepared = await sync.prepare(a, phone)
	check(prepared.ok and prepared.data.player.health == 88 and prepared.data.version == SaveStore.VERSION and prepared.data.campaign.components == ["lens"], "Celular recebe progresso e campanha v7 do PC sem falso conflito na migração v5")
	var original := FileAccess.get_file_as_string(a.store.path)
	service.reads_fail = true
	var before: int = service.publishes
	check(not (await sync.sync(a, phone, prepared.data)).ok and service.publishes == before, "Falha ao consultar remoto nunca é interpretada como ausência ou permite envio")
	check(FileAccess.get_file_as_string(a.store.path) == original, "Falha de conexão conserva todos os bytes locais")
	service.reads_fail = false
	var stale: Dictionary = prepared.data.duplicate(true)
	stale.player.health = 51
	await a.write(stale, self)
	var latest := await b.read(self)
	latest.player.health = 96
	await b.write(latest, self)
	await sync.sync(b, pc, latest)
	check((await sync.sync(a, phone, stale)).get("conflict", false), "Duas sessões incompatíveis não sobrescrevem revisão mais recente")
	var resolved: Dictionary = await sync.resolve(a, phone, true)
	check(resolved.ok and resolved.world_id != id and phone.data.worlds.size() == 2, "Resolução cria cópia com novo ID e deixa ambas disponíveis")
	check((await phone.account(id).read(self)).player.health == 96 and (await phone.account(resolved.copy_id).read(self)).player.health == 51, "Resolução preserva progresso remoto e local completos")
	var copy := phone.account(resolved.copy_id)
	var copy_state := await copy.read(self)
	copy_state.player.health = 50
	await copy.write(copy_state, self)
	service.lost_ack = true
	check(not (await sync.sync(copy, phone, copy_state)).ok and copy.sync_state.has("intent"), "Interrupção após commit mantém intenção durável e estado pendente")
	copy_state = await copy.read(self)
	copy_state.player.health = 43
	await copy.write(copy_state, self)
	before = service.publishes
	check((await sync.sync(copy, phone, copy_state)).ok and service.publishes == before and copy.sync_state.revision == 2, "Retry reconhece commit sem confirmação mesmo com novo progresso local")
	check((await copy.read(self)).player.health == 43 and not copy.sync_state.has("intent"), "Confirmação de envio antigo não substitui progresso produzido durante a rede")
	var foreign := WorldLibrary.new()
	foreign.configure("sync-other-uid", folder + "/other")
	foreign.native_only = true
	await foreign.load_index(self)
	check((await sync.refresh_library(foreign)).ok and foreign.data.worlds.is_empty(), "Listas de duas contas permanecem separadas")
	var inactive := await phone.create_world("Ainda não jogado", self)
	await sync.refresh_library(phone)
	check(service.documents.has(service.location(phone.uid, inactive)), "Mundos recém-criados e inativos também sincronizam ao consultar o lobby")
	var encoded := CloudCodec.encode(copy_state)
	var head: Dictionary = service.documents[service.location(copy.uid, copy.world_id)].head
	check(not CloudCodec.decode(head, [], copy.uid, copy.world_id).ok, "Download incompleto é rejeitado sem abrir mundo vazio")
	check(not CloudCodec.decode(head, encoded.chunks, "another-uid", copy.world_id).ok, "Payload de outra conta é rejeitado")
	var other_session := phone.account(copy.world_id)
	var concurrent_progress := await other_session.read(self)
	concurrent_progress.player.health = 12
	await other_session.write(concurrent_progress, self)
	check(not (await sync.acknowledge(copy, copy_state, head)).ok and (await other_session.read(self)).player.health == 12, "Confirmação antiga não autoriza sobrescrever o arquivo de outra sessão local")
	# Real game capture measures the actual generated world, not an estimated JSON.
	var world: Node2D = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.owner_uid = phone.uid
	world.world_id = id
	var real_inv: ResourceInventory = world.get_node("Inventory")
	real_inv.reset()
	real_inv.add_item({"item": "armadura_pedra", "quantity": 1})
	real_inv.equip_armor(0)
	real_inv.add_item({"item": "arco", "quantity": 1, "uid": 333})
	for index in range(100):
		var chest: PlacedStructure = load("res://scenes/placed_structure.tscn").instantiate()
		chest.kind = "bau"
		chest.structure_id = "chest-%d" % index
		chest.position = Vector2(600 + index * 32, 800)
		chest.system = world.get_node("Structures")
		world.get_node("WorldObjects").add_child(chest)
		chest.storage.add_resource("madeira", 64)
		chest.storage.add_resource("pedra", 64)
	var progress := WorldProgress.new()
	progress.world = world
	var measured := CloudCodec.encode(progress.capture())
	check(measured.ok, "Save real do mundo cabe nos limites medidos do protocolo")
	var restored := CloudCodec.decode({"schema": 1, "owner_uid": phone.uid, "world_id": id, "name": "Teste", "revision": 1, "snapshot": "v-test", "chunk_count": measured.chunks.size(), "raw_bytes": measured.raw_bytes, "encoded_bytes": measured.encoded_bytes, "hash": measured.hash}, measured.chunks, phone.uid, id)
	check(restored.ok and restored.data.structures.size() == 100 and restored.data.inventory.armor.item == "armadura_pedra" and restored.data.structures[0].storage.slots[0].quantity == 15, "Codec conserva equipamento e 100 baús com conteúdo no estado completo")
	var resumed: Node2D = load("res://scenes/world.tscn").instantiate()
	resumed.owner_uid = phone.uid
	resumed.world_id = id
	resumed.account_store = phone.account(id)
	resumed.initial_progress = restored.data
	resumed.persistence_enabled = true
	root.add_child(resumed)
	await process_frame
	var chests := []
	for node in resumed.get_node("WorldObjects").get_children():
		if node is PlacedStructure and node.kind == "bau": chests.append(node)
	check(resumed.progress_store.writable and resumed.get_node("Inventory").armor.item == "armadura_pedra" and chests.size() == 100 and chests[0].storage.count_item("madeira") == 64, "Partida restaura equipamento e baús após carregar o save transferido")
	resumed.queue_free()
	print("REAL SAVE: JSON=%d bytes, deflate/base64=%d bytes, chunks=%d" % [measured.raw_bytes, measured.encoded_bytes, measured.chunks.size()])
	var report := FileAccess.open(folder + "/measurements.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"raw_bytes": measured.raw_bytes, "encoded_bytes": measured.encoded_bytes, "chunks": measured.chunks.size()}))
	report.close()
	world.queue_free()
	# A clean confirmed pilot .1 snapshot must remain clean until gameplay
	# converts it; the next revision carries v7 plus explicit legacy credits.
	var migration_id := await phone.create_world("Piloto v6", self)
	var pilot: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/solo_v06.json"))
	pilot.owner_uid = phone.uid
	pilot.world_id = migration_id
	pilot.world_name = "Piloto v6"
	var old_phone := phone.account(migration_id)
	await old_phone.write(pilot, self)
	check((await sync.sync(old_phone, phone, pilot)).ok, "Fixture v6 confirma base real do protocolo")
	await sync.refresh_library(pc)
	var new_pc := pc.account(migration_id)
	var old_prepared: Dictionary = await sync.prepare(new_pc, pc)
	check(old_prepared.ok and old_prepared.data.version == 6 and CloudCodec.hash_state(old_prepared.data) == new_pc.sync_state.hash, "Download v6 conserva hash sem conversão durante leitura")
	var converted: Dictionary = old_prepared.data.duplicate(true)
	var converter := SoloCampaign.new()
	converter.restore(converted.campaign)
	converted.campaign = converter.capture()
	converted.version = SaveStore.VERSION
	converter.free()
	await new_pc.write(converted, self)
	check((await sync.sync(new_pc, pc, converted)).ok and new_pc.sync_state.revision == 2, "Conversão v6 para v7 publica revisão sem falso conflito")
	var on_phone: Dictionary = await sync.prepare(old_phone, phone)
	check(on_phone.ok and on_phone.data.version == 7 and on_phone.data.campaign.legacy_migrated and on_phone.data.campaign.components == pilot.campaign.components, "Retorno PC para celular conserva créditos e componentes")
	sync.client = actual
	sync.config.enabled = false
	service.queue_free()
	print("WORLD SYNC: %d verificações, %d falhas" % [checks, failures])
	quit(1 if failures else 0)
