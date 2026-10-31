extends SceneTree

var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if value: print("PASS: ", label)
	else:
		failures += 1
		push_error(label)
func step(frames: int = 2) -> void:
	for i in range(frames):
		await physics_frame
		await process_frame
func tap(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)
func mouse(point: Vector2, button: int = MOUSE_BUTTON_LEFT) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = button
		event.pressed = pressed
		root.push_input(event, true)
func make_world(options: Dictionary) -> Node2D:
	var world := load("res://scenes/world.tscn").instantiate() as Node2D
	for key in options: world.get_node("Exploration").set(key, options[key])
	root.add_child(world)
	world.get_node("EnemySpawner").set_physics_process(false)
	return world

func accessible_cells(player: CharacterBody2D) -> Dictionary:
	# Busca sobre a física do mapa, com o raio real do jogador; sem depender do desenho.
	var shape := CircleShape2D.new()
	shape.radius = 10
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = 9
	var start := Vector2i(player.position / 24)
	var queue: Array[Vector2i] = [start]
	var seen := {start: true}
	var free := {start: true}
	var index := 0
	while index < queue.size():
		var cell := queue[index]
		index += 1
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + direction
			if seen.has(next) or not WorldTerrain.contains(Vector2(next) * 24 + Vector2(12, 12)): continue
			seen[next] = true
			query.transform = Transform2D(0, Vector2(next) * 24 + Vector2(12, 12))
			if player.get_world_2d().direct_space_state.intersect_shape(query).is_empty():
				free[next] = true
				queue.append(next)
	return free

func accessible_point(point: Vector2, cells: Dictionary) -> bool:
	var cell := Vector2i(point / 24)
	for offset in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if cells.has(cell + offset): return true
	return false
