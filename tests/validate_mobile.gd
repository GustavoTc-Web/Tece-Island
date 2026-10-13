extends SceneTree
var failures := 0
var checks := 0
var session: Node
var controls: Control
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1
	print("PASS: " if value else "FAIL: ", label)
func step(frames: int = 3) -> void:
	for i in range(frames):
		await physics_frame
		await process_frame
func touch(index: int, point: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = down
	root.push_input(event, true)
func drag(index: int, point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	root.push_input(event, true)
func tap_button(button: Button) -> void:
	var ancestor := button.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(button)
		ancestor = ancestor.get_parent()
	await step()
	var point := button.get_global_rect().get_center()
	touch(8, point, true)
	touch(8, point, false)
func find_button(node: Node, text: String) -> Button:
	if text == "Jogar solo": text = "Continuar"
	for button in node.find_children("*", "Button", true, false):
		if button.text == text: return button
	return null
func run() -> void:
	root.size = Vector2i(960, 540)
	var mobile := root.get_node("MobileInput")
	var auth := root.get_node("FirebaseAuth")
	var original_config: Dictionary = auth.config.duplicate(true)
	auth.config.enabled = false
	print("TEST: fixture de gameplay offline; nenhuma autenticação positiva simulada")
	mobile.set_enabled(true)
	session = load("res://scenes/main.tscn").instantiate()
	session.set_script(load("res://tests/native_fixture_session.gd"))
	root.add_child(session)
	await step()
	await tap_button(find_button(session.menu, "Jogar solo"))
	await step()
	check(session.menu == null and session.game != null, "Toque abre solo pelo menu")
	var world: Node = session.game
	var player: CharacterBody2D = world.get_node("WorldObjects/Player")
	var inv: ResourceInventory = world.get_node("Inventory")
	var hud := world.get_node("HUD")
	var interaction := player.get_node("Interaction")
	controls = mobile.overlay
	touch(0, controls.centers.move, true)
	touch(1, controls.centers.aim, true)
	drag(0, controls.centers.move + Vector2(60, 0))
	drag(1, controls.centers.aim + Vector2(0, -60))
	await step()
	check(player.touch_movement.x > 0 and interaction.touch_aim.y < 0, "Dois dedos: movimento e mira independentes")
	touch(2, controls.centers.aim + Vector2(60, 0), true)
	check(controls.fingers.aim == 1, "Terceiro dedo não captura joystick ocupado")
	touch(0, controls.centers.move, false)
	check(player.touch_movement == Vector2.ZERO and interaction.touch_aim != Vector2.ZERO, "Soltar movimento mantém mira do outro dedo")
	touch(1, controls.centers.aim, false)
	check(interaction.touch_aim == Vector2.ZERO, "Soltar mira interrompe ataque")
	inv.add_item({"item": "pistola", "quantity": 1, "loaded": 8})
	inv.add_item({"item": "municao_pistola", "quantity": 8})
	await tap_button(hud.quick_buttons[0])
	check(inv.selected_index == 0 and inv.equipped_tool() == "pistola", "Barra por toque seleciona item exato")
	touch(1, controls.centers.aim + Vector2(60, 0), true)
	await step(20)
	check(inv.loaded_ammo("pistola") == 7, "Joystick atira respeitando intervalo existente")
	await step(15)
	check(inv.loaded_ammo("pistola") == 6, "Ataque mantido repete com cadência")
	touch(1, controls.centers.aim, false)
	var ammo := inv.loaded_ammo("pistola")
	await step(30)
	check(inv.loaded_ammo("pistola") == ammo, "Soltar não deixa disparos presos")
	await tap_button(find_button(controls, "Recarregar"))
	await step(80)
	check(inv.loaded_ammo("pistola") == 8, "Botão recarrega pela lógica existente")
	inv.reset()
	inv.add_item({"item": "carne_cozida", "quantity": 3})
	player.get_node("Needs").hunger = 20
	await tap_button(hud.quick_buttons[0])
	var use: Button = controls.use_button
	touch(3, use.get_global_rect().get_center(), true)
	await step(45)
	check(inv.count_item("carne_cozida") == 3, "Consumível não repete ao manter dedo no botão")
	touch(3, use.get_global_rect().get_center(), false)
	check(inv.count_item("carne_cozida") == 2, "Soltar botão consome uma unidade")
	touch(0, controls.centers.move + Vector2(60, 0), true)
	await tap_button(find_button(controls, "Inventário"))
	await step()
	check(paused and player.touch_movement == Vector2.ZERO and interaction.touch_aim == Vector2.ZERO, "Abrir painel cancela entradas mantidas e pausa solo")
	hud.select_slot(0)
	await tap_button(find_button(hud, "Mover / trocar"))
	await tap_button(hud.slot_buttons[4])
	check(inv.slot_data(4).get("item", "") == "carne_cozida" and inv.slot_data(0).is_empty(), "Origem e destino por toque reorganizam itens")
	await tap_button(find_button(hud, "Jogar 1"))
	check(inv.slot_data(4).get("quantity", 0) == 1, "Descarte pelo inventário remove uma unidade")
	await tap_button(find_button(hud.get_node("InventoryPanel"), "Fechar"))
	await step()
	check(not paused and hud.current_panel == "", "Fechar painel funciona sem teclado")
	touch(0, controls.centers.move + Vector2(60, 0), true)
	touch(1, controls.centers.aim + Vector2(60, 0), true)
	mobile._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(player.touch_movement == Vector2.ZERO and interaction.touch_aim == Vector2.ZERO, "Perda de foco limpa movimento e ataque")
	root.size = Vector2i(540, 960)
	await step()
	check(controls.portrait and not controls.rotate.visible and not player.controls_blocked and player.touch_movement == Vector2.ZERO, "Retrato permite jogar e cancela entradas da orientação anterior")
	root.size = Vector2i(960, 540)
	await step()
	check(not controls.portrait and not player.controls_blocked, "Retorno horizontal libera controles")
	inv.reset()
	inv.add_item({"item": "cama", "quantity": 1})
	var structures := world.get_node("Structures")
	check(structures.start_placement(0), "Colocação usa sistema existente")
	await step()
	var terrain: Vector2 = player.get_canvas_transform() * (player.global_position + Vector2(0, 85))
	touch(5, terrain, true)
	touch(5, terrain, false)
	await step()
	check(structures.active and inv.count_item("cama") == 1, "Toque no terreno só posiciona prévia")
	await tap_button(find_button(controls, "Confirmar"))
	await step()
	check(not structures.active and inv.count_item("cama") == 0, "Confirmação explícita coloca cama")
	inv.add_item({"item": "fogueira", "quantity": 1})
	structures.start_placement(0)
	await step()
	await tap_button(find_button(controls, "Cancelar"))
	check(not structures.active and inv.count_item("fogueira") == 1, "Cancelar conserva objeto")
	hud.set_panel("inventory")
	await step()
	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute("res://.tools/screenshots")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.tools/screenshots/mobile-native.png")
	hud.set_panel("menu")
	await step()
	await tap_button(find_button(hud.menu_view, "Voltar ao menu principal"))
	await step()
	check(session.menu != null and session.game == null and not paused, "Menu por toque responde a partir de partida pausada")
	mobile.set_enabled(false)
	session.queue_free()
	await step()
	auth.config = original_config
	print("MOBILE: ", checks, " verificações, ", failures, " falhas")
	quit(1 if failures else 0)
