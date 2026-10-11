class_name WaterWell
extends StaticBody2D
var highlighted := false
var hud: CanvasLayer
var player: CharacterBody2D
func _ready() -> void:
	add_to_group("interactables")
	add_to_group("wells")
	collision_layer = 1
	collision_mask = 6
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 22
	collision.shape = shape
	add_child(collision)
func prompt() -> String: return "E — Água potável: beber / encher cantil"
func set_highlighted(value: bool) -> void:
	highlighted = value
	queue_redraw()
func interact(_inventory: ResourceInventory) -> String:
	if hud != null and hud.has_method("open_well"): hud.open_well(self)
	return "Poço de água potável"
func can_interact() -> bool:
	if not is_instance_valid(player) or player.dead or player.global_position.distance_to(global_position) > 90: return false
	var ray := PhysicsRayQueryParameters2D.create(player.global_position, global_position, 1)
	var collision := get_world_2d().direct_space_state.intersect_ray(ray)
	return collision.is_empty() or collision.collider == self
func _draw() -> void:
	draw_circle(Vector2.ZERO, 25, Color("a7a184"))
	draw_circle(Vector2.ZERO, 17, Color("376d85"))
	draw_arc(Vector2.ZERO, 22, 0, TAU, 16, Color("ddd3ad"), 5)
	draw_line(Vector2(-25, -12), Vector2(-25, -46), Color("725237"), 5)
	draw_line(Vector2(25, -12), Vector2(25, -46), Color("725237"), 5)
	draw_line(Vector2(-28, -46), Vector2(28, -46), Color("725237"), 6)
	if highlighted: draw_arc(Vector2.ZERO, 32, 0, TAU, 32, Color("f2d786"), 2)
