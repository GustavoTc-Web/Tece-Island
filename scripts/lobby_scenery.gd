extends Control
var clock := 0.0
var frame_clock := 0.0
var character: CharacterBody2D
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Only the avatar drawing: no world, camera, inventory, collision or needs.
	character = preload("res://scripts/player.gd").new()
	character.process_mode = Node.PROCESS_MODE_DISABLED
	character.collision_layer = 0
	character.collision_mask = 0
	add_child(character)
func _process(delta: float) -> void:
	clock += delta
	frame_clock += delta
	if frame_clock < 0.125: return
	frame_clock = 0
	character.position = Vector2(size.x * 0.3, size.y * 0.7)
	character.scale = Vector2.ONE * clampf(size.y / 160, 2.5, 4)
	queue_redraw()
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("132b24"))
	var center := Vector2(size.x * 0.32, size.y * 0.72)
	draw_set_transform(center, 0, Vector2(1.8, 0.7))
	draw_circle(Vector2.ZERO, size.y * 0.24, Color("36452d"))
	draw_circle(Vector2.ZERO, size.y * 0.19, Color("4e5737"))
	draw_set_transform(Vector2.ZERO)
	for point in [Vector2(0.02, 0.28), Vector2(0.18, 0.43), Vector2(0.43, 0.35), Vector2(0.58, 0.62), Vector2(0.03, 0.92), Vector2(0.15, 1.08), Vector2(0.5, 1.06), Vector2(0.82, 0.33), Vector2(0.97, 0.87)]:
		IslandArt.tree(self, size * point, size.y / 205)
	var fire := Vector2(size.x * 0.43, size.y * 0.78)
	draw_circle(fire, 68, Color(0.9, 0.58, 0.2, 0.06 + sin(clock * 3) * 0.01))
	IslandArt.fire(self, clock, fire, size.y / 220)
	# Quiet foliage and a dark menu side keep the interface readable.
	draw_rect(Rect2(size.x * 0.61, 0, size.x * 0.39, size.y), Color(0.04, 0.12, 0.09, 0.7))
