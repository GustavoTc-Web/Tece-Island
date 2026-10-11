extends Node2D

const SIZE := Vector2(1280, 900)
const WALLS := [Rect2(0, 0, 1280, 24), Rect2(0, 876, 1280, 24), Rect2(0, 0, 24, 900), Rect2(1256, 0, 24, 900), Rect2(610, 300, 16, 190), Rect2(850, 300, 16, 190), Rect2(610, 300, 256, 16), Rect2(610, 474, 85, 16), Rect2(785, 474, 81, 16), Rect2(300, 530, 70, 55), Rect2(1070, 330, 70, 60)]

func _ready() -> void:
	for rect in WALLS:
		var body := StaticBody2D.new()
		body.position = rect.get_center()
		body.collision_layer = 1
		body.collision_mask = 6
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		collision.shape = shape
		body.add_child(collision)
		add_child(body)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color("567c46"))
	draw_rect(Rect2(626, 316, 224, 158), Color("8b805b"))
	for rect in WALLS: draw_rect(rect, Color("687b7d"))
	for point in [Vector2(140, 160), Vector2(340, 160)]:
		draw_circle(point, 90, Color(0.65, 0.77, 0.42, 0.18))
		draw_arc(point, 90, 0, TAU, 40, Color("95aa68"), 2)
	draw_string(ThemeDB.fallback_font, Vector2(635, 280), "Casa · paredes bloqueiam tiros", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("f3e7ba"))
