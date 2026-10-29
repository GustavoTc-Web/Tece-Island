extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, caption: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS: " if ok else "FAIL: ", caption)
func run() -> void:
	var auth := root.get_node("FirebaseAuth")
	var sync := root.get_node("WorldSync")
	var chat := root.get_node("GlobalChat")
	auth.config.enabled = true
	auth._user_id = "beta-new-player-fixture"
	auth._id_token = "local-fixture-never-sent"
	auth._verified = true
	auth._expires_at = Time.get_unix_time_from_system() + 3600
	sync.config = {"enabled":true,"allowed_uids":["closed-a","closed-b"],"interval_seconds":120}
	chat.config = {"enabled":true,"allowed_uids":["closed-a","closed-b"]}
	chat.uid = auth.account_uid()
	check(auth.can_play(), "New verified identity can access solo without the closed-test allowlist")
	check(not sync.enabled(auth.account_uid()) and not chat.available(), "New identity cannot access closed chat or cloud saves")
	var menu: Control = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	var diagnostic: String = menu.overlay.menu_view.diagnostic()
	check(diagnostic.contains("Plataforma:") and diagnostic.contains("Abra um mundo solo"), "Lobby help diagnostic works without a loaded world")
	check(not diagnostic.contains(auth.account_uid()) and not diagnostic.contains(auth._id_token), "Support copy excludes identity and session credential")
	menu.open_page("servers")
	check(menu.servers_list.get_child_count() > 0, "Unavailable multiplayer page remains informative")
	menu.queue_free()
	await process_frame
	var library := WorldLibrary.new()
	var folder := "user://beta-access-%d" % Time.get_ticks_usec()
	library.configure(auth.account_uid(), folder)
	check(await library.load_index(self), "New account opens a separate empty catalog")
	var id: String = await library.create_world("Beta fixture", self)
	var account := AccountProgress.new()
	account.configure(library.uid, folder, id)
	var prepared: Dictionary = await sync.prepare(account, library)
	check(prepared.get("ok", false), "Local-only new world prepares without requesting Firestore permission")
	var world: Node2D = load("res://scenes/world.tscn").instantiate()
	world.persistence_enabled = true
	world.account_store = account
	world.owner_uid = library.uid
	world.world_id = id
	world.world_name = "Beta fixture"
	world.initial_progress = prepared.get("data", {})
	root.add_child(world)
	await physics_frame
	world.get_node("DayNight").set_physics_process(false)
	var help: Control = world.get_node("HUD").menu_view
	help.open("data")
	check(help.text.text.contains("não há cópia automática") and not help.text.text.contains("Aguarde Sincronizado"), "Local-only account receives accurate save instructions")
	check(help.retry_button.text == "Salvar neste aparelho", "Local save action does not promise unavailable synchronization")
	check(await world.save_progress(true), "New account acquires a durable local save")
	var saved: Dictionary = await account.read(self)
	check(saved.get("version") == 8 and saved.get("owner_uid") == library.uid and saved.get("world_id") == id, "Save v8 is correctly owned and isolated")
	world.queue_free()
	await process_frame
	check((await account.read(self)).get("world_id") == id, "Closing the world preserves its local bytes")
	print("BETA ACCESS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