func run() -> void:
	var world := make_world({"loot_chance": 1.0, "guardian_chance": 1.0, "weapon_chance": 1.0, "pistol_weight": 1.0, "external_weapon_chance": 1.0, "random_seed": 77})
	await step()
	var all_valid := true
	for building in get_nodes_in_group("buildings"):
		all_valid = all_valid and building.has_loot and building.has_guardian and building.rolled_weapon == "pistola"
	check(all_valid, "Probabilidades configuráveis: loot/guardião/arma/pistola 100%")
	check(get_nodes_in_group("resource_drops").size() == 2, "Mesmo com 10 pontos sorteados, só uma arma externa + munição")
	var player = world.get_node("WorldObjects/Player")
	var reachable := accessible_cells(player)
	for building in get_nodes_in_group("buildings"):
		check(accessible_point(building.loot.global_position, reachable), "Caminho físico da clareira até recipiente: " + building.name)
	var free := true
	var shape := CircleShape2D.new()
	shape.radius = 12
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = 1
	for enemy in get_nodes_in_group("enemies"):
		query.transform = Transform2D(0, enemy.position)
		free = free and player.get_world_2d().direct_space_state.intersect_shape(query).is_empty()
	check(free, "Guardiões nascem livres de paredes/obstáculos")
	world.queue_free()
	await step()
	world = make_world({"loot_chance": 0.0, "guardian_chance": 1.0, "weapon_chance": 1.0, "external_weapon_chance": 0.0, "random_seed": 77})
	all_valid = true
	for building in get_nodes_in_group("buildings"):
		all_valid = all_valid and not building.has_loot and building.has_guardian and building.loot.contents.is_empty() and building.rolled_weapon == ""
	check(all_valid, "Guardião é independente do loot; sem loot não sorteia arma")
	world.queue_free()
	await step()
	world = make_world({"loot_chance": 1.0, "guardian_chance": 0.0, "weapon_chance": 1.0, "pistol_weight": 0.0, "external_weapon_chance": 0.0, "random_seed": 77})
	all_valid = true
	for building in get_nodes_in_group("buildings"):
		all_valid = all_valid and building.rolled_weapon == "espingarda" and not building.has_guardian
	check(all_valid, "Peso 0 de pistola permite testar só espingarda")
	world.queue_free()
	await step()
	world = make_world({"loot_chance": 0.0, "guardian_chance": 0.0, "external_weapon_chance": 0.0, "development_weapons": true})
	await step()
	player = world.get_node("WorldObjects/Player")
	var inv: ResourceInventory = world.get_node("Inventory")
	var interaction = player.get_node("Interaction")
	var weapons = world.get_node("Weapons")
	var hud = world.get_node("HUD")
	var structures = world.get_node("Structures")
	check(get_nodes_in_group("resource_drops").size() == 4 and inv.tools.is_empty(), "Modo desenvolvimento gera duas armas e munições no chão")
	player.position = Vector2(1090, 768)
	await step()
	tap(KEY_E)
	check(inv.count_item("pistola") == 1 and inv.count_item("municao_pistola") == 0, "E executa apenas uma interação indicada")
	tap(KEY_E)
	tap(KEY_1)
	check(inv.equipped_tool() == "pistola" and player.equipped == "pistola", "Atalho 1 seleciona pistola no primeiro espaço")
	tap(KEY_R)
	check(weapons.reloading == "pistola", "Atalho R inicia recarga")
	weapons._physics_process(2)
	await step()
	check(inv.loaded_ammo("pistola") == 8 and hud.get_node("Controls/Rows/Equipment").text.contains("8/8") and hud.get_node("Controls/Rows/Equipment").text.contains("reserva"), "HUD mostra carregada e reserva")
	var before: int = inv.loaded_ammo("pistola")
	var point: Vector2 = player.get_canvas_transform() * (player.position + Vector2(150, 0))
	mouse(point)
	check(inv.loaded_ammo("pistola") == before - 1, "Clique curto dispara pistola pelo cursor")
	var bullet: Node2D = get_nodes_in_group("projectiles")[0]
	check(bullet.direction.dot(Vector2.RIGHT) > 0.99, "Disparo mouse acompanha direção do cursor")
	inv.add_resource("pistola", 1)
	var indices: Array[int] = []
	for i in range(inv.slots.size()):
		if inv.slots[i].get("item", "") == "pistola": indices.append(i)
	inv.equip_slot(indices[1])
	check(inv.loaded_ammo("pistola") == 0, "Segunda arma tem seu próprio carregador")
	inv.set_loaded_ammo("pistola", 2)
	inv.equip_slot(indices[0])
	check(inv.loaded_ammo("pistola") == 7, "Equipar outra instância não duplica munição")
	inv.add_resource("mochila", 1)
	for i in range(inv.slots.size()):
		if inv.slots[i].get("item", "") == "mochila": inv.equip_slot(i)
	check(inv.capacity == 9 and inv.remove_backpack() and inv.loaded_ammo("pistola") == 7, "Compactar bolsa preserva arma selecionada e munição")
	inv.reset()
	inv.add_resource("madeira", 4)
	inv.add_resource("pedra", 5)
	inv.craft("fogueira")
	hud.set_panel("inventory")
	hud.select_slot(0)
	var slot_point: Vector2 = hud.slot_buttons[0].get_global_rect().get_center()
	mouse(slot_point)
	check(interaction.blocked and not interaction.mouse_held, "Clique no inventário não arma ataque")
	check(structures.start_placement(0) and not paused and hud.current_panel == "", "Colocação fecha painel e retoma simulação")
	mouse(player.get_canvas_transform() * player.position)
	check(structures.active and inv.count_item("fogueira") == 1, "Clique inválido mantém prévia e item")
	tap(KEY_ESCAPE)
	check(not structures.active and inv.count_item("fogueira") == 1, "Esc cancela sem consumo")
	structures.start_placement(0)
	mouse(player.get_canvas_transform() * player.position, MOUSE_BUTTON_RIGHT)
	check(not structures.active and inv.count_item("fogueira") == 1, "Botão direito cancela sem consumo")
	structures.start_placement(0)
	interaction.cooldown = 0
	await step()
	mouse(player.get_canvas_transform() * (player.position + Vector2(90, 0)))
	check(not structures.active and inv.count_item("fogueira") == 0 and not interaction.mouse_held and interaction.cooldown == 0, "Clique confirma colocação sem disparar golpe")
	await step()
	hud.set_panel("crafting")
	await step()
	var inside := true
	for button in hud.recipe_buttons.values():
		# Categories and the scroll intentionally keep offscreen rows. Check the
		# interactive rows currently inside the scroll viewport, not hidden groups.
		if button.is_visible_in_tree() and button.get_global_rect().intersects(hud.get_node("Crafting/Panel/Rows/Scroll").get_global_rect()):
			inside = inside and root.get_visible_rect().encloses(button.get_global_rect())
	check(inside, "Botões das receitas visíveis cabem na resolução padrão")
	hud.set_panel("")
	print("INTEGRAÇÃO: %d verificações, %d falhas" % [checks, failures])
	world.queue_free()
	await step()
	quit(1 if failures else 0)
