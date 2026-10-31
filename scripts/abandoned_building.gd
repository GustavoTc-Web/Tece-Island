class_name AbandonedBuilding
extends Node2D

const CONTAINER := preload("res://scenes/loot_container.tscn")
const CREATURE := preload("res://scenes/forest_creature.tscn")
@export_enum("casa", "castelo", "fazenda", "barro", "posto") var kind := "casa"
var footprint := Vector2(240, 180)
var initialized := false
var has_loot := false
var has_guardian := false
var rolled_weapon := ""
var guardian: ForestCreature
var loot: Node2D
var guardians: Array[ForestCreature] = []
var guardian_count := 0
var name_visible := false
var floor_visual: Node2D
var interior_revealed := false
var cleared_guards: Array[int] = []

func show_name(value: bool) -> void:
	if name_visible == value: return
	name_visible = value
	queue_redraw()

func _ready() -> void:
	if kind == "castelo": footprint = Vector2(320, 240)
	if kind == "fazenda": footprint = Vector2(280, 200)
	if kind == "posto": footprint = Vector2(280, 200)
	# Sem telhado: paredes laterais e entrada inferior de 90 px deixam o interior visível.
	wall(Vector2(0, -footprint.y / 2), Vector2(footprint.x, 14))
	wall(Vector2(-footprint.x / 2, 0), Vector2(14, footprint.y))
	wall(Vector2(footprint.x / 2, 0), Vector2(14, footprint.y))
	var segment := (footprint.x - 90) / 2
	wall(Vector2(-(45 + segment / 2), footprint.y / 2), Vector2(segment, 14))
	wall(Vector2(45 + segment / 2, footprint.y / 2), Vector2(segment, 14))
	create_floor()
	queue_redraw()

func create_floor() -> void:
	# Floors cannot share the building's Y-sort anchor: they would cover actors
	# and drops north of that anchor. Keep the complete floor below WorldObjects.
	floor_visual = preload("res://scripts/building_floor.gd").new()
	floor_visual.source = self
	var objects := get_parent()
	var sorted: bool = objects is Node2D and objects.y_sort_enabled
	var ground_parent := objects.get_parent() if sorted else objects
	ground_parent.add_child(floor_visual)
	floor_visual.global_transform = global_transform
	floor_visual.modulate = modulate
	ground_parent.move_child(floor_visual, objects.get_index() if sorted else get_index())

func _exit_tree() -> void:
	if is_instance_valid(floor_visual) and not floor_visual.is_queued_for_deletion(): floor_visual.queue_free()

func draw_floor(canvas: Node2D) -> void:
	canvas.draw_rect(Rect2(-footprint / 2, footprint), Color("6d7352") if kind != "fazenda" else Color("a39361"))
	# The rear wall belongs behind actors too: a sprite near it extends above
	# its feet and must not be sliced at the building's central Y-sort anchor.
	var half := footprint / 2
	var color := Color("85847a") if kind == "castelo" else Color("866c4f")
	if kind in ["barro", "posto"]: color = Color("bc8a52")
	canvas.draw_rect(Rect2(-half, Vector2(footprint.x, 14)), color)
	if kind == "castelo":
		for x in [-half.x, half.x]: canvas.draw_rect(Rect2(Vector2(x - 20, -half.y - 15), Vector2(40, 32)), Color("949589"))

func register_guard(creature: ForestCreature) -> void:
	var index := guardians.size()
	guardians.append(creature)
	creature.set_meta("interior_owner", self)
	creature.set_meta("activity_active", false)
	creature.set_meta("activity_layer", creature.collision_layer)
	creature.hide()
	creature.set_physics_process(false)
	creature.collision_layer = 0
	creature.wounded.connect(queue_interior_save)
	creature.defeated.connect(func():
		if index not in cleared_guards: cleared_guards.append(index)
		queue_interior_save())
	if not guardians.is_empty(): guardian = guardians[0]

func reveal_near(point: Vector2) -> void:
	if interior_revealed: return
	var doorway := global_position + Vector2(0, footprint.y / 2)
	if point.distance_to(doorway) <= 110 or Rect2(global_position - footprint / 2 + Vector2(15, 15), footprint - Vector2(30, 30)).has_point(point):
		interior_revealed = true
		queue_interior_save()

func queue_interior_save() -> void:
	var world := get_parent().get_parent()
	if world != null and world.has_method("queue_save"): world.queue_save()

func capture_interior() -> Dictionary:
	var health := {}
	for index in range(guardians.size()):
		var creature := guardians[index]
		if is_instance_valid(creature) and not creature.dead: health[str(index)] = creature.health
	return {"revealed":interior_revealed,"cleared":cleared_guards.duplicate(),"health":health}

