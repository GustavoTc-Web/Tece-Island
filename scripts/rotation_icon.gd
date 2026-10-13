extends Control
func _ready() -> void:
	custom_minimum_size = Vector2(100, 100)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	var center := size / 2
	draw_set_transform(center, -PI / 6)
	draw_rect(Rect2(-16, -30, 32, 60), Color("dccb93"), false, 4)
	draw_line(Vector2(-8, 21), Vector2(8, 21), Color("dccb93"), 3)
	draw_set_transform(center)
	draw_arc(Vector2.ZERO, 43, -PI * 0.85, -PI * 0.12, 24, Color("b7d6b2"), 3)
	draw_colored_polygon(PackedVector2Array([Vector2(42, -12), Vector2(32, -19), Vector2(39, -27)]), Color("b7d6b2"))
