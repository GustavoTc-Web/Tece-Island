extends SceneTree

var failures := 0
var session: Node
var pressed_count := 0
var requested_count := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	print("PASS: " if value else "FAIL: ", label)
	if not value: failures += 1

func step() -> void:
	for i in range(3): await process_frame

func find_button(text: String) -> Button:
	for node in session.menu.find_children("*", "Button", true, false):
		if node.text == text: return node
	return null

func click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event)
	await step()

func run() -> void:
	root.size = Vector2i(960, 540)
	session = load("res://scenes/main.tscn").instantiate()
	root.add_child(session)
	await step()
	var solo := find_button("Jogar solo")
	solo.pressed.connect(func(): pressed_count += 1)
	session.menu.solo_requested.connect(func(): requested_count += 1)
	check(not solo.disabled and solo.can_process(), "Botão habilitado e processando")
	print("solo_requested connections: ", session.menu.solo_requested.get_connections())
	await click(solo)
	check(pressed_count == 1 and requested_count == 1, "Mouse emite pressed e solo_requested")
	check(is_instance_valid(session.game) and session.menu == null, "Mouse abre mapa solo")
	if is_instance_valid(session.game):
		check(session.game.get_script() != null and session.game.get_node("Structures").player != null, "Mapa inicializado")
		check(session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "Solo usa rede offline")
		var player: Node2D = session.game.get_node("WorldObjects/Player")
		var point := player.position
		session.game.get_node("HUD").set_panel("inventory")
		await step()
		check(paused and not player.can_process() and player.position == point, "Inventário mantém pausa da simulação")
		await click(session.game.get_node("ExitUI").get_child(0))
		check(session.menu != null and session.game == null and not paused, "Retorno por mouse durante pausa")
	else:
		session.return_to_menu("Teste")
	await step()
	solo = find_button("Jogar solo")
	solo.grab_focus()
	check(solo.has_focus(), "Solo aceita foco de teclado")
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.pressed = down
		root.push_input(event)
	await step()
	check(session.menu == null and is_instance_valid(session.game), "Enter abre solo novamente")
	session.return_to_menu("Teste")
	await step()
	await click(find_button("Criar partida de teste"))
	check(session.menu == null and is_instance_valid(session.game) and session.multiplayer.multiplayer_peer is ENetMultiplayerPeer, "Mouse cria anfitrião")
	await session.leave_game()
	await step()
	check(session.menu != null and session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "Anfitrião retorna e limpa rede")
	await click(find_button("Jogar solo"))
	check(is_instance_valid(session.game) and session.game.name == "Solo", "Solo após multiplayer")
	session.return_to_menu("Fim")
	await step()
	var invalid := PackedScene.new()
	var bare := Node.new()
	invalid.pack(bare)
	bare.free()
	var fixture := "res://tests/menu_invalid_fixture.tscn"
	ResourceSaver.save(invalid, fixture)
	check(session.prepare_game(fixture) == null and session.game == null and session.menu.status.text.contains("tente novamente"), "Falha de cena mantém menu com mensagem")
	DirAccess.remove_absolute(fixture)
	await step()
	await click(find_button("Jogar solo"))
	check(is_instance_valid(session.game) and session.game.name == "Solo", "Nova tentativa após falha abre solo")
	session.return_to_menu("Fim")
	session.queue_free()
	await step()
	print("MENU failures: ", failures)
	quit(1 if failures else 0)
