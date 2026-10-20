class_name WorldScenery
extends RefCounted

# Shared draw-only ground. Simulation and campaign remain in world.gd.
static func draw_ground(canvas: Node2D) -> void:
	canvas.draw_rect(WorldTerrain.BOUNDS.grow(1000), Color("182b29"))
	canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(6912, 1536)), Color("567c46"))
	var random := RandomNumberGenerator.new()
	random.seed = 71
	for i in range(1800):
		var point := Vector2(random.randf_range(32, 2272), random.randf_range(32, 1504))
		var shade := Color("628750") if i % 2 == 0 else Color("4b713f")
		canvas.draw_line(point, point + Vector2(-2, -5), shade, 1.0)
		canvas.draw_line(point + Vector2(2, 0), point + Vector2(4, -4), shade, 1.0)
	var trail := Color("7e8b55")
	canvas.draw_line(Vector2(32, 768), Vector2(2272, 768), trail, 104.0)
	canvas.draw_line(Vector2(1152, 32), Vector2(1152, 1504), trail, 104.0)
	canvas.draw_circle(Vector2(1152, 768), 155.0, trail)
	canvas.draw_arc(Vector2(1152, 768), 140.0, 0.0, TAU, 64, Color("89955d"), 2.0)
