extends HarvestResource


func _draw() -> void:
	draw_set_transform(Vector2(5, 0), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 34.0, Color(0.07, 0.15, 0.1, 0.25))
	draw_set_transform(Vector2.ZERO)
	draw_line(Vector2(0, -5), Vector2(0, -48), Color("67482f"), 19.0)
	draw_line(Vector2(3, -8), Vector2(3, -43), Color("927044"), 5.0)
	draw_circle(Vector2(0, -62), 38.0, Color("254e3b"))
	draw_circle(Vector2(-20, -56), 25.0, Color("326346"))
	draw_circle(Vector2(18, -62), 27.0, Color("3a704c"))
	draw_circle(Vector2(-4, -80), 26.0, Color("477e53"))
	draw_arc(Vector2(-4, -80), 18.0, 3.5, 5.6, 12, Color("60915d"), 3.0)
	draw_feedback()
