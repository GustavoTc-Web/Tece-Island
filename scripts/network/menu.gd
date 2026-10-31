extends Control
signal solo_requested
signal host_requested(port: int, friendly_fire: bool)
signal join_requested(address: String, port: int)
@export var default_port := 7000
var library: WorldLibrary
var selected_world := ""
var worlds_busy := false
var main: Control
var main_rows: VBoxContainer
var primary: Button
var continue_caption: Label
var brand: Label
var status: Label
var page := "main"
var page_panel: PanelContainer
var page_title: Label
var pages := {}
var rows: VBoxContainer
var worlds_list: VBoxContainer
var servers_list: VBoxContainer
var world_name: LineEdit
var overlay: CanvasLayer
var address: LineEdit
var port: SpinBox
var damage_option: CheckBox
var dialog: Control
var dialog_panel: PanelContainer
var dialog_title: Label
var dialog_status: Label
var dialog_mode := ""
var name_callback: JavaScriptObject
var play_selected: Button
var rename_selected: Button
var release_note: Label

func _ready() -> void:
	ThemeDB.get_default_theme().default_font = IslandTheme.BODY
	ThemeDB.get_default_theme().default_font_size = 18
	var scenery := preload("res://scripts/lobby_scenery.gd").new()
	add_child(scenery)
	main = Control.new()
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(main)
	brand = Label.new()
	brand.text = "TECE-ISLAND"
	brand.add_theme_font_override("font", IslandTheme.TITLE)
	brand.add_theme_color_override("font_color", IslandTheme.AMBER)
	brand.add_theme_color_override("font_outline_color", Color("10271f"))
	brand.add_theme_constant_override("outline_size", 6)
	main.add_child(brand)
	release_note = Label.new()
	release_note.text = "Beta solo · 0.9.1-beta-rc.2"
	release_note.add_theme_color_override("font_color", IslandTheme.AMBER)
	main.add_child(release_note)
	main_rows = VBoxContainer.new()
	main_rows.add_theme_constant_override("separation", 10)
	main.add_child(main_rows)
	primary = button(main_rows, "Criar mundo", continue_world)
	continue_caption = Label.new()
	continue_caption.clip_text = true
	continue_caption.add_theme_color_override("font_color", Color("d2c9a8"))
	main_rows.add_child(continue_caption)
	for entry in [["Meus mundos", "worlds"], ["Multiplayer · indisponível", "servers"]]:
		button(main_rows, entry[0], open_page.bind(entry[1]))
	button(main_rows, "Configurações", func(): overlay.open_settings())
	var menu_button := button(main, "Menu", open_page.bind("options"))
	menu_button.name = "MenuButton"
	_create_pages()
	_create_dialog()
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_color_override("font_color", Color("e7c99a"))
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status)
	overlay = preload("res://scripts/lobby_overlay.gd").new()
	overlay.lobby = self
	add_child(overlay)
	get_viewport().size_changed.connect(resize)
	MobileInput.mode_changed.connect(resize)
	refresh_library()
	resize()
	primary.grab_focus()

func button(parent: Node, caption: String, callback: Callable) -> Button:
	var control := Button.new()
	control.text = caption
	control.custom_minimum_size.y = 48
	control.focus_mode = Control.FOCUS_ALL
	control.pressed.connect(callback)
	IslandTheme.decorate(control)
	parent.add_child(control)
	return control

