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
var transitioning := false
var transition_panel := ""
var library: WorldLibrary
var selected_world := ""
var connected_address := ""
var connected_port := 7000
var local_conflict_dialog := false
@export var connection_timeout: float = 8.0

func _ready() -> void:
	ThemeDB.get_default_theme().default_font = IslandTheme.BODY
	ThemeDB.get_default_theme().default_font_size = 18
	process_mode = Node.PROCESS_MODE_ALWAYS
	OrientationGuard.blocked_changed.connect(_orientation_changed)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(func(): return_to_menu("Falha na conexão. Confira endereço, porta e se a partida está disponível."))
	multiplayer.server_disconnected.connect(func(): return_to_menu("O anfitrião encerrou a partida ou a conexão foi perdida."))
	multiplayer.peer_disconnected.connect(_peer_left)
	FirebaseAuth.authenticated.connect(_authenticated)
	FirebaseAuth.signed_out.connect(_signed_out)
	FirebaseAuth.before_logout = _save_before_logout
	FirebaseAuth.message_changed.connect(_auth_message)
	if FirebaseAuth.can_play(): show_menu("")
	else: show_auth()

func _auth_message(text: String) -> void:
	if is_instance_valid(game) and game.has_node("HUD"): game.get_node("HUD").show_message(text)
	elif is_instance_valid(menu): menu.show_status(text)

func show_auth(message: String = "", save_current: bool = true) -> void:
	OrientationGuard.set_authenticated(false)
	library = null
	selected_world = ""
	reset_network()
	await clear_scene(save_current)
	auth_screen = AUTH.instantiate()
	add_child(auth_screen)
	if message != "": auth_screen.show_message(message)

func _authenticated() -> void:
	await clear_scene()
	show_menu("")

func _signed_out(reason: String) -> void:
	if FirebaseAuth.enabled(): show_auth(reason, false)

func show_menu(message: String) -> void:
	if not FirebaseAuth.can_play():
		show_auth("Entre com uma conta confirmada para jogar.")
		return
	menu = MENU.instantiate()
	add_child(menu)
	OrientationGuard.set_authenticated(true)
	menu.solo_requested.connect(start_solo)
	menu.host_requested.connect(host_game)
	menu.join_requested.connect(join_game)
	menu.show_status(message)
	if FirebaseAuth.enabled():
		var current_library := WorldLibrary.new()
		current_library.configure(FirebaseAuth.account_uid())
		library = current_library
		var current_menu := menu
		set_transition(true)
		var loaded := await current_library.load_index(get_tree())
		if not is_instance_valid(current_menu) or menu != current_menu or current_library.uid != FirebaseAuth.account_uid(): return
		if not loaded:
			menu.show_status(library.error + " Reabra o lobby para tentar novamente.")
			set_transition(false)
			for button in menu.find_children("*", "Button", true, false):
				if button.text in ["Continuar", "Jogar mundo", "Criar mundo", "Renomear"]: button.disabled = true
		else:
			menu.show_status("Consultando mundos da conta…" if WorldSync.enabled(library.uid) else library.warning)
			var remote := await WorldSync.refresh_library(library)
			if not is_instance_valid(current_menu) or menu != current_menu or current_library.uid != FirebaseAuth.account_uid(): return
			menu.set_library(library, selected_world)
			set_transition(false)
			if not remote.get("ok", false): menu.show_status(str(remote.get("error", "Sincronização pendente.")) + " Mundos locais preservados.")
			elif library.warning != "": menu.show_status(library.warning)
			var retry: Button = menu.button(menu.pages.worlds, "Atualizar mundos / Tentar sincronização", refresh_worlds)
			retry.visible = WorldSync.enabled(library.uid)
			if OS.has_feature("web"):
				menu.button(menu.pages.options, "Exportar cópia dos saves deste navegador", func(): JavaScriptBridge.eval("window.tcExportLocalSaves().catch(()=>alert('Não foi possível exportar. Nenhum dado foi apagado.'))"))
				JavaScriptBridge.eval("window.tcRequestPersistence().catch(()=>false)")
		var account := AccountProgress.new()
		var owner := FirebaseAuth.account_uid()
		account.configure(owner)
		var existing := await account.read(get_tree())
		var available := await account.legacy_available(get_tree())
		if not is_instance_valid(menu) or FirebaseAuth.account_uid() != owner: return
		if account.error == "" and existing.is_empty() and available:
			var import_button := Button.new()
			import_button.text = "Importar save antigo"
			import_button.position = Vector2(16, 16)
			import_button.custom_minimum_size = Vector2(250, 64)
			import_button.pressed.connect(func():
				var dialog := ConfirmationDialog.new()
				dialog.title = "Importar progresso antigo"
				dialog.dialog_text = "Atribuir o save antigo sem dono a esta conta?\nImportação única neste aparelho, com backup.\nO original será preservado. Confira o estado da sincronização."
				dialog.ok_button_text = "Importar para esta conta"
				dialog.cancel_button_text = "Cancelar"
				dialog.get_label().add_theme_font_size_override("font_size", 20)
				for button in [dialog.get_ok_button(), dialog.get_cancel_button()]:
					button.custom_minimum_size.y = 64
					button.add_theme_font_size_override("font_size", 20)
				dialog.confirmed.connect(func(): _import_legacy(account))
				dialog.canceled.connect(dialog.queue_free)
				menu.add_child(dialog)
				dialog.popup_centered(Vector2i(600, 240)))
			menu.rows.add_child(import_button)
			menu.resize()

