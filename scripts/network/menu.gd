extends Control

signal solo_requested
signal host_requested(port: int, friendly_fire: bool)
signal join_requested(address: String, port: int)

@export var default_port: int = 7000
var address: LineEdit
var port: SpinBox
var damage_option: CheckBox
var status: Label

func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("263c35")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var rows := VBoxContainer.new()
	rows.custom_minimum_size.x = 430
	rows.add_theme_constant_override("separation", 12)
	center.add_child(rows)
	var title := Label.new()
	title.text = "TC Island" if OS.has_feature("web") else "TC Island · primeiro teste multiplayer"
	title.add_theme_font_size_override("font_size", 23)
	rows.add_child(title)
	button(rows, "Jogar solo", func(): solo_requested.emit())
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
		rows.get_child(1).grab_focus()
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
	rows.get_child(1).grab_focus()

func button(parent: Node, text: String, callback: Callable) -> void:
	var control := Button.new()
	control.text = text
	control.custom_minimum_size.y = 48
	control.focus_mode = Control.FOCUS_ALL
	control.pressed.connect(callback)
	parent.add_child(control)

func show_status(text: String) -> void:
	status.text = "Modo solo · jogue na horizontal em dispositivos de toque" if OS.has_feature("web") and text.begins_with("Teste local") else text
