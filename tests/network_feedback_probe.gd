extends Node
var role := "guest"
var port := 17167
var main: Node
var arena: Node2D
var guest_id := 0
var seen := {}
var effects := {}
var response := {}
var failures := 0
var checks := 0
func _ready() -> void:
	FirebaseAuth.config.enabled = false # Offline network fixture, no mock login.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = arg.trim_prefix("--role=")
		if arg.begins_with("--port="): port = int(arg.trim_prefix("--port="))
	main = load("res://scenes/main.tscn").instantiate()
	main.set_script(load("res://tests/native_fixture_session.gd"))
	main.name = "Main"
	add_child(main)
	if role == "host":
		await main.host_game(port)
		arena = main.game
		run_host()
	else: main.join_game("127.0.0.1", port)
func _process(_delta: float) -> void:
	if role != "guest": return
	for effect in get_tree().get_nodes_in_group("combat_effects"):
		var id := effect.get_instance_id()
		if seen.has(id): continue
		seen[id] = true
		effects[effect.kind] = int(effects.get(effect.kind, 0)) + 1
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1
	print("PASS: " if value else "FAIL: ", label)
func shoot(direction: Vector2, range_value: float = 100) -> void:
	var arrow: Node2D = load("res://scenes/projectile.tscn").instantiate()
	arrow.position = Vector2(650, 600)
	arrow.direction = direction
	arrow.speed = GunRules.WEAPONS.arco.speed
	arrow.damage = GunRules.WEAPONS.arco.damage
	arrow.arrow = true
	arrow.remaining = range_value
	arrow.shooter = arena.actors[1].body.get_rid()
	arena.get_node("Objects").add_child(arrow)
func remote_effects() -> Dictionary:
	response = {}
	probe.rpc_id(guest_id)
	var end := Time.get_ticks_msec() + 3000
	while response.is_empty() and Time.get_ticks_msec() < end: await get_tree().create_timer(0.02).timeout
	return response
@rpc("authority", "call_remote", "reliable")
func probe() -> void: report.rpc_id(1, {"effects": effects})
@rpc("any_peer", "call_remote", "reliable")
func report(data: Dictionary) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == guest_id: response = data
@rpc("authority", "call_remote", "reliable")
func finish() -> void:
	main.reset_network()
	await main.clear_scene(false)
	get_tree().quit()
func run_host() -> void:
	var end := Time.get_ticks_msec() + 30000
	while arena.actors.size() < 2 and Time.get_ticks_msec() < end: await get_tree().create_timer(0.02).timeout
	check(arena.actors.size() == 2, "Dois processos conectados para feedback real")
	if arena.actors.size() != 2:
		get_tree().quit(1)
		return
	for id in arena.actors:
		if id != 1: guest_id = id
	arena.enemy.set_physics_process(false)
	arena.enemy.position = Vector2(700, 600)
	await get_tree().create_timer(0.3).timeout
	shoot(Vector2.RIGHT)
	await get_tree().create_timer(0.3).timeout
	check(arena.enemy.health == 18, "Acerto efetivo mantém doze danos do arco")
	var remote := await remote_effects()
	check(remote.get("effects", {}).get("arrow_hit", 0) == 1 and remote.get("effects", {}).get("blocked", 0) == 0, "Cliente mostra acerto somente após confirmação do servidor")
	var wall := StaticBody2D.new()
	wall.position = Vector2(675, 600)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(6, 100)
	collision.shape = shape
	wall.add_child(collision)
	arena.get_node("Objects").add_child(wall)
	await get_tree().create_timer(0.1).timeout
	shoot(Vector2.RIGHT)
	await get_tree().create_timer(0.3).timeout
	check(arena.enemy.health == 18, "Parede não altera vida nem confirma dano")
	remote = await remote_effects()
	check(remote.get("effects", {}).get("blocked", 0) == 1 and remote.get("effects", {}).get("arrow_hit", 0) == 1, "Cliente distingue bloqueio sem impacto de alvo fictício")
	shoot(Vector2.LEFT, 15)
	await get_tree().create_timer(0.3).timeout
	remote = await remote_effects()
	check(arena.enemy.health == 18 and remote.get("effects", {}).get("arrow_hit", 0) == 1, "Erro de projétil não inventa acerto na rede")
	finish.rpc_id(guest_id)
	await get_tree().create_timer(0.2).timeout
	main.reset_network()
	await main.clear_scene(false)
	print("NETWORK FEEDBACK: %d verificações, %d falhas" % [checks, failures])
	get_tree().quit(1 if failures else 0)
