class_name ForestCreature
extends CharacterBody2D
signal defeated
signal wounded

@export var max_health: int = 30
@export_enum("criatura", "esqueleto", "aranha", "cacador", "brutamonte", "uivador", "sentinela", "acolito", "guardiao_ilha") var kind := "criatura"
@export var skeleton_interval := 2.5
@export var skeleton_windup := 0.65
@export var skeleton_arrow_speed := 295.0
@export var skeleton_damage := 10
@export var spider_damage := 4
@export var spider_interval := 1.5
@export var spider_poison_duration := 3.0
var windup_remaining := 0.0
var shot_direction := Vector2.RIGHT
@export var attack_damage: int = 10
@export_range(1.0, 10.0) var attack_interval: float = 1.0
@export var attack_range: float = 30.0
@export_enum("noturno", "guardiao", "campanha", "templo") var origin: String = "noturno"
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
var combat_visible := 0.0
var attack_visual := 0.0
var attack_direction := Vector2.RIGHT
var home: Vector2
var destination: Vector2
var wander_time: float = 0.0
var wander_angle: float = 0.0
var fading: bool = false
var fade_elapsed: float = 0.0
var simulation_authority: bool = true
var safe_centers: Array[Vector2] = []
var charge_remaining := 0.0
var recovery := 0.0
var special_attack := ""
var pattern := 0
var charge_hit := false
var reinforcement_handler: Callable
var call_cooldown := 5.0

func within_territory(point: Vector2) -> bool:
	if origin == "templo": return Rect2(home - Vector2(350, 240), Vector2(700, 480)).has_point(point)
	return origin != "guardiao" or point.distance_to(home) <= territory_radius


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
	collision_mask |= 8
	if kind in ["esqueleto", "acolito"]:
		if kind == "acolito":
			max_health = 35
			skeleton_windup = 0.85
			skeleton_arrow_speed = 265
		attack_damage = skeleton_damage
		attack_interval = maxf(2.5, skeleton_interval)
		attack_range = 250
		chase_speed = 95
	elif kind == "aranha":
		attack_damage = spider_damage
		attack_interval = spider_interval
		chase_speed = 105
	elif kind == "cacador":
		max_health = 22
		chase_speed = 135
		attack_damage = 12
		attack_range = 110
		attack_interval = 2.5
	elif kind in ["brutamonte", "sentinela"]:
		max_health = 65 if kind == "sentinela" else 100
		chase_speed = 58
		attack_damage = 20 if kind == "sentinela" else 24
		attack_range = 68
		attack_interval = 3.4
	elif kind == "uivador":
		max_health = 35
		chase_speed = 80
		attack_damage = 8
		attack_interval = 2.0
	elif kind == "guardiao_ilha":
		max_health = 300
		chase_speed = 105
		attack_damage = 22
		attack_range = 460
		attack_interval = 3.6
		detection_range = 850
		give_up_range = 1100
		safe_radius = 0
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
	if kind == "guardiao_ilha" and pattern % 2 == 0 and global_position.distance_to(player.global_position) > 185: return false
	if not within_territory(player.global_position):
		return false
	if is_safe(player.global_position) or not has_line_of_sight(player.global_position):
		return false
	attack_cooldown = attack_interval
	combat_visible = 4
	attack_direction = (player.global_position - global_position).normalized()
	if kind in ["cacador", "brutamonte", "sentinela", "guardiao_ilha"]:
		special_attack = "slam" if kind in ["brutamonte", "sentinela"] else "charge"
		if kind == "guardiao_ilha":
			special_attack = "volley" if pattern % 2 == 1 else "charge"
			pattern += 1
		windup_remaining = 0.65 if kind == "cacador" else 1.2
		shot_direction = attack_direction
		queue_redraw()
		return true
	if kind in ["esqueleto", "acolito"]:
		shot_direction = predicted_direction()
		windup_remaining = skeleton_windup
		queue_redraw()
		return true
	attack_visual = 0.2
	CombatEffect.emit_at(self, global_position, "swing", attack_direction)
	var hit: bool = player.receive_damage(attack_damage)
	if hit: CombatEffect.emit_at(self, player.global_position, "impact")
	if hit and kind == "aranha" and player.has_method("apply_poison"): player.apply_poison(spider_poison_duration)
	return hit

