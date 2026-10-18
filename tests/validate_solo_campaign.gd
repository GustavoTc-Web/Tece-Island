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
func make_world(seed_value: int, data: Dictionary = {}) -> Node2D:
	var world: Node2D = load("res://scenes/world.tscn").instantiate()
	world.world_seed = seed_value
	world.initial_progress = data
	root.add_child(world)
	world.get_node("EnemySpawner").set_physics_process(false)
	world.get_node("Animals").set_physics_process(false)
	world.get_node("DayNight").set_physics_process(false)
	world.get_node("WorldObjects/Player").set_physics_process(false)
	return world

# Real collision shapes and swept edges, rather than terrain rectangles alone.
func routes(world: Node2D) -> Dictionary:
	var space := world.get_world_2d().direct_space_state
	var graph := AStar2D.new()
	var cells := {}
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 14
	query.shape = shape
	query.collision_mask = 9
	for y in range(-2496, 1450, 48):
		for x in range(48, 3400, 48):
			var point := Vector2(x, y)
			if not WorldTerrain.solid_ground(point, Vector2(28, 28)): continue
			query.transform = Transform2D(0, point)
			query.motion = Vector2.ZERO
			if not space.intersect_shape(query).is_empty(): continue
			var id := graph.get_point_count()
			graph.add_point(id, point)
			cells[Vector2i(x, y)] = id
	for cell in cells:
		for offset in [Vector2i(48, 0), Vector2i(0, 48)]:
			if not cells.has(cell + offset): continue
			query.transform = Transform2D(0, Vector2(cell))
			query.motion = Vector2(offset)
			var motion := space.cast_motion(query)
			if motion[0] >= 0.999: graph.connect_points(cells[cell], cells[cell + offset])
	var start := graph.get_closest_point(Vector2(1152, 768))
	var result := {}
	for id in SoloCampaign.LOCATIONS:
		var point: Vector2 = world.campaign.points[id].position
		var target := graph.get_closest_point(point)
		var path := graph.get_point_path(start, target)
		var ray := PhysicsRayQueryParameters2D.create(graph.get_point_position(target), point, 9)
		result[id] = not path.is_empty() and path[-1].distance_to(point) <= 65 and space.intersect_ray(ray).is_empty()
	return result

