extends Node

# Este nó existe só nesta cena de testes, nunca na cena principal do jogo.
var role := "guest"
var port := 7150
var main: Node
var arena: Node2D
var reports: Dictionary = {}
var checks := 0
var failures := 0
var guest_id := 0

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = arg.trim_prefix("--role=")
		if arg.begins_with("--port="): port = int(arg.trim_prefix("--port="))
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	if role == "host":
		main.host_game(port, true)
		arena = main.game
		run_host()
	elif role == "extra":
		main.connection_timeout = 3
		main.join_game("127.0.0.1", port)
		await get_tree().create_timer(3.8).timeout
		check(main.game == null and main.menu != null, "Terceiro participante recusado")
		finish()
	else:
		main.join_game("127.0.0.1", port)

func check(value: bool, label: String) -> void:
	checks += 1
	if value: print("PASS [", role, "]: ", label)
	else:
		failures += 1
		push_error(label)

func wait_condition(condition: Callable, seconds: float = 6) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < end:
		if condition.call(): return true
		await get_tree().create_timer(0.02).timeout
	return false

func guest() -> Dictionary:
	return arena.actors[guest_id]

func host() -> Dictionary:
	return arena.actors[1]

func command(tag: String, action: String, argument: Variant = null) -> Dictionary:
	reports.erase(tag)
	probe_command.rpc_id(guest_id, tag, action, argument)
	var received := await wait_condition(func(): return reports.has(tag))
	check(received, "Resposta do cliente: " + tag)
	return reports.get(tag, {})

@rpc("authority", "call_remote", "reliable")
func probe_command(tag: String, action: String, argument: Variant = null) -> void:
	arena = main.game
	match action:
		"move":
			Input.action_press("move_right")
			await get_tree().create_timer(0.25).timeout
			Input.action_release("move_right")
		"inventory": arena.get_node("HUD").set_panel("inventory")
		"close": arena.get_node("HUD").set_panel("")
		"burst":
			for i in range(20): arena.request_action("fire_mouse", argument)
		"fire": arena.request_action("fire_mouse", argument)
		"reload":
			for i in range(5): arena.request_action("reload")
			await get_tree().create_timer(1.4).timeout
		"collect": arena.request_action("collect")
		"respawn": arena.get_node("HUD/Death/Panel/Rows/Respawn").pressed.emit()
		"invalid":
			arena.request_action("give_item", {"item": "pedra", "quantity": 999})
			arena.request_action("damage", {"id": 1, "damage": 999})
			arena.request_action("teleport", Vector2(9999, 9999))
		"replay":
			arena.action_sequence += 1
			var sequence: int = arena.action_sequence
			arena.action_requested.rpc_id(1, sequence, "fire_mouse", argument)
			await get_tree().create_timer(0.65).timeout
			arena.action_requested.rpc_id(1, sequence, "fire_mouse", argument)
		"rejoin":
			await main.leave_game()
			await get_tree().create_timer(0.3).timeout
			main.join_game("127.0.0.1", port)
			await wait_condition(func(): return main.game != null and main.game.actors.size() == 2)
			arena = main.game
		"wait_shutdown":
			await wait_condition(func(): return main.game == null and main.menu != null)
			check(main.game == null and main.menu.status.text.contains("anfitrião"), "Encerramento do anfitrião retorna convidado ao menu com mensagem")
			check(multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "Cliente limpa a rede ao voltar ao menu")
			main.start_solo()
			check(main.game.get_node("Inventory").wood == 0, "Cliente consegue iniciar solo limpo após multiplayer")
			main.game.get_node("HUD").set_panel("inventory")
			check(get_tree().paused, "Pausa solo preservada após conexão")
			get_tree().paused = false
			finish()
			return
	await get_tree().create_timer(0.25).timeout
	var state: Dictionary = arena.make_snapshot()
	state.local_id = arena.local_id()
	state.camera = get_viewport().get_camera_2d().get_parent().name
	state.paused = get_tree().paused
	state.death_hud = arena.get_node("HUD").showing_death
	state.mob_client_authority = is_instance_valid(arena.enemy) and arena.enemy.simulation_authority
	state.mob_client_physics = is_instance_valid(arena.enemy) and arena.enemy.is_physics_processing()
	probe_report.rpc_id(1, tag, state)

