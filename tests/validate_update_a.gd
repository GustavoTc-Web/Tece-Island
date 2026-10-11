extends SceneTree
var checks := 0
var failures := 0
var world: Node
var inv: ResourceInventory
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1
	print("PASS: " if value else "FAIL: ", label)
func step() -> void:
	for i in range(3):
		await physics_frame
		await process_frame
func key(code: Key, shift: bool = false) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.shift_pressed = shift
		event.pressed = down
		root.push_input(event)
func run() -> void:
	root.size = Vector2i(960, 540)
	world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await step()
	inv = world.get_node("Inventory")
	check(inv.capacity == 7, "Inventário inicial de sete espaços")
	inv.add_resource("madeira", 4)
	inv.add_resource("fibra", 12)
	check(inv.craft("mochila") and inv.capacity == 9 and inv.count_item("mochila") == 0, "Primeira bolsa equipada automaticamente: 7 para 9")
	check(world.get_node("HUD").slot_buttons.size() == 9 and world.get_node("HUD").quick_buttons.size() == 5, "HUD sincroniza nove espaços e barra de cinco")
	inv.add_resource("cama", 9)
	var before := inv.slots
	check(not inv.remove_backpack() and inv.slots == before, "Retirada cheia bloqueada sem perda")
	check(not DropRules.discard(inv, -2, true, world.get_node("WorldObjects/Player"), world.get_node("WorldObjects"), world.MAP_SIZE), "Drop da bolsa bloqueado quando nove itens não cabem")
	inv.take_slot(8, 1)
	inv.take_slot(7, 1)
	check(not inv.remove_backpack(), "Sete itens mais bolsa também bloqueiam retirada")
	inv.take_slot(6, 1)
	check(inv.remove_backpack() and inv.capacity == 7 and inv.count_item("mochila") == 1, "Retirada guarda a bolsa no inventário")
	check(inv.equip_backpack(6) and inv.capacity == 9 and not inv.equip_backpack(6), "Reequipar não acumula bônus")
	inv.reset()
	inv.add_resource("machado_madeira")
	inv.add_resource("machado_pedra")
	inv.select_quick(0)
	check(inv.equipped_tool() == "machado_madeira", "Seleciona ferramenta exata mesmo com versão melhor")
	inv.add_resource("madeira", 8)
	inv.select_quick(2)
	key(KEY_Q)
	await step()
	check(inv.count_item("madeira") == 7, "Q joga somente uma unidade")
	key(KEY_Q, true)
	await step()
	check(inv.slot_data(2).is_empty() and not inv.slot_data(1).is_empty(), "Shift+Q joga pilha sem compactar espaços")
	key(KEY_4)
	check(inv.selected_index == 3 and inv.equipped_tool() == "maos", "Tecla 4 seleciona espaço vazio e mãos")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.position = Vector2(940, 510)
	inv.select_quick(4)
	root.push_input(wheel)
	check(inv.selected_index == 0, "Scroll retorna do quinto ao primeiro")
	world.get_node("HUD").set_panel("inventory")
	root.push_input(wheel)
	key(KEY_Q)
	check(inv.selected_index == 0 and inv.count_item("machado_madeira") == 1, "Painel bloqueia scroll e descarte por atalho")
	world.get_node("HUD").set_panel("")
	inv.reset()
	inv.add_item({"item": "pistola", "quantity": 1, "loaded": 6})
	check(DropRules.discard(inv, 0, true, world.get_node("WorldObjects/Player"), world.get_node("WorldObjects"), world.MAP_SIZE), "Arma colocada em ponto acessível")
	var drop: ResourceDrop = world.get_node("WorldObjects").get_child(-1)
	check(inv.slot_data(0).is_empty() and drop.attributes.loaded == 6, "Descarte conserva carregador")
	check(drop.collect(inv) == 1 and inv.slot_data(0).loaded == 6, "Coleta conserva carregador sem duplicar arma")
	inv.swap_slots(0, 4)
	inv.select_quick(4)
	check(inv.loaded_ammo("pistola") == 6 and inv.slot_data(0).is_empty(), "Mover item mantém atributos e seleção exata")
	world.queue_free()
	await step()
	print("UPDATE A: ", checks, " verificações, ", failures, " falhas")
	quit(1 if failures else 0)
