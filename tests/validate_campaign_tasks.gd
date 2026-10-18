extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS: " if ok else "FAIL: ", label)
func step() -> void:
	for i in range(3): await physics_frame
func make_world(data: Dictionary = {}) -> Node2D:
	var world: Node2D = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	for path in ["EnemySpawner", "Animals", "DayNight", "WorldObjects/Player"]: world.get_node(path).set_physics_process(false)
	if not data.is_empty():
		world.initial_progress = data
		world.account_store = AccountProgress.new()
		var progress := WorldProgress.new()
		progress.world = world
		progress.load_progress()
		world.objectives.reconcile(world)
	return world
func capture(world: Node2D) -> Dictionary:
	var progress := WorldProgress.new()
	progress.world = world
	return progress.capture()
func same(a: Variant, b: Variant) -> bool:
	return JSON.stringify(JSON.parse_string(JSON.stringify(a))) == JSON.stringify(JSON.parse_string(JSON.stringify(b)))
func run() -> void:
	var world := make_world()
	await step()
	var t: CampaignTasks = world.objectives.campaign_tasks
	var inv: ResourceInventory = world.get_node("Inventory")
	var hud: CanvasLayer = world.get_node("HUD")
	check(t.automatic_stage() == 0 and t.rows(0).all(func(r): return not r.done), "Mundo novo tem quatro tarefas concretas sem crédito inventado")
	check(hud.objective_button.text.contains("0/4") and hud.task_panel.next_task == "axe", "HUD mostra contador e próximo passo")
	check(hud.task_panel.size.y < world.get_viewport_rect().size.y * 0.62, "Painel expandido preserva área de jogo")
	inv.add_resource("madeira", 11)
	inv.add_resource("pedra", 7)
	for id in ["machado_madeira", "picareta_madeira", "espada_pedra", "fogueira"]: check(inv.craft(id), "Fabricação real atende " + id)
	check(t.rows(0).all(func(r): return r.done) and hud.objective_button.text.contains("4/4"), "Conclusão automática atualiza contador")
	inv.reset()
	check(t.rows(0).all(func(r): return r.done), "Perder ou usar equipamento não apaga fabricação")
	hud.task_panel.toggle.pressed.emit()
	check(t.collapsed and not hud.task_panel.rows_box.visible, "Painel recolhe sem perder contador")
	var saved := capture(world)
	check(SaveValidation.valid(saved) and saved.version == 8, "Save v8 inclui progresso validado")
	var encoded := CloudCodec.encode(saved)
	check(encoded.ok and CloudCodec.hash_state(saved) != CloudCodec.hash_state(saved.merged({"objectives": {}}, true)), "Conquistas integram hash e codec da nuvem")
	world.queue_free()
	await step()
	world = make_world(JSON.parse_string(JSON.stringify(saved)))
	t = world.objectives.campaign_tasks
	inv = world.get_node("Inventory")
	hud = world.get_node("HUD")
	check(t.rows(0).all(func(r): return r.done) and t.collapsed, "Reabrir restaura conquistas e painel recolhido")
	var once := t.capture()
	world.objectives.reconcile(world)
	world.objectives.reconcile(world)
	check(t.capture() == once, "Reconciliação repetida não duplica contagens")
	inv.add_resource("carne_cozida", 3)
	check(t.task("food3").done and t.task("food6").value == 3, "Suprimentos reconhecem preparação antecipada")
	world.get_node("WorldObjects/Player/Needs").hunger = 50
	world.get_node("WorldObjects/Player/Needs").use_slot(inv, 0)
	check(not t.task("food3").done and t.task("food3").value == 2 and t.task("food3").mode == "agora", "Consumir comida reduz condição atual")
	inv.add_resource("armadura_pedra")
	check(not t.task("wear").done, "Ter armadura na bolsa não equivale a equipar")
	inv.equip_armor(1)
	check(t.task("wear").done, "Equipar armadura conclui condição atual")
	inv.remove_armor()
	check(not t.task("wear").done, "Retirar armadura reabre condição atual")
	inv.reset()
	inv.add_item({"item":"cantil", "quantity":1, "water":2})
	check(t.task("water2").done and not t.task("water3").done, "Doses de água usam atributo real do cantil")
	inv.use_water(0)
	check(not t.task("water2").done, "Beber não deixa reserva de água fictícia")
	var cycle: DayNightCycle = world.get_node("DayNight")
	cycle.elapsed = 4 * 600 + 10
	cycle.refresh()
	check(t.automatic_stage() == 2 and t.journal_text().contains("Dia 1") and t.journal_text().contains("Dia 5"), "Mapa atrasado permanece acessível junto à lista completa")
	check(t.task("map").requirement.contains("anoitecer"), "Requisito bloqueado explica espera sem bloquear preparos")
	var before: String = world.campaign.activation_requirement()
	t.crafted.clear()
	check(world.campaign.activation_requirement() == before, "Preparações não acrescentam bloqueios à campanha")
	var legacy: Dictionary = world.objectives.capture()
	legacy.erase("campaign_tasks")
	legacy.crafted_tools = {"picareta_pedra":true, "machado_pedra":true, "espada_pedra":true}
	legacy.values.tools = 3
	legacy.values.fire = 1
	legacy.values.bag = 1
	check(world.objectives.restore(legacy) and t.ever("machado_pedra") and t.ever("fogueira") and t.ever("mochila"), "Histórico individual legado é preservado sem os itens presentes")
	check(not t.ever("armadura_pedra") and not t.ever("arco"), "Ausência de evidência não inventa fabricação antiga")
	inv.add_resource("arco")
	world.objectives.reconcile(world)
	check(t.ever("arco") and "arco" in t.inferred, "Item fabricável no save é reconhecido com origem indicada")
	var bad := t.capture()
	bad.crafted.append("arco")
	check(not CampaignTasks.valid(bad), "Fabricação duplicada em payload é rejeitada")
	bad = t.capture()
	bad.crafted.append("pistola")
	check(not CampaignTasks.valid(bad), "Item fora do catálogo de metas é rejeitado")
	var invalid := capture(world)
	invalid.objectives.campaign_tasks = bad
	check(not SaveValidation.valid(invalid), "Protocolo de save rejeita tarefas corrompidas")
	world.campaign.encounter = "won"
	check(t.task("waves").done and t.task("rescue").done, "Vitória anterior atende os marcos finais sem novo confronto")
	world.queue_free()
	await step()
	var original := FileAccess.get_file_as_string("res://tests/fixtures/solo_v07.json")
	var path := "res://.tools/tasks-v7-%d.json" % Time.get_ticks_usec()
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(original)
	file.close()
	var store := SaveStore.new()
	store.path = path
	var old := store.read()
	check(old.version == 7 and FileAccess.get_file_as_string(path + ".before-v8.json") == original, "Migração v7 preserva backup exato e hash de leitura")
	world = make_world(old)
	var current := capture(world)
	check(current.version == 8 and same(current.inventory, old.inventory) and same(current.structures, old.structures), "Migração para tarefas conserva inventário e construções")
	check(store.write(current) and FileAccess.get_file_as_string(path + ".before-v8.json") == original, "Gravar novamente conserva backup original")
	world.queue_free()
	await step()
	world = make_world()
	inv = world.get_node("Inventory")
	t = world.objectives.campaign_tasks
	# Budget fixture validates actual recipes/capacity, not timed collection.
	inv.add_resource("madeira", 12)
	inv.add_resource("fibra", 14)
	check(inv.craft("mochila") and inv.capacity == 9, "Bolsa 1 é viável antes de recolher o resto do preparo")
	inv.add_resource("pedra", 26)
	inv.add_resource("linha", 4)
	inv.add_resource("carne_crua", 2)
	check(inv.craft("machado_pedra") and inv.craft("picareta_pedra") and inv.craft("armadura_pedra"), "Orçamento do dia 2 fabrica ferramentas e proteção")
	for index in range(inv.capacity):
		if inv.slot_data(index).get("item") == "armadura_pedra": inv.equip_armor(index); break
	inv.cooking_available = true
	check(inv.craft("cantil") and inv.fill_canteen() and inv.craft("carne_cozida") and inv.craft("carne_cozida"), "Orçamento do dia 2 inclui cantil e duas comidas")
	check(t.rows(1).all(func(r):return r.done), "Cinco objetivos do dia 2 cabem na bolsa 1 e nas receitas existentes")
	inv.add_resource("madeira", 13)
	inv.add_resource("pedra", 2)
	inv.add_resource("linha", 3)
	inv.add_resource("carne_crua", 1)
	check(inv.craft("arco") and inv.craft("flecha") and inv.craft("flecha") and inv.craft("carne_cozida"), "Orçamento adicional do dia 3 fornece arco, oito flechas e terceira comida")
	check(t.rows(2).slice(0,4).all(func(r):return r.done) and not t.task("map").done, "Expedição adiantada é reconhecida sem conceder mapa")
	world.get_node("DayNight").elapsed = 2 * 600 + 310
	world.get_node("DayNight").refresh()
	world.campaign.interact("map")
	check(t.rows(2).all(func(r):return r.done), "Mapa real completa a quinta tarefa da expedição")
	world.queue_free()
	await step()
	print("CAMPAIGN TASKS: %d verificações, %d falhas" % [checks, failures])
	quit(1 if failures else 0)
