extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, caption: String) -> void:
	checks += 1
	if not value: failures += 1
	print("PASS: " if value else "FAIL: ", caption)
func run() -> void:
	var config = load("res://scripts/network/multiplayer_config.gd")
	check(config.endpoint_from_manifest({"schema":1,"protocol":3,"url":"wss://new-route.trycloudflare.com/room"}) == "wss://new-route.trycloudflare.com/room", "Current HTTPS manifest resolves the new WSS route")
	for value in [null, [], {}, {"schema":2,"protocol":3,"url":"wss://test.trycloudflare.com/room"}, {"schema":1,"protocol":2,"url":"wss://test.trycloudflare.com/room"}]:
		check(config.endpoint_from_manifest(value) == "", "Invalid manifest/protocol refused")
	for address in ["ws://test.trycloudflare.com/room", "wss://attacker.example/room", "wss://test.trycloudflare.com.attacker.example/room", "wss://user:pass@test.trycloudflare.com/room", "wss://test.trycloudflare.com/room?token=x", "wss://test.trycloudflare.com/room\n"]:
		check(config.endpoint_from_manifest({"schema":1,"protocol":3,"url":address}) == "", "Untrusted route refused: " + address.strip_edges())
	# A failed route lookup must retry even when no WebSocket was created.
	var scene = load("res://scenes/network/multiplayer_pilot.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.fatal = false
	scene.connection_phase = "discovery"
	scene.phase_started = Time.get_ticks_msec() - 10000
	scene._process(0.01)
	check(scene.failed_phase == "discovery" and scene.retry_in > 0, "Discovery deadline runs before null-socket return")
	check(scene.discovery_result.contains("9 s"), "Discovery watchdog exposes its bounded deadline")
	var previous_result: String = scene.discovery_result
	scene.retry_in = 0.001
	scene._process(0.01)
	check(scene.fatal and scene.status.text.contains("Entre novamente"), "Retry executes without a socket and still enforces account login")
	check(scene.discovery_result == previous_result, "Retry retains the last discovery failure for diagnosis")
	scene.queue_free()
	await process_frame
	print("MULTIPLAYER ENDPOINT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
