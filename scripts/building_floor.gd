extends Node2D
var source: Node2D
func _draw() -> void:
	if is_instance_valid(source): source.draw_floor(self)