func _import_legacy(account: AccountProgress) -> void:
	if transitioning or FirebaseAuth.account_uid() != account.uid: return
	set_transition(true)
	menu.show_status("Importando progresso antigo…")
	var ok := await account.import_legacy(get_tree())
	if not is_instance_valid(menu): return
	if ok and library != null:
		var next := library.data.duplicate(true)
		next.migration_done = false
		ok = await library.commit(next, get_tree()) and await library.migrate(get_tree())
		if ok: menu.set_library(library, "first-world")
	menu.show_status("Progresso antigo importado. Use Continuar." if ok else account.error)
	set_transition(false)
	for button in menu.find_children("*", "Button", true, false):
		if button.text == "Importar save antigo": button.disabled = ok

func refresh_worlds() -> void:
	if transitioning or library == null: return
	set_transition(true)
	var current_library := library
	var ok := await current_library.load_index(get_tree())
	var remote := await WorldSync.refresh_library(current_library, true) if ok else {"ok": false, "error": current_library.error}
	if not is_instance_valid(menu) or library != current_library: return
	menu.set_library(library, selected_world)
	set_transition(false)
	menu.show_status(("Lista atualizada · Sincronização pendente." if remote.get("pending", false) else "Lista atualizada.") if remote.get("ok", false) else str(remote.get("error", "Falha ao atualizar.")))

func save_summary(data: Dictionary) -> String:
	var items := 0
	for slot in data.get("inventory", {}).get("slots", []): items += int(slot.get("quantity", 0))
	return "%d itens · %d construções · %d registros" % [items, data.get("structures", []).size(), data.get("journal", {}).get("discovered", []).size()]

