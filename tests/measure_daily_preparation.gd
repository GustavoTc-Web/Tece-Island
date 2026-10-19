# Automated day-one gathering and crafting, using real resource nodes, movement,
# collision, drops, hit intervals and recipes. No materials injected into bag.
extends SceneTree
var world: Node2D
var player: CharacterBody2D
var inv: ResourceInventory
var interaction: Node
var nav: RefCounted
var seconds := 0.0
var harvested := {"madeira":0, "pedra":0}
var segments := []
func _initialize() -> void: call_deferred("run")
func tick() -> void:
	seconds += 1.0 / 60
	await physics_frame
func gather(resource: String, target: int, tool: String) -> bool:
	var start := seconds
	while inv.count_item(resource) < target and seconds < 260:
		var choices := get_nodes_in_group("harvest_resources").filter(func(n): return n.resource == resource and not n.exhausted and n.position.distance_to(player.position) < 1000)
		choices.sort_custom(func(a,b): return a.position.distance_squared_to(player.position) < b.position.distance_squared_to(player.position))
		var best: HarvestResource
		var route := PackedVector2Array()
		var length := INF
		for candidate in choices.slice(0, 10):
			for offset in [Vector2(60,0),Vector2(-60,0),Vector2(0,60),Vector2(0,-60)]:
				var path: PackedVector2Array = nav.path(player.position, candidate.anchor() + offset)
				if path.is_empty(): continue
				var distance := 0.0
				for i in range(1,path.size()): distance += path[i-1].distance_to(path[i])
				if distance < length: best=candidate; route=path; length=distance
		if best == null: return false
		for waypoint in route:
			var timeout := seconds + 8
			while player.position.distance_to(waypoint) > 8 and seconds < timeout:
				player.touch_movement = (waypoint-player.position).normalized()
				await tick()
			if seconds >= timeout: return false
		player.touch_movement = Vector2.ZERO
		inv.equip(tool)
		while is_instance_valid(best) and not best.exhausted and seconds < 260:
			interaction.target = best
			interaction.strike_target()
			await tick()
		await tick()
		for drop in get_nodes_in_group("resource_drops"):
			if drop.resource == resource and drop.position.distance_to(player.position) < 90:
				harvested[resource] += drop.quantity
				drop.collect(inv)
	segments.append({"resource":resource,"target_in_bag":target,"tool":tool,"seconds":seconds-start})
	return inv.count_item(resource) >= target
func run() -> void:
	Engine.time_scale = 4
	Engine.physics_ticks_per_second = 240
	world = load("res://scenes/world.tscn").instantiate()
	world.world_seed = 77
	root.add_child(world)
	world.get_node("Animals").set_physics_process(false)
	player = world.get_node("WorldObjects/Player")
	inv = world.get_node("Inventory")
	interaction = player.get_node("Interaction")
	for i in range(3): await physics_frame
	nav = load("res://tests/solo_navigation.gd").new()
	nav.build(world)
	var start_clock: float = world.get_node("DayNight").elapsed
	var ok := await gather("madeira",3,"maos")
	ok = ok and inv.craft("machado_madeira")
	if ok: ok = await gather("madeira",8,"machado_madeira")
	ok = ok and inv.craft("picareta_madeira")
	if ok: ok = await gather("pedra",7,"picareta_madeira")
	ok = ok and inv.craft("espada_pedra") and inv.craft("fogueira")
	var tasks: CampaignTasks = world.objectives.campaign_tasks
	var result := {"success":ok and tasks.rows(0).all(func(r):return r.done),"automated":true,"human_played":false,"seed":77,"game_seconds":seconds,"clock_seconds":world.get_node("DayNight").elapsed-start_clock,"day_budget_seconds":300,"gathered":harvested,"segments":segments,"time_scale":4,"physics_step_seconds":player.get_physics_process_delta_time(),"note":"Coleta e kit iniciais; não inclui colocar fogueira, caça, linha ou preparações dos dias seguintes."}
	var file := FileAccess.open("res://.tools/solo3-preparation-measurement.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "))
	file.close()
	print("PREPARATION MEASUREMENT: ",JSON.stringify(result))
	world.queue_free()
	await physics_frame
	quit(0 if result.success else 1)