func release_arrow() -> bool:
	if dead or fading or not is_instance_valid(player) or player.dead or not within_territory(player.global_position) or is_safe(player.global_position) or not has_line_of_sight(player.global_position): return false
	var arrow: Node2D = preload("res://scenes/projectile.tscn").instantiate()
	arrow.position = get_parent().to_local(global_position)
	arrow.direction = shot_direction
	arrow.speed = skeleton_arrow_speed
	arrow.remaining = 440
	arrow.damage = skeleton_damage
	arrow.arrow = true
	arrow.hit_players = true
	arrow.shooter = get_rid()
	if origin in ["templo", "campanha"]: arrow.add_to_group("campaign_projectiles")
	if kind == "acolito": arrow.tint = Color("bd9ffa")
	get_parent().add_child(arrow)
	attack_visual = 0.2
	CombatEffect.emit_at(self, global_position, "arrow", shot_direction)
	return true

func predicted_direction() -> Vector2:
	var travel := global_position.distance_to(player.global_position) / skeleton_arrow_speed
	var lead: Vector2 = player.velocity * minf(0.38, travel * 0.5 + 0.1)
	return (player.global_position + lead - global_position).normalized()

func release_special() -> void:
	if dead or fading or not is_instance_valid(player) or player.dead or not within_territory(player.global_position) or is_safe(player.global_position): return
	if special_attack == "charge":
		charge_remaining = 0.32 if kind == "cacador" else 0.55
		charge_hit = false
	elif special_attack == "slam":
		attack_visual = 0.2
		if global_position.distance_to(player.global_position) <= attack_range and has_line_of_sight(player.global_position) and attack_direction.dot((player.global_position - global_position).normalized()) > 0.35:
			player.receive_damage(attack_damage)
		recovery = 1.0
	elif special_attack == "call":
		if reinforcement_handler.is_valid(): reinforcement_handler.call(self)
		call_cooldown = 18.0
		recovery = 0.6
	else:
		for angle in [-0.22, 0.0, 0.22]:
			var arrow: Node2D = preload("res://scenes/projectile.tscn").instantiate()
			arrow.position = get_parent().to_local(global_position)
			arrow.direction = shot_direction.rotated(angle)
			arrow.speed = 240
			arrow.remaining = 650
			arrow.damage = 14
			arrow.arrow = true
			arrow.hit_players = true
			arrow.shooter = get_rid()
			arrow.add_to_group("campaign_projectiles")
			get_parent().add_child(arrow)
		recovery = 1.1

static func drop_quantity(monster: String, roll: float) -> int:
	if monster == "esqueleto": return 1 if roll < 0.70 else (2 if roll < 0.95 else 3)
	return 1 if roll < 0.75 else 2


func receive_damage(amount: int) -> bool:
	if not simulation_authority or dead or fading or amount <= 0 or get_tree().paused:
		return false
	health = maxi(0, health - amount)
	if kind == "uivador" and special_attack == "call" and windup_remaining > 0:
		windup_remaining = 0
		special_attack = ""
		call_cooldown = 12.0
		recovery = 0.6
	flash_time = 0.18
	combat_visible = 4
	queue_redraw()
	if health > 0: wounded.emit()
	if health == 0:
		dead = true
		visible = false
		collision_layer = 0
		collision_mask = 0
		remove_from_group("enemies")
		defeated.emit()
		if kind in ["esqueleto", "aranha"]:
			var drop: ResourceDrop = preload("res://scenes/resource_drop.tscn").instantiate()
			drop.resource = "flecha" if kind == "esqueleto" else "linha"
			drop.quantity = drop_quantity(kind, randf())
			drop.position = global_position
			get_parent().add_child(drop)
		queue_free()
	return true


