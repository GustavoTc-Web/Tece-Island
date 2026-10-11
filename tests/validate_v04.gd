extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("validate")


func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)


func step(count: int = 2) -> void:
	for i in range(count):
		await physics_frame
		await process_frame


func key(code: Key, pressed: bool = true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	root.push_input(event, true)


func tap(code: Key) -> void:
	key(code)
	key(code, false)


func mouse(point: Vector2, pressed: bool) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	event.pressed = pressed
	root.push_input(event, true)


func validate() -> void:
	# Etapa 1: espaços, pilhas, inclusão parcial e transação de fabricação.
	var inv := ResourceInventory.new()
	root.add_child(inv)
	check(inv.slots.size() == 7 and inv.wood == 0 and inv.equipped_tool() == "maos", "sete espaços vazios e mãos")
	check(inv.add_resource("madeira", 17) == 17 and inv.slots[0].quantity == 15
		and inv.slots[1].quantity == 2, "17 madeiras em pilhas de 15 e 2")
	check(inv.add_resource("madeira", 14) == 14 and inv.slots[1].quantity == 15
		and inv.slots[2].quantity == 1, "completa pilhas antes de usar vazio")
	inv.add_resource("pedra", 4)
	check(inv.slots[3].item == "pedra" and inv.wood == 31 and inv.stone == 4, "tipos não misturam e contadores somam pilhas")
	var copy := inv.slots
	copy[0].quantity = 0
	check(inv.wood == 31, "leitura da interface não altera a fonte de dados")
	inv.reset()
	check(not inv.craft("machado_madeira") and inv.wood == 0, "sem materiais não fabrica")
	inv.add_resource("madeira", 105)
	var before := inv.slots
	check(not inv.craft("machado_madeira") and inv.slots == before, "sem espaço após consumo não desconta nada")
	inv.reset()
	inv.add_resource("madeira", 93)
	check(inv.craft("machado_madeira") and inv.wood == 90 and inv.count_item("machado_madeira") == 1,
		"consumo libera pilha pequena mesmo estando todos os espaços ocupados")
	before = inv.slots
	check(not inv.craft("machado_madeira") and inv.slots == before, "ferramenta única e fabricação duplicada sem custo")
	inv.reset()
	inv.stack_limit = 2
	inv.add_resource("madeira", 4)
	check(inv.craft("machado_madeira") and inv.wood == 1, "receita consome materiais de várias pilhas")
	inv.stack_limit = 15
	inv.reset()
	inv.add_resource("madeira", 104)
	var drop := load("res://scenes/resource_drop.tscn").instantiate() as ResourceDrop
	drop.quantity = 5
	root.add_child(drop)
	check(drop.collect(inv) == 1 and drop.quantity == 4 and inv.wood == 105, "coleta parcial preserva quatro unidades no chão")
	check(drop.collect(inv) == 0 and drop.quantity == 4 and inv.wood == 105, "inventário cheio não perde nem duplica recursos")
	inv.reset()
	check(drop.collect(inv) == 4 and drop.quantity == 0 and not drop.visible, "restante pode ser recolhido depois")
	check(drop.collect(inv) == 0 and inv.wood == 4, "mesmo item esgotado não pode ser contado duas vezes")
	await step()
	check(not is_instance_valid(drop), "item totalmente recolhido é removido")
	inv.reset()
	inv.add_resource("madeira", 13)
	inv.add_resource("pedra", 8)
	for id in ResourceRules.RECIPES:
		if ItemCatalog.is_equippable(id):
			check(inv.craft(id), "receita existente preservada: " + id)
	check(inv.tools.size() == 6 and inv.wood == 0 and inv.stone == 0, "seis ferramentas usam seis espaços, mãos não usam espaço")
	before = inv.slots
	inv.equip("picareta")
	check(inv.equipped_tool() == "picareta_pedra" and inv.slots == before, "equipar melhor versão não consome nem duplica")
	inv.queue_free()
	await step()
	# Etapa 2: cenas reais, entradas, painéis, extração e coleta.
	var scene := load("res://scenes/world.tscn") as PackedScene
	var world := scene.instantiate() as Node2D
	world.get_node("Exploration").external_weapon_chance = 0
	world.get_node("Exploration").guardian_chance = 0
	root.add_child(world)
	current_scene = world
	await step()
	var player = world.get_node("WorldObjects/Player")
	var inventory := world.get_node("Inventory") as ResourceInventory
	var interaction = player.get_node("Interaction")
	var hud = world.get_node("HUD")
	var initial_count := get_nodes_in_group("harvest_resources").size()
	check(inventory.wood == 0 and inventory.stone == 0 and inventory.tools.is_empty()
		and inventory.equipped_tool() == "maos" and player.position == Vector2(1152, 768)
		and get_nodes_in_group("resource_drops").is_empty(), "nova cena começa completamente limpa")
	check(hud.slot_buttons.size() == 7, "interface com exatamente sete espaços")
	var tree := get_nodes_in_group("harvest_resources")[0] as HarvestResource
	player.position = tree.anchor() + Vector2(-45, 0)
	player.facing = Vector2.RIGHT
	await step()
	check(interaction.find_target(Vector2(-999, -999), true) == tree, "F seleciona à frente independente do cursor")
	player.facing = Vector2.LEFT
	check(interaction.find_target(tree.anchor(), true) == null, "F não seleciona recurso atrás")
	player.facing = Vector2.RIGHT
	player.position = tree.anchor() + Vector2(-81, 0)
	check(not interaction.hit_at(tree.anchor()) and tree.progress == 0, "alcance preservado")
	player.position = tree.anchor() + Vector2(-45, 0)
	await step()
	var blocker := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 5
	collision.shape = shape
	blocker.add_child(collision)
	blocker.position = player.position + Vector2(20, 0)
	world.add_child(blocker)
	await step()
	check(interaction.find_target(tree.anchor()) == null and interaction.find_target(Vector2.ZERO, true) == null,
		"linha de visão bloqueia tanto cursor quanto F")
	blocker.queue_free()
	await step()
	key(KEY_F)
	check(tree.progress > 0 and interaction.key_held, "toque em F aplica primeiro golpe")
	var first := tree.progress
	mouse(player.get_canvas_transform() * tree.anchor(), true)
	check(tree.progress == first, "F e mouse simultâneos não duplicam golpe")
	await create_timer(ResourceRules.INTERVAL.maos * 0.55).timeout
	check(tree.progress == first, "segurar respeita intervalo configurado com mãos")
	await create_timer(ResourceRules.INTERVAL.maos * 0.55).timeout
	check(is_equal_approx(tree.progress, 2.0 / 6.0), "segurar repete um golpe após o intervalo")
	key(KEY_F, false)
	mouse(player.get_canvas_transform() * tree.anchor(), false)
	var stopped := tree.progress
	await create_timer(ResourceRules.INTERVAL.maos * 1.1).timeout
	check(tree.progress == stopped, "soltar ambas as entradas interrompe golpes")
	interaction.cooldown = 0
	key(KEY_F)
	tap(KEY_I)
	await step()
	stopped = tree.progress
	await create_timer(ResourceRules.INTERVAL.maos * 1.1).timeout
	check(tree.progress == stopped and not interaction.key_held and not interaction.mouse_held,
		"abrir painel interrompe golpe contínuo")
	key(KEY_F, false)
	check(hud.current_panel == "inventory" and player.controls_blocked, "I abre inventário e bloqueia jogo")
	var panel_position: Vector2 = player.position
	Input.action_press("move_right")
	await step(5)
	Input.action_release("move_right")
	check(player.position == panel_position, "painel bloqueia movimento real")
	tap(KEY_C)
	check(hud.current_panel == "crafting" and not hud.get_node("InventoryPanel").visible, "C troca de painel sem sobreposição")
	tap(KEY_ESCAPE)
	check(hud.current_panel == "" and not player.controls_blocked, "Esc fecha painel atual")
	# Conclui árvore com golpes separados, respeitando o relógio normal.
	while is_instance_valid(tree) and not tree.exhausted:
		if interaction.cooldown > 0:
			await create_timer(interaction.cooldown + 0.03).timeout
		interaction.hit_at(tree.anchor())
	check(inventory.wood == 0 and get_nodes_in_group("resource_drops").size() == 1,
		"árvore derruba recurso sem crédito automático")
	check(not tree.apply_hit("maos") and get_nodes_in_group("resource_drops").size() == 1,
		"árvore esgotada gera uma única recompensa")
	await step()
	drop = get_nodes_in_group("resource_drops")[0]
	check(drop.resource == "madeira" and drop.quantity == 5
		and drop.position == player.position, "recompensa de madeira fica em ponto acessível")
	player.position += Vector2(100, 0)
	tap(KEY_E)
	check(inventory.wood == 0 and drop.quantity == 5, "E fora do alcance não coleta")
	player.position = drop.position
	await step()
	tap(KEY_I)
	tap(KEY_E)
	check(drop.quantity == 5 and inventory.wood == 0, "painel bloqueia coleta")
	tap(KEY_I)
	tap(KEY_E)
	check(inventory.wood == 5 and drop.quantity == 0, "E recolhe recompensa e atualiza inventário")
	await step()
	tap(KEY_C)
	hud.recipe_buttons.picareta_madeira.pressed.emit()
	check(inventory.count_item("picareta_madeira") == 1 and inventory.wood == 2, "fabrica picareta com madeira recolhida")
	tap(KEY_C)
	tap(KEY_KP_2)
	check(inventory.equipped_tool() == "picareta_madeira" and player.equipped == "picareta_madeira",
		"teclado numérico equipa e atualiza desenho do personagem")
	tap(KEY_1)
	check(inventory.equipped_tool() == "maos", "1 retorna às mãos")
	tap(KEY_2)
	tap(KEY_5)
	check(inventory.equipped_tool() == "maos" and inventory.selected_index == 4,
		"Espaço vazio seleciona mãos")
	tap(KEY_I)
	var tool_slot := -1
	for i in range(inventory.slots.size()):
		if inventory.slots[i].get("item", "") == "picareta_madeira": tool_slot = i
	await step()
	var slot_point: Vector2 = hud.slot_buttons[tool_slot].get_global_rect().get_center()
	mouse(slot_point, true)
	mouse(slot_point, false)
	before = inventory.slots
	var equip_point: Vector2 = hud.get_node("InventoryPanel/Panel/Scroll/Rows/Equip").get_global_rect().get_center()
	mouse(equip_point, true)
	mouse(equip_point, false)
	check(inventory.equipped_tool() == "picareta_madeira" and inventory.slots == before,
		"selecionar espaço e Equipar não altera itens")
	tap(KEY_ESCAPE)
	tap(KEY_1)
	tap(KEY_2)
	check(inventory.equipped_tool() == "picareta_madeira", "fileira superior 2 seleciona picareta no segundo espaço")
	var rock: HarvestResource
	for node in get_nodes_in_group("harvest_resources"):
		if node.resource == "pedra": rock = node; break
	player.position = rock.anchor() + Vector2(-45, 0)
	player.facing = Vector2.RIGHT
	await step()
	if interaction.cooldown > 0:
		await create_timer(interaction.cooldown + 0.03).timeout
	key(KEY_F)
	await create_timer(ResourceRules.INTERVAL.madeira * 5 + 0.2).timeout
	key(KEY_F, false)
	await step()
	check(not is_instance_valid(rock) and inventory.stone == 0, "picareta equipada minera com F e pedra permanece no chão")
	drop = get_nodes_in_group("resource_drops")[0]
	check(drop.resource == "pedra" and drop.quantity == 4, "rocha derruba quatro pedras")
	tap(KEY_E)
	check(inventory.stone == 4, "pedra creditada somente com E")
	check(inventory.craft("picareta_pedra") and inventory.count_item("picareta_pedra") == 1 and inventory.equipped_tool() == "picareta_madeira",
		"Fabricar picareta melhor preserva seleção exata")
	var other_tree := get_nodes_in_group("harvest_resources")[0] as HarvestResource
	player.position = other_tree.anchor() + Vector2(-45, 0)
	player.facing = Vector2.LEFT
	inventory.equip("maos")
	interaction.cooldown = 0
	await step()
	var point: Vector2 = player.get_canvas_transform() * other_tree.anchor()
	mouse(point, true)
	check(other_tree.progress > 0, "mouse aponta recurso mesmo atrás da direção de movimento")
	await create_timer(ResourceRules.INTERVAL.maos * 1.1).timeout
	check(is_equal_approx(other_tree.progress, 2.0 / 6.0), "somente mouse segurado repete com intervalo único")
	mouse(point, false)
	stopped = other_tree.progress
	await create_timer(ResourceRules.INTERVAL.maos * 1.1).timeout
	check(other_tree.progress == stopped, "soltar apenas mouse interrompe uso contínuo")
	# Mensagem de inventário cheio, escolha de um drop e inclusão parcial via E.
	inventory.reset()
	inventory.add_resource("madeira", 105)
	world._spawn_drop("madeira", 5)
	drop = get_nodes_in_group("resource_drops")[0]
	world._spawn_drop("pedra", 4)
	var farther := get_nodes_in_group("resource_drops")[1] as ResourceDrop
	farther.position += Vector2(40, 0)
	tap(KEY_E)
	check(drop.quantity == 5 and inventory.wood == 105
		and hud.get_node("Controls/Rows/Feedback").text == "Inventário cheio", "E com inventário cheio preserva recurso e informa")
	inventory.reset()
	inventory.add_resource("madeira", 104)
	tap(KEY_E)
	check(drop.quantity == 4 and inventory.wood == 105, "E faz coleta parcial em inventário real")
	check(farther.quantity == 4 and inventory.stone == 0, "E coleta somente o drop mais próximo")
	# Suja deliberadamente o estado antes de reinstanciar a cena completa.
	inventory.add_resource("madeira", 17)
	world._spawn_drop("pedra", 4)
	player.position = Vector2(600, 700)
	world.queue_free()
	await step()
	world = scene.instantiate()
	world.get_node("Exploration").external_weapon_chance = 0
	world.get_node("Exploration").guardian_chance = 0
	root.add_child(world)
	current_scene = world
	await step()
	inventory = world.get_node("Inventory")
	player = world.get_node("WorldObjects/Player")
	check(inventory.wood == 0 and inventory.stone == 0 and inventory.tools.is_empty()
		and inventory.equipped_tool() == "maos" and player.position == Vector2(1152, 768)
		and get_nodes_in_group("resource_drops").is_empty()
		and get_nodes_in_group("harvest_resources").size() == initial_count,
		"reinício completo limpa materiais, ferramentas, posição, drops e restaura cenário")
	print("RESULT: ", checks, " verificações, ", failures, " falhas")
	quit(1 if failures > 0 else 0)
