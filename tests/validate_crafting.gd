extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1
	print("PASS: " if value else "FAIL: ", label)
func run() -> void:
	var world: Node = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var hud = world.get_node("HUD")
	var inv: ResourceInventory = world.get_node("Inventory")
	hud.set_panel("crafting")
	check(not hud.crafting_view.rows.carne_cozida.visible, "Cozidos ausentes da fabricação geral")
	check(hud.crafting_view.rows.cantil.visible, "Recursos exibem cantil")
	hud.crafting_view.group = "Ferramentas"
	hud.crafting_view.refresh()
	check(hud.crafting_view.rows.picareta_madeira.visible and not hud.crafting_view.rows.cantil.visible, "Categoria separa ferramentas e recursos")
	hud.crafting_view.search.text = "picareta"
	hud.crafting_view.refresh()
	check(hud.crafting_view.rows.picareta_pedra.visible and not hud.crafting_view.rows.machado_pedra.visible, "Busca filtra pelo nome")
	hud.crafting_view.search.text = ""
	hud.crafting_view.group = "Alimentos"
	hud.crafting_view.refresh()
	check(hud.crafting_view.empty.visible, "Categoria vazia explica fogueira sem inventar receita")
	hud.set_panel("crafting")
	hud._craft("carne_cozida")
	check(inv.count_item("carne_cozida") == 0, "Comando de cozinha rejeitado fora da interface da fogueira")
	inv.add_resource("madeira", 4)
	inv.add_resource("fibra", 4)
	hud.crafting_view.group = "Recursos"
	hud.crafting_view.refresh()
	check(hud.crafting_view.labels.cantil.text.contains("Madeira: 4/2") and hud.crafting_view.labels.cantil.text.contains("×1"), "Quantidade e ingredientes disponíveis/necessários")
	check(hud.crafting_view.reasons.cama.visible and hud.recipe_buttons.cama.disabled, "Motivo visível sem depender de hover")
	hud._craft("cantil")
	check(inv.count_item("cantil") == 1 and inv.wood == 2 and inv.count_item("fibra") == 2, "Fabricação entrega e consome exatamente uma vez")
	hud.open_cooking()
	check(hud.crafting_view.rows.carne_cozida.visible and not hud.crafting_view.rows.cantil.visible, "Fogueira só exibe receitas de cozinha")
	hud._craft("carne_cozida")
	check(inv.count_item("carne_cozida") == 0, "Cozinhar exige proximidade da fogueira")
	hud.set_panel("")
	check(not paused and not world.get_node("WorldObjects/Player").controls_blocked, "Fechar devolve controles")
	world.queue_free()
	await process_frame
	print("%d verificações, %d falhas" % [checks, failures])
	quit(1 if failures else 0)
