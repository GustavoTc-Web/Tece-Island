extends Control

signal solo_requested
signal host_requested(port: int, friendly_fire: bool)
signal join_requested(address: String, port: int)

@export var default_port: int = 7000
var address: LineEdit
var port: SpinBox
var damage_option: CheckBox
var status: Label
var rows: VBoxContainer
var center: CenterContainer
var library: WorldLibrary
var selected_world := ""
var worlds_list: VBoxContainer
var servers_list: VBoxContainer
var world_name: LineEdit
var overlay: CanvasLayer
var worlds_busy := false

func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("263c35")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	center = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	rows = VBoxContainer.new()
	rows.custom_minimum_size.x = 430
	rows.add_theme_constant_override("separation", 12)
	center.add_child(rows)
	get_viewport().size_changed.connect(resize)
	MobileInput.mode_changed.connect(resize)
	var title := Label.new()
	title.text = "TECE-ISLAND · Lobby"
	title.add_theme_font_size_override("font_size", 23)
	rows.add_child(title)
	var character_row := HBoxContainer.new()
	rows.add_child(character_row)
	var preview := Control.new()
	preview.custom_minimum_size = Vector2(130, 120)
	character_row.add_child(preview)
	var character: CharacterBody2D = preload("res://scenes/player.tscn").instantiate()
	character.process_mode = Node.PROCESS_MODE_DISABLED
	character.position = Vector2(65, 116)
	character.scale = Vector2(2.5, 2.5)
	character.get_node("Camera2D").enabled = false
	preview.add_child(character)
	var identity := Label.new()
	identity.text = "Seu explorador\nSkin atual · pronto para a ilha"
	character_row.add_child(identity)
	button(rows, "Jogar solo", func(): solo_requested.emit())
	worlds_list = VBoxContainer.new()
	rows.add_child(worlds_list)
	world_name = LineEdit.new()
	world_name.placeholder_text = "Nome do mundo"
	world_name.max_length = 40
	world_name.custom_minimum_size.y = 48
	rows.add_child(world_name)
	var actions := HBoxContainer.new()
	rows.add_child(actions)
	button(actions, "Criar mundo", create_world)
	button(actions, "Renomear selecionado", rename_world)
	servers_list = VBoxContainer.new()
	rows.add_child(servers_list)
	overlay = preload("res://scripts/lobby_overlay.gd").new()
	overlay.lobby = self
	add_child(overlay)
	var utilities := HBoxContainer.new()
	rows.add_child(utilities)
	button(utilities, "Configurações", overlay.open_settings)
	button(utilities, "Ajuda", overlay.open_help)
	var mobile := CheckBox.new()
	mobile.text = "Controles de toque (testar no computador)"
	mobile.custom_minimum_size.y = 48
	mobile.button_pressed = MobileInput.enabled
	mobile.toggled.connect(MobileInput.set_enabled)
	rows.add_child(mobile)
	if OS.has_feature("web"):
		var notice := Label.new()
		notice.text = "Multiplayer em breve"
		rows.add_child(notice)
		status = Label.new()
		status.custom_minimum_size = Vector2(430, 60)
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rows.add_child(status)
		rows.get_child(2).grab_focus()
		resize()
		return
	var label := Label.new()
	label.text = "Endereço do anfitrião (duas instâncias: 127.0.0.1)"
	rows.add_child(label)
	address = LineEdit.new()
	address.text = "127.0.0.1"
	rows.add_child(address)
	var port_row := HBoxContainer.new()
	rows.add_child(port_row)
	var port_label := Label.new()
	port_label.text = "Porta UDP: "
	port_row.add_child(port_label)
	port = SpinBox.new()
	port.min_value = 1024
	port.max_value = 65535
	port.value = default_port
	port_row.add_child(port)
	damage_option = CheckBox.new()
	damage_option.text = "Permitir dano entre jogadores"
	damage_option.button_pressed = true
	rows.add_child(damage_option)
	button(rows, "Criar partida de teste", func(): host_requested.emit(int(port.value), damage_option.button_pressed))
	button(rows, "Entrar na partida de teste", func(): join_requested.emit(address.text.strip_edges(), int(port.value)))
	status = Label.new()
	status.custom_minimum_size = Vector2(430, 50)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.text = "Teste local / rede local · anfitrião + um convidado"
	rows.add_child(status)
	rows.get_child(2).grab_focus()
	resize()

