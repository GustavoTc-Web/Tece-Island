class_name HudSymbol
extends Control
var kind := "health"
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(18, 18)
func _draw() -> void:
	var s := size / 18
	draw_set_transform(Vector2.ZERO, 0, s)
	match kind:
		"health":
			draw_rect(Rect2(6, 1, 6, 16), Color("e8a58f"))
			draw_rect(Rect2(1, 6, 16, 6), Color("e8a58f"))
		"food":
			draw_line(Vector2(4, 17), Vector2(14, 2), Color("d8bf77"), 2)
			for i in range(3):
				draw_line(Vector2(7+i*2, 12-i*3), Vector2(2+i*2, 9-i*3), Color("d8bf77"), 3)
				draw_line(Vector2(8+i*2, 11-i*3), Vector2(13+i*2, 12-i*3), Color("d8bf77"), 3)
		"water": draw_colored_polygon(PackedVector2Array([Vector2(9,1),Vector2(16,12),Vector2(14,17),Vector2(4,17),Vector2(2,12)]),Color("83b9ce"))
		"goal":
			draw_circle(Vector2(9,9),7,Color("cdbf87"))
			draw_circle(Vector2(9,9),4,Color("345341"))
