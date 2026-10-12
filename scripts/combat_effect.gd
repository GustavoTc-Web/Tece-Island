class_name CombatEffect
extends Node2D

var kind := "impact"
var direction := Vector2.RIGHT
var remaining := 0.22
const LIMIT := 12

static func emit_at(actor: Node, point: Vector2, effect: String, aim: Vector2 = Vector2.RIGHT) -> void:
	if not actor.is_inside_tree(): return
	var audio := actor.get_node_or_null("/root/CombatAudio")
	if audio != null: audio.play(effect)
	if actor.get_tree().get_nodes_in_group("combat_effects").size() >= LIMIT: return
	var visual := CombatEffect.new()
	visual.kind = effect
	visual.direction = aim.normalized()
	visual.position = point
	visual.z_index = 20
	actor.get_parent().add_child(visual)
	visual.add_to_group("combat_effects")

func _process(delta: float) -> void:
	remaining -= delta
	if remaining <= 0: queue_free()
	else: queue_redraw()

func _draw() -> void:
	var color: Color = {"impact": Color("f2d786"), "blocked": Color("a3b2b5"), "damage": Color("e68f78"), "shot": Color("ffdd92"), "arrow": Color("c3ddc6"), "swing": Color("dfd7ad")}.get(kind, Color.WHITE)
	color.a = remaining / 0.22
	var radius := 4 + (1 - remaining / 0.22) * 12
	if kind in ["impact", "blocked", "damage"]:
		for i in range(5):
			var axis := Vector2.from_angle(i * TAU / 5)
			draw_line(axis * radius * 0.5, axis * radius, color, 2)
	elif kind == "swing": draw_arc(Vector2.ZERO, radius + 15, direction.angle() - 0.6, direction.angle() + 0.6, 10, color, 2)
	elif kind == "arrow": draw_line(-direction * 8, direction * radius, color, 2)
	else: draw_circle(direction * 15, radius * 0.6, color)
