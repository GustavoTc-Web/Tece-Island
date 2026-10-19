extends RefCounted
var graph := AStar2D.new()
var space: PhysicsDirectSpaceState2D
func build(world: Node2D) -> void:
	space = world.get_world_2d().direct_space_state
	var cells := {}
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 14
	query.shape = shape
	query.collision_mask = 9
	for y in range(-2496, 1450, 32):
		for x in range(-2656, 3400, 32):
			var point := Vector2(x, y)
			if not WorldTerrain.solid_ground(point, Vector2(28, 28)): continue
			query.transform = Transform2D(0, point)
			query.motion = Vector2.ZERO
			if not space.intersect_shape(query).is_empty(): continue
			var id := graph.get_point_count()
			graph.add_point(id, point)
			cells[Vector2i(x, y)] = id
	for cell in cells:
		for offset in [Vector2i(32, 0), Vector2i(0, 32)]:
			if not cells.has(cell + offset): continue
			query.transform = Transform2D(0, Vector2(cell))
			query.motion = Vector2(offset)
			if space.cast_motion(query)[0] >= 0.999: graph.connect_points(cells[cell], cells[cell + offset])
func path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var target := graph.get_closest_point(to)
	if target < 0 or graph.get_point_position(target).distance_to(to) > 65: return []
	var ray := PhysicsRayQueryParameters2D.create(graph.get_point_position(target), to, 9)
	if not space.intersect_ray(ray).is_empty(): return []
	var route := graph.get_point_path(graph.get_closest_point(from), target)
	if not route.is_empty(): route.append(to)
	return route
