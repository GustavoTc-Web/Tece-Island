extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, caption: String) -> void:
	checks += 1
	if not value: failures += 1; print("FAIL: ", caption)
func run() -> void:
	var model = load("res://scripts/network/multiplayer_prediction.gd").new()
	model.configure(JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/multiplayer-world.json")))
	for trajectory in JSON.parse_string(FileAccess.get_file_as_string("res://.tools/prediction-cases.json")):
		var point := Vector2(trajectory.start[0], trajectory.start[1])
		for step in trajectory.steps:
			point = model.move_at(point, Vector2(step.direction[0], step.direction[1]), float(step.dt))
			check(point.distance_to(Vector2(step.position[0], step.position[1])) < 0.01, "Matches authoritative geometry/speed in " + str(trajectory.name))
	model.reset(Vector2(1152, 576))
	model.advance(Vector2.RIGHT, 0.05, 1)
	model.advance(Vector2.RIGHT, 0.05, 2)
	model.reconcile(Vector2(1152 + model.data.speed * 0.05, 576), 1)
	check(model.pending.size() == 1 and model.pending[0].seq == 2, "Reconciliation discards acknowledged input and replays only newer input")
	check(absf(model.position.x - (1152 + model.data.speed * 0.1)) < 0.01, "Replay retains immediate visual movement")
	for i in 90: model.advance(Vector2.RIGHT, 0.05, i + 3)
	check(model.limited and model.pending.size() < 30, "Missing acknowledgement bounds prediction/history")
	model.reconcile(Vector2(1152, 576), 200)
	check(model.position == Vector2(1152, 576) and model.pending.is_empty(), "Server correction always restores authority")
	var inventory := ResourceInventory.new()
	root.add_child(inventory)
	var notifications := [0]
	inventory.changed.connect(func(_a, _b): notifications[0] += 1)
	var raw: Dictionary = JSON.parse_string('{"slots":[{"item":"machado_madeira","quantity":1},{},{},{},{},{},{}],"selected":0,"category":"machado","weapon_uid":0,"backpack":{},"armor":{}}')
	for i in 10: inventory.apply_network_state(raw)
	check(notifications[0] == 1, "Identical JSON snapshots notify HUD only once despite numeric JSON types")
	raw.slots[1] = {"item":"madeira","quantity":5}
	inventory.apply_network_state(raw)
	check(notifications[0] == 2 and inventory.count_item("madeira") == 5, "Real inventory changes still update once with exact reward")
	var pilot = load("res://scenes/network/multiplayer_pilot.tscn").instantiate()
	root.add_child(pilot)
	await process_frame
	pilot.online = true
	pilot.last_input_ack = 1
	pilot.receive({"type":"state","resources":[],"drops":[{"id":"drop-test","quantity":5}],"revision":1})
	pilot.receive({"type":"ack","action":"input","seq":2,"ok":true})
	pilot.receive({"type":"state","revision":2})
	check(pilot.pending_state.revision == 2 and pilot.pending_state._input_ack == 2, "Coalesced state keeps its own ordered input acknowledgement")
	check(pilot.pending_state.drops[0].quantity == 5 and pilot.pending_state.has("resources"), "Coalescing carries changed world arrays across compact states")
	pilot.receive({"type":"state","revision":3,"drops":[]})
	check(pilot.pending_state.drops.is_empty(), "Explicit empty drop array overrides carried world state")
	pilot.online = false
	pilot.queue_free(); inventory.queue_free()
	await process_frame
	print("MULTIPLAYER PREDICTION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
