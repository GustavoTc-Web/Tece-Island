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
	check(FileAccess.get_file_as_string(path + ".before-v9.json") == original, "Backup v8 preserva bytes do save produzido pela 0.8.3")
	var current: Dictionary = world.progress_store.capture()
	check(current.version == SaveStore.VERSION and world.world_seed == old.world_seed, "Migração conserva semente e versiona formato")
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
	await world.save_progress(true)
	check(FileAccess.get_file_as_string(path + ".before-v9.json") == original and FileAccess.get_file_as_string(path + ".before-campaign-v1.json") == original, "Primeira gravação conserva ambos os backups originais")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(saved.version == SaveStore.VERSION and saved.campaign.components.is_empty(), "Mundo v5 chega ao v8 sem etapas inventadas")
	# Produce a future-format fixture for the unchanged 0.8.3 rejection probe.
	var future := FileAccess.open("res://.tools/solo-v8-save.json", FileAccess.WRITE)
	future.store_string(JSON.stringify(saved))
	future.close()
	world.queue_free()
	await step()
	# This fixture was captured by pilot .1 before the revision, not fabricated
	# by the new converter. Keep it immutable for rollback and hash assertions.
	original = FileAccess.get_file_as_string("res://tests/fixtures/solo_v06.json")
	old = JSON.parse_string(original)
	var store := SaveStore.new()
	store.path = path + "-v6"
	file = FileAccess.open(store.path, FileAccess.WRITE)
	file.store_string(original)
	file.close()
	var read := store.read()
	check(read.version == 6 and read.campaign.version == 1 and CloudCodec.hash_state(read) == CloudCodec.hash_state(old), "Ler v6 conserva hash confirmado; conversão só no mundo carregado")
	world = load("res://scenes/world.tscn").instantiate()
	world.persistence_enabled = true
	world.progress_path = store.path
	root.add_child(world)
	for node in ["DayNight", "EnemySpawner", "Animals", "WorldObjects/Player"]: world.get_node(node).set_physics_process(false)
	await step()
	current = world.progress_store.capture()
	check(current.version == SaveStore.VERSION and current.campaign.version == 2 and current.campaign.components == old.campaign.components, "v6 conserva exatamente os componentes legítimos")
	check(current.campaign.repaired == old.campaign.repaired and current.campaign.attempts == old.campaign.attempts and current.campaign.deaths == old.campaign.deaths, "Conversão conserva reparo, tentativas e mortes")
	check(same(current.inventory, old.inventory) and same(current.structures, old.structures) and current.world_seed == old.world_seed, "v6 conserva inventários, construções, IDs e semente")
	check(not current.campaign.map_found and current.campaign.temples.lens.credit and world.campaign.journal_text().contains("Crédito legado"), "Crédito legado explícito; mapa novo continua pendente")
	check(not world.campaign.start_encounter() and world.campaign.activation_requirement().contains("mapa"), "Reparo antigo não salta requisito do mapa")
	await world.save_progress(true)
	await world.save_progress(true)
	check(FileAccess.get_file_as_string(store.path + ".before-v9.json") == original and FileAccess.get_file_as_string(store.path + ".before-campaign-v2.json") == original, "Backups v6 e campanha 1 são exatos e idempotentes")
	world.queue_free()
	await step()
	for count in range(4):
		var legacy: Dictionary = old.campaign.duplicate(true)
		legacy.components = SoloCampaign.COMPONENTS.slice(0, count)
		legacy.repaired = false
		legacy.encounter = "idle"
		legacy.victory_day = 0
		var c := SoloCampaign.new()
		check(c.restore(legacy) and c.components.size() == count and SoloCampaign.valid(c.capture()), "Conversão parcial %d/3 não concede nada" % count)
		c.free()
	var legacy: Dictionary = old.campaign.duplicate(true)
	legacy.encounter = "active"
	var c := SoloCampaign.new()
	check(c.restore(legacy) and c.encounter == "retry", "Ataque v6 interrompido vira retentativa")
	c.free()
	legacy.encounter = "won"
	legacy.victory_day = 12
	c = SoloCampaign.new()
	check(c.restore(legacy) and c.encounter == "won" and c.victory_day == 12 and SoloCampaign.valid(c.capture()), "Vitória v6 preservada sem redefinir campanha")
	c.free()
	print("%d verificações, %d falhas" % [checks, failures])
	quit(1 if failures else 0)
