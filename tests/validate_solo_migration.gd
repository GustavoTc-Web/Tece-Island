extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1
	print("PASS: " if value else "FAIL: ", label)
func step() -> void:
	for i in range(3): await physics_frame
func same(a: Variant, b: Variant) -> bool:
	return JSON.stringify(JSON.parse_string(JSON.stringify(a))) == JSON.stringify(JSON.parse_string(JSON.stringify(b)))
func run() -> void:
	# Captured by running unmodified main 7eae4f3 (0.8.3), seed 77.
	var original := FileAccess.get_file_as_string("res://tests/fixtures/solo_v083.json")
	var old: Dictionary = JSON.parse_string(original)
	var path := "res://.tools/solo-migration-%d.json" % Time.get_ticks_usec()
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(original)
	file.close()
	var world: Node2D = load("res://scenes/world.tscn").instantiate()
	world.persistence_enabled = true
	world.progress_path = path
	root.add_child(world)
	world.get_node("DayNight").set_physics_process(false)
	world.get_node("EnemySpawner").set_physics_process(false)
	world.get_node("WorldObjects/Player").set_physics_process(false)
	await step()
	check(FileAccess.get_file_as_string(path + ".before-v6.json") == original, "Backup v6 preserva bytes do save produzido pela 0.8.3")
	var current: Dictionary = world.progress_store.capture()
	check(current.version == 6 and world.world_seed == old.world_seed, "Migração conserva semente e versiona formato")
	check(same(current.inventory, old.inventory), "Inventário antigo conserva itens e atributos")
	check(same(current.structures, old.structures), "IDs, posição, nome e conteúdo do baú antigo permanecem exatos")
	check(current.player.position == old.player.position and current.player.health == old.player.health and absf(current.elapsed - old.elapsed) < 2, "Posição, vida e noite 11 antigas permanecem")
	var wells_ok := true
	for id in old.region_wells:
		wells_ok = wells_ok and JSON.stringify(current.region_wells[id]) == JSON.stringify(old.region_wells[id])
	check(wells_ok and current.region_wells.size() == 18, "Poços antigos não se movem; regiões novas ganham poços")
	var loot_ok := true
	for id in old.loot:
		loot_ok = loot_ok and current.loot.has(id) and JSON.stringify(current.loot[id]) == JSON.stringify(old.loot[id])
	check(loot_ok, "Todos os recipientes antigos conservam sorteio e estado")
	var resources_ok := true
	for key in current.resources:
		var xy := str(key).split(",")
		var point := Vector2(float(xy[0]), float(xy[1]))
		if WorldTerrain.region_at(point).get("id", "") in old.generated_regions:
			resources_ok = resources_ok and old.resources.has(key) and old.resources[key] == current.resources[key]
	for key in old.resources: resources_ok = resources_ok and current.resources.has(key)
	check(resources_ok, "Área antiga não regenera recursos removidos nem perde progresso de extração")
	check(world.campaign.encounter == "idle" and world.campaign.components.is_empty(), "Save antigo recebe campanha nova sem inventar conclusão")
	check(world.campaign.blocked_by_base("beacon"), "Base antiga junto ao sinal permite acesso de recuperação pelo Diário")
	world.get_node("HUD").journal_view.refresh()
	var recovery_found := false
	for button in world.get_node("HUD").journal_view.pages.get_children():
		if button is Button and button.text == "Acessar sinalizador pela base": recovery_found = true
	check(recovery_found, "Ação de recuperação aparece para construção antiga preservada")
	for id in SoloCampaign.COMPONENTS: world.campaign.collect(id)
	world.campaign.interact("beacon")
	check(world.campaign.start_encounter(), "Mundo v5 que passou da sétima noite pode enfrentar o chefe")
	world.campaign.interrupt_battle()
	await world.save_progress(true)
	check(FileAccess.get_file_as_string(path + ".before-v6.json") == original and FileAccess.get_file_as_string(path + ".before-campaign-v1.json") == original, "Primeira gravação conserva ambos os backups originais")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(saved.version == 6 and saved.campaign.encounter == "retry", "Tentativa e campanha ficam no save v6")
	# Produce a future-format fixture for the unchanged 0.8.3 rejection probe.
	var future := FileAccess.open("res://.tools/solo-v6-save.json", FileAccess.WRITE)
	future.store_string(JSON.stringify(saved))
	future.close()
	world.queue_free()
	await step()
	print("%d verificações, %d falhas" % [checks, failures])
	quit(1 if failures else 0)