@rpc("any_peer", "call_remote", "reliable")
func probe_report(tag: String, state: Dictionary) -> void:
	if not multiplayer.is_server(): return
	guest_id = multiplayer.get_remote_sender_id()
	reports[tag] = state

func fixture(first: Vector2, second: Vector2) -> void:
	host().body.position = first
	guest().body.position = second
	host().body.invulnerability = 0
	guest().body.invulnerability = 0
	host().cooldown = 0
	guest().cooldown = 0

func run_host() -> void:
	check(await wait_condition(func(): return arena.actors.size() == 2, 30), "Duas instâncias ENet conectadas")
	if arena.actors.size() != 2:
		finish()
		return
	for id in arena.actors:
		if id != 1: guest_id = id
	arena.enemy.set_physics_process(false)
	fixture(Vector2(1000, 620), Vector2(1100, 620))
	arena.choose_enemy_target()
	arena.enemy._physics_process(0.01)
	check(arena.enemy.player == host().body and host().body.health == 90, "IA do servidor ataca anfitrião próximo")
	fixture(Vector2(1100, 620), Vector2(1000, 620))
	arena.enemy.attack_cooldown = 0
	arena.choose_enemy_target()
	arena.enemy._physics_process(0.01)
	check(arena.enemy.player == guest().body and guest().body.health == 90, "IA do servidor troca alvo e ataca convidado")
	host().body.health = 100
	guest().body.health = 100
	fixture(Vector2(140, 160), Vector2(340, 160))
	var start: Vector2 = guest().body.position
	var host_start: Vector2 = host().body.position
	var data := await command("move", "move")
	check(guest().body.position.x > start.x + 25 and guest().body.position.x < start.x + 85 and host().body.position == host_start, "Movimento remoto exclusivo e limitado pelo servidor")
	check(data.camera == "Player_%d" % guest_id and get_viewport().get_camera_2d().get_parent() == host().body, "Câmeras locais independentes")
	check(not data.mob_client_authority and not data.mob_client_physics, "Cliente apenas apresenta mob, sem executar IA/dano")
	check(data.actors[guest_id].position.distance_to(guest().body.position) < 5, "Posição confirmada consistente no cliente")
	await command("inventory", "inventory")
	check(not get_tree().paused and guest().panel and not host().panel, "Inventário remoto não pausa nem bloqueia anfitrião")
	var before: Vector2 = guest().body.position
	await command("blocked_move", "move")
	check(guest().body.position == before, "Painel bloqueia apenas movimento de seu jogador")
	await command("close", "close")
	fixture(Vector2(300, 400), Vector2(500, 400))
	var ammo: int = guest().inventory.loaded_ammo("pistola")
	await command("burst", "burst", Vector2.LEFT)
	check(guest().inventory.loaded_ammo("pistola") == ammo - 1 and host().body.health == 82, "Spam de tiros aplica um disparo/dano, respeitando cadência")
	check(host().inventory.loaded_ammo("pistola") == 8, "Disparo consome só munição do remetente")
	await get_tree().create_timer(0.6).timeout
	data = await command("replay", "replay", Vector2.LEFT)
	check(guest().inventory.loaded_ammo("pistola") == ammo - 2, "Repetir identificador de ação não dispara novamente")
	check(data.actors[1].health == host().body.health, "Vida de outro jogador sincronizada")
	await command("reload", "reload")
	check(guest().inventory.loaded_ammo("pistola") == 8 and guest().inventory.count_item("municao_pistola") == 14 and host().inventory.count_item("municao_pistola") == 16, "Recarga remota transfere reserva correta sem duplicar")
	fixture(Vector2(300, 400), Vector2(500, 400))
	arena.friendly_fire = false
	var life: int = host().body.health
	await command("friendly_off", "fire", Vector2.LEFT)
	check(host().body.health == life and guest().inventory.loaded_ammo("pistola") == 7, "Fogo amigo desligado bloqueia dano, não gasto do tiro")
	arena.friendly_fire = true
	fixture(Vector2(580, 400), Vector2(680, 400))
	await command("wall", "fire", Vector2.LEFT)
	check(host().body.health == life, "Parede da casa bloqueia tiro entre jogadores")
	var slots: Array = guest().inventory.slots
	before = guest().body.position
	await command("invalid", "invalid")
	check(guest().inventory.slots == slots and guest().body.position == before and host().body.health == life, "Ações de criar item/dano/teleporte rejeitadas")
	fixture(Vector2(430, 600), Vector2(470, 600))
	probe_command.rpc_id(guest_id, "race", "collect")
	arena.request_action("collect")
	await wait_condition(func(): return reports.has("race"))
	check(host().inventory.wood + guest().inventory.wood == 5 and not is_instance_valid(arena.drop), "Coleta concorrente credita recompensa uma única vez")
	fixture(Vector2(900, 620), Vector2(980, 540))
	arena.enemy.position = Vector2(980, 620)
	arena.friendly_fire = false
	arena.request_action("fire_mouse", Vector2.RIGHT)
	await command("mob", "fire", Vector2.DOWN)
	check(not is_instance_valid(arena.enemy), "Ambos combatem e matam o mesmo mob com fogo amigo desligado")
	data = await command("mob_state", "close")
	check(not data.mob.alive and data.drop.quantity == 0, "Cliente confirma morte do mob e remoção do item")
	# Mata o convidado com seis tiros reais, respeitando invulnerabilidade.
	arena.friendly_fire = true
	fixture(Vector2(300, 400), Vector2(500, 400))
	var kept: Dictionary = guest().inventory.network_state()
	for i in range(6):
		arena.request_action("fire_mouse", Vector2.RIGHT)
		await get_tree().create_timer(0.82).timeout
	data = await command("death", "close")
	check(guest().body.dead and data.death_hud and data.actors[guest_id].health == 0, "Tiros reais causam morte confirmada nas duas instâncias")
	await command("respawn", "respawn")
	check(not guest().body.dead and guest().body.health == 100 and guest().body.position.distance_to(Vector2(340, 160)) <= 40, "Reaparecimento remoto validado em ponto seguro")
	check(guest().inventory.network_state() == kept, "Reaparecer mantém inventário e não reaplica kit")
	probe_command.rpc_id(guest_id, "rejoined", "rejoin")
	check(await wait_condition(func(): return arena.actors.size() == 1, 2), "Saída remove personagem do convidado")
	check(await wait_condition(func(): return reports.has("rejoined")), "Convidado reconecta após limpar rede")
	data = reports.get("rejoined", {})
	check(not data.get("mob", {"alive": true}).alive and data.get("drop", {"quantity": 1}).quantity == 0, "Entrada tardia não recria mob/item removidos")
	probe_command.rpc_id(guest_id, "shutdown", "wait_shutdown")
	await get_tree().create_timer(0.1).timeout
	await main.leave_game()
	check(main.game == null and main.menu != null and multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "Anfitrião encerra e limpa estado de rede")
	main.start_solo()
	check(main.game.get_node("Inventory").tools.is_empty(), "Anfitrião inicia solo sem kit multiplayer")
	main.game.get_node("HUD").set_panel("inventory")
	check(get_tree().paused, "Modo solo continua pausando nos painéis")
	get_tree().paused = false
	finish()

func finish() -> void:
	print("NETWORK ", role, ": ", checks, " verificações, ", failures, " falhas")
	get_tree().quit(1 if failures else 0)
