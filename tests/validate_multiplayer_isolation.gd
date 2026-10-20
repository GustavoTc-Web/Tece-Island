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
	check(not config.enabled(), "Multiplayer defaults off in official/source config")
	var before := {}
	for path in ["user://world.json", "user://world.json.bak", "user://worlds.json", "user://accounts"]:
		before[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
	var scene = load("res://scenes/network/multiplayer_pilot.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	check(not scene.has_method("save_progress"), "Multiplayer has no solo save or cloud upload entry point")
	check(scene.fatal and not scene.online, "Signed-out account receives explicit connection guidance")
	check(scene.get_node_or_null("WorldClock") == null, "Multiplayer does not advance solo clock/campaign")
	check(scene.get_node_or_null("Inventory") == null, "No local inventory can award multiplayer resources")
	for path in before:
		var after := FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
		check(before[path] == after, "Solo storage untouched: " + path)
	for pair in [["madeira",5,3], ["pedra",4,6]]:
		check(ResourceRules.EXTRACTION[pair[0]].reward == pair[1], "Pilot reward matches solo: " + pair[0])
		var tool := "machado_madeira" if pair[0] == "madeira" else "picareta_madeira"
		check(ResourceRules.EXTRACTION[pair[0]].hits[tool] == pair[2], "Pilot hit count matches solo: " + pair[0])
	check(is_equal_approx(ResourceRules.hit_interval("machado_madeira"), 0.54), "Pilot tool interval matches solo")
	scene.queue_free()
	await process_frame
	print("MULTIPLAYER ISOLATION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
