class_name ForestCreature
extends CharacterBody2D

@export var max_health: int = 30
@export_enum("criatura", "esqueleto", "aranha") var kind := "criatura"
@export var skeleton_interval := 2.5
@export var skeleton_windup := 0.65
@export var skeleton_arrow_speed := 240.0
var windup_remaining := 0.0
var shot_direction := Vector2.RIGHT
@export var attack_damage: int = 10
@export_range(1.0, 10.0) var attack_interval: float = 1.0
@export var attack_range: float = 30.0
@export_enum("noturno", "guardiao") var origin: String = "noturno"
@export var territory_radius: float = 180.0
@export var dawn_fade_duration: float = 0.6
@export var detection_range: float = 260.0
@export var give_up_range: float = 420.0
@export var wander_radius: float = 110.0
@export var wander_speed: float = 45.0
@export var chase_speed: float = 95.0
var player: CharacterBody2D
var safe_center := Vector2(1152, 768)
var safe_radius: float = 240.0
var health: int = 30
var dead: bool = false
var chasing: bool = false
var highlighted: bool = false
var attack_cooldown: float = 0.0
var flash_time: float = 0.0
var home: Vector2
var destination: Vector2
var wander_time: float = 0.0
var wander_angle: float = 0.0
var fading: bool = false
var fade_elapsed: float = 0.0
var simulation_authority: bool = true
var safe_centers: Array[Vector2] = []


func is_safe(point: Vector2) -> bool:
	if safe_centers.is_empty():
		return point.distance_to(safe_center) < safe_radius
	for center in safe_centers:
		if point.distance_to(center) < safe_radius:
			return true
	return false


func begin_dawn() -> void:
	if origin != "noturno" or fading or dead:
		return
	fading = true
	chasing = false
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	remove_from_group("enemies")
	set_highlighted(false)


func _ready() -> void:
	if kind == "esqueleto":
		attack_damage = 10
		attack_interval = maxf(2.5, skeleton_interval)
		attack_range = 220
		chase_speed = 75
	elif kind == "aranha":
		attack_damage = 4
		attack_interval = 1.5
		chase_speed = 105
	health = max_health
	home = global_position
	destination = home
	wander_angle = global_position.x * 0.03


func anchor() -> Vector2:
	return global_position


func contains_cursor(point: Vector2) -> bool:
	return Rect2(-22, -38, 44, 49).has_point(to_local(point))


func set_highlighted(value: bool) -> void:
	if highlighted != value:
		highlighted = value
		queue_redraw()


func has_line_of_sight(point: Vector2) -> bool:
	var ray := PhysicsRayQueryParameters2D.create(global_position, point, 1)
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()


func try_attack() -> bool:
	if not simulation_authority or dead or fading or get_tree().paused or not is_instance_valid(player) or player.dead:
		return false
	if attack_cooldown > 0.0 or global_position.distance_to(player.global_position) > attack_range:
		return false
	if origin == "guardiao" and player.global_position.distance_to(home) > territory_radius:
		return false
	if is_safe(player.global_position) or not has_line_of_sight(player.global_position):
		return false
	attack_cooldown = attack_interval
	if kind == "esqueleto":
		shot_direction = (player.global_position - global_position).normalized()
		windup_remaining = skeleton_windup
		queue_redraw()
		return true
	var hit: bool = player.receive_damage(attack_damage)
	if hit and kind == "aranha" and player.has_method("apply_poison"): player.apply_poison(3)
	return hit

func release_arrow() -> bool:
	if dead or fading or not is_instance_valid(player) or player.dead or is_safe(player.global_position) or not has_line_of_sight(player.global_position): return false
	var arrow: Node2D = preload("res://scenes/projectile.tscn").instantiate()
	arrow.position = global_position
	arrow.direction = shot_direction
	arrow.speed = skeleton_arrow_speed
	arrow.remaining = 440
	arrow.damage = 10
	arrow.arrow = true
	arrow.hit_players = true
	arrow.shooter = get_rid()
	get_parent().add_child(arrow)
	return true

static func drop_quantity(monster: String, roll: float) -> int:
	if monster == "esqueleto": return 1 if roll < 0.70 else (2 if roll < 0.95 else 3)
	return 1 if roll < 0.75 else 2


func receive_damage(amount: int) -> bool:
	if not simulation_authority or dead or fading or amount <= 0 or get_tree().paused:
		return false
	health = maxi(0, health - amount)
	flash_time = 0.18
	queue_redraw()
	if health == 0:
		dead = true
		visible = false
		collision_layer = 0
		collision_mask = 0
		remove_from_group("enemies")
		if kind in ["esqueleto", "aranha"]:
			var drop: ResourceDrop = preload("res://scenes/resource_drop.tscn").instantiate()
			drop.resource = "flecha" if kind == "esqueleto" else "linha"
			drop.quantity = drop_quantity(kind, randf())
			drop.position = global_position
			get_parent().add_child(drop)
		queue_free()
	return true


func _process(delta: float) -> void:
	if fading:
		fade_elapsed += delta
		modulate.a = maxf(0.0, 1.0 - fade_elapsed / dawn_fade_duration)
		if fade_elapsed >= dawn_fade_duration:
			queue_free()
		return
	if flash_time > 0.0:
		flash_time = maxf(0.0, flash_time - delta)
		modulate = Color(1.0, 0.4, 0.4) if flash_time > 0.0 else Color.WHITE


