extends SceneTree
var checks := 0
var failures := 0
class FailingStore extends SaveStore:
	var fail := false
	func write(data: Dictionary) -> bool:
		if fail:
			error = "Falha de gravação injetada no teste."
			return false
		return super.write(data)
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1
	print("PASS: " if value else "FAIL: ", label)
func run() -> void:
	print("TEST: fixture de gameplay offline e falha de I/O; sem autenticação simulada")
	var auth := root.get_node("FirebaseAuth")
	var original: Dictionary = auth.config.duplicate(true)
	auth.config.enabled = false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.set_script(load("res://tests/native_fixture_session.gd"))
	root.add_child(main)
	await main.start_solo()
	var world: Node2D = main.game
	var store := FailingStore.new()
	store.path = world.progress_path
	world.progress_store.store = store
	check(await world.save_progress(true), "Save inicial válido antes de sair")
	var bytes := FileAccess.get_file_as_string(store.path)
	main.set_transition(true)
	var event := InputEventKey.new()
	event.physical_keycode = KEY_J
	event.pressed = true
	world.get_node("HUD")._input(event)
	check(world.get_node("HUD").current_panel == "saving" and paused and world.get_node("WorldObjects/Player").controls_blocked, "Transição de gravação bloqueia atalhos, interfaces e personagem antes de limpar a sessão")
	main.set_transition(false)
	store.fail = true
	world.get_node("Inventory").add_resource("madeira", 7)
	await main.return_to_menu("Teste")
	check(main.game == world and main.menu == null and not paused, "Falha de save conserva partida e permite retry antes do menu")
	check(FileAccess.get_file_as_string(store.path) == bytes and not world.get_node("HUD").save_button.disabled, "Último save preservado e botão de nova tentativa disponível")
	check(not await auth.logout() and main.game == world and not main.transitioning and world.get_node("HUD/Controls/Rows/Feedback").text.contains("Falha ao salvar"), "Logout voluntário falho mantém partida utilizável e informa nova tentativa")
	store.fail = false
	await main.return_to_menu("Teste")
	check(main.game == null and main.menu != null and store.read().inventory.slots[0].quantity == 7, "Nova tentativa grava antes de limpar mundo e abrir menu")
	await main.start_solo()
	check(main.game.get_node("Inventory").wood == 7, "Voltar à partida restaura alterações concluídas")
	var library := WorldLibrary.new()
	library.configure("session-own-fixture", "res://.tools/local-session-%d" % Time.get_ticks_usec())
	library.native_only = true
	await library.load_index(self)
	var id := await library.create_world("Original", self)
	world = main.game
	world.owner_uid = library.uid
	world.world_id = id
	world.world_name = "Original"
	world.world_library = library
	world.account_store = library.account(id)
	main.library = library
	await world.save_progress(true)
	var concurrent := library.account(id)
	var newer := await concurrent.read(self)
	newer.player.health = 45
	await concurrent.write(newer, self)
	world.get_node("Inventory").add_resource("madeira", 1)
	check(not await world.save_progress(true), "Disputa local real é recusada antes de substituir progresso")
	for index in range(3): await process_frame
	var dialogs := main.find_children("*", "ConfirmationDialog", true, false)
	check(not dialogs.is_empty() and paused, "Falha concorrente oferece resolução compreensível com a partida pausada")
	if not dialogs.is_empty():
		dialogs[0].confirmed.emit()
		for index in range(8): await process_frame
		check(world.world_id != id and (await main.library.account(id).read(self)).player.health == 45 and (await world.account_store.read(self)).inventory.slots[0].quantity == 8, "Escolher cópia continua partida e mantém intacta a versão da outra sessão")
	await main.clear_scene()
	main.queue_free()
	await process_frame
	auth.config = original
	print("SESSION PROGRESS: %d verificações, %d falhas" % [checks, failures])
	quit(1 if failures else 0)
