extends SceneTree
var checks := 0
var failures := 0
var notices := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS: " if ok else "FAIL: ", label)
func run() -> void:
	var world: Node2D = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	var player: CharacterBody2D = world.get_node("WorldObjects/Player")
	player.set_physics_process(false)
	var needs: SurvivalNeeds = player.get_node("Needs")
	needs.set_physics_process(false)
	var inv: ResourceInventory = world.get_node("Inventory")
	inv.add_resource("carne_cozida", 3)
	player.health = 30
	needs.use_slot(inv, 0)
	check(inv.count_item("carne_cozida") == 2 and player.regeneration_ticks == 5, "Comer com fome cheia desconta uma unidade e inicia cinco ticks")
	player.step_regeneration(0.99)
	check(player.health == 30, "Cura espera um segundo completo")
	player.step_regeneration(0.01)
	check(player.health == 35, "Primeiro tick cura exatamente cinco HP")
	needs.use_slot(inv, 0)
	player.step_regeneration(5)
	check(player.health == 60 and player.regeneration_ticks == 0, "Outro alimento renova cinco ticks sem acumular taxa")
	player.health = 99
	player.renew_regeneration()
	paused = true
	player.step_regeneration(3)
	check(player.health == 99 and player.regeneration_ticks == 5, "Pausa solo congela cura")
	paused = false
	player.step_regeneration(5)
	check(player.health == 100, "Cura respeita vida máxima")
	player.renew_regeneration()
	player.invulnerability = 0
	player.receive_damage(200)
	check(player.dead and player.regeneration_ticks == 0, "Morte cancela regeneração")
	player.respawn(Vector2(1152, 768))
	paused = false
	inv.reset()
	inv.add_resource("pedra", 20)
	inv.add_resource("linha", 4)
	check(inv.craft("armadura_pedra") and inv.count_item("pedra") == 0 and inv.count_item("linha") == 0, "Receita usa vinte pedras e quatro linhas")
	var armor_index := -1
	for i in range(inv.capacity):
		if inv.slot_data(i).get("item", "") == "armadura_pedra": armor_index = i
	check(inv.equip_slot(armor_index) and player.protection == 10, "Equipar transfere para campo próprio e atualiza proteção")
	player.invulnerability = 0
	player.receive_damage(4)
	check(is_equal_approx(player.health, 100 - 4.0 / 1.1), "Golpe pequeno conserva redução fracionária")
	var before: float = player.health
	player.receive_damage(1, true)
	check(is_equal_approx(player.health, before - 1), "Veneno e necessidades ignoram armadura")
	player.health = 100
	player.protection = 100
	player.invulnerability = 0
	player.receive_damage(10)
	check(player.health == 95, "Cem de proteção reduz cinquenta por cento")
	for i in range(inv.capacity): inv.add_resource("cama", 1)
	check(not inv.remove_armor() and not inv.armor.is_empty(), "Inventário cheio bloqueia retirada sem perda")
	inv.take_slot(0, 1)
	check(inv.remove_armor() and player.protection == 0 and inv.count_item("armadura_pedra") == 1, "Retirada conserva item e remove bônus")
	var cycle: DayNightCycle = world.get_node("DayNight")
	cycle.set_physics_process(false)
	cycle.elapsed = 28
	cycle.refresh()
	check(world.get_node("HUD/Controls/Rows/Time").text == "Dia — Anoitece em 04:32", "HUD consulta relógio real para dia")
	cycle.elapsed = 462
	cycle.refresh()
	check(world.get_node("HUD/Controls/Rows/Time").text == "Noite — Amanhece em 02:18", "HUD consulta relógio real para noite")
	var goals: IslandObjectives = world.objectives
	goals.completed.connect(func(_title): notices += 1)
	goals.crafted("fogueira")
	for id in IslandObjectives.STONE_TOOLS: goals.crafted(id)
	goals.crafted("mochila_3")
	check(goals.tracked == "wood" and notices == 0, "Craft antecipado registrado sem pular etapa ativa")
	goals.collected("madeira", 10)
	check(goals.tracked == "stone" and notices == 1, "Madeira desbloqueia pedra")
	goals.collected("pedra", 10)
	check(goals.tracked.is_empty() and notices == 5, "Etapas antecipadas completam sequência automaticamente")
	var state := goals.capture()
	check(goals.restore(state) and notices == 5 and goals.capture() == state, "Save restaura metas sem repetir conquistas")
	for region in WorldTerrain.regions():
		if region.kind == "Aquático": continue
		var count := 0
		for node in world.get_node("WorldObjects").get_children():
			if (node is AbandonedBuilding or node.get_script() == preload("res://scripts/ruined_temple.gd")) and region.rect.has_point(node.position): count += 1
		check(count >= 1, "Construção explorável na região " + region.id)
	var progress := WorldProgress.new()
	progress.world = world
	var saved := progress.capture()
	var first_id: String = saved.building_loot.keys()[0]
	saved.building_loot[first_id] = {"contents": {}, "released": true}
	var other: Node2D = load("res://scenes/world.tscn").instantiate()
	other.persistence_enabled = true
	other.initial_progress = saved
	other.account_store = AccountProgress.new()
	other.account_store.configure("fixture")
	root.add_child(other)
	await process_frame
	check(other.region_buildings == world.region_buildings, "Migração preserva IDs e posições após recarga")
	var other_save := WorldProgress.new()
	other_save.world = other
	check(other_save.capture().building_loot[first_id].released, "Recarga não repõe loot consumido")
	check(other_save.capture().loot.size() == saved.loot.size(), "Recarga não duplica construções ou recipientes")
	world.queue_free()
	other.queue_free()
	await process_frame
	print("NEXT MECHANICS: %d verificações, %d falhas" % [checks, failures])
	quit(1 if failures else 0)
