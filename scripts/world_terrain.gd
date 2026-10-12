class_name WorldTerrain
extends Node2D

const ORIGINAL := [
	{"id": "forest", "kind": "Floresta", "rect": Rect2(0, 0, 2304, 1536)},
	{"id": "swamp", "kind": "Pântano", "rect": Rect2(2304, 0, 1536, 1536)},
	{"id": "fields", "kind": "Campos", "rect": Rect2(3840, 0, 1536, 1536)},
	{"id": "desert", "kind": "Deserto", "rect": Rect2(5376, 0, 1536, 1536)}]
const AQUATIC := [
	{"id": "aquatic_w", "kind": "Aquático", "rect": Rect2(-1536, 0, 1536, 1536)},
	{"id": "aquatic_n", "kind": "Aquático", "rect": Rect2(5376, -1536, 1536, 1536)}]
const RUINS := [
	{"id": "ruins_w", "kind": "Ruínas Escuras", "rect": Rect2(-3072, 0, 1536, 1536)},
	{"id": "ruins_s", "kind": "Ruínas Escuras", "rect": Rect2(-1536, 1536, 1536, 1536)}]
const PONDS := [Rect2(2450, 400, 130, 85), Rect2(3390, 250, 180, 100), Rect2(2770, 1250, 170, 90), Rect2(3500, 940, 160, 70)]
const COLORS := {"Floresta": Color("567c46"), "Pântano": Color("40574b"), "Campos": Color("ad9b5c"), "Deserto": Color("dec487"), "Aquático": Color("366e86"), "Ruínas Escuras": Color("494755")}
const BOUNDS := Rect2(-3072, -1536, 9984, 4608)
const SWIM_SPEED := 0.60

static func regions() -> Array:
	return ORIGINAL + AQUATIC + RUINS

static func is_dark(point: Vector2) -> bool:
	return region_at(point).get("kind", "") == "Ruínas Escuras"

static func region_at(point: Vector2) -> Dictionary:
	for region in regions():
		if region.rect.has_point(point): return region
	return {}

static func contains(point: Vector2) -> bool:
	return not region_at(point).is_empty()

static func islands(rect: Rect2) -> Array[Vector2]:
	return [rect.position + rect.size * Vector2(0.25, 0.25), rect.position + rect.size * Vector2(0.75, 0.75), rect.position + rect.size * Vector2(0.25, 0.75)]

static func is_water(point: Vector2) -> bool:
	for pond in PONDS:
		if pond.has_point(point): return true
	var region := region_at(point)
	if region.get("kind", "") != "Aquático": return false
	var rect: Rect2 = region.rect
	var local := point - rect.position
	# Connected land paths and margins; three islands complete ~20% land.
	if local.x < 14 or local.y < 14 or local.x > rect.size.x - 14 or local.y > rect.size.y - 14: return false
	if absf(local.x - rect.size.x / 2) < 46 or absf(local.y - rect.size.y / 2) < 46: return false
	for island in islands(rect):
		if point.distance_to(island) <= 112: return false
	return true

static func solid_ground(point: Vector2, size: Vector2 = Vector2.ZERO) -> bool:
	for offset in [Vector2.ZERO, -size / 2, size / 2, Vector2(-size.x, size.y) / 2, Vector2(size.x, -size.y) / 2]:
		if not contains(point + offset) or is_water(point + offset): return false
	return true

func build_boundaries() -> void:
	for region in regions():
		var rect: Rect2 = region.rect
		for edge in [[rect.position, Vector2.RIGHT, Vector2.UP, rect.size.x], [Vector2(rect.position.x, rect.end.y), Vector2.RIGHT, Vector2.DOWN, rect.size.x], [rect.position, Vector2.DOWN, Vector2.LEFT, rect.size.y], [Vector2(rect.end.x, rect.position.y), Vector2.DOWN, Vector2.RIGHT, rect.size.y]]:
			var start := -1
			for offset in range(0, int(edge[3]), 32):
				var point: Vector2 = edge[0] + edge[1] * (offset + 16)
				var outside := not contains(point + edge[2] * 16)
				if outside and start < 0: start = offset
				if not outside and start >= 0:
					boundary(edge[0] + edge[1] * start, edge[0] + edge[1] * offset)
					start = -1
			if start >= 0: boundary(edge[0] + edge[1] * start, edge[0] + edge[1] * float(edge[3]))

func boundary(from: Vector2, to: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = (from + to) / 2
	body.collision_layer = 1
	body.collision_mask = 6
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(absf(to.x - from.x), 24) if from.y == to.y else Vector2(24, absf(to.y - from.y))
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func _draw() -> void:
	for region in regions():
		if region in ORIGINAL: continue
		var rect: Rect2 = region.rect
		draw_rect(rect, COLORS[region.kind])
		if region.kind == "Ruínas Escuras":
			for i in range(110):
				var point := rect.position + Vector2(40 + posmod(i * 163, int(rect.size.x) - 80), 40 + posmod(i * 227, int(rect.size.y) - 80))
				draw_rect(Rect2(point, Vector2(10, 5)), Color("686271"))
		if region.kind == "Aquático":
			var land := Color("819b62")
			draw_rect(rect, land, false, 28)
			draw_line(Vector2(rect.get_center().x, rect.position.y), Vector2(rect.get_center().x, rect.end.y), land, 92)
			draw_line(Vector2(rect.position.x, rect.get_center().y), Vector2(rect.end.x, rect.get_center().y), land, 92)
			for island in islands(rect): draw_circle(island, 112, land)
			for i in range(100):
				var point := rect.position + Vector2(40 + posmod(i * 137, int(rect.size.x) - 80), 40 + posmod(i * 233, int(rect.size.y) - 80))
				if is_water(point): draw_line(point, point + Vector2(18, 0), Color("538b9d"), 2)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(60, 80), region.kind, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("e6e0c0"))
