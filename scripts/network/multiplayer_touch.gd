extends Control

var arena: Node2D
var fingers := {"move": -1}
var center := Vector2.ZERO
var vector := Vector2.ZERO
var radius := 65.0
var collect: Button
var inventory_button: Button
var use_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	MobileInput.overlay = self
	collect = Button.new()
	collect.text = "Coletar"
	collect.focus_mode = Control.FOCUS_NONE
	IslandTheme.decorate(collect)
	collect.pressed.connect(arena.interact)
	add_child(collect)
	inventory_button = Button.new()
	inventory_button.text = "Inventário"
	inventory_button.icon = preload("res://assets/ui/inventory.svg")
	inventory_button.expand_icon = true
	inventory_button.focus_mode = Control.FOCUS_NONE
	IslandTheme.decorate(inventory_button)
	inventory_button.pressed.connect(func(): arena.hud.set_panel("inventory"))
	add_child(inventory_button)
	use_button = Button.new()
	use_button.text = "Beber"
	use_button.focus_mode = Control.FOCUS_NONE
	IslandTheme.decorate(use_button)
	use_button.pressed.connect(func(): arena.request_action("use", arena.projected_inventory.selected_index))
	add_child(use_button)
	MobileInput.mode_changed.connect(layout)
	get_viewport().size_changed.connect(layout)
	layout()

func layout() -> void:
	visible = MobileInput.enabled and arena.online
	var unit := MobileInput.touch_minimum()
	radius = maxf(62, unit * 0.85)
	center = Vector2(radius + 24, get_viewport_rect().size.y - radius - 24)
	collect.size = Vector2(unit * 2.4, unit * 1.2)
	collect.position = Vector2(get_viewport_rect().size.x - collect.size.x - 24, center.y - collect.size.y / 2)
	collect.add_theme_font_size_override("font_size", int(maxf(20, ceilf(15 / MobileInput.css_scale()))))
	for item in [inventory_button, use_button]:
		item.size = collect.size
		item.add_theme_font_size_override("font_size", int(ceilf(15 / MobileInput.css_scale())))
		item.add_theme_constant_override("icon_max_width", int(ceilf(20 / MobileInput.css_scale())))
	inventory_button.position = collect.position - Vector2(0, collect.size.y + 12)
	use_button.position = inventory_button.position - Vector2(0, collect.size.y + 12)
	reset()

func _process(_delta: float) -> void:
	use_button.visible = arena.projected_inventory.selected_data().get("item", "") == "cantil"

func reset() -> void:
	fingers.move = -1
	vector = Vector2.ZERO
	if is_instance_valid(arena): arena.touch_vector = Vector2.ZERO
	queue_redraw()

func touch(event: InputEvent) -> void:
	if not visible or arena.blocked():
		reset()
		return
	if event is InputEventScreenTouch:
		if event.pressed and event.position.distance_to(center) < radius * 1.4 and fingers.move == -1:
			fingers.move = event.index
		elif not event.pressed and event.index == fingers.move: reset(); return
	if event.index == fingers.move:
		vector = ((event.position - center) / radius).limit_length(1)
		arena.touch_vector = vector if vector.length() > 0.15 else Vector2.ZERO
		queue_redraw()

func mouse_touch(event: InputEventMouseButton) -> bool:
	if not visible or arena.blocked(): return false
	if event.pressed and event.position.distance_to(center) >= radius * 1.4: return false
	if not event.pressed and fingers.move != -100: return false
	var translated := InputEventScreenTouch.new()
	translated.index = -100
	translated.position = event.position
	translated.pressed = event.pressed
	touch(translated)
	return true

func _draw() -> void:
	draw_circle(center, radius, Color(0.04, 0.12, 0.09, 0.65))
	draw_arc(center, radius, 0, TAU, 48, Color("b8c5a1"), 3)
	draw_circle(center + vector * radius * 0.7, radius * 0.34, Color("d9a441"))
