extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var auth := root.get_node("FirebaseAuth")
	var original: Dictionary = auth.config.duplicate(true)
	auth.config.enabled = false
	var session: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(session)
	session.library = WorldLibrary.new()
	session.library.configure("fixture-failed-connection", "res://.tools/failed-server-%d" % Time.get_ticks_usec())
	await session.library.load_index(self)
	session.connection_timeout = 0.2
	session.join_game("127.0.0.1", 18529)
	await create_timer(0.8).timeout
	var failed: bool = session.game == null and session.menu != null and not session.connecting
	var empty: bool = session.library.data.servers.is_empty()
	print("PASS: " if failed else "FAIL: ", "Conexão indisponível retorna ao lobby")
	print("PASS: " if empty else "FAIL: ", "Conexão malsucedida não entra no histórico")
	session.queue_free()
	await process_frame
	auth.config = original
	print("NETWORK HISTORY: 2 verificações, %d falhas" % (int(not failed) + int(not empty)))
	quit(0 if failed and empty else 1)
