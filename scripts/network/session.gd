extends Node

const MENU := preload("res://scenes/menu.tscn")
const SOLO := "res://scenes/world.tscn"
const ARENA := "res://scenes/network/test_arena.tscn"
const AUTH := preload("res://scenes/auth.tscn")
var game: Node
var menu: Control
var auth_screen: Control
var connecting := false
var closing := false
var connection_time: float = 0
@export var connection_timeout: float = 8.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(func(): return_to_menu("Falha na conexão. Confira endereço, porta e se a partida está disponível."))
	multiplayer.server_disconnected.connect(func(): return_to_menu("O anfitrião encerrou a partida ou a conexão foi perdida."))
	multiplayer.peer_disconnected.connect(_peer_left)
	FirebaseAuth.authenticated.connect(_authenticated)
	FirebaseAuth.signed_out.connect(_signed_out)
	if FirebaseAuth.can_play(): show_menu("Teste local / rede local · anfitrião + um convidado")
	else: show_auth()

func show_auth(message: String = "") -> void:
	reset_network()
	clear_scene()
	auth_screen = AUTH.instantiate()
	add_child(auth_screen)
	if message != "": auth_screen.show_message(message)

func _authenticated() -> void:
	clear_scene()
	show_menu("Conta validada. Escolha uma partida.")

func _signed_out(reason: String) -> void:
	if FirebaseAuth.enabled(): show_auth(reason)

func show_menu(message: String) -> void:
	if not FirebaseAuth.can_play():
		show_auth("Entre com uma conta confirmada para jogar.")
		return
	menu = MENU.instantiate()
	add_child(menu)
	menu.solo_requested.connect(start_solo)
	menu.host_requested.connect(host_game)
	menu.join_requested.connect(join_game)
	menu.show_status(message)
	if FirebaseAuth.enabled():
		var logout := Button.new()
		logout.text = "Sair da conta"
		logout.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		logout.position = Vector2(-230, 16)
		logout.custom_minimum_size = Vector2(210, 56)
		logout.pressed.connect(FirebaseAuth.logout)
		menu.add_child(logout)

func clear_scene() -> void:
	MobileInput.reset()
	MobileInput.overlay = null
	get_tree().paused = false
	for node in [game, menu, auth_screen]:
		if is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	game = null
	menu = null
	auth_screen = null

func start_solo() -> void:
	if not FirebaseAuth.can_play():
		show_auth("Entre com uma conta confirmada para jogar.")
		return
	var scene := prepare_game(SOLO)
	if scene == null: return
	reset_network()
	clear_scene()
	game = scene
	game.name = "Solo"
	add_child(game)
	add_exit_button("Voltar ao menu")
	var layer := CanvasLayer.new()
	layer.layer = 9
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(layer)
	var controls := preload("res://scripts/mobile_controls.gd").new()
	controls.player = game.get_node("WorldObjects/Player")
	controls.hud = game.get_node("HUD")
	controls.structures = game.get_node("Structures")
	controls.session = self
	layer.add_child(controls)

func host_game(port: int = 7000, allow_damage: bool = true) -> void:
	if not FirebaseAuth.can_play():
		show_auth()
		return
	if OS.has_feature("web"):
		menu.show_status("Multiplayer em breve. Jogue solo nesta versão Web.")
		return
	if connecting or is_instance_valid(game): return
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, 1) # Um convidado, além do anfitrião.
	if error != OK:
		menu.show_status("Não foi possível abrir a porta %d (erro %d). Tente outra porta." % [port, error])
		return
	var scene := prepare_game(ARENA)
	if scene == null:
		peer.close()
		return
	multiplayer.multiplayer_peer = peer
	clear_scene()
	game = scene
	game.name = "Arena"
	game.friendly_fire = allow_damage
	add_child(game)
	add_exit_button("Encerrar partida / Menu")
	game.get_node("HUD").show_message("Anfitrião · porta %d · aguardando convidado" % port)

func join_game(address: String = "127.0.0.1", port: int = 7000) -> void:
	if not FirebaseAuth.can_play():
		show_auth()
		return
	if OS.has_feature("web"):
		menu.show_status("Multiplayer em breve. Jogue solo nesta versão Web.")
		return
	if connecting or is_instance_valid(game): return
	if address == "":
		menu.show_status("Informe o endereço do anfitrião.")
		return
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port)
	if error != OK:
		menu.show_status("Falha ao iniciar conexão (erro %d)." % error)
		return
	multiplayer.multiplayer_peer = peer
	connecting = true
	connection_time = 0
	menu.show_status("Conectando a %s:%d…" % [address, port])

func _connected() -> void:
	if not FirebaseAuth.can_play():
		show_auth()
		return
	connecting = false
	var scene := prepare_game(ARENA)
	if scene == null: return
	clear_scene()
	game = scene
	game.name = "Arena"
	add_child(game)
	add_exit_button("Sair da partida / Menu")

func prepare_game(path: String) -> Node:
	var packed := load(path) as PackedScene
	if packed != null and packed.can_instantiate():
		var scene := packed.instantiate()
		if scene != null:
			var script := scene.get_script() as Script
			if script != null and script.can_instantiate():
				# A sessão continua respondendo durante a pausa; a simulação não.
				if path == SOLO:
					scene.process_mode = Node.PROCESS_MODE_PAUSABLE
				return scene
			scene.free()
	push_error("Não foi possível carregar a partida: " + path)
	return_to_menu("Não foi possível abrir a partida. Confira os erros do projeto e tente novamente.")
	return null

func _process(delta: float) -> void:
	if connecting:
		connection_time += delta
		if connection_time >= connection_timeout:
			return_to_menu("Conexão não concluída: servidor indisponível, partida cheia ou porta bloqueada.")

func add_exit_button(text: String) -> void:
	var layer := CanvasLayer.new()
	layer.name = "ExitUI"
	layer.layer = 10
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(layer)
	var button := Button.new()
	button.text = text
	button.position = Vector2(690, 16)
	button.custom_minimum_size = Vector2(210, 52)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(leave_game)
	layer.add_child(button)

func leave_game() -> void:
	if closing: return
	closing = true
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		if multiplayer.is_server():
			for id in multiplayer.get_peers(): session_ended.rpc_id(id)
		else:
			leave_requested.rpc_id(1)
		# Dá ao ENet um passo para entregar o aviso antes de fechar o socket.
		await get_tree().create_timer(0.15, true).timeout
	return_to_menu("Partida encerrada. Você pode criar, entrar ou jogar solo.")

@rpc("any_peer", "call_remote", "reliable")
func leave_requested() -> void:
	if not multiplayer.is_server(): return
	var sender := multiplayer.get_remote_sender_id()
	if is_instance_valid(game) and game.has_method("remove_peer"):
		game.remove_peer(sender)
	multiplayer.multiplayer_peer.disconnect_peer(sender)

@rpc("authority", "call_remote", "reliable")
func session_ended() -> void:
	return_to_menu("O anfitrião encerrou a partida.")

func _peer_left(id: int) -> void:
	if multiplayer.is_server() and is_instance_valid(game) and game.has_method("remove_peer"):
		game.remove_peer(id)

func reset_network() -> void:
	connecting = false
	closing = false
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

func return_to_menu(message: String) -> void:
	reset_network()
	clear_scene()
	show_menu(message)
