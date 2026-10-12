class_name NaturalWells
extends RefCounted
const LEGACY_POSITIONS := {"forest": Vector2(1310, 768), "swamp": Vector2(3000, 768), "fields": Vector2(4520, 768), "desert": Vector2(6030, 768)}

static func valid_metadata(metadata: Dictionary) -> bool:
	for id in metadata:
		var state = metadata[id]
		if not state is Dictionary or not state.get("has_well") is bool: return false
		if state.has_well and (not state.get("position") is Array or state.position.size() != 2): return false
		if state.has_well:
			var point := SaveStore.vector(state.position, Vector2.INF)
			if not point.is_finite() or WorldTerrain.region_at(point).get("id", "") != id: return false
	return true

static func generate(_seed_value: int, previous: Dictionary = {}, structures: Array = []) -> Dictionary:
	var result := {}
	for region in WorldTerrain.regions():
		# User postponed random wells: keep the original one fixed well per region.
		var state := {"has_well": true}
		if state.has_well:
			var rect: Rect2 = region.rect
			var first: Vector2 = LEGACY_POSITIONS.get(region.id, rect.get_center() + Vector2(160, 0))
			if previous.has(region.id) and previous[region.id].get("has_well", false):
				first = SaveStore.vector(previous[region.id].get("position"), first)
			# The original four locations stay canonical across save formats.
			if LEGACY_POSITIONS.has(region.id): first = LEGACY_POSITIONS[region.id]
			var candidates := [first]
			for offset in [Vector2(-160, 0), Vector2(0, -160), Vector2(0, 160), Vector2(320, 0), Vector2(0, 320), Vector2(-320, 0), Vector2(0, -320)]:
				candidates.append(rect.get_center() + offset)
			for x in range(64, int(rect.size.x) - 64, 64):
				candidates.append(Vector2(rect.position.x + x, rect.get_center().y))
			var found := false
			for point in candidates:
				if not rect.grow(-32).has_point(point) or not WorldTerrain.solid_ground(point, Vector2(48, 48)): continue
				var occupied := false
				for structure in structures:
					var position := SaveStore.vector(structure.get("position"))
					if absf(position.x - point.x) < 70 and absf(position.y - point.y) < 60: occupied = true
				if occupied: continue
				state.position = SaveStore.point(point)
				found = true
				break
			# No well may overwrite a saved player base.
			if not found: state.has_well = false
		result[region.id] = state
	return result

static func spawn(world: Node2D, metadata: Dictionary) -> void:
	for id in metadata:
		var state: Dictionary = metadata[id]
		if not state.get("has_well", false): continue
		var well := WaterWell.new()
		well.position = SaveStore.vector(state.position)
		well.hud = world.get_node("HUD")
		well.player = world.get_node("WorldObjects/Player")
		well.set_meta("region_id", id)
		world.get_node("WorldObjects").add_child(well)
