extends "res://tests/validate_integration.gd"
func run() -> void:
	root.size = Vector2i(960, 540)
	var world := make_world({"random_seed": 103})
	await step()
	var player: CharacterBody2D = world.get_node("WorldObjects/Player")
	var inv: ResourceInventory = world.get_node("Inventory")
	var cycle: DayNightCycle = world.get_node("DayNight")
	cycle.set_physics_process(false)
	check(cycle.day_duration == 300 and cycle.night_duration == 300 and not cycle.is_night(), "Ciclo 300 + 300 começa de dia")
	cycle.elapsed = 285
	cycle.refresh()
	check(cycle.phase == "Anoitecer" and cycle.color.r < 0.9 and cycle.remaining_seconds == 15, "Transição gradual dentro dos 300s e contador")
	cycle.advance(15)
	check(cycle.is_night() and cycle.color == cycle.night_color, "Noite perceptível no CanvasModulate real")
	paused = true
	cycle.advance(10)
	check(cycle.elapsed == 300, "Pausa congela relógio")
	paused = false
	cycle.elapsed = 600
	cycle.refresh()
	check(cycle.day_number == 2 and cycle.phase == "Dia" and cycle.color == Color.WHITE, "600s fecha ciclo e restaura dia claro")
	check(world.get_node("Exploration").loot_chance == 0.70, "Chance de loot padrão 70%")
	var random := RandomNumberGenerator.new()
	random.seed = 617
	var occupied := [0, 0, 0]
	var valid := true
	var weapons := 0
	for i in range(20000):
		occupied[AbandonedBuilding.occupation_count(random.randf())] += 1
		var contents := AbandonedBuilding.roll_contents(random)
		valid = valid and contents.size() in [1, 2]
		for item in contents:
			valid = valid and int(contents[item]) >= 1 and int(contents[item]) <= 3
			if GunRules.WEAPONS.has(item):
				weapons += 1
				valid = valid and contents.size() == 2 and contents.has(GunRules.WEAPONS[item].ammo)
	check(valid, "20 mil sorteios: 1–2 entradas; arma e munição dentro do limite")
	check(absf(occupied[0] / 20000.0 - 0.70) < 0.015 and absf(occupied[1] / 20000.0 - 0.28) < 0.015 and absf(occupied[2] / 20000.0 - 0.02) < 0.008, "Ocupação única 70/28/2, sobre todas as construções")
	check(absf(weapons / 20000.0 - 0.05) < 0.01, "Raridade de armas preservada em 5% do loot")
	var reachable := accessible_cells(player)
	check(get_nodes_in_group("buildings").size() == 9, "Seis construções existentes mais três no deserto")
	for building in get_nodes_in_group("buildings"):
		check(accessible_point(building.loot.global_position, reachable), "Entrada transitável: " + building.kind)
		var contents: Dictionary = building.loot.contents.duplicate(true)
		building.populate(random, world.get_node("Exploration"))
		check(building.loot.contents == contents, "Revisita não sorteia novamente")
	for well in get_nodes_in_group("wells"):
		check(accessible_point(well.position + Vector2(0, 48), reachable), "Poço alcançável: " + str(well.position))
	check(player.get_node("Camera2D").limit_right == 6912 and world.terrain.get_child_count() > 0, "Câmera e borda cobrem deserto")
	var structures := world.get_node("Structures")
	inv.add_resource("cama")
	inv.add_resource("fogueira")
	check(structures.start_placement(0) and not paused and structures.active, "Colocar cama fecha painel e inicia prévia")
	check(not structures.can_place(player.position), "Colocação sobre jogador bloqueada")
	structures.update_preview(player.position + Vector2(0, -80))
	check(structures.valid and structures.confirm() and inv.count_item("cama") == 0, "Confirmar terreno livre consome cama uma vez")
	var bed: PlacedStructure = world.get_node("WorldObjects").get_child(-1)
	check(structures.use_bed(bed).contains("definido"), "Cama define reaparecimento durante dia")
	structures.start_placement(1)
	structures.cancel()
	check(inv.count_item("fogueira") == 1 and not structures.active, "Cancelar fogueira preserva item")
	structures.start_placement(1)
	structures.update_preview(player.position + Vector2(0, 80))
	check(structures.confirm(), "Coloca fogueira")
	var fire: PlacedStructure = world.get_node("WorldObjects").get_child(-1)
	check(fire.light != null and fire.light.energy > 0, "Fogueira tem iluminação local")
	world.queue_free()
	await step()
	print("UPDATE B: ", checks, " verificações, ", failures, " falhas")
	quit(1 if failures else 0)
