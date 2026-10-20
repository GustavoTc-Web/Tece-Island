extends SceneTree

var colliders := []
func _initialize() -> void: call_deferred("run")
func point(value: Vector2) -> Array: return [value.x, value.y]
func rectangle(value: Rect2) -> Array: return [value.position.x, value.position.y, value.size.x, value.size.y]
func well_clear(position: Vector2, id: String) -> bool:
	if not WorldTerrain.solid_ground(position, Vector2(48, 48)): return false
	for collider in colliders:
		if collider.owner == id: continue
		var center := Vector2(collider.x, collider.y)
		if collider.type == "circle" and position.distance_to(center) < float(collider.radius) + 25: return false
		if collider.type == "rect" and Rect2(center - Vector2(collider.size[0], collider.size[1]) / 2, Vector2(collider.size[0], collider.size[1])).grow(25).has_point(position): return false
	return true
func collision_nodes(node: Node, owner_id: String = "") -> void:
	if node is StaticBody2D and not node.is_queued_for_deletion():
		for child in node.get_children():
			if not child is CollisionShape2D or child.disabled: continue
			var item := {"owner": owner_id, "x": child.global_position.x, "y": child.global_position.y}
			if child.shape is CircleShape2D:
				item.type = "circle"
				item.radius = child.shape.radius
			elif child.shape is RectangleShape2D:
				item.type = "rect"
				item.size = point(child.shape.size)
			else:
				push_error("Unsupported multiplayer collider: " + str(child.shape))
				quit(1)
				return
			colliders.append(item)
	for child in node.get_children(): collision_nodes(child, owner_id)

func run() -> void:
	var world: Node2D = load("res://scenes/world.tscn").instantiate()
	world.world_seed = 20261020
	root.add_child(world)
	paused = true
	var resources := []
	var wells := []
	var buildings := []
	var seen := {}
	for node in world.get_node("WorldObjects").get_children():
		if node.is_queued_for_deletion(): continue
		if node is HarvestResource:
			var id := "%s:%d:%d" % [node.resource, roundi(node.position.x), roundi(node.position.y)]
			if seen.has(id): continue
			seen[id] = true
			var item := {"id": id, "kind": node.resource, "x": node.position.x, "y": node.position.y,
				"tint": [node.modulate.r, node.modulate.g, node.modulate.b], "visual": "standard"}
			if node.get_script().resource_path.ends_with("campaign_tree.gd"): item.visual = "burned" if node.burned else "pine"
			resources.append(item)
			collision_nodes(node, id)
		elif node is WaterWell:
			var id := "well:" + str(node.get_meta("region_id", ""))
			wells.append({"id": id, "x": node.position.x, "y": node.position.y})
			collision_nodes(node, id)
		elif node is AbandonedBuilding:
			var id := "building:%d:%d" % [roundi(node.position.x), roundi(node.position.y)]
			buildings.append({"id": id, "x": node.position.x, "y": node.position.y, "kind": node.kind,
				"temple": node is RuinedTemple, "tint": [node.modulate.r, node.modulate.g, node.modulate.b]})
			# Export walls only. Loot and guardians are not multiplayer interactions yet.
			for child in node.get_children():
				if child is StaticBody2D: collision_nodes(child, id)
	collision_nodes(world.get_node("Biomes"))
	collision_nodes(world.terrain)
	# Validate clear ground for wells, including regions with ruined buildings.
	for well in wells:
		var original := Vector2(well.x, well.y)
		var destination := original
		if not well_clear(original, well.id):
			var found := false
			for distance in [64, 128, 192, 256, 320]:
				for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
					var candidate: Vector2 = original + direction * distance
					if WorldTerrain.region_at(candidate).get("id", "") != str(well.id).trim_prefix("well:") or not well_clear(candidate, well.id): continue
					destination = candidate
					found = true
					break
				if found: break
			assert(found, "No safe multiplayer well placement: " + str(well.id))
		well["solo_position"] = point(original)
		well.x = destination.x
		well.y = destination.y
		for collider in colliders:
			if collider.owner == well.id:
				collider.x += destination.x - original.x
				collider.y += destination.y - original.y
	var regions := []
	for region in WorldTerrain.regions(): regions.append({"id": region.id, "kind": region.kind, "rect": rectangle(region.rect)})
	var ponds := []
	for pond in WorldTerrain.PONDS: ponds.append(rectangle(pond))
	var intervals := {}
	for tool in ["maos", "machado_madeira", "picareta_madeira"]: intervals[tool] = ResourceRules.hit_interval(tool)
	var needs := SurvivalNeeds.new()
	var data := {"version": 1, "seed": world.world_seed, "bounds": rectangle(WorldTerrain.BOUNDS),
		"regions": regions, "ponds": ponds, "resources": resources, "wells": wells, "buildings": buildings,
		"colliders": colliders, "spawns": [[1152, 768], [1212, 768]], "speed": 210, "player_radius": 10,
		"reach": 82, "well_reach": 90, "swim_speed": WorldTerrain.SWIM_SPEED,
		"extraction": ResourceRules.EXTRACTION, "interval": intervals,
		"water": {"maximum": needs.max_thirst, "per_minute": needs.thirst_per_minute, "restores": needs.water_restores}}
	needs.free()
	DirAccess.make_dir_recursive_absolute("res://assets/data")
	var file := FileAccess.open("res://assets/data/multiplayer-world.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "  ") + "\n")
	file.close()
	var samples := []
	var random := RandomNumberGenerator.new()
	random.seed = 17
	for i in range(700):
		var position := Vector2(random.randf_range(-3100, 6950), random.randf_range(-2600, 3100))
		samples.append({"point": point(position), "inside": WorldTerrain.contains(position), "water": WorldTerrain.is_water(position)})
	for region in WorldTerrain.regions():
		for position in [region.rect.position, region.rect.get_center(), region.rect.end - Vector2.ONE]:
			samples.append({"point": point(position), "inside": WorldTerrain.contains(position), "water": WorldTerrain.is_water(position)})
	file = FileAccess.open("res://tests/fixtures/multiplayer-terrain-parity.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(samples) + "\n")
	file.close()
	print("SHARED WORLD: %d regions, %d resources, %d wells, %d buildings, %d colliders" % [regions.size(), resources.size(), wells.size(), buildings.size(), colliders.size()])
	world.queue_free()
	quit()