func _process(delta: float) -> void:
	if combat_visible > 0 or attack_visual > 0:
		combat_visible = maxf(0, combat_visible - delta)
		attack_visual = maxf(0, attack_visual - delta)
		queue_redraw()
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
	call_cooldown = maxf(0.0, call_cooldown - delta)
	recovery = maxf(0, recovery - delta)
	if charge_remaining > 0:
		charge_remaining = maxf(0, charge_remaining - delta)
		velocity = shot_direction * (230 if kind == "cacador" else 280)
		if is_safe(global_position + velocity * delta) or not within_territory(global_position + velocity * delta):
			charge_remaining = 0
			velocity = Vector2.ZERO
			recovery = 1.0
			return
		move_and_slide()
		if not charge_hit and not player.dead and not is_safe(player.global_position) and global_position.distance_to(player.global_position) < 36 and has_line_of_sight(player.global_position):
			charge_hit = true
			player.receive_damage(attack_damage)
		if charge_remaining == 0 or get_slide_collision_count() > 0:
			charge_remaining = 0
			recovery = 1.0
		return
	if windup_remaining > 0:
		if kind in ["esqueleto", "acolito"] and windup_remaining > 0.2: shot_direction = predicted_direction()
		windup_remaining = maxf(0, windup_remaining - delta)
		queue_redraw()
		velocity = Vector2.ZERO
		if windup_remaining == 0:
			if kind in ["esqueleto", "acolito"]: release_arrow()
			else: release_special()
		return
	if recovery > 0:
		velocity = Vector2.ZERO
		return
	var distance := global_position.distance_to(player.global_position)
	var player_safe := is_safe(player.global_position)
	var outside_territory := not within_territory(player.global_position)
	if player.dead or player_safe or distance > give_up_range or outside_territory:
		chasing = false
	elif distance <= detection_range and has_line_of_sight(player.global_position):
		chasing = true
	if chasing:
		destination = player.global_position
		if kind == "uivador" and call_cooldown <= 0 and has_line_of_sight(player.global_position):
			special_attack = "call"
			windup_remaining = 2.0
			combat_visible = 4
			queue_redraw()
		else: try_attack()
	else:
		if origin in ["guardiao", "templo"]:
			destination = home
		wander_time -= delta
		if origin not in ["guardiao", "templo"] and (wander_time <= 0.0 or global_position.distance_to(destination) < 8.0):
			wander_time = 3.0
			wander_angle += 1.7
			destination = home + Vector2.from_angle(wander_angle) * wander_radius
	var direction := (destination - global_position).normalized()
	var speed := chase_speed if chasing else wander_speed
	var moving := (destination - global_position).length() > 3.0 and (not chasing or distance > attack_range * 0.8)
	if kind in ["esqueleto", "acolito"] and chasing:
		if distance < 130:
			direction = -direction
			moving = true
		elif distance > 205 or not has_line_of_sight(player.global_position): moving = true
		else: moving = false
	if kind == "guardiao_ilha" and chasing: moving = distance > (175 if pattern % 2 == 0 else 330)
	if windup_remaining > 0: moving = false
	velocity = Vector2.ZERO
	if moving:
		# Desvio local simples; o corpo físico nunca atravessa árvores ou bordas.
		for angle in [0.0, PI / 4, -PI / 4, PI / 2, -PI / 2]:
			var motion := direction.rotated(angle) * speed * delta
			if not within_territory(global_position + motion):
				continue
			if is_safe(global_position + motion):
				continue
			if not test_move(global_transform, motion):
				velocity = motion / delta
				break
	move_and_slide()