func _create_pages() -> void:
	page_panel = PanelContainer.new()
	page_panel.add_theme_stylebox_override("panel", IslandTheme.panel(Color(0.065, 0.16, 0.12, 0.97)))
	add_child(page_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	page_panel.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	button(header, "Voltar", open_page.bind("main"))
	page_title = Label.new()
	page_title.add_theme_font_override("font", IslandTheme.TITLE)
	page_title.add_theme_font_size_override("font_size", 30)
	page_title.add_theme_color_override("font_color", IslandTheme.AMBER)
	header.add_child(page_title)
	for id in ["worlds", "servers", "advanced", "options", "development"]:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 10)
		box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.add_child(box)
		pages[id] = box
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pages.worlds.add_child(scroll)
	worlds_list = VBoxContainer.new()
	worlds_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	worlds_list.add_theme_constant_override("separation", 8)
	scroll.add_child(worlds_list)
	var actions := HBoxContainer.new()
	pages.worlds.add_child(actions)
	play_selected = button(actions, "Jogar mundo", func(): if library == null or not selected_world.is_empty(): solo_requested.emit())
	button(actions, "Criar mundo", open_name.bind("create"))
	rename_selected = button(actions, "Renomear", open_name.bind("rename"))
	rows = VBoxContainer.new()
	pages.worlds.add_child(rows)
	var local := Label.new()
	local.text = "Mundos desta conta · cópias locais preservadas"
	local.add_theme_color_override("font_color", Color("b5bea5"))
	rows.add_child(local)
	var server_scroll := ScrollContainer.new()
	server_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	server_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pages.servers.add_child(server_scroll)
	servers_list = VBoxContainer.new()
	servers_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	server_scroll.add_child(servers_list)
	if not OS.has_feature("web"):
		button(pages.servers, "Conexão avançada", open_page.bind("advanced"))
		var label := Label.new()
		label.text = "Endereço do servidor"
		pages.advanced.add_child(label)
		address = LineEdit.new()
		address.placeholder_text = "IP ou endereço"
		address.text = "127.0.0.1"
		pages.advanced.add_child(address)
		var port_label := Label.new()
		port_label.text = "Porta UDP"
		pages.advanced.add_child(port_label)
		port = SpinBox.new()
		port.min_value = 1024
		port.max_value = 65535
		port.value = default_port
		pages.advanced.add_child(port)
		button(pages.advanced, "Conectar", func(): join_requested.emit(address.text.strip_edges(), int(port.value)))
	button(pages.options, "Ajuda", func(): overlay.open_help())
	var logout := button(pages.options, "Sair da conta", FirebaseAuth.logout)
	logout.visible = FirebaseAuth.enabled()
	if OS.is_debug_build():
		button(pages.options, "Desenvolvimento", open_page.bind("development"))
		var touch := CheckButton.new()
		touch.text = "Simular controles de toque"
		touch.button_pressed = MobileInput.enabled
		touch.toggled.connect(MobileInput.set_enabled)
		pages.development.add_child(touch)
		if not OS.has_feature("web"):
			damage_option = CheckBox.new()
			damage_option.text = "Permitir dano entre jogadores"
			damage_option.button_pressed = true
			pages.development.add_child(damage_option)
			button(pages.development, "Criar partida de teste", func(): host_requested.emit(int(port.value), damage_option.button_pressed))
			button(pages.development, "Entrar na partida de teste", func(): join_requested.emit(address.text.strip_edges(), int(port.value)))

