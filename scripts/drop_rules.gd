class_name DropRules
extends RefCounted

static func accessible_point(player: CharacterBody2D, map_size: Vector2) -> Vector2:
	var shape := CircleShape2D.new()
	shape.radius = 12
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = 7
	query.exclude = [player.get_rid()]
	for radius in [32.0, 48.0, 16.0, 0.0]:
		for i in range(8):
			var point: Vector2 = player.global_position + player.facing.rotated(i * TAU / 8) * radius
			if not Rect2(Vector2(32, 32), map_size - Vector2(64, 64)).has_point(point): continue
			query.transform = Transform2D(0, point)
			if not player.get_world_2d().direct_space_state.intersect_shape(query).is_empty(): continue
			var ray := PhysicsRayQueryParameters2D.create(player.global_position, point, 1)
			if player.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(): return point
	return Vector2.INF

static func discard(inventory: ResourceInventory, index: int, whole: bool, player: CharacterBody2D, container: Node2D, map_size: Vector2) -> bool:
	var data := inventory.backpack.duplicate(true) if index == -2 else inventory.slot_data(index)
	if data.is_empty(): return false
	if index == -2 and inventory.backpack_plan(true).is_empty(): return false
	var point := accessible_point(player, map_size)
	if not point.is_finite(): return false
	data.quantity = int(data.quantity) if whole else 1
	var drop := preload("res://scenes/resource_drop.tscn").instantiate() as ResourceDrop
	drop.resource = data.item
	drop.quantity = data.quantity
	drop.attributes = data.duplicate(true)
	drop.position = point
	container.add_child(drop)
	if index == -2: inventory.remove_backpack(true)
	else: inventory.take_slot(index, data.quantity)
	return true
