extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1
	print("PASS: " if value else "FAIL: ", label)
func step(frames: int = 3) -> void:
	for i in range(frames): await physics_frame
func run() -> void:
	var world: Node2D = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await step()
	var inv: ResourceInventory = world.get_node("Inventory")
	var player: CharacterBody2D = world.get_node("WorldObjects/Player")
	var structures: Node = world.get_node("Structures")
	var objects: Node2D = world.get_node("WorldObjects")
	player.set_physics_process(false)
	inv.add_resource("madeira", 4)
	check(inv.craft("parede_madeira") and inv.wood == 0, "Parede custa quatro madeiras")
	inv.add_resource("madeira", 6)
	check(inv.craft("porta_madeira") and inv.wood == 0, "Porta custa seis madeiras")
	inv.add_resource("madeira", 4)
	inv.add_resource("vidro", 2)
	check(inv.craft("vidraca") and inv.wood == 0 and inv.count_item("vidro") == 0, "Vidraça custa quatro madeiras e dois vidros")
	check(structures.start_placement(0), "Parede usa colocação existente")
	structures.update_preview(Vector2(1152, 672))
	check(structures.confirm() and inv.count_item("parede_madeira") == 0, "Confirmar válido consome peça uma vez")
	await step()
	var wall: PlacedStructure
	for node in objects.get_children():
		if node is PlacedStructure and node.kind == "parede_madeira": wall = node
	player.position = Vector2(1152, 722)
	await step()
	check(player.test_move(player.global_transform, Vector2(0, -70)), "Parede bloqueia corpo do jogador")
	player.position = Vector2(1152, 768)
	structures.start_placement(1)
	structures.rotate_placement()
	structures.update_preview(Vector2(1152, 864))
	check(structures.confirm(), "Rotação confirma porta na grade")
	await step()
	var door: PlacedStructure
	for node in objects.get_children():
		if node is PlacedStructure and node.kind == "porta_madeira": door = node
	check(is_equal_approx(door.rotation, PI / 2), "Porta guarda orientação vertical")
	player.position = Vector2(1102, 864)
	await step()
	check(player.test_move(player.global_transform, Vector2(70, 0)), "Porta fechada bloqueia passagem")
	door.interact(inv)
	await step()
	check(door.door_open and not player.test_move(player.global_transform, Vector2(70, 0)), "Porta aberta libera passagem")
	player.position = door.position
	await step()
	check(door.interact(inv).contains("ocupada") and door.door_open, "Porta não fecha sobre personagem")
	player.position = Vector2(1102, 864)
	await step()
	check(door.interact(inv) == "Porta fechada", "Pode tentar fechar após sair da passagem")
	player.position = Vector2(1152, 768)
	structures.start_placement(2)
	structures.update_preview(Vector2(1248, 736))
	check(structures.confirm(), "Vidraça posicionada sem perder itens")
	await step()
	var glass: PlacedStructure
	for node in objects.get_children():
		if node is PlacedStructure and node.kind == "vidraca": glass = node
	player.position = Vector2(1248, 686)
	await step()
	check(player.test_move(player.global_transform, Vector2(0, 70)), "Vidraça bloqueia corpo")
	var enemy: ForestCreature = load("res://scenes/forest_creature.tscn").instantiate()
	enemy.player = player
	enemy.origin = "guardiao"
	enemy.safe_radius = 0
	enemy.position = Vector2(1248, 800)
	objects.add_child(enemy)
	enemy.set_physics_process(false)
	await step()
	check(enemy.has_line_of_sight(player.position), "Vidraça deixa visão atravessar")
	inv.reset()
	inv.add_resource("arco", 1)
	inv.add_resource("flecha", 3)
	inv.select_quick(0)
	world.get_node("Weapons").fire(Vector2.DOWN)
	await step(35)
	check(enemy.health == 30, "Vidraça bloqueia flecha visível")
	glass.collision_layer = 0
	glass.get_node("CollisionShape2D").disabled = true
	await step(35)
	world.get_node("Weapons").fire(Vector2.DOWN)
	await step(35)
	check(enemy.health == 18, "Controle: sem barreira flecha causa doze danos")
	glass.collision_layer = 8
	glass.get_node("CollisionShape2D").disabled = false
	inv.reset()
	inv.add_resource("parede_madeira", 1)
	player.position = Vector2(1152, 768)
	await step()
	structures.start_placement(0)
	structures.update_preview(wall.position)
	check(not structures.confirm() and inv.count_item("parede_madeira") == 1, "Sobreposição rejeitada sem consumir")
	structures.update_preview(player.position)
	check(not structures.confirm() and inv.count_item("parede_madeira") == 1, "Personagem impede sobreposição")
	structures.preview_point = player.position + Vector2(300, 0)
	check(not structures.confirm() and inv.count_item("parede_madeira") == 1, "Fora do alcance não consome")
	structures.cancel()
	check(inv.count_item("parede_madeira") == 1, "Cancelar conserva a peça")
	player.position = Vector2(-1000, 300)
	await step()
	structures.start_placement(0)
	structures.update_preview(player.position + Vector2(80, 0))
	check(not structures.confirm() and inv.count_item("parede_madeira") == 1, "Água rejeita parede")
	structures.cancel()
	door.set_open(true)
	await step()
	var progress := WorldProgress.new()
	progress.world = world
	progress.store.path = "res://.tools/save-tests/base-%d.json" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute("res://.tools/save-tests")
	check(await progress.save(), "Save de base gravado")
	var restored: Node2D = load("res://scenes/world.tscn").instantiate()
	restored.persistence_enabled = true
	restored.progress_path = progress.store.path
	root.add_child(restored)
	await step()
	var loaded_pieces := 0
	var loaded_door: PlacedStructure
	for node in restored.get_node("WorldObjects").get_children():
		if node is PlacedStructure and node.kind in PlacedStructure.PIECES:
			loaded_pieces += 1
			if node.kind == "porta_madeira": loaded_door = node
	check(loaded_pieces == 3 and loaded_door.door_open and loaded_door.position == door.position and is_equal_approx(loaded_door.rotation, door.rotation), "Carregar conserva paredes, vidro, posição e estado/orientação da porta")
	var random := RandomNumberGenerator.new()
	random.seed = 100
	var glass_found := 0
	var budget_ok := true
	for i in range(200):
		var loot := AbandonedBuilding.roll_contents(random, 0)
		budget_ok = budget_ok and loot.size() <= 2
		glass_found += int(loot.get("vidro", 0))
	check(glass_found > 0 and budget_ok, "Vidro aparece em saque sem ampliar orçamento")
	world.queue_free()
	restored.queue_free()
	await process_frame
	print("%d verificações, %d falhas" % [checks, failures])
	quit(1 if failures else 0)
