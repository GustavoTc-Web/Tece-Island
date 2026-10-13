class_name RegionalBuildings
extends RefCounted
const CLEARANCE := Vector2(300, 270)

static func valid(metadata: Dictionary) -> bool:
	for id in metadata:
		if not metadata[id] is Array: return false
		var seen := {}
		for state in metadata[id]:
			if not state is Dictionary: return false
			var point := SaveStore.vector(state.get("position"), Vector2.INF)
			var stable_id := str(state.get("id", ""))
			if not point.is_finite() or WorldTerrain.region_at(point).get("id", "") != id or stable_id.is_empty() or seen.has(stable_id): return false
			if state.get("kind", "") not in ["casa", "castelo", "fazenda", "barro", "posto"]: return false
			seen[stable_id] = true
	return true

static func generate(world: Node2D) -> Dictionary:
	var previous: Dictionary = world.initial_progress.get("region_buildings", {})
	var result := previous.duplicate(true)
	if not valid(previous): return {}
	for region in WorldTerrain.regions():
		if region.kind in ["Aquático", "Ruínas Escuras"]: continue
		# Presence is checked in each region, including the original map.
		var covered := false
		for node in world.get_node("WorldObjects").get_children():
			if node is AbandonedBuilding and region.rect.has_point(node.position): covered = true
		if covered or (result.has(region.id) and not result[region.id].is_empty()): continue
		var states: Array = []
		var rect: Rect2 = region.rect
		for y in range(int(rect.position.y) + 210, int(rect.end.y) - 210, 96):
			for x in range(int(rect.position.x) + 210, int(rect.end.x) - 210, 96):
				if states.size() >= 3: break
				var point := Vector2(x, y)
				if not free_space(world, point, states): continue
				var kind: String = {"Floresta": "casa", "Pântano": "casa", "Campos": "fazenda", "Deserto": "barro"}[region.kind]
				states.append({"id": "region-" + region.id + "-%d" % states.size(), "kind": kind, "position": SaveStore.point(point)})
			if states.size() >= 3: break
		result[region.id] = states
	return result

static func free_space(world: Node2D, point: Vector2, states: Array) -> bool:
	if not WorldTerrain.solid_ground(point, CLEARANCE): return false
	var area := Rect2(point - CLEARANCE / 2, CLEARANCE)
	for state in world.initial_progress.get("structures", []):
		if area.grow(64).has_point(SaveStore.vector(state.get("position"))): return false
	for state in states:
		if point.distance_to(SaveStore.vector(state.position)) < 420: return false
	for node in world.get_node("WorldObjects").get_children():
		if node is HarvestResource and area.grow(30).has_point(node.position): return false
		if node is WaterWell and area.grow(60).has_point(node.position): return false
		if node is AbandonedBuilding and area.intersects(Rect2(node.position - node.footprint / 2, node.footprint).grow(64)): return false
	return true

static func spawn(world: Node2D, metadata: Dictionary) -> void:
	for region_id in metadata:
		for state in metadata[region_id]:
			var building := AbandonedBuilding.new()
			building.position = SaveStore.vector(state.position)
			building.kind = state.kind
			if WorldTerrain.region_at(building.position).get("kind", "") == "Pântano": building.modulate = Color("a2bbb0")
			building.set_meta("building_id", state.id)
			building.set_meta("region_id", region_id)
			world.get_node("WorldObjects").add_child(building)
			var random := RandomNumberGenerator.new()
			random.seed = (str(world.world_seed) + "/" + str(state.id)).hash()
			building.populate(random, world.get_node("Exploration"))
			building.loot.set_meta("loot_id", state.id)
