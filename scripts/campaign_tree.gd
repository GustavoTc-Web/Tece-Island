extends "res://scripts/tree.gd"
var burned := false
func _draw() -> void:
	if exhausted: return
	draw_line(Vector2.ZERO, Vector2(0, -55), Color("373839") if burned else Color("655c49"), 9)
	if burned:
		for side in [-1, 1]:
			draw_polyline(PackedVector2Array([Vector2(0, -25), Vector2(side * 18, -42), Vector2(side * 22, -54)]), Color("333637"), 6)
	else:
		for y in [-27, -43, -59]:
			draw_colored_polygon(PackedVector2Array([Vector2(-25, y + 18), Vector2(0, y - 18), Vector2(25, y + 18)]), Color("33584e"))
	if highlighted: draw_arc(Vector2.ZERO, 24, 0, TAU, 24, Color("f2d786"), 2)
