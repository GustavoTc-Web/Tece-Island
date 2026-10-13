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
	var goals: IslandObjectives = world.objectives
	goals.completed.connect(func(_title): notices += 1)
	var inv: ResourceInventory = world.get_node("Inventory")
	for pair in [["madeira", 45], ["pedra", 13], ["fibra", 12], ["linha", 12]]: inv.add_resource(pair[0], pair[1])
	check(goals.values.wood == 0 and goals.values.stone == 0, "Posse sem coleta não inventa histórico")
	check(inv.craft("mochila") and inv.craft("mochila_2") and inv.craft("mochila_3") and goals.values.bag == 3, "Melhorias reais registram bolsa antecipada")
	for id in IslandObjectives.STONE_TOOLS: check(inv.craft(id) and goals.crafted_tools[id], "Craft real registra " + id)
	check(not inv.craft("picareta_pedra") and goals.values.tools == 3, "Craft rejeitado não duplica progresso")
	check(inv.craft("fogueira") and goals.values.fire == 1 and notices == 0, "Fogueira antecipada aguarda sequência")
	for item in ["madeira", "pedra"]:
		var drop: ResourceDrop = load("res://scenes/resource_drop.tscn").instantiate()
		drop.resource = item
		drop.quantity = 10
		world.get_node("WorldObjects").add_child(drop)
		drop.collect(inv)
		if item == "madeira": check(goals.tracked == "stone" and notices == 1, "Coleta real libera segunda etapa")
	check(goals.tracked.is_empty() and notices == 5, "Coleta libera metas antecipadas na ordem")
	var state := goals.capture()
	check(goals.restore(state) and goals.capture() == state and notices == 5, "Restore não repete sons ou avisos")
	var legacy := IslandObjectives.new()
	check(legacy.restore({"values": {"wood": 10, "tool": 1, "base": 2}}), "Objetivos anteriores aceitos")
	legacy.reconcile(world)
	check(legacy.values.wood == 10 and legacy.values.stone == 0 and legacy.values.tools == 3 and legacy.values.fire == 1 and legacy.values.bag == 3, "Migração usa coleta registrada e itens fabricáveis presentes")
	legacy.free()
	var hud: CanvasLayer = world.get_node("HUD")
	hud.objective_button.pressed.emit()
	check(hud.current_panel == "journal" and hud.journal_view.pages.get_child_count() == 6 and hud.journal_view.text.text == "Objetivos iniciais concluídos", "Botão abre cinco etapas e confirmação final")
	hud.set_panel("")
	goals.enabled = false
	goals.changed.emit()
	check(not hud.objective_button.visible, "Configuração permite ocultar objetivo")
	world.queue_free()
	await process_frame
	print("OBJECTIVES: %d verificações, %d falhas" % [checks, failures])
	quit(1 if failures else 0)
