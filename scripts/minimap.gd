class_name IslandMinimap
extends Control
var player: CharacterBody2D
var explored := {}
var clock := 0.0
const CENTER := Vector2(74, 74)
const CELL := 128.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -124
	offset_right = -16
	offset_top = 90
	offset_bottom = 198
	scale = Vector2(0.72, 0.72)
	custom_minimum_size = Vector2(148, 148)

func reveal() -> void:
	var origin := player.global_position.snapped(Vector2(CELL, CELL))
	for x in range(-3, 4):
		for y in range(-3, 4):
			var point := origin + Vector2(x, y) * CELL
			if point.distance_to(player.global_position) <= 350 and WorldTerrain.contains(point):
				explored[SaveStore.key(point)] = true

func _process(delta: float) -> void:
	var hud := get_parent()
	visible = hud.current_panel == "" and not hud.showing_death
	if hud.menu_button != null: offset_top = hud.menu_button.size.y + 32
	clock += delta
	if clock < 0.2 or not is_instance_valid(player): return
	clock = 0
	reveal()
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(player): return
	draw_circle(CENTER, 73, Color("182b29"))
	for x in range(-8, 9):
		for y in range(-8, 9):
			var offset := Vector2(x, y) * 8
			if offset.length() > 66: continue
			var point := player.global_position + offset * 8
			if not explored.has(SaveStore.key(point.snapped(Vector2(CELL, CELL)))): continue
			var region := WorldTerrain.region_at(point)
			if region.is_empty(): continue
			var color: Color = WorldTerrain.COLORS[region.kind]
			if region.kind == "Aquático" and not WorldTerrain.is_water(point): color = Color("819b62")
			draw_rect(Rect2(CENTER + offset - Vector2(4, 4), Vector2(8, 8)), color)
	draw_arc(CENTER, 73, 0, TAU, 64, Color("d0bb81"), 2)
	var direction: Vector2 = player.facing.normalized()
	draw_colored_polygon(PackedVector2Array([CENTER + direction * 9, CENTER - direction * 5 + direction.orthogonal() * 5, CENTER - direction * 5 - direction.orthogonal() * 5]), Color("ffe5a1"))
	draw_string(ThemeDB.fallback_font, Vector2(43, 163), "Minimapa", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("e0d7c0"))
