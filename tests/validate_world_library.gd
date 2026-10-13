extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS: " if ok else "FAIL: ", label)
func run() -> void:
	var folder := "res://.tools/world-library-%d" % Time.get_ticks_usec()
	var a := WorldLibrary.new()
	a.configure("fixture-A", folder)
	a.native_only = true
	var b := WorldLibrary.new()
	b.configure("fixture-B", folder)
	b.native_only = true
	check(await a.load_index(self) and await b.load_index(self), "Duas contas inicializam catálogos separados")
	var one := await a.create_world("Praia", self)
	var two := await a.create_world("Floresta", self)
	check(one != two and WorldLibrary.safe_id(one), "Mundos têm IDs únicos e seguros")
	check(not WorldLibrary.safe_id("../outro"), "IDs rejeitam saída da pasta da conta")
	var world: Node2D = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.owner_uid = a.uid
	world.world_id = one
	var inv: ResourceInventory = world.get_node("Inventory")
	inv.add_resource("madeira", 10)
	world.objectives.collected("madeira", 10)
	world.journal.collect("arrival")
	var progress := WorldProgress.new()
	progress.world = world
	var state := progress.capture()
	var first := a.account(one)
	var second := a.account(two)
	check(await first.write(state, self), "Primeiro mundo salva estado real com dono e ID")
	check((await second.read(self)).is_empty() and (await b.account(one).read(self)).is_empty(), "Segundo mundo e outra conta não herdam inventário ou progresso")
	check(not await second.write(state, self), "Escrita com ID de outro mundo é bloqueada")
	world.world_id = two
	inv.reset()
	inv.add_resource("pedra", 7)
	world.objectives.restore({})
	world.journal.restore({})
	check(await second.write(progress.capture(), self), "Segundo mundo grava inventário independente")
	var saved_one := await first.read(self)
	var saved_two := await second.read(self)
	check(saved_one.inventory.slots[0].item == "madeira" and saved_two.inventory.slots[0].item == "pedra" and saved_one.journal.discovered == ["arrival"] and saved_two.journal.discovered.is_empty(), "Recarga conserva itens e diário de cada mundo")
	check(saved_one.objectives.values.wood == 10 and saved_two.objectives.values.wood == 0, "Objetivos separados por mundo")
	check(await a.rename_world(one, "Meu refúgio", self) and await a.touch_world(one, self), "Renomear e último acesso persistem")
	var reloaded := WorldLibrary.new()
	reloaded.configure(a.uid, folder)
	reloaded.native_only = true
	check(await reloaded.load_index(self) and reloaded.data.worlds[0].name == "Meu refúgio" and reloaded.data.worlds[0].last_access > 0, "Catálogo recarrega nome e acesso")
	check(b.data.worlds.is_empty() and a.data.servers.is_empty(), "Conta B e histórico de servidores começam vazios")
	check(await a.record_server("127.0.0.1", 7000, self) and await a.record_server("127.0.0.1", 7000, self) and a.data.servers.size() == 1, "Reconexões bem-sucedidas atualizam uma única entrada")
	var c := WorldLibrary.new()
	c.configure("fixture-C", folder)
	c.native_only = true
	var original := state.duplicate(true)
	original.owner_uid = c.uid
	original.erase("world_id")
	original.version = 4
	check(await c.account().write(original, self), "Save anterior preparado no caminho por conta")
	var old_path := c.account().store.path
	var bytes := FileAccess.get_file_as_string(old_path)
	var migrated_ok := await c.load_index(self)
	if not migrated_ok: print("MIGRATION ERROR: ", c.error)
	check(migrated_ok and c.data.worlds.size() == 1 and c.data.worlds[0].name == "Meu primeiro mundo", "Migração cria primeiro mundo uma vez")
	check(FileAccess.get_file_as_string(old_path) == bytes and FileAccess.get_file_as_string(old_path + ".before-worlds.json") == bytes, "Migração mantém bytes originais e backup")
	var migrated := await c.account("first-world").read(self)
	check(migrated.inventory == JSON.parse_string(JSON.stringify(original.inventory)) and migrated.world_id == "first-world" and migrated.owner_uid == c.uid, "Migração confirma inventário, dono e ID")
	check(await c.load_index(self) and c.data.worlds.size() == 1, "Reabrir catálogo não duplica mundo migrado")
	var invalid := original.duplicate(true)
	invalid.owner_uid = "fixture-D"
	var d := WorldLibrary.new()
	d.configure("fixture-D", folder)
	d.native_only = true
	await d.account().write(invalid, self)
	var corrupt := FileAccess.open(d.account().store.path, FileAccess.WRITE)
	corrupt.store_string("arquivo corrompido")
	corrupt.close()
	check(not await d.load_index(self) and not d.error.is_empty(), "Legado inválido bloqueia migração sem criar mundo vazio")
	world.queue_free()
	await process_frame
	print("WORLD LIBRARY: %d verificações, %d falhas" % [checks, failures])
	quit(1 if failures else 0)
