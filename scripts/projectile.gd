extends Node2D

var direction := Vector2.RIGHT
var speed: float = 900.0
var remaining: float = 550.0
var damage: int = 18
var shooter: RID
var hit_players: bool = false
var friendly_fire: bool = true
var simulation_authority: bool = true

func _physics_process(delta: float) -> void:
	var distance := minf(remaining, speed * delta)
	var end := global_position + direction * distance
	# Raycast varrido evita atravessar paredes finas entre dois frames.
	var ray := PhysicsRayQueryParameters2D.create(global_position, end, 7 if hit_players else 5)
	ray.exclude = [shooter]
	var collision := get_world_2d().direct_space_state.intersect_ray(ray)
	if not collision.is_empty():
		if simulation_authority and (collision.collider is ForestCreature or collision.collider is NeutralAnimal):
			collision.collider.receive_damage(damage)
		elif simulation_authority and hit_players and friendly_fire and collision.collider.has_method("receive_damage"):
			collision.collider.receive_damage(damage)
		queue_free()
		set_physics_process(false)
		return
	global_position = end
	remaining -= distance
	if remaining <= 0:
		queue_free()

func _draw() -> void:
	draw_line(-direction * 8, Vector2.ZERO, Color("ffe5a1"), 3)
