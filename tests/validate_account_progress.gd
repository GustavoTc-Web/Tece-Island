extends SceneTree
var checks := 0
var failures := 0
class FailingStore extends SaveStore:
	var fail := false
	var writes := 0
	func write(data: Dictionary) -> bool:
		writes += 1
		if fail:
			error = "Falha de gravação injetada no teste."
			return false
		return super.write(data)
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1
	print("PASS: " if value else "FAIL: ", label)
func run() -> void:
	print("TEST: UIDs e falha de I/O de fixture; nenhuma autenticação positiva simulada")
	var folder := "res://.tools/account-test-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(folder)
	var world: Node2D = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.owner_uid = "fixture-A"
	var progress := WorldProgress.new()
	progress.world = world
	var data := progress.capture()
	var a := AccountProgress.new()
	a.configure("fixture-A", folder)
	var b := AccountProgress.new()
	b.configure("fixture-B", folder)
	check(a.store.path != b.store.path and not a.store.path.contains("@"), "Caminhos diferentes pelo UID, sem e-mail")
	check(await a.write(data, self), "Conta A grava estado real")
	check((await b.read(self)).is_empty(), "Conta B não carrega conta A")
	var different := data.duplicate(true)
	different.owner_uid = "fixture-B"
	different.player.health = 62
	different.journal = {"discovered": ["trail"], "unread": {"trail": true}}
	check(await b.write(different, self), "Conta B grava progresso próprio")
	check((await a.read(self)).player.health == 100 and (await b.read(self)).player.health == 62, "Troca preserva mundos e valores separados")
	var account_world: Node2D = load("res://scenes/world.tscn").instantiate()
	account_world.owner_uid = b.uid
	account_world.account_store = b
	account_world.initial_progress = await b.read(self)
	account_world.persistence_enabled = true
	root.add_child(account_world)
	await physics_frame
	check(account_world.get_node("WorldObjects/Player").health == 62 and account_world.journal.discovered == ["trail"], "Mundo e interface carregam apenas conta B")
	account_world.queue_free()
	await process_frame
	check(not await a.write(different, self), "Dono diferente bloqueia escrita")
	var foreign := SaveStore.new()
	foreign.path = a.store.path
	foreign.write(different)
	check((await a.read(self)).is_empty() and a.error.contains("outra conta"), "Arquivo com dono divergente bloqueia leitura")
	foreign.write(data)
	var legacy := SaveStore.new()
	legacy.path = folder.path_join("solo-progress.json")
	var old := data.duplicate(true)
	old.erase("owner_uid")
	old.version = 3
	legacy.write(old)
	var bytes := FileAccess.get_file_as_string(legacy.path)
	var c := AccountProgress.new()
	c.configure("fixture-C", folder)
	check(await c.legacy_available(self), "Legado sem dono fica disponível para importação explícita")
	check(not await a.import_legacy(self), "Importação nunca substitui conta com progresso")
	check(await c.import_legacy(self), "Importação explícita atribui progresso a C")
	check((await c.read(self)).owner_uid == "fixture-C" and FileAccess.get_file_as_string(legacy.path) == bytes, "Importação preserva original e marca dono")
	check(FileAccess.get_file_as_string(legacy.path + ".before-v%d.json" % SaveStore.VERSION) == bytes, "Backup versionado exato antes da migração")
	var d := AccountProgress.new()
	d.configure("fixture-D", folder)
	check(not await d.legacy_available(self) and not await d.import_legacy(self), "Importação única impede outra conta apropriar-se do legado")
	var saved_world: Node2D = load("res://scenes/world.tscn").instantiate()
	saved_world.persistence_enabled = true
	saved_world.progress_path = folder.path_join("controller.json")
	root.add_child(saved_world)
	await physics_frame
	var failing := FailingStore.new()
	failing.path = saved_world.progress_path
	saved_world.progress_store.store = failing
	var controller: ProgressController = saved_world.save_controller
	controller.flush()
	controller.flush()
	check(controller.saving and saved_world.get_node("HUD").save_button.text == "Salvando…", "Salvando antecede conclusão real")
	for i in range(4): await process_frame
	check(failing.writes == 1 and saved_world.get_node("HUD").save_button.text == "Salvo", "Pedidos simultâneos coalescem e sucesso vem após gravação")
	var valid_bytes := FileAccess.get_file_as_string(failing.path)
	failing.fail = true
	saved_world.get_node("Inventory").add_resource("madeira", 5)
	check(not await saved_world.save_progress(true), "Falha real do backend chega ao estado de salvamento")
	check(FileAccess.get_file_as_string(failing.path) == valid_bytes and not saved_world.get_node("HUD").save_button.disabled, "Falha preserva último save e oferece nova tentativa")
	failing.fail = false
	check(await saved_world.save_progress(true) and failing.read().inventory.slots[0].quantity == 5, "Nova tentativa grava alterações pendentes")
	var auth := root.get_node("FirebaseAuth")
	var callback_before: Callable = auth.before_logout
	auth._user_id = "fixture-only-UID"
	auth.before_logout = func(): return false
	check(not await auth.logout() and auth._user_id == "fixture-only-UID", "Falha de gravação impede logout voluntário e permite tentar novamente")
	var trace := {"called": false}
	auth.before_logout = func(): trace.called = auth._user_id == "fixture-only-UID"; return true
	await auth.logout()
	check(trace.called and auth._user_id.is_empty() and auth._id_token.is_empty(), "Logout termina gravação antes de limpar UID/tokens")
	auth.before_logout = callback_before
	world.queue_free()
	saved_world.queue_free()
	await process_frame
	print("ACCOUNT PROGRESS: %d verificações, %d falhas" % [checks, failures])
	quit(1 if failures else 0)