func recover_world(account: AccountProgress) -> void:
	var current_menu := menu
	set_transition(true)
	menu.show_status("Procurando cópias preservadas…")
	var candidates := await account.recovery_candidates(get_tree())
	var cloud_error := ""
	if WorldSync.enabled(account.uid):
		var response: Dictionary = await WorldSync.client.head(account.uid, account.world_id)
		if response.get("ok", false) and response.has("head"):
			var download: Dictionary = await WorldSync.client.download(account.uid, account.world_id, response.head)
			if download.get("ok", false):
				download.data._sync = WorldSync.base(response.head)
				candidates.append({"source": "cloud", "remote": true, "revision": response.head.revision, "data": download.data})
			else: cloud_error = str(download.get("error", "Nuvem indisponível."))
		elif not response.get("ok", false): cloud_error = str(response.get("error", "Nuvem indisponível."))
	if not is_instance_valid(current_menu) or menu != current_menu: return
	set_transition(false)
	if candidates.is_empty():
		menu.show_status("Nenhum backup válido encontrado aqui. Exporte os saves e confira o navegador da última partida. " + cloud_error)
		return
	var dialog := AcceptDialog.new()
	dialog.title = "Recuperar uma cópia do mundo"
	dialog.ok_button_text = "Cancelar"
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(520, 220)
	dialog.add_child(scroll)
	var rows := VBoxContainer.new()
	scroll.add_child(rows)
	for index in range(candidates.size()):
		var candidate: Dictionary = candidates[index]
		var title := "Nuvem · revisão %d" % int(candidate.revision) if candidate.get("remote", false) else "Cópia local %d" % (index + 1)
		menu.button(rows, title + " · " + save_summary(candidate.data), func():
			dialog.hide()
			set_transition(true)
			var ok := await account.recover_data(candidate.data, get_tree()) if candidate.get("remote", false) else await account.recover(candidate.source, get_tree())
			set_transition(false)
			if not is_instance_valid(current_menu) or menu != current_menu: return
			menu.show_status("Backup recuperado; original preservado." if ok else account.error)
			dialog.queue_free()
			if ok: start_solo())
	menu.add_child(dialog)
	dialog.popup_centered(Vector2i(580, 300))

func resolve_world(account: AccountProgress) -> void:
	var details: Dictionary = WorldSync.conflicts.get(WorldSync.key(account), {})
	var dialog := ConfirmationDialog.new()
	dialog.title = "Duas versões do mundo"
	dialog.dialog_text = "Este aparelho: %s\nNuvem: revisão %d confirmada pelo serviço.\n\nVamos manter a nuvem e criar uma cópia do progresso deste aparelho.\nEscolha qual versão continuar. Nenhuma delas será descartada." % [save_summary(details.get("local", {})), int(details.get("head", {}).get("revision", 0))]
	dialog.ok_button_text = "Continuar cópia deste aparelho"
	dialog.cancel_button_text = "Decidir depois"
	var remote_button := dialog.add_button("Continuar versão da nuvem", true, "remote")
	for button in [dialog.get_ok_button(), dialog.get_cancel_button(), remote_button]: button.custom_minimum_size.y = 56
	var choose := func(local: bool):
		dialog.hide()
		set_transition(true)
		menu.show_status("Preservando as duas versões…")
		var result: Dictionary = await WorldSync.resolve(account, library, local)
		if not is_instance_valid(menu): return
		set_transition(false)
		dialog.queue_free()
		if not result.get("ok", false): menu.show_status(str(result.get("error", "Falha ao resolver. Tente novamente."))); return
		menu.selected_world = result.world_id
		menu.set_library(library, result.world_id)
		start_solo()
	dialog.confirmed.connect(func(): choose.call(true))
	dialog.custom_action.connect(func(_action): choose.call(false))
	dialog.canceled.connect(dialog.queue_free)
	menu.add_child(dialog)
	dialog.popup_centered(Vector2i(760, 300))

func set_transition(value: bool) -> void:
	transitioning = value
	if is_instance_valid(game) and game.has_method("save_progress"):
		var hud: CanvasLayer = game.get_node("HUD")
		if value and hud.current_panel != "saving":
			transition_panel = hud.current_panel
			hud.set_panel("saving")
		elif not value and hud.current_panel == "saving":
			hud.set_panel(transition_panel)
			transition_panel = ""
	if is_instance_valid(menu):
		for button in menu.find_children("*", "Button", true, false): button.disabled = value
		if not value: menu.refresh_controls()

func _save_before_logout() -> bool:
	if not is_instance_valid(game) or not game.has_method("save_progress"): return true
	var paused := get_tree().paused
	set_transition(true)
	get_tree().paused = true
	MobileInput.reset()
	var ok: bool = await game.save_progress(true)
	if not ok:
		get_tree().paused = paused
		set_transition(false)
	return ok

