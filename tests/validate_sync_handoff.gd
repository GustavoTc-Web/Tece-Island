extends SceneTree
const MEMORY_SERVICE = preload("res://tests/validate_world_sync.gd")
var failures := 0
var checks := 0
class DelayedRead extends Node:
	var backend: Node
	var delay_next := false
	signal resume
	func head(uid: String, id: String) -> Dictionary:
		if delay_next:
			delay_next = false
			await resume
		return backend.head(uid, id)
	func list_worlds(uid: String) -> Dictionary: return backend.list_worlds(uid)
	func download(uid: String, id: String, head: Dictionary) -> Dictionary: return backend.download(uid, id, head)
	func publish(uid: String, id: String, state: Dictionary, previous: Dictionary, title: String) -> Dictionary: return backend.publish(uid, id, state, previous, title)
	func prune(_uid: String, _id: String) -> void: pass
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS: " if ok else "FAIL: ", label)
func wood(data: Dictionary) -> int:
	var count := 0
	for slot in data.get("inventory", {}).get("slots", []):
		if slot.get("item", "") == "madeira": count += int(slot.quantity)
	return count
func add_wood(data: Dictionary, amount: int) -> void:
	var inventory := ResourceInventory.new()
	inventory.restore_state(data.inventory)
	inventory.add_resource("madeira", amount)
	data.inventory = inventory.network_state()
	inventory.free()
func open_world(main: Node, library: WorldLibrary, id: String, data: Dictionary) -> Node2D:
	await main.clear_scene(false)
	var world: Node2D = load("res://scenes/world.tscn").instantiate()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	world.owner_uid = library.uid
	world.world_id = id
	world.world_name = library.entry(id).name
	world.world_library = library
	world.account_store = library.account(id)
	await world.account_store.read(self)
	world.initial_progress = data
	world.persistence_enabled = true
	main.game = world
	main.library = library
	main.add_child(world)
	world.get_node("HUD").set_panel("menu")
	for index in range(3): await process_frame
	return world