func resize() -> void:
	center.custom_minimum_size = get_viewport_rect().size
	rows.custom_minimum_size.x = minf(740, get_viewport_rect().size.x - 48)
	if not MobileInput.enabled: return
	var font := int(maxf(20, ceilf(15 / MobileInput.css_scale())))
	for child in rows.get_children():
		if child is Button:
			child.custom_minimum_size.y = MobileInput.touch_minimum()
			child.add_theme_font_size_override("font_size", font)
			child.clip_text = true
		if child is Label:
			child.add_theme_font_size_override("font_size", font)
			child.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func button(parent: Node, text: String, callback: Callable) -> void:
	var control := Button.new()
	control.text = text
	control.custom_minimum_size.y = 48
	control.focus_mode = Control.FOCUS_ALL
	control.pressed.connect(callback)
	parent.add_child(control)

func show_status(text: String) -> void:
	status.text = "Modo solo · explore a ilha" if OS.has_feature("web") and text.begins_with("Teste local") else text

func set_library(source: WorldLibrary, selected: String = "") -> void:
	library = source
	selected_world = selected
	if selected_world.is_empty() and not library.data.worlds.is_empty(): selected_world = library.data.worlds[0].id
	refresh_library()

func last_access(value: float) -> String:
	return "Ainda não acessado" if value <= 0 else Time.get_datetime_string_from_unix_time(int(value)).replace("T", " ") + " UTC"

func refresh_library() -> void:
	for list in [worlds_list, servers_list]:
		for child in list.get_children(): list.remove_child(child); child.queue_free()
	var heading := Label.new()
	heading.text = "Meus mundos · Mundos salvos neste aparelho"
	worlds_list.add_child(heading)
	for world in library.data.worlds:
		var entry := Button.new()
		entry.text = ("Selecionado · " if selected_world == world.id else "") + world.name + "\nÚltimo acesso: " + last_access(float(world.last_access))
		entry.custom_minimum_size.y = 64
		entry.set_meta("world_id", world.id)
		entry.pressed.connect(func(): selected_world = world.id; world_name.text = world.name; refresh_library())
		worlds_list.add_child(entry)
	if library.data.worlds.is_empty():
		var empty := Label.new()
		empty.text = "Nenhum mundo. Dê um nome e toque Criar mundo."
		worlds_list.add_child(empty)
	var servers := Label.new()
	servers.text = "Servidores acessados"
	servers_list.add_child(servers)
	if library.data.servers.is_empty():
		var empty := Label.new()
		empty.text = "Você ainda não acessou nenhum servidor."
		servers_list.add_child(empty)
	for server in library.data.servers:
		var entry := Button.new()
		entry.text = str(server.name) + " · " + last_access(float(server.last_access))
		entry.disabled = OS.has_feature("web")
		entry.tooltip_text = "Reconexão ENet disponível no aplicativo desktop" if OS.has_feature("web") else "Reconectar"
		entry.pressed.connect(func(): join_requested.emit(server.address, int(server.port)))
		servers_list.add_child(entry)
	resize()

func create_world() -> void:
	if library == null or worlds_busy: return
	worlds_busy = true
	var id := await library.create_world(world_name.text, get_tree())
	if not is_inside_tree(): return
	worlds_busy = false
	if id.is_empty(): show_status(library.error)
	else:
		selected_world = id
		world_name.text = ""
		show_status("Mundo criado neste aparelho. Selecione Jogar solo para começar.")
		refresh_library()

func rename_world() -> void:
	if library == null or worlds_busy: return
	worlds_busy = true
	var ok: bool = await library.rename_world(selected_world, world_name.text, get_tree())
	if not is_inside_tree(): return
	worlds_busy = false
	show_status("Mundo renomeado." if ok else library.error)
	if ok: refresh_library()