func _exit_tree() -> void:
	if FirebaseAuth.before_logout == _save_before_logout: FirebaseAuth.before_logout = Callable()

func clear_scene(save_current: bool = true) -> void:
	if GlobalChat.opened: GlobalChat.toggle()
	MobileInput.reset()
	MobileInput.overlay = null
	if is_instance_valid(game) and game.has_method("save_progress") and save_current:
		get_tree().paused = true
		await game.save_progress(true)
	for node in [game, menu, auth_screen]:
		if is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	game = null
	menu = null
	auth_screen = null
	get_tree().paused = false
	transitioning = false
	transition_panel = ""

func start_solo() -> void:
	if OrientationGuard.blocked: return
	if transitioning or is_instance_valid(game): return
	if is_instance_valid(menu) and menu.worlds_busy: return
	if not FirebaseAuth.can_play():
		show_auth("Entre com uma conta confirmada para jogar.")
		return
	var scene := prepare_game(SOLO)
	if scene == null: return
	set_transition(true)
	if FirebaseAuth.enabled():
		var account := AccountProgress.new()
		var owner := FirebaseAuth.account_uid()
		selected_world = menu.selected_world
		if not WorldLibrary.safe_id(selected_world):
			scene.free()
			menu.show_status("Crie e selecione um mundo para jogar.")
			set_transition(false)
			return
		account.configure(owner, "user://", selected_world)
		menu.show_status("Carregando progresso desta conta…")
		var prepared := await WorldSync.prepare(account, library)
		if not FirebaseAuth.can_play() or FirebaseAuth.account_uid() != owner:
			scene.free()
			set_transition(false)
			return
		if not prepared.get("ok", false):
			scene.free()
			menu.show_status(str(prepared.get("error", "Falha ao carregar.")) + " Tente novamente.")
			set_transition(false)
			if prepared.get("conflict", false): resolve_world(account)
			elif prepared.get("recovery", false): recover_world(account)
			return
		scene.account_store = account
		scene.owner_uid = owner
		scene.world_id = selected_world
		scene.world_name = library.entry(selected_world).get("name", "Meu mundo")
		scene.world_library = library
		scene.progress_path = account.store.path
		scene.initial_progress = prepared.data
		if not await library.touch_world(selected_world, get_tree()):
			scene.free()
			menu.show_status(library.error)
			set_transition(false)
			return
	reset_network()
	await clear_scene()
	game = scene
	game.name = "Solo"
	game.persistence_enabled = true
	add_child(game)
	game.local_conflict_found.connect(resolve_local_session)
	if game.account_store != null:
		# A new world must acquire its first durable local save before play advances.
		await game.save_progress(true)
	if game.get_node("WorldObjects/Player").dead or OrientationGuard.blocked: game._on_panel_toggled(false)
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