func run() -> void:
	print("TEST: troca entre aparelhos com mundo real e transporte controlado, sem contas reais")
	var auth := root.get_node("FirebaseAuth")
	auth.config.enabled = false
	var sync := root.get_node("WorldSync")
	var service := MEMORY_SERVICE.MemoryService.new()
	root.add_child(service)
	sync.client = service
	sync.config = {"enabled": true, "allowed_uids": [], "interval_seconds": 120}
	var folder := "res://.tools/handoff-%d" % Time.get_ticks_usec()
	var pc := WorldLibrary.new()
	pc.configure("handoff-own-fixture", folder + "/pc")
	pc.native_only = true
	await pc.load_index(self)
	var id := await pc.create_world("Troca PC-celular", self)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.set_script(load("res://tests/native_fixture_session.gd"))
	root.add_child(main)
	await main.start_solo()
	var world: Node2D = main.game
	world.owner_uid = pc.uid
	world.world_id = id
	world.world_name = pc.entry(id).name
	world.world_library = pc
	world.account_store = pc.account(id)
	main.library = pc
	world.get_node("Inventory").add_resource("madeira", 7)
	world.get_node("HUD").set_panel("menu")
	for index in range(4): await process_frame
	await world.save_progress(true)
	var account: AccountProgress = world.account_store
	var saved := await account.read(self)
	await sync.sync(account, pc, saved)
	var confirmed := await account.read(self)
	check(CloudCodec.hash_state(confirmed) == confirmed._sync.hash, "PC confirma cópia local exatamente igual à revisão enviada")
	await main.return_to_menu("Troca de aparelho")
	for index in range(3): await process_frame
	var after_lobby := await pc.account(id).read(self)
	var differing := []
	for field in CloudCodec.payload(confirmed):
		if JSON.stringify(confirmed[field]) != JSON.stringify(after_lobby.get(field)): differing.append(field)
	print("LOBBY DIFF: ", differing)
	check(CloudCodec.hash_state(after_lobby) == after_lobby._sync.hash, "Retorno ao lobby sem gameplay conserva igualdade com a base confirmada")
	var phone := WorldLibrary.new()
	phone.configure(pc.uid, folder + "/phone")
	phone.native_only = true
	await phone.load_index(self)
	await sync.refresh_library(phone)
	var phone_account := phone.account(id)
	var prepared: Dictionary = await sync.prepare(phone_account, phone)
	var phone_progress: Dictionary = prepared.data
	phone_progress.inventory.slots[0].quantity += 3
	await phone_account.write(phone_progress, self)
	await sync.sync(phone_account, phone, phone_progress)
	var retry: Dictionary = await sync.sync(pc.account(id), pc, after_lobby)
	check(not retry.get("conflict", false) and not sync.conflicts.has(sync.key(account)), "Tentativa com snapshot local limpo reconhece avanço remoto sem criar conflito")
	var next: Dictionary = await sync.prepare(pc.account(id), pc)
	check(next.get("ok", false) and not next.get("conflict", false) and next.data.inventory.slots[0].quantity == 10, "PC recebe avanço exclusivo do celular depois de sincronizar e voltar ao lobby")
	check(not sync.conflicts.has(sync.key(account)), "Carregamento remoto limpo não deixa conflito antigo travando a próxima partida")
	var before := await pc.account(id).read(self)
	var restored := await open_world(main, pc, id, before)
	check(CloudCodec.hash_state(restored.progress_store.capture()) == before._sync.hash, "Carregar o mundo completo e pausar mantém a base confirmada")
	# A remote-only advance during the final save at the real lobby transition.
	phone_progress = await phone_account.read(self)
	phone_progress.inventory.slots[0].quantity += 4
	await phone_account.write(phone_progress, self)
	await sync.sync(phone_account, phone, phone_progress)
	sync.attempted_at[sync.key(restored.account_store)] = -10000 # Own fixture, no real waits or cloud traffic.
	await main.return_to_menu("Avanço remoto antes de sair")
	for index in range(3): await process_frame
	check(main.game == null and main.menu != null and not sync.conflicts.has(sync.key(account)), "Save final do retorno ao lobby não cria conflito quando só a nuvem avançou")
	check(CloudCodec.hash_state(await pc.account(id).read(self)) == before._sync.hash, "Envio adiado não troca a base nem sobrescreve a cópia local")
	next = await sync.prepare(pc.account(id), pc)
	check(next.get("ok", false) and next.data.inventory.slots[0].quantity == 14, "Reentrada após o save final carrega automaticamente o progresso remoto")
	# Delay a remote read while unsaved gameplay appears on PC. Never overwrite it.
	restored = await open_world(main, pc, id, next.data)
	await restored.save_progress(true)
	var clean: Dictionary = await restored.account_store.read(self)
	phone_progress = await phone_account.read(self)
	add_wood(phone_progress, 2)
	await phone_account.write(phone_progress, self)
	await sync.sync(phone_account, phone, phone_progress)
	var delayed := DelayedRead.new()
	delayed.backend = service
	delayed.delay_next = true
	root.add_child(delayed)
	sync.client = delayed
	sync.sync(restored.account_store, pc, clean)
	restored.get_node("Inventory").add_resource("madeira", 5)
	await restored.save_progress(true)
	delayed.resume.emit()
	while sync.busy.has(sync.key(account)): await process_frame
	check(wood(await restored.account_store.read(self)) == 19, "Alteração local durante consulta remota é preservada inteira")
	await main.return_to_menu("Alterações independentes")
	for index in range(3): await process_frame
	sync.client = service
	var own := pc.account(id)
	next = await sync.prepare(own, pc)
	check(next.get("conflict", false) and sync.conflicts.has(sync.key(own)), "Mudanças independentes continuam exigindo resolução no lobby")
	main.library = pc
	main.resolve_world(own)
	check(not main.find_children("*", "ConfirmationDialog", true, false).is_empty(), "Conflito real mantém o diálogo Duas versões do mundo")
	var resolved: Dictionary = await sync.resolve(own, pc, false)
	check(resolved.get("ok", false) and wood(await pc.account(id).read(self)) == 16 and wood(await pc.account(resolved.copy_id).read(self)) == 19, "Continuar nuvem preserva a versão independente do PC como outro mundo")
	check(service.documents.has(service.location(pc.uid, resolved.copy_id)), "Ambas as versões ficam disponíveis também na nuvem")
	main.queue_free()
	await process_frame
	print("SYNC HANDOFF: %d verificações, %d falhas" % [checks, failures])
	quit(1 if failures else 0)
