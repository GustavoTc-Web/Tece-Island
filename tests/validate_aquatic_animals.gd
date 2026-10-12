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
	var player: CharacterBody2D = world.get_node("WorldObjects/Player")
	var inv: ResourceInventory = world.get_node("Inventory")
	var spawner: Node = world.get_node("Animals")
	var structures: Node = world.get_node("Structures")
	player.set_physics_process(false)
	spawner.set_physics_process(false)
	check(WorldTerrain.ORIGINAL[1].rect == Rect2(2304, 0, 1536, 1536) and WorldTerrain.ORIGINAL[3].rect == Rect2(5376, 0, 1536, 1536), "Regiões atuais mantêm coordenadas")
	var water_samples := 0
	var samples := 0
	var region: Dictionary = WorldTerrain.AQUATIC[0]
	for x in range(0, 1536, 16):
		for y in range(0, 1536, 16):
			samples += 1
			if WorldTerrain.is_water(region.rect.position + Vector2(x + 8, y + 8)): water_samples += 1
	var ratio := float(water_samples) / samples
	check(ratio >= 0.75 and ratio <= 0.85, "Aquático aproximadamente oitenta por cento água: %.1f" % (ratio * 100))
	player.position = Vector2(-1000, 300)
	await step()
	player.step_movement(1.0 / 60, Vector2.RIGHT)
	check(player.swimming and is_equal_approx(player.velocity.length(), player.speed * 0.6), "Nado a sessenta por cento da velocidade")
	check(not structures.can_place(player.position + Vector2(80, 0)), "Água rejeita estruturas")
	player.position = Vector2(-768, 768)
	await step()
	player.step_movement(1.0 / 60, Vector2.RIGHT)
	check(not player.swimming and is_equal_approx(player.velocity.length(), player.speed), "Voltar à terra restaura velocidade")
	check(WorldTerrain.solid_ground(Vector2(-768, 768), Vector2(64, 48)), "Passagem central permite construção em terra")
	var fish_count := 0
	var kinds := []
	for animal in get_nodes_in_group("animals"):
		if animal.is_fish():
			fish_count += 1
			kinds.append(animal.kind)
			check(WorldTerrain.is_water(animal.position), "Peixe nasce na água")
	check(fish_count >= 4 and kinds.has("lambari") and kinds.has("tilapia"), "Duas espécies habitam as regiões aquáticas")
	await step(90)
	var stayed := true
	for animal in get_nodes_in_group("animals"):
		if animal.is_fish(): stayed = stayed and WorldTerrain.is_water(animal.position) and animal.habitat.has_point(animal.position)
	check(stayed, "Peixes permanecem na água ao se mover")
	for kind in ["lambari", "tilapia"]:
		player.position = Vector2(-1000, 300)
		var fish := NeutralAnimal.new()
		fish.kind = kind
		fish.player = player
		fish.position = player.position + Vector2(20, 0)
		fish.habitat = region.rect
		world.get_node("WorldObjects").add_child(fish)
		fish.receive_damage(100)
		await step()
		var meat: ResourceDrop
		for drop in get_nodes_in_group("resource_drops"):
			if drop.resource == "carne_peixe": meat = drop
		check(is_instance_valid(meat) and meat.quantity == 1 and WorldTerrain.is_water(meat.position), "Peixe deixa exatamente uma carne na água: " + kind)
		player.get_node("Interaction").update_pickup()
		player.get_node("Interaction").collect_nearest()
		await step()
	check(inv.count_item("carne_peixe") == 2, "Coleta na água independente do mouse")
	inv.add_resource("madeira", 1)
	check(not inv.craft("peixe_cozido"), "Peixe só pode ser cozido na fogueira")
	inv.cooking_available = true
	check(inv.craft("peixe_cozido") and inv.count_item("carne_peixe") == 1, "Cozinhar peixe consome uma carne e uma madeira")
	var food_index := -1
	for i in range(inv.capacity):
		if inv.slot_data(i).get("item", "") == "peixe_cozido": food_index = i
	player.get_node("Needs").hunger = 20
	player.get_node("Needs").use_slot(inv, food_index)
	check(inv.count_item("peixe_cozido") == 0 and player.get_node("Needs").hunger == 50, "Comer peixe consome uma unidade")
	player.position = Vector2(1152, 768)
	await step()
	var bird: NeutralAnimal = spawner.try_bird(0)
	check(is_instance_valid(bird), "Fixture de sorteio válido gera Garça-azul")
	check(spawner.try_bird(0) == null, "No máximo uma Garça-azul")
	var attempts: int = spawner.bird_attempts
	spawner.bird_clock = 60
	for i in range(120): spawner._physics_process(1.0 / 60)
	check(spawner.bird_attempts == attempts, "Chance não é sorteada por frame")
	if is_instance_valid(bird):
		player.position = bird.position - Vector2(100, 0)
		bird._physics_process(1.0 / 60)
		check(bird.velocity.length() > player.speed and bird.get_node("CollisionShape2D").shape.radius == 6, "Ave foge depressa e é difícil de acertar")
		var old_meat := 0
		for drop in get_nodes_in_group("resource_drops"):
			if drop.resource == "carne_crua": old_meat += drop.quantity
		bird.receive_damage(100)
		await step()
		var meat := 0
		for drop in get_nodes_in_group("resource_drops"):
			if drop.resource == "carne_crua": meat += drop.quantity
		check(meat - old_meat == 1, "Garça-azul deixa exatamente uma carne")
	check(spawner.bird_chance == 0.02 and spawner.bird_attempt_interval >= 60, "Chance dois por cento e intervalo mínimo de sessenta segundos")
	check(world.terrain.get_child_count() < 40, "Bordas agrupadas limitam corpos físicos")
	world.queue_free()
	await process_frame
	print("%d verificações, %d falhas" % [checks, failures])
	quit(1 if failures else 0)
