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
	store.fail = true
	world.get_node("Inventory").add_resource("madeira", 7)
	await main.return_to_menu("Teste")
	check(main.game == world and main.menu == null and not paused, "Falha de save conserva partida e permite retry antes do menu")
	check(FileAccess.get_file_as_string(store.path) == bytes and not world.get_node("HUD").save_button.disabled, "Último save preservado e botão de nova tentativa disponível")
	check(not await auth.logout() and main.game == world and not main.transitioning, "Logout voluntário falho mantém partida utilizável")
	store.fail = false
	await main.return_to_menu("Teste")
	check(main.game == null and main.menu != null and store.read().inventory.slots[0].quantity == 7, "Nova tentativa grava antes de limpar mundo e abrir menu")
	await main.start_solo()
	check(main.game.get_node("Inventory").wood == 7, "Voltar à partida restaura alterações concluídas")
	await main.clear_scene()
	main.queue_free()
	await process_frame
	auth.config = original
	print("SESSION PROGRESS: %d verificações, %d falhas" % [checks, failures])
	quit(1 if failures else 0)
