extends SceneTree
var checks := 0
var failures := 0
var notices := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1
	print("PASS: " if value else "FAIL: ", label)
func run() -> void:
	var world: Node2D = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	var goals: IslandObjectives = world.objectives
	goals.completed.connect(func(_title): notices += 1)
	var inv: ResourceInventory = world.get_node("Inventory")
	inv.add_resource("madeira", 20)
	check(goals.values.wood == 0, "Posse sem evento não inventa contagem histórica de coleta")
	var drop: ResourceDrop = load("res://scenes/resource_drop.tscn").instantiate()
	drop.quantity = 10
	world.get_node("WorldObjects").add_child(drop)
	drop.collect(inv)
	check(goals.values.wood == 10 and notices == 1, "Coleta real completa objetivo e notifica uma vez")
	goals.collected("madeira", 10)
	check(notices == 1, "Novas coletas não duplicam conclusão")
	check(inv.craft("machado_madeira") and goals.values.tool == 1, "Fabricação efetiva completa ferramenta")
	check(not inv.craft("machado_pedra") and notices == 2, "Receita sem materiais não progride")
	world.get_node("Structures").placed.emit("cama")
	world.get_node("Structures").placed.emit("cama")
	check(goals.values.base == 1, "Camas repetidas contam apenas um dos tipos")
	world.get_node("Structures").placed.emit("fogueira")
	check(goals.values.base == 2, "Cama e fogueira completam base")
	inv.add_resource("carne_crua", 1)
	inv.cooking_available = true
	inv.craft("carne_cozida")
	check(goals.values.meal == 1, "Cozinhar refeição progride somente com craft válido")
	world.journal.collect("trail")
	check(goals.values.record == 0, "Segundo registro não substitui primeiro")
	world.journal.collect("arrival")
	check(goals.values.record == 1, "Primeiro registro completa marco")
	world.get_node("WorldObjects/Player").position = world.ruins.temples[0].position + Vector2(0, 100)
	goals.visit(world)
	check(goals.values.temple == 1 and notices == 6, "Visita ao interior real do templo completa sexto objetivo")
	goals.tracked = "temple"
	goals.collapsed = true
	goals.enabled = false
	var state := goals.capture()
	goals.restore(state)
	goals.reconcile(world)
	check(notices == 6 and goals.capture() == state, "Restore preserva acompanhamento e não renotifica conquistas")
	var legacy := IslandObjectives.new()
	legacy.restore({})
	var bed: PlacedStructure = load("res://scenes/placed_structure.tscn").instantiate()
	bed.kind = "cama"
	bed.system = world.get_node("Structures")
	world.get_node("WorldObjects").add_child(bed)
	legacy.reconcile(world)
	check(legacy.values.base == 1 and legacy.values.wood == 0 and legacy.values.tool == 0, "Legado reconhece cama presente sem inventar histórico ausente")
	legacy.free()
	var hud: CanvasLayer = world.get_node("HUD")
	hud.set_panel("journal")
	hud.journal_view.goals_mode = true
	hud.journal_view.refresh()
	check(hud.journal_view.pages.get_child_count() == 7 and not hud.objective_button.visible, "Lista separada e painel bloqueia HUD")
	hud.set_panel("")
	check(not hud.objective_button.visible, "Desativação persiste na interface")
	world.queue_free()
	await process_frame
	print("OBJECTIVES: %d verificações, %d falhas" % [checks, failures])
	quit(1 if failures else 0)
