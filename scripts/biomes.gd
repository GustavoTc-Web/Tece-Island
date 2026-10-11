extends Node2D

const FOREST_END := 2304.0
const SWAMP_END := 3840.0
const MAP_END := 6912.0
const CACTI := [Vector2(5500, 260), Vector2(5900, 620), Vector2(6000, 1320), Vector2(6410, 920), Vector2(6730, 1250), Vector2(6770, 550)]

func initialize(world: Node2D) -> void:
	for point in CACTI: obstacle(Rect2(point - Vector2(12, 10), Vector2(24, 20)))
	for point in [Vector2(5840, 210), Vector2(5980, 990), Vector2(6550, 1320)]:
		world.add_obstacle(world.ROCK, point)
	for point in [Vector2(1310, 768), Vector2(3000, 768), Vector2(4520, 768), Vector2(6030, 768)]:
		var well := WaterWell.new()
		well.position = point
		well.hud = world.get_node("HUD")
		well.player = world.get_node("WorldObjects/Player")
		world.get_node("WorldObjects").add_child(well)
	for point in [Vector2(2470, 230), Vector2(2600, 1050), Vector2(3150, 260), Vector2(3500, 1220), Vector2(3700, 330), Vector2(3540, 500)]:
		world.add_obstacle(world.TREE, point)
		var tree: Node2D = world.get_node("WorldObjects").get_child(-1)
		tree.modulate = Color(0.7, 0.85, 0.8)
	for point in [Vector2(2510, 700), Vector2(3380, 840), Vector2(3960, 700), Vector2(4420, 880), Vector2(5000, 690)]:
		world.add_obstacle(world.BUSH, point)
	for point in [Vector2(3060, 1400), Vector2(3670, 1100), Vector2(4020, 230), Vector2(4500, 1350), Vector2(5180, 1020)]:
		world.add_obstacle(world.ROCK, point)
	# Poças e cercas têm colisões, deixando o corredor horizontal e os acessos livres.
	for rect in [Rect2(2450, 400, 130, 85), Rect2(3390, 250, 180, 100), Rect2(2770, 1250, 170, 90), Rect2(3500, 940, 160, 70)]:
		obstacle(rect)
	for rect in [Rect2(3970, 1040, 12, 160), Rect2(4440, 240, 180, 12), Rect2(5050, 1150, 150, 12)]:
		obstacle(rect)

func obstacle(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	body.collision_layer = 1
	body.collision_mask = 6
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func _draw() -> void:
	draw_rect(Rect2(2304, 0, 1536, 1536), Color("40574b"))
	draw_rect(Rect2(3840, 0, 1536, 1536), Color("ad9b5c"))
	draw_rect(Rect2(5376, 0, 1536, 1536), Color("dec487"))
	for point in CACTI:
		draw_line(point, point - Vector2(0, 50), Color("698353"), 12)
		draw_polyline(PackedVector2Array([point - Vector2(0, 25), point - Vector2(22, 25), point - Vector2(22, 40)]), Color("698353"), 8)
		draw_polyline(PackedVector2Array([point - Vector2(0, 15), point + Vector2(20, -15), point + Vector2(20, -30)]), Color("698353"), 8)
	for i in range(200):
		var point := Vector2(5400 + posmod(i * 179, 1470), 40 + posmod(i * 137, 1440))
		draw_line(point, point + Vector2(8, -3), Color("c5a66f"), 2)
	draw_line(Vector2(5376, 768), Vector2(6880, 768), Color("cbb27f"), 104)
	for point in [Vector2(5680, 440), Vector2(6200, 1120), Vector2(6580, 400)]:
		var entrance: Vector2 = point + Vector2(0, 110)
		var corner: Vector2 = entrance + Vector2(180, 0)
		draw_polyline(PackedVector2Array([entrance, corner, Vector2(corner.x, 768)]), Color("cbb27f"), 64)
	draw_string(ThemeDB.fallback_font, Vector2(5450, 80), "Deserto", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("785733"))
	var random := RandomNumberGenerator.new()
	random.seed = 203
	for i in range(1200):
		var point := Vector2(random.randf_range(2340, 5340), random.randf_range(40, 1490))
		draw_line(point, point + Vector2(3, -6), Color("597663") if point.x < 3840 else Color("c5b777"), 2)
	for rect in [Rect2(2450, 400, 130, 85), Rect2(3390, 250, 180, 100), Rect2(2770, 1250, 170, 90), Rect2(3500, 940, 160, 70)]:
		draw_rect(rect, Color("2d4548"))
		draw_line(rect.position + Vector2(12, 15), rect.position + Vector2(rect.size.x - 12, 15), Color("62817a"), 3)
	for rect in [Rect2(3970, 1040, 12, 160), Rect2(4440, 240, 180, 12), Rect2(5050, 1150, 150, 12)]:
		draw_rect(rect, Color("6d593c"))
	draw_line(Vector2(2304, 768), Vector2(5344, 768), Color("8b9366"), 104)
	# Cada construção tem um acesso até o caminho principal.
	for point in [Vector2(2800, 460), Vector2(3250, 1120), Vector2(4230, 460), Vector2(4780, 1120), Vector2(4930, 430)]:
		if point.y < 768:
			draw_line(point + Vector2(0, 100), Vector2(point.x, 768), Color("8b9366"), 72)
		else:
			var side := -220.0 if point.x == 3250 else 220.0
			var entrance: Vector2 = point + Vector2(0, 140)
			var corner: Vector2 = entrance + Vector2(side, 0)
			draw_polyline(PackedVector2Array([entrance, corner, Vector2(corner.x, 768)]), Color("8b9366"), 64)
	draw_string(ThemeDB.fallback_font, Vector2(2380, 80), "Pântano", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("e5e3ba"))
	draw_string(ThemeDB.fallback_font, Vector2(3920, 80), "Campos secos", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("fff0b3"))
