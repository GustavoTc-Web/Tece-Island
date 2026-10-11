extends HarvestResource


func _draw() -> void:
	draw_set_transform(Vector2(3, 2), 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 27.0, Color(0.07, 0.15, 0.1, 0.25))
	draw_set_transform(Vector2.ZERO)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-25, -3), Vector2(-22, -25), Vector2(-7, -36),
		Vector2(15, -32), Vector2(25, -17), Vector2(22, 2), Vector2(-9, 6)
	]), Color("687b7d"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-22, -25), Vector2(-7, -36), Vector2(15, -32),
		Vector2(10, -17), Vector2(-9, -13)
	]), Color("98a7a2"))
	draw_line(Vector2(10, -17), Vector2(22, 2), Color("4e6568"), 2.0)
	draw_feedback()
