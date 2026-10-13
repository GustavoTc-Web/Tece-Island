extends CharacterBody2D

signal health_changed(current: float, maximum: int)
signal died
signal poison_changed(remaining: float)

@export var speed: float = 210.0
@export var max_health: int = 100
@export var invulnerability_duration: float = 0.75
var health: float = 100.0
var protection := 0.0
var regeneration_ticks := 0
var regeneration_clock := 0.0

func renew_regeneration() -> void:
	regeneration_ticks = 5
	regeneration_clock = 0.0

func cancel_regeneration() -> void:
	regeneration_ticks = 0
	regeneration_clock = 0.0

func step_regeneration(delta: float) -> void:
	if get_tree().paused or dead or not simulation_authority or regeneration_ticks == 0: return
	regeneration_clock += delta
	while regeneration_clock >= 1.0 - 0.000001 and regeneration_ticks > 0:
		regeneration_clock = maxf(0, regeneration_clock - 1.0)
		regeneration_ticks -= 1
		health = minf(max_health, health + 5.0)
		health_changed.emit(health, max_health)
var dead: bool = false
var invulnerability: float = 0.0
var damage_flash: float = 0.0
var facing: Vector2 = Vector2.DOWN
var controls_blocked: bool = false
var touch_movement := Vector2.ZERO
var equipped: String = "maos"
var swing_time: float = 0.0
var swing_direction := Vector2.DOWN
var swing_radius: float = 50.0
var swing_kind := "swing"
var network_controlled: bool = false
var simulation_authority: bool = true
var identity_label: String = ""
var identity_color := Color("d9a441")
var poison_remaining := 0.0
var poison_tick := 0.0
var terrain_enabled := false
var swimming := false

func apply_poison(duration: float = 3.0) -> void:
	if dead or not simulation_authority: return
	if poison_remaining <= 0: poison_tick = 1.0
	poison_remaining = duration
	poison_changed.emit(poison_remaining)
	queue_redraw()

func step_poison(delta: float) -> void:
	if poison_remaining <= 0 or dead or not simulation_authority or get_tree().paused: return
	var active_delta := minf(delta, poison_remaining)
	var previous_tenth := ceili(poison_remaining * 10)
	poison_remaining = maxf(0, poison_remaining - delta)
	poison_tick -= active_delta
	while poison_tick <= 0.00001 and not dead:
		receive_damage(1, true)
		poison_tick += 1.0
	if ceili(poison_remaining * 10) != previous_tenth: poison_changed.emit(poison_remaining)
	queue_redraw()


func show_swing(direction: Vector2, radius: float, effect: String = "swing") -> void:
	swing_kind = effect
	swing_direction = direction
	swing_radius = radius
	swing_time = 0.16
	CombatEffect.emit_at(self, global_position, effect, direction)
	queue_redraw()


func _ready() -> void:
	health = max_health


func receive_damage(amount: int, ignore_invulnerability: bool = false) -> bool:
	if not simulation_authority or dead or amount <= 0 or (invulnerability > 0.0 and not ignore_invulnerability) or get_tree().paused:
		return false
	var effective := float(amount) if ignore_invulnerability else float(amount) * 100.0 / (100.0 + clampf(protection, 0, 100))
	health = maxf(0, health - effective)
	invulnerability = invulnerability_duration
	damage_flash = 0.2
	CombatEffect.emit_at(self, global_position + Vector2(0, -18), "damage")
	health_changed.emit(health, max_health)
	if health == 0:
		dead = true
		cancel_regeneration()
		velocity = Vector2.ZERO
		died.emit()
	return true


func respawn(point: Vector2) -> void:
	cancel_regeneration()
	position = point
	facing = Vector2.DOWN
	health = max_health
	dead = false
	velocity = Vector2.ZERO
	invulnerability = invulnerability_duration
	damage_flash = 0.0
	poison_remaining = 0
	poison_changed.emit(0)
	poison_tick = 0
	modulate = Color.WHITE
	health_changed.emit(health, max_health)
	queue_redraw()
	if has_node("Needs"): $Needs.reset()


func _process(delta: float) -> void:
	if swing_time > 0.0:
		swing_time = maxf(0.0, swing_time - delta)
		queue_redraw()
	if damage_flash > 0.0:
		damage_flash = maxf(0.0, damage_flash - delta)
		modulate = Color(1.0, 0.35, 0.35) if damage_flash > 0.0 else Color.WHITE


func show_equipment(tool: String) -> void:
	equipped = tool
	queue_redraw()


func _physics_process(delta: float) -> void:
	step_regeneration(delta)
	step_poison(delta)
	if network_controlled:
		return
	step_movement(delta, Input.get_vector("move_left", "move_right", "move_up", "move_down") + touch_movement)


