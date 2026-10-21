extends Node2D
# Keep the solo's exact drawing commands, but submit only visible 512-unit cells.
# Clipping prevents large background rectangles/paths from overdrawing neighbors.
const CELL := 512.0
var chunks := {}
var visible_cells := Rect2i()

class Recorder extends RefCounted:
	var commands := []
	func store(method: StringName, args: Array, bounds: Rect2) -> void:
		commands.append({"method": method, "args": args, "bounds": bounds.grow(4)})
	func draw_rect(rect: Rect2, color: Color, filled: bool = true, width: float = -1.0) -> void:
		store(&"draw_rect", [rect, color, filled, width], rect.grow(maxf(width, 0)))
	func draw_line(a: Vector2, b: Vector2, color: Color, width: float = -1.0) -> void:
		store(&"draw_line", [a, b, color, width], Rect2(a, Vector2.ZERO).expand(b).grow(maxf(width, 1)))
	func draw_polyline(points: PackedVector2Array, color: Color, width: float = -1.0) -> void:
		var bounds := Rect2(points[0], Vector2.ZERO)
		for point in points: bounds = bounds.expand(point)
		store(&"draw_polyline", [points, color, width], bounds.grow(maxf(width, 1)))
	func draw_circle(center: Vector2, radius: float, color: Color) -> void:
		store(&"draw_circle", [center, radius, color], Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2))
	func draw_arc(center: Vector2, radius: float, start: float, end: float, count: int, color: Color, width: float = -1.0) -> void:
		store(&"draw_arc", [center, radius, start, end, count, color, width], Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2).grow(maxf(width, 1)))
	func draw_string(font: Font, point: Vector2, text: String, alignment: int, width: float, font_size: int, color: Color) -> void:
		var size := font.get_string_size(text, alignment, width, font_size)
		store(&"draw_string", [font, point, text, alignment, width, font_size, color], Rect2(point - Vector2(0, font_size), size + Vector2(0, font_size)))

class Tile extends Control:
	var commands := []
	func _draw() -> void:
		draw_set_transform(-position)
		for command in commands: callv(command.method, command.args)

func _ready() -> void:
	var recorder := Recorder.new()
	WorldScenery.draw_ground(recorder)
	WorldTerrain.draw_scenery(recorder)
	preload("res://scripts/biomes.gd").draw_scenery(recorder)
	CampaignTerrain.draw_scenery(recorder)
	for command in recorder.commands:
		var bounds: Rect2 = command.bounds.intersection(WorldTerrain.BOUNDS.grow(512))
		if not bounds.has_area(): continue
		for x in range(floori(bounds.position.x / CELL), ceili(bounds.end.x / CELL)):
			for y in range(floori(bounds.position.y / CELL), ceili(bounds.end.y / CELL)):
				var key := Vector2i(x, y)
				if not chunks.has(key):
					var tile := Tile.new()
					tile.position = Vector2(key) * CELL
					tile.size = Vector2.ONE * CELL
					tile.clip_contents = true
					tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
					tile.visible = false
					add_child(tile)
					chunks[key] = tile
				chunks[key].commands.append(command)

func show_area(area: Rect2) -> void:
	var first := Vector2i(floori(area.position.x / CELL), floori(area.position.y / CELL))
	var last := Vector2i(ceili(area.end.x / CELL), ceili(area.end.y / CELL))
	var cells := Rect2i(first, last - first)
	if cells == visible_cells: return
	visible_cells = cells
	for key in chunks: chunks[key].visible = cells.has_point(key)