func _draw() -> void:
	if is_instance_valid(player) and chasing and kind not in ["esqueleto", "acolito"] and attack_cooldown < 0.3:
		var aim := (player.global_position - global_position).angle()
		draw_arc(Vector2.ZERO, attack_range, aim - 0.5, aim + 0.5, 12, Color("ffc16c"), 3)
	if attack_visual > 0:
		draw_set_transform(attack_direction * sin(attack_visual / 0.2 * PI) * 5)
	if kind != "criatura":
		draw_monster()
		return
	draw_set_transform(Vector2(0, 3), 0.0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 22, Color(0.08, 0.1, 0.12, 0.35))
	draw_set_transform(Vector2.ZERO)
	if attack_visual > 0: draw_set_transform(attack_direction * sin(attack_visual / 0.2 * PI) * 5)
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
	if combat_visible > 0:
		draw_rect(Rect2(-22, -48, 44, 5), Color("302c42"))
		draw_rect(Rect2(-22, -48, 44.0 * health / max_health, 5), Color("db866a"))

func draw_monster() -> void:
	if kind in ["cacador", "brutamonte", "sentinela", "uivador", "guardiao_ilha"]:
		var radius := 15.0 if kind == "cacador" else (28.0 if kind == "guardiao_ilha" else 23.0)
		var body := Color("5b687d") if kind == "cacador" else (Color("566e67") if kind == "guardiao_ilha" else Color("8c7866"))
		if kind == "sentinela": body = Color("5c506e")
		if kind == "uivador": body = Color("a16952")
		draw_circle(Vector2(0, -15), radius, body)
		for side in [-1, 1]:
			draw_circle(Vector2(side * radius, -8), radius * 0.4, body.darkened(0.2))
			draw_circle(Vector2(side * 7, -24), 3, Color("f8d590"))
			draw_line(Vector2(side * 10, 0), Vector2(side * 14, 9), body.darkened(0.2), 8)
		if kind == "guardiao_ilha":
			for side in [-1, 1]: draw_polyline(PackedVector2Array([Vector2(side * 16, -33), Vector2(side * 25, -55), Vector2(side * 34, -43)]), Color("b9c5ad"), 7)
		if kind == "sentinela":
			draw_rect(Rect2(-15, -30, 30, 25), Color("36324d"))
			draw_polyline(PackedVector2Array([Vector2(-10, -18), Vector2(0, -26), Vector2(10, -18), Vector2(0, -10), Vector2(-10, -18)]), Color("be9ce4"), 3)
		if kind == "uivador":
			for side in [-1, 1]: draw_line(Vector2(side * 12, -28), Vector2(side * 26, -45), Color("e3bc86"), 6)
		if windup_remaining > 0:
			var color := Color("93deea") if special_attack == "volley" else Color("ffcb77")
			if special_attack == "call":
				draw_arc(Vector2.ZERO, 35 + (2 - windup_remaining) * 35, 0, TAU, 32, Color("ff9d83"), 4)
				draw_string(IslandTheme.BODY, Vector2(-30, -62), "CHAMADO", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("ffcf9f"))
			elif special_attack == "slam": draw_arc(Vector2.ZERO, attack_range, 0, TAU, 24, color, 3)
			else:
				for angle in ([-0.22, 0.0, 0.22] if special_attack == "volley" else [0.0]): draw_line(Vector2.ZERO, shot_direction.rotated(angle) * (120 if special_attack == "volley" else 95), color, 3)
			draw_arc(Vector2(0, -25), radius + 8, 0, TAU, 24, color, 3)
	elif kind in ["esqueleto", "acolito"]:
		if kind == "acolito":
			draw_colored_polygon(PackedVector2Array([Vector2(-14, -24), Vector2(14, -24), Vector2(21, 8), Vector2(-21, 8)]), Color("49365d"))
			draw_arc(Vector2(0, -30), 17, PI, TAU, 16, Color("a586c8"), 5)
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
	if combat_visible > 0:
		draw_rect(Rect2(-22, -52, 44, 5), Color("302c42"))
		draw_rect(Rect2(-22, -52, 44.0 * health / max_health, 5), Color("db866a"))
