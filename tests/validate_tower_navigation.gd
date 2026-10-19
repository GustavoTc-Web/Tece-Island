# Collision/movement/interaction probe. Clock and enemy spawning are controlled;
# this measures access, not combat balance or human play.
extends SceneTree
var checks := 0
var failures := 0
var routes := []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS: " if ok else "FAIL: ", label)
func step(count: int = 3) -> void:
	for i in range(count): await physics_frame
func clock(world: Node2D, day: int, night: bool) -> void:
	world.get_node("DayNight").elapsed = (day - 1) * 600 + (310 if night else 10)
	world.get_node("DayNight").refresh()
func press_e() -> void:
	# At 4x, multiple physics ticks can share one input/render frame. Deliver
	# distinct key-down/up frames rather than batching an impossibly short tap.
	await process_frame
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
	await step()
	event = InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
	await step()
func walk(player: CharacterBody2D, path: PackedVector2Array) -> Dictionary:
	var ticks := 0
	var distance := 0.0
	for waypoint in path:
		var timeout := 0
		while player.position.distance_to(waypoint) > 7 and timeout < 480:
			player.touch_movement = (waypoint - player.position).normalized()
			var previous := player.position
			await physics_frame
			distance += previous.distance_to(player.position)
			ticks += 1
			timeout += 1
		if timeout >= 480:
			player.touch_movement = Vector2.ZERO
			return {"success":false,"stuck":SaveStore.point(player.position),"target":SaveStore.point(waypoint)}
	player.touch_movement = Vector2.ZERO
	var turns := []
	for i in range(1, path.size()):
		if i == path.size() - 1 or not (path[i] - path[i-1]).normalized().is_equal_approx((path[i+1] - path[i]).normalized()): turns.append(SaveStore.point(path[i]))
	return {"success":not path.is_empty(),"seconds":ticks / 60.0,"distance":distance,"waypoints":path.size(),"turns":turns}
func scenario(fixture: String, seed_value: int, day: int) -> void:
	var world: Node2D = load("res://scenes/world.tscn").instantiate()
	var path := "res://.tools/tower-%d.json" % Time.get_ticks_usec()
	var original := ""
	if not fixture.is_empty():
		original = FileAccess.get_file_as_string(fixture)
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(original)
		file.close()
		world.persistence_enabled = true
		world.progress_path = path
	else: world.world_seed = seed_value
	root.add_child(world)
	for id in ["EnemySpawner", "Animals", "DayNight"]: world.get_node(id).set_physics_process(false)
	var player: CharacterBody2D = world.get_node("WorldObjects/Player")
	await step()
	var label := fixture.get_file() if not fixture.is_empty() else "seed %d" % seed_value
	var before := WorldProgress.new()
	before.world = world
	var initial := before.capture()
	var campaign: SoloCampaign = world.campaign
	check(is_instance_valid(campaign.points.get("map")) and campaign.points.map.is_in_group("interactables") and campaign.points.map.can_interact(), label + ": mapa físico e interação existem após carregar")
	check(not campaign.map_found, label + ": carregar não concede mapa")
	clock(world, day, false)
	var navigation: Dictionary = world.minimap.tower_navigation()
	check(not navigation.is_empty() and navigation.outside and navigation.bearing == "N", label + ": torre indicada fora do alcance mesmo sem descobrir sinal")
	var nav = load("res://tests/solo_navigation.gd").new()
	nav.build(world)
	var route: PackedVector2Array = nav.path(player.position, campaign.points.map.position + Vector2(0, 40))
	check(not route.is_empty(), label + ": percurso conectado por terreno e colisões reais")
	# Whole route is walked, with physics and no coordinate assignment to player.
	clock(world, day, true)
	var result: Dictionary = await walk(player, route)
	result.fixture = label
	result.night = day
	routes.append(result)
	check(result.success and player.position.distance_to(campaign.points.map.position) < 70, label + ": chega à base da torre caminhando")
	var interaction: Node = player.get_node("Interaction")
	var messages: Array[String] = []
	interaction.message_requested.connect(func(message): messages.append(message))
	interaction.update_pickup()
	check(interaction.pickup == campaign.points.map, label + ": E seleciona o mapa com linha de visão")
	clock(world, day, false)
	check(campaign.points.map.prompt().contains("anoitecer"), label + ": chegada de dia explica horário")
	await press_e()
	check(not campaign.map_found, label + ": E de dia não concede mapa")
	clock(world, 2, true)
	await press_e()
	check(not campaign.map_found and campaign.points.map.prompt().contains("noite 3"), label + ": noite 2 continua bloqueada")
	clock(world, day, true)
	check(campaign.points.map.prompt().contains("E ou botão Interagir"), label + ": chegada à noite explica controle")
	var input_before := {"blocked":interaction.blocked,"paused":paused,"dead":player.dead,"panel":world.get_node("HUD").current_panel,"pickup_is_map":interaction.pickup == campaign.points.map,"requirement":campaign.night_requirement(3),"position":SaveStore.point(player.position)}
	await press_e()
	if not campaign.map_found: print("KEY DIAGNOSTIC: ", JSON.stringify({"fixture":label,"before":input_before,"messages":messages,"pressed":Input.is_action_pressed("collect")}))
	check(campaign.map_found and world.objectives.campaign_tasks.task("map").done, label + ": tecla E recupera mapa e conclui objetivo na noite %d" % day)
	check(world.minimap.tower_navigation().is_empty() and not campaign.points.map.can_interact(), label + ": marcador some e coleta não se repete")
	var progress := WorldProgress.new()
	progress.world = world
	var current := progress.capture()
	check(JSON.stringify(current.inventory) == JSON.stringify(initial.inventory) and JSON.stringify(current.structures) == JSON.stringify(initial.structures), label + ": inventário e construções preservados")
	check(campaign.components == initial.campaign.components and campaign.repaired == initial.campaign.repaired and campaign.encounter == initial.campaign.encounter, label + ": coleta não concede templos, reparo ou vitória")
	if not fixture.is_empty():
		await world.save_progress(true)
		check(FileAccess.get_file_as_string(fixture) == original, label + ": fixture original preservada")
		world.queue_free()
		await step()
		world = load("res://scenes/world.tscn").instantiate()
		world.persistence_enabled = true
		world.progress_path = path
		root.add_child(world)
		for id in ["EnemySpawner", "Animals", "DayNight"]: world.get_node(id).set_physics_process(false)
		await step()
		check(world.campaign.map_found and world.objectives.campaign_tasks.task("map").done and not world.campaign.points.map.can_interact(), label + ": reabertura mantém coleta única")
	world.queue_free()
	await step()
