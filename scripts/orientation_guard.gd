extends Node

signal blocked_changed(value: bool)
var authenticated := false
var blocked := false
var layer: CanvasLayer
var notice: Control
var message: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	notice = ColorRect.new()
	notice.color = Color("142b24")
	notice.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(notice)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	notice.add_child(center)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 20)
	center.add_child(rows)
	message = Label.new()
	message.text = "↻\nGire o celular para jogar.\nUse a posição horizontal para visualizar melhor o mundo e os controles."
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.custom_minimum_size.x = 340
	message.add_theme_font_size_override("font_size", 24)
	rows.add_child(message)
	var fullscreen := Button.new()
	fullscreen.text = "Tela cheia e girar"
	fullscreen.custom_minimum_size.y = 64
	fullscreen.pressed.connect(request_landscape)
	rows.add_child(fullscreen)
	notice.hide()

func mobile() -> bool:
	return bool(JavaScriptBridge.eval("navigator.maxTouchPoints > 0")) if OS.has_feature("web") else OS.has_feature("mobile")

func set_authenticated(value: bool) -> void:
	authenticated = value
	refresh()

func _process(_delta: float) -> void:
	refresh()

func refresh() -> void:
	var size := Vector2(DisplayServer.window_get_size())
	if OS.has_feature("web"):
		size = Vector2(float(JavaScriptBridge.eval("innerWidth")), float(JavaScriptBridge.eval("innerHeight")))
	var next := authenticated and mobile() and size.y > size.x
	if next != blocked:
		blocked = next
		MobileInput.reset()
		blocked_changed.emit(blocked)
	notice.visible = blocked
	message.custom_minimum_size.x = minf(500, get_viewport().get_visible_rect().size.x - 48)

func _input(event: InputEvent) -> void:
	if blocked and not (event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouse):
		get_viewport().set_input_as_handled()

func request_landscape() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.tcRequestLandscape && window.tcRequestLandscape()")
	else:
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
