extends Node
@export var rabbit_limit: int = 6
@export var cow_limit: int = 3
@export var replenish_interval: float = 120.0
@export var fish_limit := 8
@export var bird_chance := 0.02
@export var bird_attempt_interval := 60.0
var bird_clock := 60.0
var bird_attempts := 0
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
	for region in WorldTerrain.AQUATIC:
		for kind in ["lambari", "tilapia"]:
			for i in range(2): spawn_fish(kind, region)
func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or player.dead: return
	bird_clock -= delta
	if bird_clock <= 0:
		bird_clock = maxf(60, bird_attempt_interval)
		try_bird()
	clock -= delta
	if clock <= 0:
		clock = replenish_interval
		spawn("coelho")
		spawn("vaca")
		var region := WorldTerrain.region_at(player.global_position)
		if region.get("kind", "") == "Aquático":
			spawn_fish("lambari", region)
			spawn_fish("tilapia", region)

func spawn_fish(kind: String, region: Dictionary) -> NeutralAnimal:
	var count := 0
	for animal in get_tree().get_nodes_in_group("animals"):
		if animal.kind == kind: count += 1
	if count >= fish_limit: return null
	var rect: Rect2 = region.rect
	for i in range(20):
		var point := rect.position + Vector2(randf_range(50, rect.size.x - 50), randf_range(50, rect.size.y - 50))
		if not WorldTerrain.is_water(point): continue
		var animal := NeutralAnimal.new()
		animal.kind = kind
		animal.position = point
		animal.player = player
		animal.habitat = rect.grow(-24)
		container.add_child(animal)
		return animal
	return null

func try_bird(roll: float = -1) -> NeutralAnimal:
	for animal in get_tree().get_nodes_in_group("animals"):
		if animal.kind == "garca_azul": return null
	var region := WorldTerrain.region_at(player.global_position)
	if region.is_empty(): return null
	var rect: Rect2 = region.rect
	var candidate := Vector2.INF
	var shape := CircleShape2D.new()
	shape.radius = 10
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = 7
	for i in range(8):
		var point: Vector2 = player.global_position + Vector2.from_angle(i * TAU / 8) * 380
		if not rect.grow(-24).has_point(point) or not WorldTerrain.solid_ground(point): continue
		query.transform = Transform2D(0, point)
		if not player.get_world_2d().direct_space_state.intersect_shape(query).is_empty(): continue
		candidate = point
		break
	if not candidate.is_finite(): return null
	bird_attempts += 1
	if (randf() if roll < 0 else roll) >= bird_chance: return null
	var bird := NeutralAnimal.new()
	bird.kind = "garca_azul"
	bird.position = candidate
	bird.player = player
	bird.habitat = rect.grow(-24)
	container.add_child(bird)
	return bird
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
