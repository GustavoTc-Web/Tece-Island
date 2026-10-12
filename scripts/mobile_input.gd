extends Node

signal mode_changed
var enabled := false
var overlay: Control
var gui_touches: Dictionary = {}
var focus_callback: JavaScriptObject

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled = DisplayServer.is_touchscreen_available()
	if OS.has_feature("web"):
		enabled = bool(JavaScriptBridge.eval("navigator.maxTouchPoints > 0"))
		focus_callback = JavaScriptBridge.create_callback(func(_args): reset())
		JavaScriptBridge.get_interface("window").tcIslandResetInputs = focus_callback
		JavaScriptBridge.eval("window.addEventListener('blur', () => window.tcIslandResetInputs()); document.addEventListener('visibilitychange', () => { if (document.hidden) window.tcIslandResetInputs(); });")
	mode_changed.connect(reset)

func set_enabled(value: bool) -> void:
	enabled = value
	mode_changed.emit()

func reset() -> void:
	gui_touches.clear()
	if is_instance_valid(overlay): overlay.reset()
	for action in ["move_left", "move_right", "move_up", "move_down", "hit", "use_tool"]:
		Input.action_release(action)

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		reset()

# Only UI touches are bridged to buttons. Joystick fingers never generate mouse input.
func _input(event: InputEvent) -> void:
	if enabled and is_instance_valid(overlay) and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if overlay.mouse_touch(event):
			get_viewport().set_input_as_handled()
			return
	if enabled and is_instance_valid(overlay) and event is InputEventMouseMotion and overlay.fingers.values().has(-100):
		var drag := InputEventScreenDrag.new()
		drag.index = -100
		drag.position = event.position
		overlay.touch(drag)
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventScreenTouch and not event is InputEventScreenDrag: return
	if event is InputEventScreenTouch:
		if event.pressed:
			var control := button_at(get_tree().root, event.position)
			if control != null:
				gui_touches[event.index] = {"control": control, "position": event.position, "dragged": false}
				if control is LineEdit and control.editable:
					control.grab_focus()
					control.edit()
			elif is_instance_valid(overlay) and enabled:
				overlay.touch(event)
		else:
			if gui_touches.has(event.index):
				var capture: Dictionary = gui_touches[event.index]
				var control: Control = capture.control
				gui_touches.erase(event.index)
				if is_instance_valid(control) and control is Button and control.is_visible_in_tree() and not control.disabled and not capture.dragged and not event.canceled and control.get_global_rect().has_point(event.position):
					if control.toggle_mode: control.button_pressed = not control.button_pressed
					control.pressed.emit()
			elif is_instance_valid(overlay): overlay.touch(event)
	else:
		if gui_touches.has(event.index):
			var capture: Dictionary = gui_touches[event.index]
			if event.position.distance_to(capture.position) > 12: capture.dragged = true
			var control: Node = capture.control
			while is_instance_valid(control):
				if control is ScrollContainer:
					control.scroll_vertical -= roundi(event.relative.y)
					break
				control = control.get_parent()
		elif is_instance_valid(overlay) and enabled:
			overlay.touch(event)
	get_viewport().set_input_as_handled()

func button_at(node: Node, point: Vector2) -> Control:
	if node is CanvasItem and not node.is_visible_in_tree(): return null
	if node is Control and node.clip_contents and not node.get_global_rect().has_point(point): return null
	var children := node.get_children()
	children.reverse()
	for child in children:
		var found := button_at(child, point)
		if found != null: return found
	if node is Button and node.get_global_rect().has_point(point): return node
	if node is LineEdit and node.get_global_rect().has_point(point): return node
	if node is ScrollContainer and node.get_global_rect().has_point(point): return node
	return null
