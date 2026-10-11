class_name NeutralAnimal
extends CharacterBody2D
@export_enum("coelho", "vaca") var kind := "coelho"
@export var rabbit_health: int = 15
@export var cow_health: int = 40
@export var flee_distance: float = 150
var player: CharacterBody2D
var health := 15
var dead := false
var highlighted := false
var panic := 0.0
var wander_clock := 0.0
var direction := Vector2.RIGHT
var habitat := Rect2(48, 48, 5280, 1440)

func _ready() -> void:
	add_to_group("animals")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 4
	collision_mask = 7
	health = cow_health if kind == "vaca" else rabbit_health
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 16 if kind == "vaca" else 9
	collision.shape = shape
	add_child(collision)
func anchor() -> Vector2: return global_position
func contains_cursor(point: Vector2) -> bool:
	return Rect2(-24, -30, 48, 42).has_point(to_local(point))
func set_highlighted(value: bool) -> void:
	highlighted = value
	queue_redraw()
func _physics_process(delta: float) -> void:
	if dead or get_tree().paused: return
	panic = maxf(0, panic - delta)
	wander_clock -= delta
	if wander_clock <= 0:
		wander_clock = randf_range(3, 6)
		direction = Vector2.from_angle(randf() * TAU)
	var fleeing: bool = is_instance_valid(player) and not player.dead and (panic > 0 or (kind == "coelho" and global_position.distance_to(player.global_position) < flee_distance))
	if fleeing: direction = (global_position - player.global_position).normalized()
	var speed := (105.0 if kind == "coelho" else 70.0) if fleeing else 20.0
	var next := global_position + direction * speed * delta
	if not habitat.has_point(next): direction = (habitat.get_center() - global_position).normalized()
	velocity = direction * speed
	move_and_slide()
	if get_slide_collision_count() > 0:
		direction = direction.rotated(PI * 0.6)
		wander_clock = 1
func receive_damage(amount: int) -> bool:
	if dead or get_tree().paused or amount <= 0: return false
	health = maxi(0, health - amount)
	panic = 8
	if health == 0:
		dead = true
		collision_layer = 0
		remove_from_group("animals")
		var drop := preload("res://scenes/resource_drop.tscn").instantiate() as ResourceDrop
		drop.resource = "carne_crua"
		drop.quantity = randi_range(2, 3) if kind == "vaca" else 1
		drop.position = global_position
		get_parent().add_child(drop)
		visible = false
		queue_free()
	queue_redraw()
	return true
func _draw() -> void:
	if kind == "coelho":
		draw_circle(Vector2(0, -8), 11, Color("c9b8a0"))
		draw_line(Vector2(-5, -15), Vector2(-7, -30), Color("e5d6c1"), 5)
		draw_line(Vector2(3, -15), Vector2(5, -30), Color("e5d6c1"), 5)
		draw_circle(Vector2(8, -9), 2, Color("342f29"))
	else:
		draw_rect(Rect2(-22, -23, 44, 27), Color("e6ddc6"))
		draw_rect(Rect2(-12, -20, 14, 12), Color("564e43"))
		draw_circle(Vector2(21, -12), 10, Color("e6ddc6"))
		for x in [-15, 13]: draw_line(Vector2(x, 0), Vector2(x, 9), Color("756651"), 5)
		draw_circle(Vector2(24, -15), 2, Color("342f29"))
	if highlighted: draw_arc(Vector2.ZERO, 28, 0, TAU, 32, Color("f2d786"), 2)
