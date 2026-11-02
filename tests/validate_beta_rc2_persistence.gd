# Prepared migration/persistence scenarios, separate from normal exploratory play.
extends "res://tests/validate_integration.gd"
func reopen(path: String) -> Node2D:
	var world: Node2D = load("res://scenes/world.tscn").instantiate()
	world.persistence_enabled = true
	world.progress_path = path
	world.get_node("Exploration").guardian_chance = 1.0
	root.add_child(world)
	for id in ["DayNight","EnemySpawner","Animals","WorldObjects/Player"]: world.get_node(id).set_physics_process(false)
	return world
func find_building(world: Node2D, key: String) -> AbandonedBuilding:
	for node in world.get_node("WorldObjects").get_children():
		if node is AbandonedBuilding and SaveStore.key(node.position) == key: return node
	return null
func total_drops(world: Node2D) -> int:
	var total := 0
	for drop in get_nodes_in_group("resource_drops"):
		if world.is_ancestor_of(drop) and not drop.is_queued_for_deletion(): total += drop.quantity
	return total
func run() -> void:
	var original := FileAccess.get_file_as_string("res://tests/fixtures/solo_v08.json")
	var path := "res://.tools/rc2-reopen-%d.json" % Time.get_ticks_usec()
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(original)
	file.close()
	var world := reopen(path)
	await step(3)
	var tasks: RefCounted = world.objectives.campaign_tasks
	check(FileAccess.get_file_as_string(path + ".before-v9.json") == original, "Actual v8 migration preserves an exact before-v9 backup")
	check(tasks.sleep_credits.is_empty(), "Opening a historical v8 world invents no sleep credit")
	var temple: RuinedTemple = world.ruins.temples[0]
	var key := SaveStore.key(temple.position)
	var guard := temple.guardians[0]
	temple.reveal_near(temple.position + Vector2(0,300))
	world.update_activity()
	guard.receive_damage(10)
	var remaining: int = guard.health
	var inv: ResourceInventory = world.get_node("Inventory")
	inv.reset()
	for data in [{"item":"madeira","quantity":9},{"item":"espada_pedra","quantity":1},{"item":"cantil","quantity":1,"water":2}]: inv.add_item(data)
	inv.equip_slot(1)
	inv.swap_slots(1,0)
	tasks.completed_stages.assign([2])
	tasks.sleep_credits.assign([2])
	tasks.sleep_used.clear()
	var chest: Node2D = temple.chests[0]
	chest.interact(inv)
	var drops := total_drops(world)
	check(drops > 0 and chest.released, "Opening a temple chest releases its actual loot budget onto ground")
	check(await world.save_progress(true), "Save v9 accepts inventory, wounded interior and unspent sleep ledger")
	world.queue_free()
	await step(3)
	world = reopen(path)
	await step(3)
	temple = find_building(world,key)
	guard = temple.guardians[0]
	tasks = world.objectives.campaign_tasks
	inv = world.get_node("Inventory")
	check(temple.interior_revealed and guard.health == remaining, "Reopening preserves reveal and wounded guardian HP")
	check(inv.slot_data(0).item == "espada_pedra" and inv.selected_index == 0 and inv.slot_data(2).water == 2, "Reopening preserves sorted inventory, equipment reference and attributes")
	check(tasks.sleep_credits == [2] and tasks.sleep_used.is_empty(), "An unused late-stage sleep survives reopening exactly once")
	check(total_drops(world) == drops and temple.chests[0].released, "Reopening chest preserves exact ground quantity without a second release")
	temple.chests[0].interact(inv)
	check(total_drops(world) == drops, "Revisiting opened chest cannot duplicate loot")
	guard.receive_damage(1000)
	await step(2)
	drops = total_drops(world)
	tasks.consume_sleep_credit()
	check(await world.save_progress(true), "Defeated guard and spent sleep credit commit together")
	world.queue_free()
	await step(3)
	world = reopen(path)
	await step(3)
	temple = find_building(world,key)
	check(temple.cleared_guards == [0] and not is_instance_valid(temple.guardians[0]), "Reopening never respawns the defeated interior guardian")
	check(total_drops(world) == drops and world.objectives.campaign_tasks.sleep_credits.is_empty() and world.objectives.campaign_tasks.sleep_used == [2], "Reopening never duplicates guardian drops or regrants spent sleep")
	var snapshot: Dictionary = world.progress_store.capture()
	check(snapshot.version == 9 and snapshot.objectives.campaign_tasks.version == 2 and SaveValidation.valid(snapshot), "Save v9 and tasks v2 validate after actual file reopen")
	check(FileAccess.get_file_as_string(path + ".before-v9.json") == original, "Repeated saves retain the untouched pre-migration v8 bytes")
	var bad := snapshot.duplicate(true)
	bad.objectives.campaign_tasks.sleep_credits = [2,2]
	check(not SaveValidation.valid(bad), "Duplicated sleep permissions are rejected")
	bad = snapshot.duplicate(true)
	bad.building_interiors[key].health = {"0":-1}
	check(not SaveValidation.valid(bad), "Corrupt interior state is rejected without loading")
	world.queue_free()
	await step(3)
	print("RC2 PERSISTENCE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
