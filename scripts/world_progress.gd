class_name WorldProgress
extends RefCounted
var store := SaveStore.new()
var world: Node2D
var writable := true

func capture() -> Dictionary:
	var player: CharacterBody2D = world.get_node("WorldObjects/Player")
	var needs: Node = player.get_node("Needs")
	var result := {"version": SaveStore.VERSION, "inventory": world.get_node("Inventory").network_state(), "player": {"position": SaveStore.point(player.position), "health": player.health, "hunger": needs.hunger, "thirst": needs.thirst}, "elapsed": world.get_node("DayNight").elapsed, "structures": [], "drops": [], "resources": {}, "loot": {}, "wells": []}
	var structures: Node = world.get_node("Structures")
	if is_instance_valid(structures.respawn_bed): result.bed = SaveStore.point(structures.respawn_bed.position)
	result.player.poison = player.poison_remaining
	result.player.poison_tick = player.poison_tick
	result.world_seed = world.world_seed
	result.explored = world.minimap.explored.duplicate(true)
	result.region_wells = world.region_wells.duplicate(true)
	result.region_buildings = world.region_buildings.duplicate(true)
	result.building_loot = {}
	result.wells_policy = "fixed"
	result.journal = world.journal.capture()
	result.objectives = world.objectives.capture()
	result.campaign = world.campaign.capture()
	if not world.owner_uid.is_empty(): result.owner_uid = world.owner_uid
	if not world.world_id.is_empty(): result.world_id = world.world_id
	if world.account_store != null:
		result._sync = world.account_store.sync_state.duplicate(true)
		result.world_name = world.world_name
	result.generated_regions = []
	for region in WorldTerrain.regions(): result.generated_regions.append(region.id)
	for node in world.get_node("WorldObjects").get_children():
		if node.is_queued_for_deletion(): continue
		if node is PlacedStructure:
			var state := {"kind": node.kind, "position": SaveStore.point(node.position)}
			state.id = node.structure_id
			if node.kind == "bau": state.chest_name = node.chest_name
			state.rotation = node.rotation
			if node.kind == "porta_madeira": state.door_open = node.door_open
			if node.kind == "bau": state.storage = node.storage.network_state()
			result.structures.append(state)
		elif node is ResourceDrop:
			result.drops.append({"item": node.resource, "quantity": node.quantity, "attributes": node.attributes, "position": SaveStore.point(node.position)})
		elif node is HarvestResource and not node.exhausted:
			result.resources[SaveStore.key(node.position)] = node.progress
		elif node is WaterWell:
			result.wells.append(SaveStore.point(node.position))
	for node in world.find_children("*", "Node2D", true, false):
		if node.get_script() == preload("res://scripts/loot_container.gd"):
			result.loot[SaveStore.key(node.global_position)] = {"contents": node.contents, "released": node.released}
			if node.has_meta("loot_id"): result.building_loot[str(node.get_meta("loot_id"))] = {"contents": node.contents, "released": node.released}
	return result

func load_progress() -> void:
	world.loading_progress = true
	_load_progress()
	world.loading_progress = false

