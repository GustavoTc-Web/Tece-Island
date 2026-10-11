extends HarvestResource

func _draw() -> void:
	for offset in [Vector2(-10, -8), Vector2(10, -10), Vector2(0, -18)]:
		draw_circle(offset, 13, Color("385b37"))
		draw_line(offset, offset + Vector2(4, -6), Color("97ad65"), 3)
	draw_feedback()
