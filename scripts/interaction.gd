extends Node

signal target_changed(message: String)
signal pickup_changed(message: String)
signal message_requested(message: String)
signal discard_requested(index: int, whole: bool)
signal use_requested(index: int)

@export var interaction_distance: float = 80.0
@export var combat_distance: float = 50.0
@export var pickup_distance: float = 70.0
var inventory: ResourceInventory
var blocked: bool = false
var cooldown: float = 0.0
var mouse_held: bool = false
var key_held: bool = false
var touch_aim := Vector2.ZERO

func set_touch_aim(direction: Vector2) -> void:
	touch_aim = direction
	if direction != Vector2.ZERO: player.facing = direction.normalized()
var cursor_screen: Vector2 = Vector2.ZERO
var target: Node2D
var weapons: Node
var pickup: Node2D
@onready var player: CharacterBody2D = get_parent()


func _ready() -> void:
	cursor_screen = get_viewport().get_mouse_position()


func cursor_world() -> Vector2:
	# Guarda a posição do evento e reconverte a cada frame: a câmera pode se mover.
	return player.get_canvas_transform().affine_inverse() * cursor_screen


func _physics_process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	update_target(cursor_world(), key_held or touch_aim != Vector2.ZERO)
	update_pickup()
	# Um único relógio atende as duas entradas; F tem prioridade se ambas estão ativas.
	if not blocked and (mouse_held or key_held or touch_aim != Vector2.ZERO):
		strike_target()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		cursor_screen = event.position
	if event.is_action_released("hit"):
		mouse_held = false
	if event.is_action_released("use_tool"):
		key_held = false
	if blocked or event.is_echo():
		return


func _unhandled_input(event: InputEvent) -> void:
	if blocked or event.is_echo():
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit: return
	for index in range(5):
		if event.is_action_pressed("equip_" + str(index + 1)):
			inventory.select_quick(index)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		inventory.select_quick(posmod(inventory.selected_index + (-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1), 5))
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_Q:
		discard_requested.emit(inventory.selected_index, event.shift_pressed)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("reload"):
		weapons.reload()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("hit"):
		if ItemCatalog.is_consumable(inventory.selected_data().get("item", "")):
			use_requested.emit(inventory.selected_index)
			get_viewport().set_input_as_handled()
			return
		mouse_held = true
		var click := event as InputEventMouseButton
		update_target(player.get_canvas_transform().affine_inverse() * click.position, key_held)
		strike_target()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("use_tool"):
		if ItemCatalog.is_consumable(inventory.selected_data().get("item", "")):
			use_requested.emit(inventory.selected_index)
			get_viewport().set_input_as_handled()
			return
		key_held = true
		update_target(Vector2.ZERO, true)
		strike_target()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("collect"):
		collect_nearest()
		get_viewport().set_input_as_handled()


func set_blocked(value: bool) -> void:
	blocked = value
	mouse_held = false
	key_held = false
	touch_aim = Vector2.ZERO
	update_target(cursor_world())
	update_pickup()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		mouse_held = false
		key_held = false
		touch_aim = Vector2.ZERO


func can_reach(candidate: Node2D) -> bool:
	var distance_limit := combat_distance if candidate is ForestCreature or candidate is NeutralAnimal else interaction_distance
	if player.global_position.distance_to(candidate.anchor()) > distance_limit:
		return false
	var ray := PhysicsRayQueryParameters2D.create(player.global_position, candidate.anchor(), 5)
	ray.exclude = [player.get_rid()]
	var collision := player.get_world_2d().direct_space_state.intersect_ray(ray)
	return collision.is_empty() or collision.collider == candidate


func find_target(cursor: Vector2, in_front: bool = false) -> Node2D:
	if blocked or player.dead or get_tree().paused:
		return null
	if inventory != null and GunRules.WEAPONS.has(inventory.equipped_tool()):
		return null
	var chosen: Node2D = null
	var nearest := INF
	var candidates := get_tree().get_nodes_in_group("harvest_resources") + get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("animals")
	for node in candidates:
		var candidate := node as Node2D
		if (candidate is HarvestResource and candidate.exhausted) or ((candidate is ForestCreature or candidate is NeutralAnimal) and candidate.dead):
			continue
		if not can_reach(candidate):
			continue
		var offset: Vector2 = candidate.anchor() - player.global_position
		if in_front:
			# Cone de 90 graus centrado na última direção de movimento.
			if offset.normalized().dot(player.facing.normalized()) < 0.7071:
				continue
			if offset.length_squared() < nearest:
				chosen = candidate
				nearest = offset.length_squared()
		elif candidate.contains_cursor(cursor):
			if chosen == null or candidate.global_position.y > chosen.global_position.y:
				chosen = candidate
	return chosen


