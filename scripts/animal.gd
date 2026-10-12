class_name NeutralAnimal
extends CharacterBody2D
@export_enum("coelho", "vaca", "lambari", "tilapia", "garca_azul") var kind := "coelho"
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
var animation := 0.0

func is_fish() -> bool: return kind in ["lambari", "tilapia"]

func _ready() -> void:
	add_to_group("animals")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 4
	collision_mask = 15
	health = cow_health if kind == "vaca" else rabbit_health
	if is_fish(): health = 10 if kind == "lambari" else 15
	if kind == "garca_azul": health = 10
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape := CircleShape2D.new()
	shape.radius = 16 if kind == "vaca" else 9
	if kind == "garca_azul": shape.radius = 6
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
	animation += delta
	if kind == "garca_azul" or is_fish(): queue_redraw()
	panic = maxf(0, panic - delta)
	wander_clock -= delta
	if wander_clock <= 0:
		wander_clock = randf_range(3, 6)
		direction = Vector2.from_angle(randf() * TAU)
	var fleeing: bool = is_instance_valid(player) and not player.dead and (panic > 0 or (kind in ["coelho", "garca_azul"] and global_position.distance_to(player.global_position) < (220 if kind == "garca_azul" else flee_distance)))
	if fleeing: direction = (global_position - player.global_position).normalized()
	var speed := (105.0 if kind == "coelho" else 70.0) if fleeing else 20.0
	if is_fish(): speed = 75 if fleeing else 32
	if kind == "garca_azul": speed = 270 if fleeing else 40
	var next := global_position + direction * speed * delta
	if not habitat.has_point(next): direction = (habitat.get_center() - global_position).normalized()
	if is_fish():
		var found := false
		for angle in [0.0, PI / 2, -PI / 2, PI]:
			var candidate := direction.rotated(angle)
			var point := global_position + candidate * speed * delta
			if habitat.has_point(point) and WorldTerrain.is_water(point) and WorldTerrain.contains(point):
				direction = candidate
				found = true
				break
		if not found: return
	velocity = direction * speed
	var previous := global_position
	move_and_slide()
	if is_fish() and (not habitat.has_point(global_position) or not WorldTerrain.is_water(global_position)):
		global_position = previous
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
		drop.resource = "carne_peixe" if is_fish() else "carne_crua"
		drop.quantity = randi_range(2, 3) if kind == "vaca" else 1
		drop.position = global_position
		get_parent().add_child(drop)
		visible = false
		queue_free()
	queue_redraw()
	return true
func _draw() -> void:
	if is_fish():
		draw_set_transform(Vector2(0, -5), direction.angle())
		var color := Color("bed3c3") if kind == "lambari" else Color("779c91")
		var length := 12 if kind == "lambari" else 18
		draw_set_transform(Vector2(0, -5), direction.angle(), Vector2(1.4, 0.65))
		draw_circle(Vector2.ZERO, length * 0.65, color)
		draw_colored_polygon(PackedVector2Array([Vector2(-length / 2, 0), Vector2(-length, -7), Vector2(-length, 7)]), color.darkened(0.2))
		draw_circle(Vector2(length / 2 - 2, -2), 2, Color("253947"))
		if kind == "tilapia":
			for x in [-5, 0, 5]: draw_line(Vector2(x, -5), Vector2(x, 5), Color("455f68"), 2)
		draw_set_transform(Vector2.ZERO)
	elif kind == "garca_azul":
		for x in [-5, 4]: draw_line(Vector2(x, -5), Vector2(x + 2, 10), Color("a08d57"), 2)
		draw_colored_polygon(PackedVector2Array([Vector2(-17, -12), Vector2(-6, -28), Vector2(10, -19), Vector2(12, -7)]), Color("5e88aa"))
		draw_line(Vector2(6, -18), Vector2(11, -35), Color("adc5d4"), 5)
		draw_line(Vector2(11, -35), Vector2(18, -40), Color("adc5d4"), 4)
		draw_circle(Vector2(19, -41), 6, Color("819eb9"))
		draw_colored_polygon(PackedVector2Array([Vector2(23, -42), Vector2(39, -39), Vector2(23, -37)]), Color("d6b65a"))
		draw_circle(Vector2(21, -42), 1.5, Color("1e3143"))
		var lift := sin(animation * 12) * (12 if panic > 0 else 3)
		draw_colored_polygon(PackedVector2Array([Vector2(-8, -20), Vector2(-30, -30 - lift), Vector2(-22, -11)]), Color("375776"))
		draw_line(Vector2(-4, -24), Vector2(-20, -28 - lift), Color("a8c1d4"), 2)
	elif kind == "coelho":
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