func run() -> void:
	Engine.time_scale = 4
	Engine.physics_ticks_per_second = 240
	await scenario("", 77, 3)
	await scenario("res://tests/fixtures/solo_v083.json", 77, 11)
	await scenario("res://tests/fixtures/solo_v06.json", 77, 11)
	await scenario("res://tests/fixtures/solo_v07.json", 77, 4)
	await scenario("res://tests/fixtures/solo_v08.json", 77, 4)
	for seed_value in [5, 7, 117]: await scenario("", seed_value, 3)
	await old_base()
	var file := FileAccess.open("res://.tools/solo4-tower-routes.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"automated":true,"human_played":false,"enemies_disabled":true,"physics_step":1.0/60,"routes":routes},"  "))
	file.close()
	print("%d verificações, %d falhas" % [checks, failures])
	quit(1 if failures else 0)

func old_base() -> void:
	var world: Node2D = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	for id in ["EnemySpawner", "Animals", "DayNight"]: world.get_node(id).set_physics_process(false)
	var wall: PlacedStructure = load("res://scenes/placed_structure.tscn").instantiate()
	wall.kind = "parede_madeira"
	wall.position = SoloCampaign.LOCATIONS.map
	wall.structure_id = "old-wall-on-tower"
	world.get_node("WorldObjects").add_child(wall)
	# Serialize/reload an existing obstruction, rather than trying to place a new
	# structure inside today's reserved objective radius.
	var progress := WorldProgress.new()
	progress.world = world
	var saved := progress.capture()
	world.queue_free()
	await step()
	world = load("res://scenes/world.tscn").instantiate()
	world.account_store = AccountProgress.new()
	world.initial_progress = saved
	root.add_child(world)
	progress = WorldProgress.new()
	progress.world = world
	progress.load_progress()
	for id in ["EnemySpawner", "Animals", "DayNight"]: world.get_node(id).set_physics_process(false)
	var player: CharacterBody2D = world.get_node("WorldObjects/Player")
	player.position = SoloCampaign.LOCATIONS.map + Vector2(0, 120)
	await step()
	check(not world.campaign.map_found and world.campaign.blocked_by_base("map"), "Base antiga: obstrução preservada, sem conceder mapa")
	clock(world, 4, false)
	var hud: Node = world.get_node("HUD")
	hud.journal_view.refresh()
	var recover: Button
	for child in hud.journal_view.pages.get_children():
		if child is Button and child.text == "Acessar mapa pela base": recover = child
	check(recover != null, "Base antiga: Diário oferece interação manual próxima")
	if recover != null: recover.pressed.emit()
	check(not world.campaign.map_found, "Base antiga: ação do Diário respeita horário diurno")
	clock(world, 4, true)
	if recover != null: recover.pressed.emit()
	check(world.campaign.map_found, "Base antiga: ação manual recupera mapa na noite posterior")
	progress = WorldProgress.new()
	progress.world = world
	var current := progress.capture()
	check(JSON.stringify(saved.structures) == JSON.stringify(current.structures), "Base antiga: parede mantém ID, posição e estado após coleta")
	world.queue_free()
	await step()
