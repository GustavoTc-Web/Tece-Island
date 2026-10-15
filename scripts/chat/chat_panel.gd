extends CanvasLayer

var launcher: Button
var panel: PanelContainer
var rows: VBoxContainer
var list: VBoxContainer
var scroll: ScrollContainer
var status: Label
var alias_row: HBoxContainer
var alias_field: LineEdit
var alias_button: Button
var composer: HBoxContainer
var input: LineEdit
var send: Button
var unmute: Button
var rendered_messages := ""
var clear_version := -1

func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	launcher = button("Chat", self, GlobalChat.toggle)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", IslandTheme.panel())
	add_child(panel)
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	panel.add_child(rows)
	var header := HBoxContainer.new()
	rows.add_child(header)
	var title := Label.new()
	title.text = "Chat global · piloto"
	title.add_theme_font_override("font", IslandTheme.TITLE)
	title.add_theme_color_override("font_color", IslandTheme.AMBER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	button("Recolher", header, GlobalChat.toggle)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(status)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rows.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	alias_row = HBoxContainer.new()
	rows.add_child(alias_row)
	alias_field = LineEdit.new()
	alias_field.placeholder_text = "Apelido (2 a 20 caracteres)"
	alias_field.max_length = 20
	alias_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	alias_row.add_child(alias_field)
	alias_button = button("Definir", alias_row, func(): GlobalChat.save_nickname(alias_field.text))
	alias_field.text_submitted.connect(GlobalChat.save_nickname)
	composer = HBoxContainer.new()
	rows.add_child(composer)
	input = LineEdit.new()
	input.placeholder_text = "Mensagem (até 200 caracteres)"
	input.max_length = 200
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	composer.add_child(input)
	send = button("Enviar", composer, func(): GlobalChat.send_text(input.text))
	input.text_submitted.connect(GlobalChat.send_text)
	var actions := HBoxContainer.new()
	rows.add_child(actions)
	unmute = button("Reativar silenciados", actions, func(): GlobalChat.muted.clear(); GlobalChat.persist_mutes())
	button("Tentar conexão", actions, func(): GlobalChat._web_action(["retry"]))
	GlobalChat.changed.connect(render)
	get_viewport().size_changed.connect(layout)
	layout()
	render()

func button(text: String, parent: Node, callback: Callable) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size.y = 44
	result.focus_mode = Control.FOCUS_NONE
	IslandTheme.decorate(result)
	result.pressed.connect(callback)
	parent.add_child(result)
	return result

func layout() -> void:
	var size := get_viewport().get_visible_rect().size
	launcher.position = Vector2(size.x / 2 - 48, 10)
	launcher.size = Vector2(96, 44)
	panel.position = Vector2(maxf(12, size.x - 556), 12)
	panel.size = Vector2(minf(544, size.x - 24), size.y - 24)

func render() -> void:
	if panel == null: return
	var state := GlobalChat.view_state()
	launcher.visible = state.available and not state.opened
	panel.visible = state.available and state.opened
	status.text = state.status
	alias_row.visible = state.nickname == ""
	alias_button.disabled = state.busy or not state.ready
	composer.visible = state.nickname != ""
	input.editable = not state.busy
	send.disabled = state.busy or not state.ready or state.remaining > 0
	send.text = "Enviando…" if state.busy else ("%d s" % state.remaining if state.remaining > 0 else "Enviar")
	unmute.visible = state.muted > 0
	if clear_version != state.clear_draft:
		input.clear()
		alias_field.clear()
		clear_version = state.clear_draft
	var signature := JSON.stringify(state.messages) + str(state.admin)
	if signature == rendered_messages: return
	rendered_messages = signature
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	for message in state.messages:
		var box := VBoxContainer.new()
		list.add_child(box)
		var label := Label.new()
		label.text = str(message.nickname) + " · " + local_time(str(message.sent_at))
		label.add_theme_color_override("font_color", IslandTheme.AMBER)
		box.add_child(label)
		var text := Label.new()
		text.text = str(message.text)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(text)
		var controls := HBoxContainer.new()
		box.add_child(controls)
		if message.uid != GlobalChat.uid: button("Silenciar", controls, GlobalChat.mute.bind(str(message.uid)))
		if state.admin: button("Remover", controls, GlobalChat.remove_message.bind(str(message.id)))
	layout()
	await get_tree().process_frame
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)

static func local_time(value: String) -> String:
	var seconds := Time.get_unix_time_from_datetime_string(value.left(19)) + int(Time.get_time_zone_from_system().bias) * 60
	var time := Time.get_datetime_dict_from_unix_time(seconds)
	return "%02d:%02d" % [time.hour, time.minute]
