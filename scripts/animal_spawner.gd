extends Node
@export var rabbit_limit: int = 6
@export var cow_limit: int = 3
@export var replenish_interval: float = 120.0
var player: CharacterBody2D
var container: Node2D
var clock := 120.0
var next_point := 0
const POINTS := [Vector2(1460, 768), Vector2(1750, 850), Vector2(800, 880), Vector2(1950, 950), Vector2(4200, 900), Vector2(4650, 600), Vector2(4100, 1250), Vector2(700, 1050)]
func initialize(body: CharacterBody2D, objects: Node2D) -> void:
	player = body
	container = objects
	clock = replenish_interval
	for i in range(6): spawn("vaca" if i in [2, 4] else "coelho", false)
func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or player.dead: return
	clock -= delta
	if clock <= 0:
		clock = replenish_interval
		spawn("coelho")
		spawn("vaca")
func spawn(kind: String, avoid_player: bool = true) -> NeutralAnimal:
	var count := 0
	for animal in get_tree().get_nodes_in_group("animals"):
		if animal.kind == kind: count += 1
	if count >= (cow_limit if kind == "vaca" else rabbit_limit): return null
	var shape := CircleShape2D.new()
	shape.radius = 18
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = 7
	for i in range(POINTS.size()):
		var point: Vector2 = POINTS[next_point]
		next_point = (next_point + 1) % POINTS.size()
		if avoid_player and point.distance_to(player.global_position) < 250: continue
		query.transform = Transform2D(0, point)
		if not player.get_world_2d().direct_space_state.intersect_shape(query).is_empty(): continue
		var animal := NeutralAnimal.new()
		animal.kind = kind
		animal.position = point
		animal.player = player
		container.add_child(animal)
		return animal
	return null
