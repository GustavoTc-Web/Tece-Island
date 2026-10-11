class_name HarvestResource
extends StaticBody2D

signal depleted(resource: String, amount: int)

@export_enum("madeira", "pedra", "fibra") var resource: String = "madeira"
var progress: float = 0.0
var exhausted: bool = false
var highlighted: bool = false
var flash_time: float = 0.0


func anchor() -> Vector2:
	return $CollisionShape2D.global_position


func contains_cursor(point: Vector2) -> bool:
	if resource == "fibra":
		return Rect2(-24, -30, 48, 40).has_point(to_local(point))
	var bounds := Rect2(-46, -110, 92, 123) if resource == "madeira" else Rect2(-27, -38, 54, 46)
	return bounds.has_point(to_local(point))


func set_highlighted(value: bool) -> void:
	if highlighted != value:
		highlighted = value
		queue_redraw()


func apply_hit(tool: String) -> bool:
	if exhausted:
		return false
	var rule: Dictionary = ResourceRules.EXTRACTION[resource]
	if not rule.hits.has(tool):
		return false
	# Progresso proporcional permite trocar de ferramenta sem perder trabalho.
	progress = minf(1.0, progress + 1.0 / float(rule.hits[tool]))
	flash_time = 0.16
	queue_redraw()
	if progress >= 1.0 - 0.00001:
		exhausted = true
		visible = false
		collision_layer = 0
		collision_mask = 0
		$CollisionShape2D.set_deferred("disabled", true)
		remove_from_group("harvest_resources")
		# Marca antes do sinal: nem chamadas no mesmo frame repetem a recompensa.
		depleted.emit(resource, rule.reward)
		queue_free()
	return true


func _process(delta: float) -> void:
	if flash_time > 0.0:
		flash_time = maxf(0.0, flash_time - delta)
		modulate = Color(1.4, 1.3, 0.8) if flash_time > 0.0 else Color.WHITE


func draw_feedback() -> void:
	var center := $CollisionShape2D.position as Vector2
	if highlighted:
		draw_arc(center, 24.0 if resource == "madeira" else 30.0, 0.0, TAU, 32, Color("f2d786"), 2.0)
	if highlighted or progress > 0.0:
		var bar := Vector2(-25, 18)
		draw_rect(Rect2(bar, Vector2(50, 6)), Color("263c35"))
		draw_rect(Rect2(bar, Vector2(50 * progress, 6)), Color("f2d786"))
