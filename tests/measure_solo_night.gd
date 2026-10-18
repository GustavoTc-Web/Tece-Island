# Automated physical run: real movement, collision, melee cooldown, hostile AI,
# food regeneration and damage. This is not a human playtest. No firearms,
# invincibility, teleports during the measured route, or direct enemy damage.
extends SceneTree
var world: Node2D
var player: CharacterBody2D
var interaction: Node
var inv: ResourceInventory
var nav: RefCounted
var elapsed := 0.0
var foods := 0
var damage := 0.0
var previous_hp := 100.0
var reports := []
var current_path := PackedVector2Array()
var waypoint := 0
var repath := 0.0
var last_goal := Vector2.INF
func _initialize() -> void: call_deferred("run")
func tick(goal: Vector2) -> void:
	var delta := 1.0 / 60
	elapsed += delta
	repath -= delta
	if repath <= 0 or goal.distance_to(last_goal) > 45:
		current_path = nav.path(player.position, goal)
		waypoint = 0
		repath = 0.4
		last_goal = goal
	while waypoint < current_path.size() and player.position.distance_to(current_path[waypoint]) < 8: waypoint += 1
	var direction := Vector2.ZERO
	if waypoint < current_path.size(): direction = (current_path[waypoint] - player.position).normalized()
	player.touch_movement = direction
	# A prepared player can counter nearby open-world pursuers while moving;
	# strike_target still enforces range, walls, damage and the normal cooldown.
	for mob in get_nodes_in_group("enemies"):
		if mob.origin == "noturno" and not mob.dead and interaction.can_reach(mob):
			interaction.target = mob
			interaction.strike_target()
			break
	if player.health < previous_hp: damage += previous_hp - player.health
	previous_hp = player.health
	if player.health <= 70 and player.regeneration_ticks == 0:
		for index in range(inv.capacity):
			if inv.slot_data(index).get("item") == "carne_cozida":
				player.get_node("Needs").use_slot(inv, index)
				foods += 1
				break
func travel(goal: Vector2, label: String) -> bool:
	var start := elapsed
	interaction.touch_aim = Vector2.ZERO
	while player.position.distance_to(goal) > 20 and elapsed - start < 100 and not player.dead:
		tick(goal)
		await physics_frame
	player.touch_movement = Vector2.ZERO
	var ok := player.position.distance_to(goal) <= 20
	reports.append({"label": label, "seconds": elapsed - start, "success": ok, "position": SaveStore.point(player.position)})
	print("MEASURE: ", JSON.stringify(reports[-1]))
	return ok
func fight(id: String) -> bool:
	var start := elapsed
	world.campaign.interact(id)
	while id not in world.campaign.components and elapsed - start < 110 and not player.dead:
		var chosen: ForestCreature
		var nearest := INF
		for mob in get_nodes_in_group("temple_enemies"):
			if mob.dead or mob.get_meta("temple_id") != id: continue
			var distance: float = player.position.distance_to(mob.position)
			if distance < nearest: chosen = mob; nearest = distance
		if is_instance_valid(chosen):
			tick(chosen.position)
			interaction.set_touch_aim(chosen.position - player.position)
			# A visible heavy windup gives time to retreat then counterattack.
			if chosen.special_attack == "slam" and chosen.windup_remaining > 0 and nearest < 110:
				player.touch_movement = (player.position - chosen.position).normalized()
		else:
			tick(player.position)
			player.touch_movement = Vector2.ZERO
		await physics_frame
	interaction.touch_aim = Vector2.ZERO
	player.touch_movement = Vector2.ZERO
	var ok: bool = id in world.campaign.components
	reports.append({"label": "combat_" + id, "seconds": elapsed - start, "success": ok, "health": player.health, "kills": world.campaign.temples[id].cleared.size()})
	print("MEASURE: ", JSON.stringify(reports[-1]))
	return ok
func run() -> void:
	Engine.time_scale = 4
	Engine.physics_ticks_per_second = 240
	world = load("res://scenes/world.tscn").instantiate()
	world.world_seed = 77
	root.add_child(world)
	world.get_node("Animals").set_physics_process(false)
	player = world.get_node("WorldObjects/Player")
	interaction = player.get_node("Interaction")
	inv = world.get_node("Inventory")
	inv.reset()
	inv.add_resource("espada_pedra")
	inv.add_resource("armadura_pedra")
	inv.equip_armor(1)
	inv.add_resource("carne_cozida", 6)
	inv.select_quick(0)
	player.position = SoloCampaign.LOCATIONS.lens + Vector2(0, 35)
	world.campaign.discovered = true
	world.campaign.map_found = true
	world.campaign.temples.lens.started = true
	world.campaign.temples.lens.cleared = CampaignEncounters.enemy_ids("lens")
	world.campaign.collect("lens")
	world.get_node("DayNight").elapsed = 4 * 600 + 300
	world.get_node("DayNight").refresh()
	for i in range(3): await physics_frame
	nav = load("res://tests/solo_navigation.gd").new()
	nav.build(world)
	var clock_start: float = world.get_node("DayNight").elapsed
	var ok := await travel(SoloCampaign.LOCATIONS.coil + Vector2(0, 35), "route_high_to_ashes")
	if ok: ok = await fight("coil")
	if ok: ok = await travel(SoloCampaign.LOCATIONS.core + Vector2(0, 35), "route_ashes_to_echo")
	if ok: ok = await fight("core")
	# Recovery after both encounters is included, followed by a 30 s error reserve.
	var start := elapsed
	if player.health < 95:
		for index in range(inv.capacity):
			if inv.slot_data(index).get("item") == "carne_cozida":
				player.get_node("Needs").use_slot(inv, index)
				foods += 1
				break
	while ok and player.health < 95 and elapsed - start < 15:
		tick(player.position)
		player.touch_movement = Vector2.ZERO
		await physics_frame
	reports.append({"label": "recovery", "seconds": elapsed - start})
	var clock_seconds: float = world.get_node("DayNight").elapsed - clock_start
	var result := {"automated": true, "human_played": false, "seed": 77, "ambient_spawns": true, "time_scale": 4, "physics_step_seconds": player.get_physics_process_delta_time(), "clock_seconds": clock_seconds, "equipment": ["espada_pedra", "armadura_pedra"], "food_used": foods, "damage_received": damage, "elapsed_seconds": elapsed, "error_reserve_seconds": 30, "budget_seconds": 300, "success": ok and not player.dead and elapsed + 30 <= 300 and absf(clock_seconds - elapsed) < 0.2, "health": player.health, "segments": reports}
	var file := FileAccess.open("res://.tools/solo2-night-measurement.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  "))
	file.close()
	print("NIGHT MEASUREMENT: ", JSON.stringify(result))
	world.queue_free()
	await physics_frame
	quit(0 if result.success else 1)
