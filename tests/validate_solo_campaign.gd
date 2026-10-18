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
func make_world(seed_value: int = 77, data: Dictionary = {}) -> Node2D:
	var world: Node2D = load("res://scenes/world.tscn").instantiate()
	world.world_seed = seed_value
	root.add_child(world)
	for path in ["EnemySpawner", "Animals", "DayNight", "WorldObjects/Player"]: world.get_node(path).set_physics_process(false)
	if not data.is_empty():
		world.initial_progress = data
		world.account_store = AccountProgress.new()
		var progress := WorldProgress.new()
		progress.world = world
		progress.load_progress()
	return world
func clock(world: Node2D, day: int, night: bool, offset: float = 10) -> void:
	world.get_node("DayNight").elapsed = (day - 1) * 600 + (300 if night else 0) + offset
	world.get_node("DayNight").refresh()
func capture(world: Node2D) -> Dictionary:
	var progress := WorldProgress.new()
	progress.world = world
	return progress.capture()
func mobs(world: Node2D, group: String) -> Array:
	var result := []
	for mob in get_nodes_in_group(group):
		if world.is_ancestor_of(mob) and not mob.dead and not mob.is_queued_for_deletion(): result.append(mob)
	return result
func conquer(world: Node2D, id: String) -> void:
	world.get_node("WorldObjects/Player").position = SoloCampaign.LOCATIONS[id] + Vector2(0, 35)
	world.campaign.interact(id)
	for i in range(6):
		await step(35)
		for mob in mobs(world, "temple_enemies"):
			mob.set_physics_process(false)
			mob.receive_damage(1000)
