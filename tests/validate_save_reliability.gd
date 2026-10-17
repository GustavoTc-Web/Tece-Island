extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS: " if ok else "FAIL: ", label)
func run() -> void:
	var folder := "res://.tools/reliability-%d" % Time.get_ticks_usec()
	var library := WorldLibrary.new()
	library.configure("reliability-fixture", folder)
	library.native_only = true
	await library.load_index(self)
	var id := await library.create_world("Mundo que sumiu", self)
	var account := library.account(id)
	var inv := ResourceInventory.new()
	inv.reset()
	inv.add_resource("madeira", 37)
	var state := {"version": 5, "owner_uid": library.uid, "world_id": id, "world_name": "Mundo que sumiu", "inventory": inv.network_state(), "world_seed": 4321}
	inv.free()
	check(await account.write(state, self), "Fixture própria grava progresso real")
	var original := FileAccess.get_file_as_string(account.store.path)
	DirAccess.remove_absolute(library.index_path())
	var fresh := WorldLibrary.new()
	fresh.configure(library.uid, folder)
	fresh.native_only = true
	check(await fresh.load_index(self) and fresh.entry(id).name == "Mundo que sumiu", "Catálogo ausente encontra save órfão e conserva ID/nome")
	check(FileAccess.get_file_as_string(account.store.path) == original, "Reconstrução da lista não modifica o save")
	var broken_index := FileAccess.open(fresh.index_path(), FileAccess.WRITE)
	broken_index.store_string("catálogo quebrado")
	broken_index.close()
	check(await fresh.load_index(self) and not fresh.entry(id).is_empty(), "Catálogo corrompido recupera backup/lista sem esconder mundo")
	var another := library.account(id)
	await account.read(self)
	await another.read(self)
	var next := state.duplicate(true)
	next.world_seed = 99
	check(await account.write(next, self) and not await another.write(state, self), "Sessão antiga não sobrescreve save de outra sessão")
	check((await library.account(id).read(self)).world_seed == 99, "Progressão mais recente permanece no arquivo principal")
	check(another.local_conflict, "Conflito local bloqueia retries que poderiam sobrescrever outra sessão")
	var fork := await fresh.fork_local(state, "Minha cópia", self)
	check(fork.ok and (await fresh.account(fork.id).read(self)).world_seed == 4321 and (await fresh.account(id).read(self)).world_seed == 99, "Partida concorrente pode continuar como outro mundo com as duas versões preservadas")
	var candidates := await another.recovery_candidates(self)
	check(candidates.size() >= 2, "Versão concorrente e backup anterior permanecem recuperáveis")
	var corrupt := FileAccess.open(account.store.path, FileAccess.WRITE)
	corrupt.store_string("save incompleto")
	corrupt.close()
	check((await account.read(self)).is_empty() and account.blocked, "Save inválido é falha de leitura, nunca mundo novo")
	check(not await account.write(state, self) and FileAccess.get_file_as_string(account.store.path) == "save incompleto", "Falha de leitura bloqueia substituição automática")
	candidates = await account.recovery_candidates(self)
	check(not candidates.is_empty() and await account.recover(candidates[0].source, self), "Recuperação explícita usa backup validado e preserva original corrompido")
	check(not (await account.read(self)).is_empty(), "Save recuperado pode ser carregado")
	var broken_again := FileAccess.open(account.store.path, FileAccess.WRITE)
	broken_again.store_string("original quebrado para recuperação remota")
	broken_again.close()
	var foreign_candidate := state.duplicate(true)
	foreign_candidate.owner_uid = "wrong-account"
	check(not await account.recover_data(foreign_candidate, self), "Recuperação remota também recusa dados de outra conta")
	check(await account.recover_data(state, self) and (await account.read(self)).world_seed == 4321, "Escolha explícita de cópia remota validada restaura save local com original preservado")
	DirAccess.remove_absolute(account.store.path)
	var sync := root.get_node("WorldSync")
	check(not (await sync.prepare(library.account(id), fresh)).get("ok", false), "Arquivo principal ausente com backup não cria mundo vazio")
	var foreign := WorldLibrary.new()
	foreign.configure("other-account", folder)
	foreign.native_only = true
	check(await foreign.load_index(self) and foreign.data.worlds.is_empty(), "Varredura de recuperação não transfere mundos entre contas")
	# Interrupted migration with an already divergent first-world.
	var legacy := WorldLibrary.new()
	legacy.configure("legacy-fixture", folder)
	legacy.native_only = true
	var old := state.duplicate(true)
	old.owner_uid = legacy.uid
	old.erase("world_id")
	old.version = 4
	await legacy.account().write(old, self)
	var different := old.duplicate(true)
	different.world_id = "first-world"
	different.world_seed = 666
	await legacy.account("first-world").write(different, self)
	check(await legacy.load_index(self) and legacy.data.worlds.size() == 2, "Migração interrompida com versões diferentes preserva dois mundos")
	check(await legacy.load_index(self) and legacy.data.worlds.size() == 2, "Repetir a migração não duplica versões")
	check((await legacy.account("first-world").read(self)).world_seed == 666, "Migração não substitui destino diferente")
	print("SAVE RELIABILITY: %d verificações, %d falhas" % [checks, failures])
	quit(1 if failures else 0)
