extends Node2D

const STRUCTURE := preload("res://scenes/placed_structure.tscn")
@export var placement_distance: float = 110.0
@export var sleep_enemy_distance: float = 260.0
var player: CharacterBody2D
var inventory: ResourceInventory
var hud: CanvasLayer
var cycle: DayNightCycle
var container: Node2D
var map_size := Vector2(2304, 1536)
var active := false
var slot_index := -1
var item := ""
var preview_point := Vector2.ZERO
var valid := false
var respawn_bed: PlacedStructure
var placement_armed := false

func start_placement(index: int) -> bool:
	var data := inventory.slots
	if index < 0 or index >= data.size() or data[index].get("item", "") not in ["cama", "fogueira", "bau"]:
		return false
	slot_index = index
	item = data[index].item
	hud.set_panel("")
	active = true
	placement_armed = false
	set_deferred("placement_armed", true)
	player.get_node("Interaction").set_blocked(true)
	hud.show_message("Colocar: clique confirma · Esc / botão direito cancela")
	update_preview(player.global_position + player.facing * 85)
	return true

func update_preview(point: Vector2) -> void:
	preview_point = player.global_position + (point - player.global_position).limit_length(placement_distance)
	preview_point = preview_point.snapped(Vector2(8, 8))
	valid = can_place(preview_point)
	queue_redraw()

func can_place(point: Vector2) -> bool:
	if not Rect2(Vector2(48, 48), map_size - Vector2(96, 96)).has_point(point):
		return false
	var shape := RectangleShape2D.new()
	shape.size = Vector2(64, 48)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0, point)
	query.collision_mask = 7
	return player.get_world_2d().direct_space_state.intersect_shape(query).is_empty()

func confirm() -> bool:
	if not active or get_tree().paused or not can_place(preview_point):
		return false
	if not inventory.consume_slot(slot_index, item):
		cancel()
		return false
	var structure := STRUCTURE.instantiate() as PlacedStructure
	structure.kind = item
	structure.position = preview_point
	structure.system = self
	container.add_child(structure)
	cancel()
	return true

func cancel() -> void:
	active = false
	player.get_node("Interaction").set_blocked(hud.current_panel != "" or player.dead)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseMotion and not MobileInput.enabled:
		update_preview(player.get_canvas_transform().affine_inverse() * event.position)
	if event.is_action_pressed("close_panel") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed):
		cancel()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("hit"):
		if MobileInput.enabled: return
		if not placement_armed:
			get_viewport().set_input_as_handled()
			return
		update_preview(player.get_canvas_transform().affine_inverse() * event.position)
		confirm()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("use_tool") or event.is_action_pressed("collect"):
		get_viewport().set_input_as_handled()

func _physics_process(_delta: float) -> void:
	if active and not MobileInput.enabled:
		update_preview(get_global_mouse_position())

func use_bed(bed: PlacedStructure) -> String:
	respawn_bed = bed
	if not cycle.is_night():
		return "Ponto de reaparecimento definido. Durma aqui à noite."
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.global_position.distance_to(bed.global_position) < sleep_enemy_distance:
			return "Dormir bloqueado: inimigo próximo. Ponto de reaparecimento definido."
	cycle.sleep_until_dawn()
	# Aplica a regra já no salto de tempo, sem esperar outro frame.
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.begin_dawn()
	return "Você dormiu até o amanhecer."

func near_fire(point: Vector2) -> bool:
	for structure in get_tree().get_nodes_in_group("campfires"):
		if point.distance_to(structure.global_position) > 100: continue
		var ray := PhysicsRayQueryParameters2D.create(point, structure.global_position, 1)
		var collision := player.get_world_2d().direct_space_state.intersect_ray(ray)
		if collision.is_empty() or collision.collider == structure: return true
	return false

func respawn_point(fallback: Vector2) -> Vector2:
	if is_instance_valid(respawn_bed):
		for offset in [Vector2(0, 55), Vector2(0, -55), Vector2(65, 0), Vector2(-65, 0)]:
			var point: Vector2 = respawn_bed.global_position + offset
			if can_place(point):
				return point
	return fallback

func _draw() -> void:
	if active:
		var color := Color(0.3, 0.95, 0.4, 0.65) if valid else Color(1, 0.25, 0.25, 0.65)
		draw_rect(Rect2(preview_point - Vector2(32, 24), Vector2(64, 48)), color)
		draw_string(ThemeDB.fallback_font, preview_point + Vector2(-25, -30), ItemCatalog.title(item), HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
