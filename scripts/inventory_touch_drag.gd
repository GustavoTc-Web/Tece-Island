extends Node

# Touch UI stays in the existing MobileInput bridge; it never synthesizes a
# mouse press or a gameplay action. Nothing is removed until a valid release.
const HOLD_SECONDS := 0.35
const SLOP_CSS := 10.0
var hud: CanvasLayer
var finger := -1
var phase := "idle"
var held := 0.0
var origin := Vector2.ZERO
var point := Vector2.ZERO
var source: Control
var target: Control
var scroll: ScrollContainer
var payload := {}
var preview: Control
var ignored: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	MobileInput.inventory_touch_drag = self
	get_viewport().size_changed.connect(cancel)

func available() -> bool:
	return is_instance_valid(hud) and hud.current_panel == "inventory" and hud.get_node("InventoryPanel").visible and not hud.network_mode and not GlobalChat.opened and not OrientationGuard.blocked

func handle_input(event: InputEvent) -> bool:
	if not event is InputEventScreenTouch and not event is InputEventScreenDrag: return false
	if event is InputEventScreenTouch and event.pressed:
		ignored.erase(event.index)
		# A fresh press after an OS interruption may reuse the old finger ID.
		if phase == "cancelled" and event.index == finger: finish()
		if finger >= 0:
			cancel()
			ignored[event.index] = true
			return true
		if not MobileInput.enabled or not available(): return false
		var control := MobileInput.button_at(hud.get_node("InventoryPanel"), event.position)
		if control == null or not control.has_method("inventory_drag_data"): return false
		var data: Dictionary = control.inventory_drag_data()
		if data.is_empty(): return false
		finger = event.index
		source = control
		payload = data
		origin = event.position
		point = origin
		held = 0
		phase = "pending"
		var parent := source.get_parent()
		while parent != null and not parent is ScrollContainer: parent = parent.get_parent()
		scroll = parent as ScrollContainer
		return true
	if ignored.has(event.index):
		if event is InputEventScreenTouch: ignored.erase(event.index)
		return true
	if event.index != finger or finger < 0: return false
	point = event.position
	if not available(): cancel()
	if event is InputEventScreenDrag:
		if phase == "pending" and origin.distance_to(point) * MobileInput.css_scale() > SLOP_CSS:
			phase = "scrolling"
		if phase == "scrolling" and is_instance_valid(scroll): scroll.scroll_vertical -= roundi(event.relative.y)
		elif phase == "dragging": update_preview()
	elif event is InputEventScreenTouch:
		if not event.canceled and is_instance_valid(source) and source.accepts_inventory_drag(payload):
			if phase == "dragging":
				update_preview()
				if is_instance_valid(target): target.apply_inventory_drag(payload)
			elif phase == "pending" and source.get_global_rect().has_point(point): source.pressed.emit()
		finish()
	return true

func _process(delta: float) -> void:
	if finger < 0: return
	if not available() or not is_instance_valid(source) or not source.accepts_inventory_drag(payload):
		cancel()
		return
	if phase != "pending": return
	held += delta
	if held < HOLD_SECONDS: return
	phase = "dragging"
	hud.inventory_drag_active = true
	hud.moving_slot = -1
	preview = source.inventory_drag_preview()
	preview.z_index = 100
	hud.add_child(preview)
	update_preview()

func update_preview() -> void:
	restore_target()
	if not is_instance_valid(preview): return
	var scale := MobileInput.css_scale()
	preview.position = point + Vector2(16, -68) / scale
	var view := get_viewport().get_visible_rect().size
	preview.position = preview.position.clamp(Vector2.ZERO, (view - preview.size).max(Vector2.ZERO))
	var control := MobileInput.button_at(hud.get_node("InventoryPanel"), point)
	if control != null and control.has_method("accepts_inventory_drag") and control.accepts_inventory_drag(payload):
		target = control
		target.decorate_slot(true)

func restore_target() -> void:
	if is_instance_valid(target): target.decorate_slot(target.rendered_active)
	target = null

func cancel() -> void:
	restore_target()
	if is_instance_valid(preview): preview.queue_free()
	preview = null
	if is_instance_valid(hud): hud.inventory_drag_active = false
	if finger >= 0: phase = "cancelled"

func finish() -> void:
	cancel()
	finger = -1
	phase = "idle"
	source = null
	scroll = null
	payload = {}

func _exit_tree() -> void:
	finish()
	if MobileInput.inventory_touch_drag == self: MobileInput.inventory_touch_drag = null