func resolve_local_session() -> void:
	if local_conflict_dialog or not is_instance_valid(game): return
	local_conflict_dialog = true
	# Let the caller finish its failed leave/logout transition before opening.
	await get_tree().process_frame
	if not is_instance_valid(game):
		local_conflict_dialog = false
		return
	var current_game := game
	var previous_pause := get_tree().paused
	get_tree().paused = true
	MobileInput.reset()
	var dialog := ConfirmationDialog.new()
	dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	dialog.title = "Outra sessão salvou este mundo"
	dialog.dialog_text = "O progresso da outra sessão será mantido.\nVamos salvar sua partida atual como outro mundo,\npara que você possa continuar sem perder nenhuma versão."
	dialog.ok_button_text = "Salvar minha partida como cópia"
	dialog.cancel_button_text = "Decidir depois"
	dialog.confirmed.connect(func():
		var source: WorldLibrary = current_game.world_library
		var fresh := WorldLibrary.new()
		fresh.configure(source.uid, source.folder)
		fresh.native_only = source.native_only
		var loaded := await fresh.load_index(get_tree())
		var title: String = (current_game.world_name.left(22) + " · cópia do aparelho").left(40)
		var result := await fresh.fork_local(current_game.progress_store.capture(), title, get_tree()) if loaded else {"ok": false, "error": fresh.error}
		if result.get("ok", false):
			current_game.world_id = result.id
			current_game.world_name = title
			current_game.account_store = result.account
			current_game.world_library = fresh
			library = fresh
			selected_world = result.id
			current_game.save_controller.changed()
			await current_game.save_progress(true)
		current_game.get_node("HUD").show_message("As duas versões foram preservadas. Você continua na cópia." if result.get("ok", false) else str(result.get("error", "Falha ao preservar cópia.")))
		get_tree().paused = previous_pause
		local_conflict_dialog = false
		dialog.queue_free())
	dialog.canceled.connect(func():
		get_tree().paused = previous_pause
		local_conflict_dialog = false
		dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered(Vector2i(660, 260))

func host_game(port: int = 7000, allow_damage: bool = true) -> void:
	if is_instance_valid(menu) and menu.worlds_busy: return
	if not FirebaseAuth.can_play():
		show_auth()
		return
	if OS.has_feature("web"):
		menu.show_status("Multiplayer em breve. Jogue solo nesta versão Web.")
		return
	if transitioning or connecting or is_instance_valid(game): return
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
	await clear_scene()
	game = scene
	game.name = "Arena"
	game.friendly_fire = allow_damage
	add_child(game)
	add_exit_button("Encerrar partida / Menu")
	game.get_node("HUD").show_message("Anfitrião · porta %d · aguardando convidado" % port)

func join_game(address: String = "127.0.0.1", port: int = 7000) -> void:
	if is_instance_valid(menu) and menu.worlds_busy: return
	if not FirebaseAuth.can_play():
		show_auth()
		return
	if OS.has_feature("web"):
		menu.show_status("Multiplayer em breve. Jogue solo nesta versão Web.")
		return
	if transitioning or connecting or is_instance_valid(game): return
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
	connected_address = address
	connected_port = port
	connection_time = 0
	menu.show_status("Conectando a %s:%d…" % [address, port])

func _connected() -> void:
	if not FirebaseAuth.can_play():
		show_auth()
		return
	connecting = false
	var scene := prepare_game(ARENA)
	if scene == null: return
	if library != null:
		if not await library.record_server(connected_address, connected_port, get_tree()): menu.show_status("Conexão realizada, mas o histórico local falhou: " + library.error)
	await clear_scene()
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

func _orientation_changed(value: bool) -> void:
	if not is_instance_valid(game): return
	MobileInput.reset()
	if game.has_method("_on_panel_toggled"):
		game._on_panel_toggled(game.get_node("HUD").current_panel != "")
	elif game.has_node("HUD"):
		var hud: CanvasLayer = game.get_node("HUD")
		if value: hud.set_panel("menu")

func add_exit_button(text: String) -> void:
	# Guests build their HUD after the first authoritative actor snapshot.
	var current_game := game
	while is_instance_valid(current_game) and game == current_game and current_game.get_node("HUD").menu_view == null:
		await get_tree().process_frame
	if is_instance_valid(current_game) and game == current_game:
		current_game.get_node("HUD").menu_view.leave_action = leave_game

func leave_game() -> void:
	if transitioning or FirebaseAuth.logging_out: return
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
	if FirebaseAuth.logging_out: return
	if is_instance_valid(game) and game.has_method("save_progress"):
		var paused := get_tree().paused
		get_tree().paused = true
		set_transition(true)
		var ok: bool = await game.save_progress(true)
		if not ok:
			get_tree().paused = paused
			set_transition(false)
			closing = false
			game.get_node("HUD").show_message("Falha ao salvar. Tente novamente antes de voltar ao menu.")
			return
	reset_network()
	await clear_scene(false)
	show_menu(message)
