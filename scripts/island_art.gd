class_name IslandArt
extends RefCounted

static func tree(canvas: CanvasItem, point: Vector2 = Vector2.ZERO, factor: float = 1.0) -> void:
	canvas.draw_set_transform(point + Vector2(5, 0) * factor, 0, Vector2(factor, factor * 0.45))
	canvas.draw_circle(Vector2.ZERO, 34, Color(0.07, 0.15, 0.1, 0.25))
	canvas.draw_set_transform(point, 0, Vector2.ONE * factor)
	canvas.draw_line(Vector2(0, -5), Vector2(0, -48), Color("67482f"), 19)
	canvas.draw_line(Vector2(3, -8), Vector2(3, -43), Color("927044"), 5)
	canvas.draw_circle(Vector2(0, -62), 38, Color("254e3b"))
	canvas.draw_circle(Vector2(-20, -56), 25, Color("326346"))
	canvas.draw_circle(Vector2(18, -62), 27, Color("3a704c"))
	canvas.draw_circle(Vector2(-4, -80), 26, Color("477e53"))
	canvas.draw_arc(Vector2(-4, -80), 18, 3.5, 5.6, 12, Color("60915d"), 3)
	canvas.draw_set_transform(Vector2.ZERO)

static func fire(canvas: CanvasItem, time: float = 0.0, point: Vector2 = Vector2.ZERO, factor: float = 1.0) -> void:
	canvas.draw_set_transform(point, 0, Vector2.ONE * factor)
	for i in range(8): canvas.draw_circle(Vector2.from_angle(i * TAU / 8) * 18, 6, Color("939d91"))
	canvas.draw_line(Vector2(-12, 8), Vector2(12, -8), Color("735038"), 6)
	var height := 24 + sin(time * 9) * 4
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-12, 4), Vector2(0, -height), Vector2(12, 4)]), Color("eb923b"))
	canvas.draw_circle(Vector2(0, -5), 6, Color("ffe697"))
	canvas.draw_set_transform(Vector2.ZERO)
