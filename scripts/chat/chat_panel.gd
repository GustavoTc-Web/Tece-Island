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
var alias_cancel: Button
var profile: Label
var edit_alias: Button
var retry: Button
var unread_button: Button
var unread := 0
var last_sequence := 0
var was_editing := false
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
	var profile_row := HBoxContainer.new()
	rows.add_child(profile_row)
	profile = Label.new()
	profile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	profile_row.add_child(profile)
	edit_alias = button("Alterar apelido", profile_row, GlobalChat.edit_nickname)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rows.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	unread_button = button("Novas mensagens · Ver", rows, func(): scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value); unread = 0; unread_button.hide())
	unread_button.hide()
	scroll.get_v_scroll_bar().value_changed.connect(func(_v):
		if at_bottom(): unread = 0; unread_button.hide())
	alias_row = HBoxContainer.new()
	rows.add_child(alias_row)
	alias_field = LineEdit.new()
	alias_field.placeholder_text = "Apelido (2 a 20 caracteres)"
	alias_field.max_length = 20
	alias_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	alias_row.add_child(alias_field)
	alias_button = button("Salvar", alias_row, func(): GlobalChat.save_nickname(alias_field.text))
	alias_cancel = button("Cancelar", alias_row, GlobalChat.cancel_nickname)
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
	retry = button("Tentar conexão", actions, func(): GlobalChat._web_action(["retry"]))
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

func at_bottom() -> bool:
	var bar := scroll.get_v_scroll_bar()
	return bar.max_value - bar.page - bar.value < 60

func render() -> void:
	if panel == null: return
	var state := GlobalChat.view_state()
	launcher.visible = state.available and not state.opened
	panel.visible = state.available and state.opened
	status.text = state.status + "\n" + (state.connection_error if state.connection_error != "" else ("Conectado · atualizado às " + state.last_sync if state.last_sync != "" else "Aguardando conexão"))
	profile.text = "Apelido atual: " + state.nickname
	edit_alias.visible = state.nickname != "" and not state.editing_nickname
	edit_alias.disabled = state.busy
	alias_row.visible = state.nickname == "" or state.editing_nickname
	alias_cancel.visible = state.nickname != ""
	alias_cancel.disabled = state.busy
	if state.editing_nickname and not was_editing:
		alias_field.text = state.nickname
		alias_field.grab_focus()
		alias_field.select_all()
	was_editing = state.editing_nickname
	alias_button.disabled = state.busy or not state.ready
	composer.visible = state.nickname != "" and not state.editing_nickname
	input.editable = not state.busy
	send.disabled = state.busy or not state.ready or state.remaining > 0
	send.text = "Enviando…" if state.busy else ("%d s" % state.remaining if state.remaining > 0 else "Enviar")
	unmute.visible = state.muted > 0
	retry.visible = state.connection_error != ""
	retry.disabled = state.busy or state.retry_seconds > 0
	if clear_version != state.clear_draft:
		input.clear()
		if state.uid == "":
			alias_field.clear()
			last_sequence = 0
			unread = 0
			unread_button.hide()
		clear_version = state.clear_draft
	var signature := JSON.stringify(state.messages) + str(state.admin)
	if signature == rendered_messages: return
	rendered_messages = signature
	var bottom := at_bottom()
	var old_scroll := scroll.scroll_vertical
	var anchor := -1
	var offset := 0.0
	for child in list.get_children():
		if child.position.y + child.size.y > old_scroll:
			anchor = int(child.get_meta("sequence", -1))
			offset = child.position.y - old_scroll
			break
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	for message in state.messages:
		var box := VBoxContainer.new()
		box.set_meta("sequence", message.sequence)
		if int(message.sequence) > last_sequence and not bottom: unread += 1
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
	for message in state.messages: last_sequence = maxi(last_sequence, int(message.sequence))
	unread_button.visible = not bottom and unread > 0
	unread_button.text = "%d novas mensagens · Ver" % unread
	await get_tree().process_frame
	if bottom:
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
		unread = 0
	else:
		scroll.scroll_vertical = old_scroll
		for child in list.get_children():
			if int(child.get_meta("sequence", -1)) == anchor:
				scroll.scroll_vertical = int(child.position.y - offset)
				break

static func local_time(value: String) -> String:
	var seconds := Time.get_unix_time_from_datetime_string(value.left(19)) + int(Time.get_time_zone_from_system().bias) * 60
	var time := Time.get_datetime_dict_from_unix_time(seconds)
	return "%02d:%02d" % [time.hour, time.minute]