func step_movement(delta: float, direction: Vector2) -> void:
	# Na rede, só o servidor chama isto, com seu próprio passo de física.
	invulnerability = maxf(0.0, invulnerability - delta)
	if controls_blocked or dead:
		velocity = Vector2.ZERO
		return
	# get_vector limita o comprimento a 1: a diagonal não fica mais rápida.
	direction = direction.limit_length(1.0)
	var water: bool = terrain_enabled and WorldTerrain.is_water(global_position)
	if water != swimming:
		swimming = water
		queue_redraw()
	velocity = direction * speed * (WorldTerrain.SWIM_SPEED if swimming else 1.0)
	if direction != Vector2.ZERO:
		facing = direction
		queue_redraw()
	# CharacterBody2D desliza nas superfícies e aplica a velocidade em pixels/s.
	# A cena usa Floating: na visão de cima não há distinção entre chão e parede.
	move_and_slide()


func _draw() -> void:
	if swimming:
		draw_arc(Vector2(0, -3), 21, 0, PI, 16, Color("94c8db"), 3)
		draw_string(IslandTheme.BODY, Vector2(-15, -52), "Nado", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("c2e4e9"))
	if poison_remaining > 0:
		draw_arc(Vector2.ZERO, 17, 0, TAU, 20, Color("89c866"), 2)
	if swing_time > 0.0 and swing_kind == "swing":
		var angle := swing_direction.angle()
		draw_arc(Vector2.ZERO, swing_radius, angle - PI / 4, angle + PI / 4, 20, Color(1, 0.9, 0.65, swing_time / 0.16), 3)
	# A origem fica nos pés, tanto para a colisão quanto para a ordenação visual.
	draw_ellipse_shadow()
	draw_line(Vector2(-5, -5), Vector2(-5, 1), Color("263c46"), 6.0)
	draw_line(Vector2(5, -5), Vector2(5, 1), Color("263c46"), 6.0)
	draw_style_box(body_style(), Rect2(-11, -25, 22, 22))
	if protection > 0:
		draw_rect(Rect2(-11, -25, 22, 17), Color("9d9ba7"))
		draw_line(Vector2(0, -24), Vector2(0, -9), Color("686775"), 2)
	draw_circle(Vector2(0, -31), 9.0, Color("e6bb8d"))
	draw_circle(Vector2(0, -35), 10.0, Color("68462f"))
	draw_circle(Vector2(0, -31) + facing * 6.0, 3.0, Color("e6bb8d"))
	var arm_motion := swing_direction * sin(swing_time / 0.16 * PI) * 7 if swing_time > 0 else Vector2.ZERO
	draw_line(Vector2(-13, -21), Vector2(-13, -11) + arm_motion, Color("e6bb8d"), 5.0)
	draw_line(Vector2(13, -21), Vector2(13, -11) + arm_motion, Color("e6bb8d"), 5.0)
	draw_tool()
	if identity_label != "":
		draw_string(IslandTheme.BODY, Vector2(-27, -53), identity_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, identity_color)


func draw_tool() -> void:
	if equipped == "maos":
		return
	var hand := Vector2(15 if facing.x >= 0 else -15, -14)
	if swing_time > 0:
		hand += swing_direction * sin(swing_time / 0.16 * PI) * (8 if swing_kind == "swing" else -4)
	var head := hand + Vector2(4, -19)
	if equipped == "arco":
		draw_arc(hand, 15, -PI / 2, PI / 2, 12, Color("b58b55"), 3)
		draw_line(hand + Vector2(0, -15), hand + Vector2(0, 15), Color("ded1a6"), 1)
		return
	if GunRules.WEAPONS.has(equipped):
		draw_line(hand, hand + facing.normalized() * (26 if equipped == "espingarda" else 16), Color("b6c5be"), 6)
		draw_circle(hand, 4, Color("644631"))
		return
	var material: String = ResourceRules.RECIPES[equipped].material
	var color := Color("b58b55") if material == "madeira" else Color("b6c5be")
	draw_line(hand + Vector2(-2, 6), head, Color("795434"), 4.0)
	match ResourceRules.RECIPES[equipped].category:
		"machado": draw_rect(Rect2(head + Vector2(-8, -3), Vector2(14, 10)), color)
		"picareta": draw_line(head + Vector2(-10, 4), head + Vector2(10, -1), color, 5.0)
		"espada": draw_line(hand, head + Vector2(2, -8), color, 5.0)


func draw_ellipse_shadow() -> void:
	draw_set_transform(Vector2(0, 1), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 17.0, Color(0.08, 0.16, 0.12, 0.3))
	draw_set_transform(Vector2.ZERO)


func body_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = identity_color
	style.set_corner_radius_all(6)
	return style