static func valid_interiors(data: Variant) -> bool:
	if not data is Dictionary: return false
	for entry in data.values():
		if not entry is Dictionary or not entry.get("revealed") is bool or not entry.get("cleared") is Array or not entry.get("health") is Dictionary: return false
		var seen := {}
		for index in entry.cleared:
			if not (index is int or index is float) or index < 0 or index > 3 or index != int(index) or seen.has(str(int(index))): return false
			seen[str(int(index))] = true
		for key in entry.health:
			var value: Variant = entry.health[key]
			if str(key) not in ["0","1","2","3"] or seen.has(str(key)) or not (value is int or value is float) or not is_finite(value) or value <= 0 or value > 1000: return false
	return true

func restore_interior(data: Dictionary) -> void:
	interior_revealed = data.revealed
	cleared_guards.assign(data.cleared)
	for index in range(guardians.size()):
		var creature := guardians[index]
		if not is_instance_valid(creature): continue
		if index in cleared_guards:
			# Restore a defeat without emitting defeat/drop signals a second time.
			creature.dead = true
			creature.remove_from_group("enemies")
			creature.collision_layer = 0
			creature.queue_free()
		elif data.health.has(str(index)): creature.health = mini(creature.max_health, int(data.health[str(index)]))

func wall(point: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 6
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	body.position = point
	body.add_child(collision)
	add_child(body)

func populate(random: RandomNumberGenerator, system: Node2D) -> void:
	if initialized:
		return
	initialized = true
	# Sorteios independentes e feitos uma única vez na criação desta partida.
	has_loot = random.randf() < system.loot_chance
	var occupation := random.randf()
	guardian_count = occupation_count(occupation, system.guardian_chance, system.two_guardian_chance)
	has_guardian = guardian_count > 0
	loot = CONTAINER.instantiate()
	loot.position = Vector2(-45, 20)
	if has_loot: loot.contents = roll_contents(random, system.weapon_chance, system.pistol_weight)
	for item in loot.contents:
		if GunRules.WEAPONS.has(item): rolled_weapon = item
	add_child(loot)
	for i in range(guardian_count):
		var creature := CREATURE.instantiate() as ForestCreature
		creature.origin = "guardiao"
		creature.territory_radius = footprint.length() * 0.55
		creature.player = system.player
		creature.position = global_position + Vector2(35 + i * 50, -25)
		get_parent().add_child(creature)
		register_guard(creature)

static func occupation_count(roll: float, occupied: float = 0.30, double: float = 0.02) -> int:
	return 2 if roll < minf(double, occupied) else (1 if roll < occupied else 0)

static func roll_contents(random: RandomNumberGenerator, weapon_chance: float = 0.05, pistol_weight: float = 0.75) -> Dictionary:
	var contents := {}
	if random.randf() < weapon_chance:
		var weapon := "pistola" if random.randf() < pistol_weight else "espingarda"
		contents[weapon] = 1
		contents[GunRules.WEAPONS[weapon].ammo] = random.randi_range(1, 3)
	else:
		var choices := ["madeira", "pedra", "fibra", "municao_pistola", "cartucho", "carne_crua", "carne_cozida", "cantil", "vidro"]
		for i in range(random.randi_range(1, 2)):
			var index := random.randi_range(0, choices.size() - 1)
			contents[choices[index]] = 1 if choices[index] == "cantil" else random.randi_range(1, 3)
			choices.remove_at(index)
	return contents

func _draw() -> void:
	var half := footprint / 2
	var color := Color("85847a") if kind == "castelo" else Color("866c4f")
	if kind in ["barro", "posto"]: color = Color("bc8a52")
	draw_rect(Rect2(-half, Vector2(14, footprint.y)), color)
	draw_rect(Rect2(Vector2(half.x - 14, -half.y), Vector2(14, footprint.y)), color)
	draw_line(Vector2(-half.x, half.y), Vector2(-45, half.y), color, 14)
	draw_line(Vector2(45, half.y), Vector2(half.x, half.y), color, 14)
	# Tábuas decorativas parcialmente escondem o recipiente, sem colisões inacessíveis.
	draw_line(Vector2(-75, 10), Vector2(-20, -12), Color("544d3b"), 7)
	if kind == "fazenda":
		for x in range(-100, 101, 40):
			draw_line(Vector2(x, -60), Vector2(x + 10, -25), Color("615336"), 5)
	if name_visible: draw_string(IslandTheme.BODY, Vector2(-half.x, -half.y - 22), {"casa": "Casa quebrada", "castelo": "Castelo abandonado", "fazenda": "Fazenda misteriosa", "barro": "Ruína de barro", "posto": "Posto abandonado"}[kind], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("eee0b7"))