func _physics_process(delta: float) -> void:
	if not simulation_authority or dead or fading or not is_instance_valid(player):
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	if windup_remaining > 0:
		windup_remaining = maxf(0, windup_remaining - delta)
		queue_redraw()
		if windup_remaining == 0: release_arrow()
	var distance := global_position.distance_to(player.global_position)
	var player_safe := is_safe(player.global_position)
	var outside_territory := origin == "guardiao" and player.global_position.distance_to(home) > territory_radius
	if player.dead or player_safe or distance > give_up_range or outside_territory:
		chasing = false
	elif distance <= detection_range and has_line_of_sight(player.global_position):
		chasing = true
	if chasing:
		destination = player.global_position
		try_attack()
	else:
		if origin == "guardiao":
			destination = home
		wander_time -= delta
		if origin != "guardiao" and (wander_time <= 0.0 or global_position.distance_to(destination) < 8.0):
			wander_time = 3.0
			wander_angle += 1.7
			destination = home + Vector2.from_angle(wander_angle) * wander_radius
	var direction := (destination - global_position).normalized()
	var speed := chase_speed if chasing else wander_speed
	velocity = Vector2.ZERO
	if (destination - global_position).length() > 3.0 and (not chasing or distance > attack_range * 0.8):
		# Desvio local simples; o corpo físico nunca atravessa árvores ou bordas.
		for angle in [0.0, PI / 4, -PI / 4, PI / 2, -PI / 2]:
			var motion := direction.rotated(angle) * speed * delta
			if origin == "guardiao" and (global_position + motion).distance_to(home) > territory_radius:
				continue
			if is_safe(global_position + motion):
				continue
			if not test_move(global_transform, motion):
				velocity = motion / delta
				break
	move_and_slide()


func _draw() -> void:
	if kind != "criatura":
		draw_monster()
		return
	draw_set_transform(Vector2(0, 3), 0.0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 22, Color(0.08, 0.1, 0.12, 0.35))
	draw_set_transform(Vector2.ZERO)
	draw_circle(Vector2(-10, 1), 7, Color("403d52"))
	draw_circle(Vector2(10, 1), 7, Color("403d52"))
	draw_colored_polygon(PackedVector2Array([Vector2(-18, -15), Vector2(-21, -36), Vector2(-6, -25)]), Color("a592b2"))
	draw_colored_polygon(PackedVector2Array([Vector2(18, -15), Vector2(21, -36), Vector2(6, -25)]), Color("a592b2"))
	draw_circle(Vector2(0, -13), 20, Color("766681"))
	draw_circle(Vector2(-7, -17), 4, Color("f2d786"))
	draw_circle(Vector2(7, -17), 4, Color("f2d786"))
	draw_line(Vector2(-5, -6), Vector2(5, -6), Color("302c42"), 3)
	if highlighted:
		draw_arc(Vector2.ZERO, 25, 0, TAU, 32, Color("efae7b"), 2)
	if highlighted or health < max_health:
		draw_rect(Rect2(-22, -48, 44, 5), Color("302c42"))
		draw_rect(Rect2(-22, -48, 44.0 * health / max_health, 5), Color("db866a"))

func draw_monster() -> void:
	if kind == "esqueleto":
		draw_circle(Vector2(0, -30), 12, Color("dedbc3"))
		for x in [-5, 5]: draw_circle(Vector2(x, -32), 3, Color("343e48"))
		draw_line(Vector2(0, -18), Vector2(0, -4), Color("dedbc3"), 4)
		for y in [-16, -11, -6]: draw_line(Vector2(-8, y), Vector2(8, y), Color("cbc9b2"), 3)
		for x in [-7, 7]:
			draw_line(Vector2(0, -4), Vector2(x, 5), Color("dedbc3"), 4)
			draw_line(Vector2(x, -17), Vector2(x * 2, -6), Color("dedbc3"), 3)
		draw_arc(Vector2(17, -13), 12, -PI / 2, PI / 2, 10, Color("aa8753"), 3)
		if windup_remaining > 0:
			draw_line(Vector2.ZERO, shot_direction * 50, Color("ffc16c"), 3)
			draw_arc(Vector2(0, -30), 18, 0, TAU, 20, Color("ffc16c"), 2)
	else:
		for side in [-1, 1]:
			for i in range(4):
				var start := Vector2(side * 7, -10 + i * 4)
				var bend := Vector2(side * 23, -19 + i * 10)
				draw_polyline(PackedVector2Array([start, bend, bend + Vector2(side * 4, 6)]), Color("615369"), 3)
		draw_circle(Vector2(0, -8), 14, Color("55405f"))
		draw_circle(Vector2(0, 4), 9, Color("7a596f"))
		for x in [-4, 4]: draw_circle(Vector2(x, 7), 2, Color("d8bf68"))
	if highlighted: draw_arc(Vector2.ZERO, 27, 0, TAU, 24, Color("efae7b"), 2)
	if highlighted or health < max_health:
		draw_rect(Rect2(-22, -52, 44, 5), Color("302c42"))
		draw_rect(Rect2(-22, -52, 44.0 * health / max_health, 5), Color("db866a"))
