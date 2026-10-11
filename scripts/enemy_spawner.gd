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


func alive_count() -> int:
	var total := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.origin == "noturno":
			total += 1
	return total


func current_limit() -> int:
	return night_limit if cycle.is_night() and cycle.phase != "Amanhecer" else 0


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
	query.collision_mask = 7
	for i in range(SPAWN_POINTS.size()):
		var point: Vector2 = SPAWN_POINTS[next_point]
		next_point = (next_point + 1) % SPAWN_POINTS.size()
		if point.distance_to(safe_center) < safe_radius + 40.0 or point.distance_to(player.global_position) < minimum_player_distance:
			continue
		query.transform = Transform2D(0.0, point)
		if not player.get_world_2d().direct_space_state.intersect_shape(query).is_empty():
			continue
		var enemy := CREATURE.instantiate() as ForestCreature
		enemy.position = point
		enemy.player = player
		enemy.safe_center = safe_center
		enemy.safe_radius = safe_radius
		container.add_child(enemy)
		return enemy
	return null