func _create_dialog() -> void:
	dialog = Control.new()
	dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dialog)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.08, 0.055, 0.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog.add_child(shade)
	dialog_panel = PanelContainer.new()
	dialog_panel.add_theme_stylebox_override("panel", IslandTheme.panel())
	dialog.add_child(dialog_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	dialog_panel.add_child(content)
	dialog_title = Label.new()
	dialog_title.add_theme_font_override("font", IslandTheme.TITLE)
	content.add_child(dialog_title)
	world_name = LineEdit.new()
	world_name.max_length = 40
	world_name.placeholder_text = "Nome do mundo"
	world_name.text_submitted.connect(func(_value): confirm_name())
	content.add_child(world_name)
	dialog_status = Label.new()
	dialog_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(dialog_status)
	var actions := HBoxContainer.new()
	content.add_child(actions)
	button(actions, "Confirmar", confirm_name)
	button(actions, "Cancelar", close_name)
	dialog.hide()

func open_page(id: String) -> void:
	if worlds_busy or dialog_mode != "": return
	if id == "development" and not OS.is_debug_build(): return
	if id == "advanced" and OS.has_feature("web"): return
	MobileInput.reset()
	page = id
	main.visible = id == "main"
	page_panel.visible = id != "main"
	for key in pages: pages[key].visible = key == id
	page_title.text = {"main":"", "worlds":"Meus mundos", "servers":"Multiplayer", "advanced":"Conexão avançada", "options":"Menu", "development":"Desenvolvimento"}.get(id, "")
	resize()

func resize() -> void:
	var view := get_viewport_rect().size
	var unit := MobileInput.touch_minimum() if MobileInput.enabled else 48.0
	var font := int(maxf(18, ceilf(15 / MobileInput.css_scale()))) if MobileInput.enabled else 20
	for control in find_children("*", "Control", true, false):
		if control is Button or control is LineEdit or control is SpinBox:
			control.custom_minimum_size.y = unit
			control.add_theme_font_size_override("font_size", font)
		if control is Label and control not in [brand, page_title, dialog_title]: control.add_theme_font_size_override("font_size", font - 2)
	brand.position = Vector2(32, 26)
	brand.add_theme_font_size_override("font_size", int(clampf(view.y * 0.105, 36, 58)))
	release_note.position = Vector2(32, 26 + brand.get_minimum_size().y)
	main_rows.custom_minimum_size.x = clampf(view.x * 0.3, 280, 360)
	main_rows.size = Vector2(main_rows.custom_minimum_size.x, main_rows.get_combined_minimum_size().y)
	main_rows.position = Vector2(view.x - main_rows.size.x - 36, clampf((view.y - main_rows.size.y) / 2, 84, maxf(84, view.y - main_rows.size.y - 16)))
	var menu_button: Button = main.get_node("MenuButton")
	menu_button.size = Vector2(unit * 1.5, unit)
	menu_button.position = Vector2(view.x - menu_button.size.x - 24, 20)
	page_panel.position = Vector2(maxf(24, (view.x - 780) / 2), 20)
	page_panel.size = Vector2(minf(780, view.x - 48), view.y - 68)
	dialog_panel.position = (view - Vector2(minf(520, view.x - 48), unit * 4.6)) / 2
	dialog_panel.size = Vector2(minf(520, view.x - 48), unit * 4.6)
	status.position = Vector2(32, view.y - 40)
	status.size = Vector2(view.x * 0.56 - 32 if page == "main" else view.x - 64, 32)

func last_world_id() -> String:
	if library == null: return ""
	var latest := -1.0
	var id := ""
	for world in library.data.worlds:
		var access := float(world.get("last_access", 0))
		if (access > 0 or world.id == "first-world") and access > latest:
			latest = access
			id = world.id
	return id

func continue_world() -> void:
	if worlds_busy: return
	if library == null:
		solo_requested.emit()
		return
	var last := last_world_id()
	if last.is_empty(): open_name("create")
	else:
		selected_world = last
		solo_requested.emit()

func set_library(source: WorldLibrary, selected: String = "") -> void:
	library = source
	selected_world = selected
	var exists := false
	for world in library.data.worlds:
		if world.id == selected_world: exists = true
	if not exists: selected_world = library.data.worlds[0].id if not library.data.worlds.is_empty() else ""
	refresh_library()

func last_access(value: float) -> String:
	if value <= 0: return "Última partida: ainda não jogado"
	if OS.has_feature("web"):
		return "Última partida: " + str(JavaScriptBridge.eval("window.tcLocalDate(%f)" % value))
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var date := Time.get_datetime_dict_from_unix_time(int(value) + bias)
	var now := Time.get_datetime_dict_from_system()
	var yesterday := Time.get_datetime_dict_from_unix_time(int(Time.get_unix_time_from_system()) + bias - 86400)
	var prefix := "%02d/%02d/%04d" % [date.day, date.month, date.year]
	if date.year == now.year and date.month == now.month and date.day == now.day: prefix = "hoje"
	elif date.year == yesterday.year and date.month == yesterday.month and date.day == yesterday.day: prefix = "ontem"
	return "Última partida: %s, %02dh%02d" % [prefix, date.hour, date.minute]

func refresh_library() -> void:
	for list in [worlds_list, servers_list]:
		for child in list.get_children(): list.remove_child(child); child.queue_free()
	var last := last_world_id()
	primary.text = "Continuar" if library == null or not last.is_empty() else "Criar mundo"
	IslandTheme.decorate(primary, true)
	continue_caption.text = ""
	if library != null:
		for world in library.data.worlds:
			if world.id == last: continue_caption.text = world.name
			var caption: String = world.name + "\n" + last_access(float(world.last_access))
			if WorldSync.enabled(library.uid):
				var save_state: Dictionary = WorldSync.states.get(library.uid + ":" + str(world.id), {})
				if save_state.has("text"): caption += "\n" + str(save_state.text)
			var entry := button(worlds_list, caption, select_world.bind(str(world.id)))
			entry.set_meta("world_id", world.id)
			IslandTheme.decorate(entry, selected_world == world.id)
		if library.data.worlds.is_empty():
			var empty := Label.new()
			empty.text = "Sua próxima aventura começa em um novo mundo."
			worlds_list.add_child(empty)
		for server in library.data.servers:
			var caption: String = str(server.name) + "\n" + last_access(float(server.last_access)).replace("Última partida:", "Último acesso:")
			if OS.has_feature("web"):
				var entry := Label.new()
				entry.text = caption
				servers_list.add_child(entry)
			else: button(servers_list, caption, func(): join_requested.emit(server.address, int(server.port)))
	if library == null or library.data.servers.is_empty():
		var empty := Label.new()
		empty.text = "Você ainda não acessou nenhum servidor."
		servers_list.add_child(empty)
	if OS.has_feature("web"):
		var info := Label.new()
		info.text = "Multiplayer indisponível nesta beta. Jogue a campanha solo em Meus mundos. Não há data anunciada para o multiplayer."
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		servers_list.add_child(info)
	open_page(page)
	refresh_controls()
	resize()

func refresh_controls() -> void:
	play_selected.disabled = library != null and selected_world.is_empty()
	rename_selected.disabled = library == null or selected_world.is_empty()

func select_world(id: String) -> void:
	if worlds_busy: return
	selected_world = id
	refresh_library()

func open_name(mode: String) -> void:
	if worlds_busy or library == null: return
	var current_name := ""
	if mode == "rename":
		for world in library.data.worlds:
			if world.id == selected_world: current_name = world.name
		if current_name.is_empty(): show_status("Selecione um mundo para renomear."); return
	dialog_mode = mode
	dialog_title.text = "Criar mundo" if mode == "create" else "Renomear mundo"
	world_name.text = current_name
	dialog_status.text = ""
	MobileInput.reset()
	if OS.has_feature("web"):
		name_callback = JavaScriptBridge.create_callback(func(args):
			if str(args[0]) == "cancel": close_name()
			else:
				world_name.text = str(args[1])
				confirm_name())
		JavaScriptBridge.get_interface("tcWorldNameDialog").open(dialog_title.text, current_name, name_callback)
	else:
		dialog.show()
		world_name.grab_focus()
		world_name.select_all()

func close_name() -> void:
	if worlds_busy: return
	dialog_mode = ""
	dialog.hide()
	if OS.has_feature("web"): JavaScriptBridge.get_interface("tcWorldNameDialog").close()
	MobileInput.reset()

func confirm_name() -> void:
	if dialog_mode == "create": create_world()
	elif dialog_mode == "rename": rename_world()

func create_world() -> void:
	if library == null or worlds_busy: return
	set_busy(true)
	var id := await library.create_world(world_name.text, get_tree())
	if not is_inside_tree(): return
	set_busy(false)
	if id.is_empty(): name_error(library.error)
	else:
		selected_world = id
		close_name()
		open_page("worlds")
		refresh_library()
		show_status("Mundo criado. Selecione Jogar mundo para começar.")
		if WorldSync.enabled(library.uid):
			var result := await WorldSync.refresh_library(library)
			if is_inside_tree(): show_status(("Mundo salvo neste aparelho · Sincronização pendente." if result.get("pending", false) else "Mundo criado e sincronização confirmada.") if result.get("ok", false) else str(result.get("error", "Sincronização pendente.")))

func rename_world() -> void:
	if library == null or worlds_busy: return
	set_busy(true)
	var ok: bool = await library.rename_world(selected_world, world_name.text, get_tree())
	if not is_inside_tree(): return
	set_busy(false)
	if not ok: name_error(library.error)
	else:
		close_name()
		refresh_library()
		show_status("Nome do mundo salvo.")
		if WorldSync.enabled(library.uid):
			var result := await WorldSync.refresh_library(library, true)
			if is_inside_tree(): show_status(("Nome salvo neste aparelho · Sincronização pendente." if result.get("pending", false) else "Nome sincronizado.") if result.get("ok", false) else str(result.get("error", "Sincronização pendente.")))

func set_busy(value: bool) -> void:
	worlds_busy = value
	if OS.has_feature("web"): JavaScriptBridge.get_interface("tcWorldNameDialog").setBusy(value)
	for control in dialog.find_children("*", "Button", true, false): control.disabled = value

func name_error(text: String) -> void:
	dialog_status.text = text
	if OS.has_feature("web"): JavaScriptBridge.get_interface("tcWorldNameDialog").message(text)

func show_status(text: String) -> void:
	status.text = "" if text.begins_with("Teste local") or text.begins_with("Conta validada") else text

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("close_panel") and not worlds_busy:
		if dialog_mode != "": close_name()
		elif page != "main": open_page("main")
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	if OS.has_feature("web"): JavaScriptBridge.get_interface("tcWorldNameDialog").close()
