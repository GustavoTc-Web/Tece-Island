class_name CombatEffect
extends Node2D

var kind := "impact"
var direction := Vector2.RIGHT
var remaining := 0.22
const LIMIT := 12

static func emit_at(actor: Node, point: Vector2, effect: String, aim: Vector2 = Vector2.RIGHT, relay: bool = true) -> void:
	if not actor.is_inside_tree(): return
	if relay and effect in ["impact", "arrow_hit", "shot_hit", "damage", "blocked"]:
		var arena := actor.get_tree().get_first_node_in_group("arena_combat_feedback")
		if arena != null and arena.multiplayer.is_server(): arena.send_combat_feedback(point, effect, aim)
	var audio := actor.get_node_or_null("/root/CombatAudio")
	if audio != null and effect != "miss": audio.play("impact" if effect.ends_with("_hit") else effect)
	if actor.get_tree().get_nodes_in_group("combat_effects").size() >= LIMIT: return
	var visual := CombatEffect.new()
	visual.kind = effect
	visual.direction = aim.normalized()
	visual.position = point
	visual.z_index = 20
	var parent := actor if actor.has_method("send_combat_feedback") else actor.get_parent()
	parent.add_child(visual)
	visual.add_to_group("combat_effects")

func _process(delta: float) -> void:
	remaining -= delta
	if remaining <= 0: queue_free()
	else: queue_redraw()

func _draw() -> void:
	var color: Color = {"impact": Color("f2d786"), "arrow_hit": Color("c3ddc6"), "shot_hit": Color("ffd192"), "miss": Color("859b94"), "blocked": Color("a3b2b5"), "damage": Color("e68f78"), "shot": Color("ffdd92"), "arrow": Color("c3ddc6"), "swing": Color("dfd7ad")}.get(kind, Color.WHITE)
	color.a = remaining / 0.22
	var radius := 4 + (1 - remaining / 0.22) * 12
	if kind in ["impact", "shot_hit", "blocked", "damage"]:
		for i in range(5):
			var axis := Vector2.from_angle(i * TAU / 5)
			draw_line(axis * radius * 0.5, axis * radius, color, 2)
	elif kind == "swing": draw_arc(Vector2.ZERO, radius + 15, direction.angle() - 0.6, direction.angle() + 0.6, 10, color, 2)
	elif kind in ["arrow", "arrow_hit", "miss"]: draw_line(-direction * 8, direction * radius, color, 2)
	else: draw_circle(direction * 15, radius * 0.6, color)