func update_target(cursor: Vector2, in_front: bool = false) -> void:
	var chosen := find_target(cursor, in_front)
	if is_instance_valid(target) and target != chosen:
		target.set_highlighted(false)
	target = chosen
	var text := ""
	if is_instance_valid(target):
		target.set_highlighted(true)
		if target is ForestCreature or target is NeutralAnimal:
			text = "F / mouse — Criatura · %d vida" % target.health
		else:
			text = "F / mouse — %s · %d%%" % [target.resource, roundi(target.progress * 100)]
	target_changed.emit(text)


func strike_target() -> bool:
	if blocked or player.dead or get_tree().paused or cooldown > 0.0:
		return false
	var tool := inventory.equipped_tool()
	if ItemCatalog.is_consumable(inventory.selected_data().get("item", "")): return false
	if GunRules.WEAPONS.has(tool):
		cooldown = GunRules.WEAPONS[tool].interval
		var direction: Vector2 = touch_aim.normalized() if touch_aim != Vector2.ZERO else (player.facing if key_held else (cursor_world() - player.global_position).normalized())
		return weapons.fire(direction)
	if not is_instance_valid(target) or not can_reach(target):
		return false
	# Inclusive mensagens inadequadas são limitadas pelo mesmo intervalo.
	cooldown = ResourceRules.hit_interval(tool)
	# A seleção é única para combate e extração: este golpe segue só um ramo.
	if target is ForestCreature or target is NeutralAnimal:
		player.show_swing((target.anchor() - player.global_position).normalized(), combat_distance)
		return target.receive_damage(ResourceRules.combat_damage(tool))
	if not ResourceRules.EXTRACTION[target.resource].hits.has(tool):
		message_requested.emit(ResourceRules.guidance(target.resource))
		return false
	return target.apply_hit(tool)


func hit_at(cursor: Vector2) -> bool:
	update_target(cursor)
	return strike_target()


func update_pickup() -> void:
	var chosen: Node2D = null
	var nearest := pickup_distance * pickup_distance
	if not blocked:
		for node in get_tree().get_nodes_in_group("resource_drops") + get_tree().get_nodes_in_group("interactables"):
			var drop := node as Node2D
			if drop.has_method("can_interact") and not drop.can_interact(): continue
			var distance := player.global_position.distance_squared_to(drop.global_position)
			var ray := PhysicsRayQueryParameters2D.create(player.global_position, drop.global_position, 1)
			var collision := player.get_world_2d().direct_space_state.intersect_ray(ray)
			var reachable: bool = collision.is_empty() or collision.collider == drop
			if (not drop is ResourceDrop or drop.quantity > 0) and reachable and distance <= nearest and (chosen == null or distance < nearest):
				chosen = drop
				nearest = distance
	if is_instance_valid(pickup) and pickup != chosen:
		pickup.set_highlighted(false)
	pickup = chosen
	var text := ""
	if is_instance_valid(pickup):
		pickup.set_highlighted(true)
		text = "E — Recolher %d %s" % [pickup.quantity, ItemCatalog.title(pickup.resource)] if pickup is ResourceDrop else pickup.prompt()
	pickup_changed.emit(text)


func collect_nearest() -> int:
	update_pickup()
	if blocked or player.dead or get_tree().paused:
		return 0
	if not is_instance_valid(pickup):
		message_requested.emit("Aproxime-se de um item ou objeto para interagir.")
		return 0
	if not pickup is ResourceDrop:
		message_requested.emit(pickup.interact(inventory))
		return 0
	var kind: String = pickup.resource
	var amount: int = pickup.collect(inventory)
	message_requested.emit("+%d %s" % [amount, kind] if amount > 0 else "Inventário cheio")
	update_pickup()
	return amount