func run() -> void:
	var world := make_world(77)
	await step()
	var campaign: SoloCampaign = world.campaign
	var player: CharacterBody2D = world.get_node("WorldObjects/Player")
	var cycle: DayNightCycle = world.get_node("DayNight")
	var hud: CanvasLayer = world.get_node("HUD")
	check(campaign.encounter == "idle" and not campaign.repaired, "Nova campanha começa sem vitória")
	check(campaign.collect("core") and not campaign.collect("core"), "Componente antecipado é único e independente do loot")
	check(not campaign.collect("pistola"), "Loot comum não entra na campanha")
	for id in ["lens", "coil"]: campaign.collect(id)
	campaign.interact("beacon")
	check(campaign.repaired and campaign.components.size() == 3, "Três componentes reparam o sinalizador")
	cycle.elapsed = 6 * 600 + 20
	cycle.refresh()
	check(not campaign.start_encounter(), "Dia 7 de dia não ativa chefe")
	cycle.elapsed = 5 * 600 + 320
	cycle.refresh()
	check(not campaign.start_encounter(), "Noite 6 não ativa chefe")
	cycle.elapsed = 6 * 600 + 320
	cycle.refresh()
	player.position = SoloCampaign.LOCATIONS.beacon + Vector2(0, 50)
	check(campaign.start_encounter() and campaign.boss.kind == "guardiao_ilha", "Noite 7 ativa somente o chefe da campanha")
	var snapshot := campaign.capture()
	var resumed := SoloCampaign.new()
	check(resumed.restore(snapshot) and resumed.encounter == "retry" and resumed.components.size() == 3, "Reabrir durante chefe exige reativação e preserva componentes")
	resumed.free()
	campaign.interrupt_battle()
	await step()
	check(campaign.encounter == "retry" and not is_instance_valid(campaign.boss), "Fuga limpa o chefe para nova tentativa")
	check(campaign.start_encounter(), "Nova tentativa não gasta componentes")
	player.invulnerability = 0
	player.receive_damage(200)
	check(campaign.encounter == "retry" and campaign.repaired and campaign.deaths == 1, "Derrota preserva mundo e reparo")
	world.respawn_player()
	await step()
	cycle.elapsed = 10 * 600 + 320
	cycle.refresh()
	player.position = SoloCampaign.LOCATIONS.beacon + Vector2(0, 50)
	check(campaign.start_encounter(), "Mundo posterior ao dia 7 ainda conclui campanha")
	cycle.elapsed = 11 * 600
	cycle.refresh()
	await step()
	check(campaign.encounter == "retry" and campaign.components.size() == 3, "Amanhecer interrompe confronto e conserva os componentes")
	cycle.elapsed = 11 * 600 + 320
	cycle.refresh()
	check(campaign.start_encounter() and campaign.boss.health == 300, "Outra noite reinicia chefe em vida cheia")
	campaign.boss.receive_damage(300)
	check(campaign.encounter == "won" and campaign.victory_day == 12 and hud.current_panel == "victory", "Matar Guardião conclui campanha e abre resumo")
	hud.set_panel("")
	check(not paused and campaign.encounter == "won" and not campaign.start_encounter(), "Continuar explorando preserva vitória sem duplicar chefe")
	var progress := WorldProgress.new()
	progress.world = world
	var saved := progress.capture()
	check(SaveValidation.valid(saved), "Snapshot com campanha passa pela validação de saves")
	var encoded := CloudCodec.encode(saved)
	check(encoded.ok and CloudCodec.hash_state(saved) != CloudCodec.hash_state(saved.merged({"campaign": {}} , true)), "Campanha participa do hash e envelope de sincronização")
	var bad := saved.duplicate(true)
	bad.campaign.components.append("core")
	check(not SaveValidation.valid(bad), "Componente duplicado em save é rejeitado")
	bad = saved.duplicate(true)
	bad.campaign.version = 99
	check(not SaveValidation.valid(bad), "Versão desconhecida da campanha bloqueia gravação")
	var legacy := saved.duplicate(true)
	legacy.erase("campaign")
	legacy.version = 5
	check(SaveValidation.valid(legacy), "Save 0.8.3 sem campanha continua válido")
	var store := SaveStore.new()
	store.path = "res://.tools/campaign-backup-%d.json" % Time.get_ticks_usec()
	var first_write := store.write(legacy)
	var original := FileAccess.get_file_as_string(store.path)
	check(first_write and store.write(saved), "Inclusão da campanha salva com backup")
	var backup := FileAccess.get_file_as_string(store.path + ".before-campaign-v1.json")
	check(backup == original and store.write(saved) and FileAccess.get_file_as_string(store.path + ".before-campaign-v1.json") == backup, "Backup anterior à campanha permanece exato e idempotente")
	for seed_value in [1, 77, 20261018, 2147480000]:
		world.queue_free()
		await step()
		world = make_world(seed_value)
		await step()
		var accessibility := routes(world)
		for id in accessibility: check(accessibility[id], "Rota física semente %d: %s" % [seed_value, id])
	var full_inventory: ResourceInventory = world.get_node("Inventory")
	for i in range(7): full_inventory.add_resource("cama", 1)
	var full_state := full_inventory.network_state()
	world.get_node("WorldObjects/Player").position = SoloCampaign.LOCATIONS.lens + Vector2(0, 35)
	await step()
	world.get_node("WorldObjects/Player/Interaction").collect_nearest()
	check("lens" in world.campaign.components and full_state == full_inventory.network_state(), "Coleta física com bolsa cheia protege componente fora do inventário")
	# Load the real captured world, without discarding inventory/resources/IDs.
	world.queue_free()
	await step()
	world = make_world(77, saved)
	progress.world = world
	world.initial_progress = saved
	world.account_store = AccountProgress.new()
	progress.load_progress()
	await step()
	check(world.campaign.encounter == "won" and world.get_node("HUD").current_panel == "", "Vitória reabre sem bloquear continuação")
	world.queue_free()
	await step()
	print("%d verificações, %d falhas" % [checks, failures])
	quit(1 if failures else 0)