func run() -> void:
	var world := make_world()
	await step()
	var c: SoloCampaign = world.campaign
	var p: CharacterBody2D = world.get_node("WorldObjects/Player")
	check(c.encounter == "idle" and not c.repaired and c.components.is_empty(), "Mundo novo não concede etapas")
	check(not c.collect("lens") and not c.collect("pistola"), "Componentes exigem desafio, fora do loot comum")
	c.interact("beacon")
	check(c.interact("map").contains("noite 3") and not c.map_found, "Mapa bloqueado explica noite 3")
	check(not c.points.beacon.prompt().contains("ativar") and c.objective().contains("mapa"), "Noite 1 não anuncia ativação bloqueada")
	clock(world, 3, false)
	check(c.interact("map").contains("anoitecer") and not c.map_found, "Terceiro dia ainda exige anoitecer")
	clock(world, 3, true)
	c.interact("map")
	check(c.map_found and c.journal_text().contains("EXTREMO"), "Mapa revela os três desafios e preparo")
	check(c.temple_requirement("lens").contains("noite 4") and c.temple_requirement("coil").contains("primeiro"), "Pré-requisitos de templo e ordem concretos")
	clock(world, 4, true)
	check(world.get_node("HUD/Controls/Rows/Time").text.begins_with("Noite 4") and c.objective() == "Templo 1 · 0/4 vencidos", "Relógio e objetivo usam o mesmo dia ao saltar entre noites")
	p.position = SoloCampaign.LOCATIONS.lens + Vector2(0, 35)
	c.interact("lens")
	await step(35)
	var first := mobs(world, "temple_enemies")
	check(first.size() == 2 and first.any(func(m): return m.kind == "sentinela"), "Templo alto apresenta duas ameaças antes do Acólito")
	first[0].receive_damage(1000)
	first[1].set_physics_process(false)
	first[1].receive_damage(15)
	var saved := capture(world)
	var hp: int = first[1].health
	check(saved.campaign.temples.lens.cleared.size() == 1 and saved.campaign.temples.lens.health.values().has(hp), "Vitória individual e dano do templo entram no save")
	world.queue_free()
	await step()
	world = make_world(77, saved)
	c = world.campaign
	p = world.get_node("WorldObjects/Player")
	clock(world, 5, false)
	await step(35)
	first = mobs(world, "temple_enemies")
	check(first.size() == 1 and first[0].health == hp, "Reentrada diurna retoma só o inimigo vivo com a vida salva")
	await conquer(world, "lens")
	check(c.components == ["lens"] and c.temples.lens.cleared.size() == 4, "Duas formações garantem primeiro componente")
	check(not c.collect("lens") and c.interact("lens").contains("registrada"), "Conquista não duplica recompensa")
	check(c.temple_requirement("coil").contains("anoitecer"), "Extremo novo não inicia de dia")
	clock(world, 5, true)
	await conquer(world, "coil")
	await conquer(world, "core")
	check(c.components.size() == 3 and c.temples.coil.cleared.size() == 6 and c.temples.core.cleared.size() == 6, "Dois extremos distintos completam três componentes")
	check(c.interact("beacon").contains("dia 6") and not c.repaired, "Reparo aguarda sexto dia")
	clock(world, 6, false)
	c.interact("beacon")
	check(c.repaired and c.activation_requirement().contains("anoitecer"), "Sexto dia repara; ataque exige noite")
	p.position = SoloCampaign.LOCATIONS.beacon + Vector2(0, 50)
	clock(world, 6, true, 160)
	check(not c.start_encounter() and c.activation_requirement().contains("Pouco tempo"), "Ataque tardio explica orçamento mínimo")
	clock(world, 6, true)
	check(c.start_encounter() and c.attempts == 1, "Sexta noite inicia ataque sem consumir componentes")
	await step(40)
	check(c.final_enemies().size() == 3 and not is_instance_valid(c.boss), "Invasores precedem o Guardião")
	var resumed := SoloCampaign.new()
	check(resumed.restore(c.capture()) and resumed.encounter == "retry" and resumed.components.size() == 3, "Saída no ataque exige tentativa e preserva conquistas")
	resumed.free()
	c.interrupt_battle()
	await step()
	check(c.final_enemies().is_empty() and c.start_encounter(), "Retentativa limpa invasores sem duplicação")
	p.invulnerability = 0
	p.receive_damage(1000)
	check(c.encounter == "retry" and c.deaths == 1 and c.repaired, "Morte conserva templos, componentes e reparo")
	world.respawn_player()
	await step()
	p.position = SoloCampaign.LOCATIONS.beacon + Vector2(0, 50)
	clock(world, 9, true)
	check(c.start_encounter(), "Atraso permite tentar na noite 9")
	clock(world, 10, false)
	await step()
	check(c.encounter == "retry" and c.victory_day == 0, "Relógio sem Guardião não vence")
	clock(world, 10, true)
	c.start_encounter()
	for wave in range(2):
		await step(130)
		var active := c.final_enemies()
		check(active.size() == 3 and active.all(func(m): return m.kind != "guardiao_ilha"), "Formação final %d precede chefe" % (wave + 1))
		for mob in active: mob.set_physics_process(false)
		for mob in active: mob.receive_damage(1000)
	await step(130)
	check(c.final_wave == 2 and c.final_enemies().size() == 1 and is_instance_valid(c.boss), "Guardião é o último encontro")
	c.boss.receive_damage(1000)
	check(c.encounter == "awaiting_dawn" and world.get_node("HUD").current_panel != "victory", "Matar chefe aguarda amanhecer")
	saved = capture(world)
	check(SaveValidation.valid(saved) and CloudCodec.encode(saved).ok, "Campanha completa cabe no protocolo validado")
	world.queue_free()
	await step()
	world = make_world(77, saved)
	c = world.campaign
	check(c.encounter == "awaiting_dawn" and c.final_enemies().is_empty(), "Desconexão após chefe conserva resgate pendente")
	clock(world, 11, false, 0)
	await step()
	check(c.encounter == "won" and c.victory_day == 11 and world.get_node("HUD").current_panel == "victory", "Amanhecer seguinte confirma vitória e resumo")
	world.get_node("HUD").set_panel("")
	check(not paused and not c.start_encounter(), "Continuar explora sem outro chefe")
	saved = capture(world)
	var bad := saved.duplicate(true)
	bad.campaign.components.append("lens")
	check(not SaveValidation.valid(bad), "Save com recompensa duplicada é rejeitado")
	bad = saved.duplicate(true)
	bad.campaign.temples.core.cleared.clear()
	check(not SaveValidation.valid(bad), "Componente sem conquista é rejeitado")
	world.queue_free()
	await step()
	world = make_world(77, saved)
	await step()
	check(world.campaign.encounter == "won" and world.get_node("HUD").current_panel == "", "Vitória salva reabre sem repetir tela")
	world.queue_free()
	await step()
	for seed_value in [1, 77, 20261018, 2147480000]:
		world = make_world(seed_value)
		await step()
		var nav: RefCounted = load("res://tests/solo_navigation.gd").new()
		nav.build(world)
		for id in SoloCampaign.LOCATIONS:
			var path: PackedVector2Array = nav.path(Vector2(1152, 768), SoloCampaign.LOCATIONS[id])
			check(not path.is_empty(), "Caminho com colisões semente %d: %s" % [seed_value, id])
		world.queue_free()
		await step()
	print("%d verificações, %d falhas" % [checks, failures])
	quit(1 if failures else 0)
