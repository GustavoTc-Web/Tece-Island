extends Node

const CREATURE := preload("res://scenes/forest_creature.tscn")
const SPAWN_POINTS := [Vector2(450, 768), Vector2(1850, 768), Vector2(1152, 320), Vector2(1152, 1230), Vector2(2600, 768), Vector2(3400, 768), Vector2(4200, 768), Vector2(5100, 768)]

@export var day_limit: int = 0
@export var night_limit: int = 5
@export var spawn_interval: float = 12.0
@export var safe_radius: float = 240.0
@export var minimum_player_distance: float = 220.0
var safe_center := Vector2(1152, 768)
var player: CharacterBody2D
var cycle: DayNightCycle
var container: Node2D
var cooldown: float = 0.0
var next_point: int = 0
var next_kind := 0
const KINDS := ["criatura", "esqueleto", "aranha"]

func kinds_for_day(day: int) -> Array:
	if day >= 6: return KINDS + ["cacador", "brutamonte", "uivador"]
	if day >= 3: return KINDS + ["cacador"]
	if day >= 2: return KINDS
	return ["criatura"]


func alive_count() -> int:
	var total := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.origin == "noturno":
			total += 1
	return total


func current_limit() -> int:
	if not cycle.is_night() or cycle.phase == "Amanhecer": return 0
	var campaign: SoloCampaign = get_parent().get("campaign")
	if campaign != null and campaign.encounter in ["active", "awaiting_dawn"]: return 0
	return mini(night_limit, 3 if cycle.day_number == 1 else (4 if cycle.day_number == 2 else 5))


func _physics_process(delta: float) -> void:
	if current_limit() == 0:
		for enemy in get_tree().get_nodes_in_group("enemies"):
			enemy.begin_dawn()
	cooldown = maxf(0.0, cooldown - delta)
	if cooldown <= 0.0:
		cooldown = spawn_interval
		try_spawn()


func try_spawn() -> ForestCreature:
	if get_tree().paused or player.dead or alive_count() >= current_limit():
		return null
	var shape := CircleShape2D.new()
	shape.radius = 18.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = 15
	var points: Array = SPAWN_POINTS.duplicate()
	if player.terrain_enabled:
		points = []
		for i in range(12): points.append(player.global_position + Vector2.from_angle(i * TAU / 12) * 330)
	for i in range(points.size()):
		var point: Vector2 = points[next_point % points.size()]
		next_point += 1
		if player.terrain_enabled and not WorldTerrain.solid_ground(point, Vector2(36, 36)): continue
		if point.distance_to(safe_center) < safe_radius + 40.0 or point.distance_to(player.global_position) < minimum_player_distance:
			continue
		query.transform = Transform2D(0.0, point)
		if not player.get_world_2d().direct_space_state.intersect_shape(query).is_empty():
			continue
		var enemy := CREATURE.instantiate() as ForestCreature
		var pool := kinds_for_day(cycle.day_number)
		enemy.kind = pool[next_kind % pool.size()]
		next_kind += 1
		if enemy.kind == "uivador" and howler_count() >= 1: enemy.kind = "criatura"
		enemy.position = point
		enemy.player = player
		enemy.safe_center = safe_center
		enemy.safe_radius = safe_radius
		enemy.detection_range = 360
		enemy.give_up_range = 560
		enemy.reinforcement_handler = summon_for_howler
		container.add_child(enemy)
		return enemy
	return null

func howler_count() -> int:
	var total := 0
	for mob in get_tree().get_nodes_in_group("enemies"):
		if mob.kind == "uivador" and not mob.dead: total += 1
	return total

func summon_for_howler(caller: ForestCreature) -> int:
	if not is_instance_valid(caller) or caller.dead or caller.fading or player.dead: return 0
	var reinforcements := 0
	var local_count := 0
	for mob in get_tree().get_nodes_in_group("enemies"):
		if mob.has_meta("howler_reinforcement"): reinforcements += 1
		if mob.origin == caller.origin: local_count += 1
	var budget := mini(2 - reinforcements, 5 - local_count)
	if budget <= 0: return 0
	var campaign: SoloCampaign = get_parent().get("campaign")
	if campaign == null: return 0
	var spawned := 0
	for i in range(budget):
		var mob := campaign.spawn_enemy("criatura", caller.position + Vector2(140 if i == 0 else -140, 70), caller.origin, caller.home)
		if mob == null: continue
		mob.set_meta("howler_reinforcement", true)
		mob.safe_radius = caller.safe_radius
		if caller.is_in_group("final_encounter"):
			mob.add_to_group("final_encounter")
			mob.defeated.connect(campaign._final_enemy_defeated)
		spawned += 1
	return spawned
