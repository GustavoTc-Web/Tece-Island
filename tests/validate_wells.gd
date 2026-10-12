extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1
	print("PASS: " if value else "FAIL: ", label)
func step(frames: int = 3) -> void:
	for i in range(frames): await physics_frame
func run() -> void:
	var metadata := NaturalWells.generate(77)
	var all_fixed := true
	for id in metadata: all_fixed = all_fixed and metadata[id].has_well
	check(metadata.size() == 16 and all_fixed, "Um poço fixo em cada uma das dezesseis regiões")
	check(NaturalWells.generate(999) == metadata, "Mundos novos não sorteiam distribuição")
	var originals := true
	for id in NaturalWells.LEGACY_POSITIONS:
		originals = originals and SaveStore.vector(metadata[id].position) == NaturalWells.LEGACY_POSITIONS[id]
	check(originals, "Quatro poços originais preservados nas mesmas coordenadas")
	var valid := true
	for id in metadata:
		var point := SaveStore.vector(metadata[id].position)
		valid = valid and WorldTerrain.region_at(point).id == id and WorldTerrain.solid_ground(point, Vector2(48, 48))
	check(valid, "Novos poços em solo acessível")
	var world: Node2D = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await step()
	check(get_nodes_in_group("wells").size() == 16, "Mundo aplica regra anterior às novas regiões")
	var inv: ResourceInventory = world.get_node("Inventory")
	inv.add_item({"item": "cantil", "quantity": 1, "water": 2})
	inv.add_item({"item": "pistola", "quantity": 1, "loaded": 5})
	var progress := WorldProgress.new()
	progress.world = world
	var old := progress.capture()
	old.version = 1
	old.erase("region_wells")
	old.erase("wells_policy")
	old.wells = []
	for point in NaturalWells.LEGACY_POSITIONS.values(): old.wells.append(SaveStore.point(point))
	var storage := ResourceInventory.new()
	storage.base_capacity = 12
	storage.reset()
	storage.add_item({"item": "cantil", "quantity": 1, "water": 3})
	old.structures.append({"kind": "bau", "position": [-608, 768], "storage": storage.network_state()})
	storage.free()
	DirAccess.make_dir_recursive_absolute("res://.tools/save-tests")
	var path := "res://.tools/save-tests/fixed-wells-%d.json" % Time.get_ticks_usec()
	var bytes := JSON.stringify(old)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(bytes)
	file.close()
	var restored: Node2D = load("res://scenes/world.tscn").instantiate()
	restored.persistence_enabled = true
	restored.progress_path = path
	root.add_child(restored)
	await step()
	check(FileAccess.get_file_as_string(path + ".before-v3.json") == bytes, "Backup exato antes de converter formato antigo")
	var saved: Dictionary = restored.progress_store.store.read()
	check(saved.version == 3 and saved.region_wells.size() == 16 and saved.wells_policy == "fixed", "Layout fixo persistido")
	check(restored.get_node("Inventory").slots == inv.slots, "Conversão conserva inventário, munição e doses")
	var found_base := false
	for node in restored.get_node("WorldObjects").get_children():
		if node is PlacedStructure and node.kind == "bau": found_base = node.position == Vector2(-608, 768) and node.storage.slot_data(0).water == 3
	check(found_base, "Base e conteúdo conservados na posição antiga")
	var overlap := false
	for state in saved.region_wells.values():
		if state.has_well and SaveStore.vector(state.position).distance_to(Vector2(-608, 768)) < 60: overlap = true
	check(not overlap, "Poço novo não sobrescreve base salva")
	var reentered: Node2D = load("res://scenes/world.tscn").instantiate()
	reentered.persistence_enabled = true
	reentered.progress_path = path
	root.add_child(reentered)
	await step()
	check(reentered.region_wells == restored.region_wells, "Reentrar e carregar preservam o layout")
	var draft := {}
	for region in WorldTerrain.regions(): draft[region.id] = {"has_well": false}
	var repaired := NaturalWells.generate(1, draft)
	var restored_count := 0
	for state in repaired.values():
		if state.has_well: restored_count += 1
	check(restored_count == 16, "Estado da proposta descartada também retorna à regra fixa")
	world.queue_free()
	restored.queue_free()
	reentered.queue_free()
	await process_frame
	print("%d verificações, %d falhas" % [checks, failures])
	quit(1 if failures else 0)
