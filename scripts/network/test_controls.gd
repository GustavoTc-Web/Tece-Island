extends Node

var arena: Node2D
var mouse_held := false
var key_held := false
var cursor := Vector2.ZERO
var focused := true
var send_clock: float = 0
var input_sequence := 0

func clear_held() -> void:
	mouse_held = false
	key_held = false
	send_input()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		focused = false
		if is_instance_valid(arena): clear_held()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		focused = true

func _physics_process(delta: float) -> void:
	send_clock -= delta
	if send_clock <= 0:
		send_clock = 0.05
		send_input()

func send_input() -> void:
	if not is_instance_valid(arena) or not arena.actors.has(arena.local_id()): return
	var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down") if focused and not arena.local_blocked() else Vector2.ZERO
	var aim := aim_direction()
	input_sequence += 1
	arena.submit_input(input_sequence, movement, aim, mouse_held, key_held)

func aim_direction() -> Vector2:
	if not arena.actors.has(arena.local_id()): return Vector2.RIGHT
	var body: CharacterBody2D = arena.actors[arena.local_id()].body
	return (body.get_canvas_transform().affine_inverse() * cursor - body.global_position).normalized()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton: cursor = event.position
	if event.is_action_released("hit"):
		mouse_held = false
		send_input()
	if event.is_action_released("use_tool"):
		key_held = false
		send_input()
	if arena.local_blocked() or event.is_echo(): return

func _unhandled_input(event: InputEvent) -> void:
	if arena.local_blocked() or event.is_echo(): return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit: return
	for index in range(5):
		if event.is_action_pressed("equip_" + str(index + 1)):
			clear_held()
			arena.request_action("select", index)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var inv: ResourceInventory = arena.actors[arena.local_id()].inventory
		arena.request_action("select", posmod(inv.selected_index + (-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1), 5))
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_Q:
		var inv: ResourceInventory = arena.actors[arena.local_id()].inventory
		arena.request_action("discard", {"index": inv.selected_index, "whole": event.shift_pressed})
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("hit"):
		if _consume_selected():
			get_viewport().set_input_as_handled()
			return
		mouse_held = true
		arena.request_action("fire_mouse", aim_direction())
	elif event.is_action_pressed("use_tool"):
		if _consume_selected():
			get_viewport().set_input_as_handled()
			return
		key_held = true
		arena.request_action("fire_front")
	elif event.is_action_pressed("reload"):
		arena.request_action("reload")
	elif event.is_action_pressed("collect"):
		arena.request_action("collect")
	else: return
	send_input()
	get_viewport().set_input_as_handled()

func _consume_selected() -> bool:
	var inv: ResourceInventory = arena.actors[arena.local_id()].inventory
	if not ItemCatalog.is_consumable(inv.selected_data().get("item", "")): return false
	arena.request_action("use", inv.selected_index)
	return true
