class_name SaveValidation
extends RefCounted

static func valid(data: Variant, uid: String = "", world_id: String = "") -> bool:
	if not data is Dictionary or not data.get("inventory") is Dictionary: return false
	if not data.get("version") is float and not data.get("version") is int: return false
	if int(data.version) < 0 or int(data.version) > SaveStore.VERSION: return false
	if uid != "" and data.get("owner_uid", "") != uid: return false
	if world_id != "" and data.get("world_id", "") != world_id: return false
	for field in ["structures", "drops", "wells", "generated_regions"]:
		if data.has(field) and not data[field] is Array: return false
	for field in ["player", "resources", "loot", "explored", "region_wells", "region_buildings", "building_loot", "objectives", "journal", "_sync"]:
		if data.has(field) and not data[field] is Dictionary: return false
	var sync: Dictionary = data.get("_sync", {})
	if sync.has("revision") and (not (sync.revision is int or sync.revision is float) or int(sync.revision) < 0): return false
	if int(sync.get("revision", 0)) > 0 and (not sync.get("hash") is String or RegEx.create_from_string("^[a-f0-9]{64}$").search(sync.hash) == null): return false
	if sync.has("intent") and (not sync.intent is Dictionary or int(sync.intent.get("revision", 0)) <= 0 or not sync.intent.get("hash") is String or RegEx.create_from_string("^[a-f0-9]{64}$").search(sync.intent.hash) == null): return false
	if data.has("region_wells") and not NaturalWells.valid_metadata(data.region_wells): return false
	if data.has("region_buildings") and not RegionalBuildings.valid(data.region_buildings): return false
	var inventory := ResourceInventory.new()
	var ok := inventory.restore_state(data.inventory)
	inventory.free()
	var goals := IslandObjectives.new()
	ok = goals.restore(data.get("objectives", {})) and ok
	goals.free()
	var journal := IslandJournal.new()
	ok = journal.restore(data.get("journal", {})) and ok
	journal.free()
	for state in data.get("structures", []):
		if not state is Dictionary or state.get("kind", "") not in ["cama", "fogueira", "bau"] + PlacedStructure.PIECES: return false
		if not SaveStore.vector(state.get("position"), Vector2.INF).is_finite(): return false
		if state.has("door_open") and not state.door_open is bool: return false
		var angle := float(state.get("rotation", 0))
		if not is_finite(angle) or (not is_zero_approx(angle) and not is_equal_approx(angle, PI / 2)): return false
		if state.kind == "bau":
			inventory = ResourceInventory.new()
			inventory.base_capacity = 12
			ok = inventory.restore_state(state.get("storage", {})) and ok
			inventory.free()
	for state in data.get("drops", []):
		if not state is Dictionary or not state.get("attributes", {}) is Dictionary or int(state.get("quantity", 0)) <= 0: return false
		if not ItemCatalog.NAMES.has(state.get("item", "")) and not ResourceRules.RECIPES.has(state.get("item", "")): return false
		if not SaveStore.vector(state.get("position"), Vector2.INF).is_finite(): return false
	for field in ["loot", "building_loot"]:
		for state in data.get(field, {}).values():
			if not state is Dictionary or not state.get("contents") is Dictionary or not state.get("released") is bool: return false
	return ok
