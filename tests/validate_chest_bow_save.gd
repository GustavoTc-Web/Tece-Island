extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1
	print("PASS: " if value else "FAIL: ", label)
func step(frames: int = 3) -> void:
	for i in range(frames): await physics_frame
func run() -> void:
	var world: Node2D = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await step()
	var inv: ResourceInventory = world.get_node("Inventory")
	var player: CharacterBody2D = world.get_node("WorldObjects/Player")
	var weapons: Node = world.get_node("Weapons")
	inv.add_resource("madeira", 20)
	inv.add_resource("pedra", 8)
	check(inv.craft("bau") and inv.wood == 0 and inv.stone == 0 and inv.count_item("bau") == 1, "Baú custa 20 madeiras e 8 pedras")
	var structure: PlacedStructure = load("res://scenes/placed_structure.tscn").instantiate()
	structure.kind = "bau"
	structure.system = world.get_node("Structures")
	structure.position = player.position + Vector2(65, 0)
	world.get_node("WorldObjects").add_child(structure)
	await step()
	check(structure.storage.capacity == 12, "Baú tem doze slots")
	inv.reset()
	inv.add_item({"item": "pistola", "quantity": 1, "loaded": 6})
	inv.add_item({"item": "cantil", "quantity": 1, "water": 2})
	check(inv.transfer_to(structure.storage, 0) == 1 and inv.slot_data(0).is_empty() and structure.storage.slot_data(0).loaded == 6, "Guardar arma conserva munição sem duplicar")
	check(inv.transfer_to(structure.storage, 1) == 1 and structure.storage.slot_data(1).water == 2, "Guardar cantil conserva doses")
	check(structure.dismantle(inv).contains("Baú cheio") and not structure.is_queued_for_deletion(), "Baú cheio não pode ser desmontado")
	inv.add_resource("madeira", 15)
	for i in range(10): structure.storage.add_item({"item": "cama", "quantity": 1})
	var before := inv.network_state()
	check(inv.transfer_to(structure.storage, 0) == 0 and before == inv.network_state(), "Transferir para baú cheio conserva origem")
	structure.storage.take_slot(2, 1)
	check(inv.transfer_to(structure.storage, 0, false) == 1 and inv.wood == 14 and structure.storage.count_item("madeira") == 1, "Transferir uma unidade respeita capacidade")
	check(structure.storage.transfer_to(inv, 1) == 1 and inv.slot_data(1).water == 2, "Retirar conserva doses")
	inv.reset()
	inv.add_resource("madeira", 2)
	inv.add_resource("pedra", 1)
	check(inv.craft("flecha") and inv.count_item("flecha") == 4 and inv.wood == 0 and inv.stone == 0, "Receita produz quatro flechas")
	inv.reset()
	inv.add_item({"item": "flecha", "quantity": 14})
	inv.add_resource("madeira", 2)
	inv.add_resource("pedra", 1)
	check(inv.craft("flecha") and inv.count_item("flecha") == 18 and inv.slot_data(0).quantity == 15, "Resultado distribui quatro flechas respeitando pilhas")
	inv.reset()
	inv.add_resource("arco", 1)
	inv.select_quick(0)
	check(not weapons.fire(Vector2.RIGHT), "Sem flechas não dispara")
	inv.add_resource("flecha", 3)
	player.controls_blocked = true
	check(not weapons.fire(Vector2.RIGHT) and inv.count_item("flecha") == 3, "Interface bloqueia tiro e consumo")
	player.controls_blocked = false
	check(not weapons.fire(Vector2.ZERO) and inv.count_item("flecha") == 3, "Mira cancelada não consome")
	check(weapons.fire(Vector2.LEFT) and inv.count_item("flecha") == 2, "Disparo efetivo consome uma")
	check(not weapons.fire(Vector2.LEFT) and inv.count_item("flecha") == 2, "Cadência impede segundo tiro imediato")
	check(GunRules.WEAPONS.arco.damage == 12 and GunRules.WEAPONS.arco.interval == 1.0, "Dano 12 e intervalo de um segundo")
	await step(65)
	var enemy: ForestCreature = load("res://scenes/forest_creature.tscn").instantiate()
	enemy.position = player.position + Vector2(180, 0)
	enemy.player = player
	enemy.origin = "guardiao"
	enemy.simulation_authority = false
	world.get_node("WorldObjects").add_child(enemy)
	await step()
	check(weapons.fire(Vector2.RIGHT), "Arco dispara novamente depois do intervalo")
	await step(35)
	check(enemy.health == 30, "Baú sólido bloqueia flecha antes do inimigo")
	var progress := WorldProgress.new()
	progress.world = world
	DirAccess.make_dir_recursive_absolute("res://.tools/save-tests")
	progress.store.path = "res://.tools/save-tests/progress.json"
	check(progress.save(), "Save gravado em arquivo de teste")
	var saved := progress.store.read()
	check(saved.structures[0].storage.slots[0].loaded == 6, "Save inclui propriedades da arma no baú")
	var old := FileAccess.get_file_as_string(progress.store.path)
	inv.add_resource("linha", 2)
	check(progress.save() and FileAccess.get_file_as_string(progress.store.path + ".backup.json") == old, "Substituição preserva backup exato do save anterior")
	var restored: Node2D = load("res://scenes/world.tscn").instantiate()
	restored.persistence_enabled = true
	restored.progress_path = progress.store.path
	root.add_child(restored)
	await step()
	var reader: WorldProgress = restored.progress_store
	check(reader.capture().loot == saved.loot, "Semente do save conserva todos os recipientes e seu saque")
	check(reader.writable and restored.get_node("Inventory").count_item("linha") == 2, "Carregar restaura inventário")
	var loaded_chest: PlacedStructure
	for node in restored.get_node("WorldObjects").get_children():
		if node is PlacedStructure and node.kind == "bau": loaded_chest = node
	check(is_instance_valid(loaded_chest) and loaded_chest.position == structure.position and loaded_chest.storage.slots == structure.storage.slots, "Carregar restaura posição e conteúdo do baú")
	var bad_path := "res://.tools/save-tests/bad.json"
	var file := FileAccess.open(bad_path, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	reader.store.path = bad_path
	reader.load_progress()
	check(not reader.writable and not reader.save() and FileAccess.get_file_as_string(bad_path) == "{broken", "Save inválido nunca sobrescrito")
	var migration := saved.duplicate(true)
	migration.version = 0
	var migration_path := "res://.tools/save-tests/migrate-%d.json" % Time.get_ticks_usec()
	file = FileAccess.open(migration_path, FileAccess.WRITE)
	var original := JSON.stringify(migration)
	file.store_string(original)
	file.close()
	var migrator := SaveStore.new()
	migrator.path = migration_path
	var converted := migrator.read()
	check(converted.version == SaveStore.VERSION and FileAccess.get_file_as_string(migration_path + ".before-v%d.json" % SaveStore.VERSION) == original and FileAccess.get_file_as_string(migration_path) == original, "Conversão de fixture antiga cria backup antes de alterar estado")
	world.queue_free()
	restored.queue_free()
	await process_frame
	print("%d verificações, %d falhas" % [checks, failures])
	quit(1 if failures else 0)
