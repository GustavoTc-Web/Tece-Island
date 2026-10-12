extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1
	print("PASS: " if value else "FAIL: ", label)
func step() -> void:
	for i in range(4): await physics_frame
func place(world: Node2D, kind: String, offset: Vector2) -> PlacedStructure:
	var piece: PlacedStructure = load("res://scenes/placed_structure.tscn").instantiate()
	piece.kind = kind
	piece.system = world.get_node("Structures")
	piece.position = piece.system.player.position + offset
	world.get_node("WorldObjects").add_child(piece)
	return piece
func run() -> void:
	var world: Node2D = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await step()
	var inv: ResourceInventory = world.get_node("Inventory")
	var chest := place(world, "bau", Vector2(65, 0))
	chest.storage.add_resource("madeira", 10)
	var id := chest.structure_id
	check(chest.rename_chest("Expedição") and chest.structure_id == id and chest.storage.wood == 10, "Renomear conserva ID e conteúdo")
	check(not chest.rename_chest("a".repeat(25)) and not chest.rename_chest(" "), "Nome rejeita vazio e mais de 24 caracteres")
	inv.add_resource("madeira", 13)
	for i in range(6): inv.add_resource("cama", 1)
	check(chest.storage.transfer_to(inv, 0, true) == 2 and chest.storage.wood == 8 and inv.wood == 15, "Pilha transfere apenas espaço disponível, conserva resto")
	check(chest.storage.transfer_to(inv, 0) == 0 and chest.storage.wood == 8, "Destino cheio não duplica nem perde itens")
	check(chest.dismantle(inv).contains("Baú cheio") and not chest.is_queued_for_deletion(), "Baú ocupado bloqueia desmontagem")
	var progress := WorldProgress.new()
	progress.world = world
	var state := progress.capture()
	check(state.structures[0].id == id and state.structures[0].chest_name == "Expedição", "Save identifica baú pelo ID e guarda nome")
	var second: Node2D = load("res://scenes/world.tscn").instantiate()
	root.add_child(second)
	await step()
	var restored := WorldProgress.new()
	restored.world = second
	restored.store.path = "res://.tools/base-practical-save.json"
	check(restored.store.write(state), "Gravação do estado real")
	restored.load_progress()
	var found: PlacedStructure
	for node in second.get_node("WorldObjects").get_children():
		if node is PlacedStructure: found = node
	check(found != null and found.structure_id == id and found.chest_name == "Expedição" and found.storage.wood == 8, "Reload conserva identidade nome e pilha restante")
	second.queue_free()
	await process_frame
	chest.storage.reset()
	check(chest.dismantle(inv).contains("metade") and chest.is_queued_for_deletion(), "Baú vazio desmonta mesmo com inventário cheio")
	var wood := 0
	var stone := 0
	for drop in get_nodes_in_group("resource_drops"):
		if drop.resource == "madeira": wood += drop.quantity
		if drop.resource == "pedra": stone += drop.quantity
	check(wood == 10 and stone == 4, "Excedente devolve metade exata no chão")
	inv.reset()
	var bed := place(world, "cama", Vector2(0, 65))
	world.get_node("Structures").respawn_bed = bed
	bed.dismantle(inv)
	check(world.get_node("Structures").respawn_bed == null and inv.wood == 4 and inv.count_item("fibra") == 3, "Cama desmontada limpa vínculo e devolve 4 madeiras 3 fibras")
	var fire := place(world, "fogueira", Vector2(-65, 0))
	fire.dismantle(inv)
	check(inv.stone == 2, "Pedra ímpar arredonda metade para baixo")
	var far := place(world, "parede_madeira", Vector2(300, 0))
	check(far.dismantle(inv).contains("Aproxime") and not far.is_queued_for_deletion(), "Distância bloqueia desmontagem")
	var hud: CanvasLayer = world.get_node("HUD")
	hud.open_base()
	check(hud.current_panel == "base" and hud.base_view.confirm.disabled, "Interface exige selecionar peça e confirmar")
	hud.set_panel("")
	world.queue_free()
	await process_frame
	print("BASE PRACTICAL: %d verificações, %d falhas" % [checks, failures])
	quit(1 if failures else 0)
