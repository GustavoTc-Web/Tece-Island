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
	var cycle: DayNightCycle = world.get_node("DayNight")
	player.set_physics_process(false)
	for guard in get_nodes_in_group("enemies"): guard.set_physics_process(false)
	cycle.elapsed = 10
	cycle.refresh()
	player.position = Vector2(-2304, 768)
	await step()
	check(cycle.local_darkness and cycle.color == cycle.night_color and not cycle.is_night(), "Ruínas escuras mesmo de dia sem mudar ciclo")
	var bed: PlacedStructure = load("res://scenes/placed_structure.tscn").instantiate()
	bed.system = world.get_node("Structures")
	bed.position = player.position
	world.get_node("WorldObjects").add_child(bed)
	var elapsed := cycle.elapsed
	check(world.get_node("Structures").use_bed(bed).contains("Não é possível dormir") and cycle.elapsed == elapsed, "Ruínas bloqueiam sono com motivo")
	player.position = Vector2(1152, 768)
	await step()
	check(not cycle.local_darkness and cycle.color == Color.WHITE, "Sair restaura luz global do dia")
	cycle.elapsed = 340
	cycle.refresh()
	player.position = Vector2(-2304, 768)
	await step()
	player.position = Vector2(1152, 768)
	await step()
	check(not cycle.local_darkness and cycle.color == cycle.night_color and cycle.is_night(), "Sair à noite mantém luz global da noite")
	check(world.ruins.temples.size() == 4 and world.ruins.guardians.size() <= world.ruins.guard_limit, "Poucos templos e limite próprio de guardiões")
	for temple in world.ruins.temples:
		check(temple.chests.size() >= 3 and temple.chests.size() <= 5, "Templo tem de três a cinco baús")
		var total := 0
		for chest in temple.chests:
			for amount in chest.contents.values(): total += int(amount)
		check(total == world.ruins.loot_budget_per_temple, "Orçamento por templo independe da quantidade de baús")
		var random := RandomNumberGenerator.new()
		temple.populate_temple(random, 100)
		var repeated := 0
		for chest in temple.chests:
			for amount in chest.contents.values(): repeated += int(amount)
		check(repeated == total, "Revisitar não repopula saque")
		var ray := PhysicsRayQueryParameters2D.create(temple.position + Vector2(30, 290), temple.position + Vector2(30, 35), 1)
		check(player.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(), "Entrada acessível conecta corredor central")
	for guard in world.ruins.guardians:
		check(guard.origin == "guardiao", "Guardião de templo permanece em qualquer horário")
	var progress := WorldProgress.new()
	progress.world = world
	var saved := progress.capture()
	check(saved.world_seed == world.world_seed and saved.generated_regions.has("ruins_w") and saved.loot.size() >= 21, "Save registra semente, regiões e conteúdo dos templos")
	var kinds := {}
	for region in WorldTerrain.regions(): kinds[region.kind] = true
	check(kinds.size() == 6, "Apenas Aquático e Ruínas são novos tipos")
	world.queue_free()
	await process_frame
	print("%d verificações, %d falhas" % [checks, failures])
	quit(1 if failures else 0)