func _load_progress() -> void:
	var data: Dictionary = world.initial_progress if world.account_store != null else store.read()
	if store.error != "":
		writable = false
		world.get_node("HUD").show_message(store.error)
		return
	if data.is_empty(): return
	if not SoloCampaign.valid(data.get("campaign", {})):
		writable = false
		world.get_node("HUD").show_message("Campanha incompatível: save original preservado.")
		return
	for field in ["structures", "drops", "wells"]:
		if data.has(field) and not data[field] is Array:
			writable = false
	for field in ["resources", "loot", "player", "explored", "region_wells", "region_buildings", "building_loot"]:
		if data.has(field) and not data[field] is Dictionary:
			writable = false
	if data.has("region_wells") and data.region_wells is Dictionary and not NaturalWells.valid_metadata(data.region_wells): writable = false
	if data.has("region_buildings") and data.region_buildings is Dictionary and not RegionalBuildings.valid(data.region_buildings): writable = false
	if not writable:
		world.get_node("HUD").show_message("Progresso incompatível: o save original foi preservado.")
		return
	# Validate all inventories before changing anything in the running world.
	var goals_check := IslandObjectives.new()
	if not data.get("objectives", {}) is Dictionary or not goals_check.restore(data.get("objectives", {})):
		writable = false
		goals_check.free()
		world.get_node("HUD").show_message("Objetivos incompatíveis: save original preservado.")
		return
	goals_check.free()
	var journal_check := IslandJournal.new()
	if not data.get("journal", {}) is Dictionary or not journal_check.restore(data.get("journal", {})):
		writable = false
		journal_check.free()
		world.get_node("HUD").show_message("Diário incompatível: save original preservado.")
		return
	journal_check.free()
	var validation := ResourceInventory.new()
	var valid := validation.restore_state(data.inventory)
	validation.free()
	for state in data.get("structures", []):
		if not state is Dictionary or state.get("kind", "") not in ["cama", "fogueira", "bau"] + PlacedStructure.PIECES:
			valid = false
			break
		if not SaveStore.vector(state.get("position"), Vector2.INF).is_finite(): valid = false
		if state.has("door_open") and not state.door_open is bool: valid = false
		var angle := float(state.get("rotation", 0))
		if not is_finite(angle) or (not is_zero_approx(angle) and not is_equal_approx(angle, PI / 2)): valid = false
		if state.kind == "bau":
			validation = ResourceInventory.new()
			validation.base_capacity = 12
			valid = validation.restore_state(state.get("storage", {})) and valid
			validation.free()
	for state in data.get("drops", []):
		if not state is Dictionary or not state.get("attributes", {}) is Dictionary or int(state.get("quantity", 0)) <= 0:
			valid = false
			break
		if not ItemCatalog.NAMES.has(state.get("item", "")) and not ResourceRules.RECIPES.has(state.get("item", "")): valid = false
	for state in data.get("loot", {}).values():
		if not state is Dictionary or not state.get("contents") is Dictionary or not state.get("released") is bool: valid = false
	for state in data.get("building_loot", {}).values():
		if not state is Dictionary or not state.get("contents") is Dictionary or not state.get("released") is bool: valid = false
	if not valid:
		writable = false
		world.get_node("HUD").show_message("Progresso incompatível: o save original foi preservado.")
		return
	world.get_node("Inventory").restore_state(data.inventory)
	world.objectives.restore(data.get("objectives", {}))
	world.journal.restore(data.get("journal", {}))
	world.campaign.restore(data.get("campaign", {}))
	world.minimap.explored = data.get("explored", {}).duplicate(true)
	var player: CharacterBody2D = world.get_node("WorldObjects/Player")
	var player_state: Dictionary = data.get("player", {})
	player.position = SaveStore.vector(player_state.get("position"), player.position)
	player.health = clampf(float(player_state.get("health", 100)), 0, player.max_health)
	player.dead = player.health <= 0
	player.cancel_regeneration()
	world.get_node("HUD").show_death(player.dead)
	player.poison_remaining = clampf(float(player_state.get("poison", 0)), 0, 60)
	player.poison_tick = clampf(float(player_state.get("poison_tick", 1)), 0, 1)
	player.get_node("Needs").hunger = clampf(float(player_state.get("hunger", 100)), 0, 100)
	player.get_node("Needs").thirst = clampf(float(player_state.get("thirst", 100)), 0, 100)
	world.get_node("HUD").update_health(player.health, player.max_health)
	world.get_node("HUD").update_poison(player.poison_remaining)
	world.get_node("HUD").update_needs(player.get_node("Needs").hunger, player.get_node("Needs").thirst)
	world.get_node("DayNight").elapsed = maxf(0, float(data.get("elapsed", 0)))
	world.get_node("DayNight").refresh()
	var objects: Node2D = world.get_node("WorldObjects")
	for node in objects.get_children():
		if node is ResourceDrop: node.queue_free()
		elif node is HarvestResource and data.has("resources"):
			var key := SaveStore.key(node.position)
			var region := WorldTerrain.region_at(node.global_position)
			var old_regions: Array = data.get("generated_regions", ["forest", "swamp", "fields", "desert"])
			if not data.resources.has(key) and region.get("id", "") in old_regions:
				node.collision_layer = 0
				node.queue_free()
			elif data.resources.has(key): node.progress = clampf(float(data.resources[key]), 0, 0.999)
	for state in data.get("structures", []):
		var structure: PlacedStructure = preload("res://scenes/placed_structure.tscn").instantiate()
		structure.kind = state.kind
		structure.structure_id = str(state.get("id", state.kind + "-" + SaveStore.key(SaveStore.vector(state.get("position")))))
		structure.chest_name = str(state.get("chest_name", "Baú")).strip_edges().left(24)
		if structure.chest_name.is_empty(): structure.chest_name = "Baú"
		structure.position = SaveStore.vector(state.get("position"))
		structure.rotation = float(state.get("rotation", 0))
		structure.system = world.get_node("Structures")
		objects.add_child(structure)
		if structure.kind == "bau": structure.storage.restore_state(state.storage)
		if structure.kind == "porta_madeira": structure.set_open(bool(state.get("door_open", false)))
		if data.has("bed") and structure.kind == "cama" and structure.position == SaveStore.vector(data.bed): world.get_node("Structures").respawn_bed = structure
	for state in data.get("drops", []):
		var drop: ResourceDrop = preload("res://scenes/resource_drop.tscn").instantiate()
		drop.resource = state.item
		drop.quantity = int(state.quantity)
		drop.attributes = state.get("attributes", {}).duplicate(true)
		drop.position = SaveStore.vector(state.position)
		objects.add_child(drop)
	for node in world.find_children("*", "Node2D", true, false):
		if node.get_script() == preload("res://scripts/loot_container.gd"):
			var key := SaveStore.key(node.global_position)
			var state: Dictionary = data.get("building_loot", {}).get(str(node.get_meta("loot_id", "")), data.get("loot", {}).get(key, {}))
			if not state.is_empty():
				node.contents = state.contents.duplicate(true)
				node.released = bool(state.released)
				node.queue_redraw()
	world.get_node("HUD").show_message("Progresso local carregado.")
	world.objectives.reconcile(world)

func save() -> bool:
	if not writable: return false
	var snapshot := capture()
	var ok: bool = await world.account_store.write(snapshot, world.get_tree()) if world.account_store != null else store.write(snapshot)
	if not ok: world.get_node("HUD").show_message(world.account_store.error if world.account_store != null else store.error)
	if ok: world.last_local_snapshot = JSON.parse_string(str(world.account_store.expected)) if world.account_store != null else snapshot
	return ok
