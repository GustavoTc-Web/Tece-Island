extends Node2D

const PLAYER := preload("res://scenes/player.tscn")
const INVENTORY := preload("res://scripts/inventory.gd")
const WEAPONS := preload("res://scripts/weapon_system.gd")
const MOB := preload("res://scenes/forest_creature.tscn")
const DROP := preload("res://scenes/resource_drop.tscn")
const SPAWNS: Array[Vector2] = [Vector2(140, 160), Vector2(340, 160)]
@export var friendly_fire: bool = true
@export var initial_reserve: int = 16
@export var snapshot_interval: float = 0.05
@export var input_timeout: float = 0.4
var actors: Dictionary = {}
var enemy: ForestCreature
var drop: ResourceDrop
var revision: int = 0
var last_revision: int = -1
var snapshot_clock: float = 0
var action_sequence: int = 0
var shot_sequence: int = 0
var last_shot: int = 0
var hud_initialized := false
var dropped_items: Dictionary = {}
var next_drop_id := 1

func _ready() -> void:
	add_to_group("arena_combat_feedback")
	$Controls.arena = self
	$HUD.network_mode = true
	$HUD.panel_toggled.connect(_panel_toggled)
	$HUD.network_action_requested.connect(request_action)
	$HUD.respawn_requested.connect(func(): request_action("respawn"))
	$HUD.placement_requested.connect(func(_index): $HUD.show_message("Construções fora da arena de teste"))
	$HUD.get_node("Controls/Rows/Instructions").text = "Arena multiplayer · WASD / setas · F / mouse · E · R"
	$HUD.get_node("Controls/Rows/Time").text = "Teste local · até dois jogadores"
	if multiplayer.is_server():
		add_actor(1, true)
		create_enemy()
		drop = DROP.instantiate() as ResourceDrop
		drop.position = Vector2(450, 600)
		drop.quantity = 5
		$Objects.add_child(drop)
	else:
		join_ready.rpc_id(1)

func local_id() -> int:
	return multiplayer.get_unique_id()

func local_blocked() -> bool:
	return not actors.has(local_id()) or $HUD.current_panel != "" or actors[local_id()].body.dead

func add_actor(id: int, server: bool) -> void:
	if actors.has(id): return
	var body = PLAYER.instantiate()
	body.name = "Player_%d" % id
	body.network_controlled = true
	body.simulation_authority = server
	body.identity_label = "P1 · anfitrião" if id == 1 else "P2 · convidado"
	body.identity_color = Color("d9a441") if id == 1 else Color("71b5d1")
	body.position = SPAWNS[0 if id == 1 else 1]
	body.collision_mask = 7
	var camera: Camera2D = body.get_node("Camera2D")
	camera.limit_right = 1280
	camera.limit_bottom = 900
	camera.enabled = id == local_id()
	var interaction := body.get_node("Interaction")
	interaction.set_physics_process(false)
	interaction.set_process_input(false)
	interaction.set_process_unhandled_input(false)
	$Objects.add_child(body)
	var inv := ResourceInventory.new()
	inv.name = "Inventory"
	body.add_child(inv)
	inv.equipment_changed.connect(body.show_equipment)
	inv.changed.connect(func(_wood, _stone): body.protection = inv.armor_protection())
	var record := {"body": body, "inventory": inv, "spawn": body.position, "movement": Vector2.ZERO, "aim": Vector2.RIGHT, "mouse": false, "front": false, "panel": false, "age": 0.0, "cooldown": 0.0, "input_seq": -1, "action_seq": -1, "window": 0, "requests": 0}
	if server:
		inv.add_resource("pistola", 1)
		inv.add_resource("municao_pistola", initial_reserve)
		inv.equip("pistola")
		inv.set_loaded_ammo("pistola", GunRules.WEAPONS.pistola.magazine)
		var weapon := Node.new()
		weapon.set_script(WEAPONS)
		weapon.name = "Weapons"
		weapon.player = body
		weapon.inventory = inv
		weapon.container = $Objects
		weapon.hit_players = true
		weapon.shot_fired.connect(_shot_fired.bind(id))
		weapon.message_requested.connect(_feedback.bind(id))
		body.add_child(weapon)
		record.weapons = weapon
	actors[id] = record
	if server: server_respawn(id)
	if id == local_id():
		$HUD.initialize(inv)
		inv.changed.connect($HUD.update_counts)
		body.health_changed.connect($HUD.update_health)
		$HUD.update_counts(inv.wood, inv.stone)
		hud_initialized = true

func create_enemy() -> void:
	enemy = MOB.instantiate() as ForestCreature
	enemy.position = Vector2(980, 620)
	enemy.safe_centers = SPAWNS.duplicate()
	enemy.safe_radius = 90
	enemy.simulation_authority = multiplayer.is_server()
	enemy.player = actors[1].body if actors.has(1) else null
	$Objects.add_child(enemy)
	enemy.set_physics_process(multiplayer.is_server())

@rpc("any_peer", "call_remote", "reliable")
func join_ready() -> void:
	if not multiplayer.is_server(): return
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 1 or sender not in multiplayer.get_peers(): return
	if not actors.has(sender) and actors.size() < 2:
		add_actor(sender, true)
		$HUD.show_message("Convidado conectado. Dois jogadores na arena.")
	if actors.has(sender): initial_snapshot.rpc_id(sender, make_snapshot())

func remove_peer(id: int) -> void:
	if id == 1 or not actors.has(id): return
	var body: Node = actors[id].body
	$Objects.remove_child(body)
	body.queue_free()
	actors.erase(id)
	if multiplayer.is_server(): $HUD.show_message("O convidado saiu. Aguardando outra conexão.")

func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		for id in actors:
			var actor: Dictionary = actors[id]
			actor.age += delta
			actor.cooldown = maxf(0, actor.cooldown - delta)
			if actor.age > input_timeout:
				actor.movement = Vector2.ZERO
				actor.mouse = false
				actor.front = false
			actor.body.step_movement(delta, actor.movement)
			if not actor.panel and not actor.body.dead and (actor.mouse or actor.front):
				server_fire(id, actor.body.facing if actor.front else actor.aim)
		choose_enemy_target()
		snapshot_clock -= delta
		if snapshot_clock <= 0:
			snapshot_clock = snapshot_interval
			revision += 1
			var state := make_snapshot()
			for id in actors:
				if id != 1: receive_snapshot.rpc_id(id, state)
	update_local_hud()

func choose_enemy_target() -> void:
	if not is_instance_valid(enemy) or enemy.dead: return
	var closest: CharacterBody2D
	var distance := INF
	for actor in actors.values():
		var body: CharacterBody2D = actor.body
		if body.dead or enemy.is_safe(body.position): continue
		var next := enemy.position.distance_squared_to(body.position)
		if next < distance:
			closest = body
			distance = next
	enemy.player = closest
	if closest == null:
		enemy.velocity = Vector2.ZERO
		enemy.chasing = false

func submit_input(seq: int, movement: Vector2, aim: Vector2, mouse: bool, front: bool) -> void:
	if multiplayer.is_server(): accept_input(1, seq, movement, aim, mouse, front)
	else: input_requested.rpc_id(1, seq, movement, aim, mouse, front)

@rpc("any_peer", "call_remote", "unreliable_ordered", 2)
func input_requested(seq: int, movement: Vector2, aim: Vector2, mouse: bool, front: bool) -> void:
	if multiplayer.is_server(): accept_input(multiplayer.get_remote_sender_id(), seq, movement, aim, mouse, front)

func accept_input(id: int, seq: int, movement: Vector2, aim: Vector2, mouse: bool, front: bool) -> void:
	if not multiplayer.is_server() or not actors.has(id) or not movement.is_finite() or not aim.is_finite(): return
	var actor: Dictionary = actors[id]
	if seq <= actor.input_seq: return
	actor.input_seq = seq
	actor.age = 0.0
	actor.aim = aim.normalized()
	actor.movement = movement.limit_length(1) if not actor.panel else Vector2.ZERO
	actor.mouse = mouse and not actor.panel
	actor.front = front and not actor.panel

func request_action(action: String, argument: Variant = null) -> void:
	action_sequence += 1
	if multiplayer.is_server(): accept_action(1, action_sequence, action, argument)
	else: action_requested.rpc_id(1, action_sequence, action, argument)

@rpc("any_peer", "call_remote", "reliable")
func action_requested(seq: int, action: String, argument: Variant = null) -> void:
	if multiplayer.is_server(): accept_action(multiplayer.get_remote_sender_id(), seq, action, argument)

func accept_action(id: int, seq: int, action: String, argument: Variant = null) -> void:
	if not multiplayer.is_server() or not actors.has(id): return
	var actor: Dictionary = actors[id]
	if seq <= actor.action_seq: return
	actor.action_seq = seq
	var second := floori(Time.get_ticks_msec() / 1000.0)
	if second != actor.window:
		actor.window = second
		actor.requests = 0
	actor.requests += 1
	if actor.requests > 30: return
	if action == "panel" and argument is bool:
		actor.panel = argument
		actor.body.controls_blocked = argument or actor.body.dead
		actor.movement = Vector2.ZERO
		actor.mouse = false
		actor.front = false
		return
	if action == "respawn":
		if actor.body.dead: server_respawn(id)
		return
	if actor.body.dead: return
	if action == "select" and argument is int and not actor.panel:
		actor.mouse = false
		actor.front = false
		actor.inventory.select_quick(argument)
		return
	if action == "swap" and argument is Vector2i and actor.panel:
		actor.inventory.swap_slots(argument.x, argument.y)
		return
	if action == "discard" and argument is Dictionary and argument.get("index") is int and argument.get("whole") is bool:
		var before := $Objects.get_child_count()
		if DropRules.discard(actor.inventory, argument.index, argument.whole, actor.body, $Objects, Vector2(1280, 900)):
			var object := $Objects.get_child(before)
			dropped_items[next_drop_id] = object
			next_drop_id += 1
		else: _feedback("Descarte bloqueado: inventário ou terreno inválido.", id)
		return
	if action == "use" and argument is int:
		_feedback(actor.body.get_node("Needs").use_slot(actor.inventory, argument), id)
		return
	# Equipamento por interface funciona com painel aberto; ações do mundo não.
	if action == "equip" and argument is String and argument in ["maos", "machado", "picareta", "espada", "pistola", "espingarda"]:
		if not actor.inventory.equip(argument): _feedback("Essa ferramenta não está no inventário.", id)
		return
	if action == "equip_slot" and argument is int:
		actor.inventory.equip_slot(argument)
		return
	if actor.panel: return
	match action:
		"fire_front": server_fire(id, actor.body.facing)
		"fire_mouse":
			if argument is Vector2 and argument.is_finite(): server_fire(id, argument.normalized())
		"reload": actor.weapons.reload()
		"collect": server_collect(id)
	# Não existem ações para fornecer itens, escolher dano ou editar outro jogador.

func server_fire(id: int, direction: Vector2) -> bool:
	if not multiplayer.is_server() or not actors.has(id) or not direction.is_finite(): return false
	var actor: Dictionary = actors[id]
	if actor.cooldown > 0 or actor.panel or actor.body.dead or direction.length_squared() < 0.5: return false
	var tool: String = actor.inventory.equipped_tool()
	if ItemCatalog.is_consumable(actor.inventory.selected_data().get("item", "")): return false
	if GunRules.WEAPONS.has(tool):
		actor.cooldown = GunRules.WEAPONS[tool].interval
		actor.weapons.friendly_fire = friendly_fire
		return actor.weapons.fire(direction)
	actor.cooldown = ResourceRules.hit_interval(tool)
	if not is_instance_valid(enemy) or enemy.dead: return false
	var offset: Vector2 = enemy.anchor() - actor.body.position
	if offset.length() > 50 or offset.normalized().dot(direction) < 0.7071: return false
	var ray := PhysicsRayQueryParameters2D.create(actor.body.position, enemy.anchor(), 5)
	ray.exclude = [actor.body.get_rid()]
	var collision := get_world_2d().direct_space_state.intersect_ray(ray)
	if not collision.is_empty() and collision.collider != enemy: return false
	actor.body.show_swing(direction, 50)
	return enemy.receive_damage(ResourceRules.combat_damage(tool))

func server_collect(id: int) -> int:
	if not multiplayer.is_server() or not actors.has(id): return 0
	var actor: Dictionary = actors[id]
	var chosen := nearest_drop(actor.body)
	if chosen == null: return 0
	var kind := chosen.resource
	var amount := chosen.collect(actor.inventory)
	_feedback("+%d %s" % [amount, ItemCatalog.title(kind)] if amount else "Inventário cheio", id)
	return amount

func nearest_drop(body: CharacterBody2D) -> ResourceDrop:
	var chosen: ResourceDrop
	var nearest := 70.0
	for object in [drop] + dropped_items.values():
		if not is_instance_valid(object) or object.quantity <= 0: continue
		var distance := body.position.distance_to(object.position)
		if distance > nearest: continue
		var ray := PhysicsRayQueryParameters2D.create(body.position, object.position, 1)
		if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty(): continue
		chosen = object
		nearest = distance
	return chosen

func server_respawn(id: int) -> void:
	if not multiplayer.is_server() or not actors.has(id): return
	var actor: Dictionary = actors[id]
	var shape := CircleShape2D.new()
	shape.radius = 14
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = 7
	query.exclude = [actor.body.get_rid()]
	for offset in [Vector2.ZERO, Vector2(40, 0), Vector2(-40, 0), Vector2(0, 40), Vector2(0, -40)]:
		var point: Vector2 = actor.spawn + offset
		query.transform = Transform2D(0, point)
		if get_world_2d().direct_space_state.intersect_shape(query).is_empty():
			actor.body.respawn(point)
			actor.body.collision_layer = 2
			actor.body.controls_blocked = false
			actor.panel = false
			actor.mouse = false
			actor.front = false
			actor.cooldown = 0
			return # Não aplica o kit novamente.
	_feedback("Ponto ocupado. Tente reaparecer novamente.", id)

func _panel_toggled(open: bool) -> void:
	$Controls.clear_held()
	request_action("panel", open)

func update_local_hud() -> void:
	if not hud_initialized or not actors.has(local_id()): return
	var body: CharacterBody2D = actors[local_id()].body
	$HUD.update_health(body.health, body.max_health)
	$HUD.update_needs(body.get_node("Needs").hunger, body.get_node("Needs").thirst)
	if body.dead and not $HUD.showing_death:
		$HUD.set_panel("")
		$HUD.show_death(true)
		$Controls.clear_held()
	elif not body.dead and $HUD.showing_death: $HUD.show_death(false)
	if multiplayer.is_server():
		for actor in actors.values():
			if actor.body.dead: actor.body.collision_layer = 0
	var prompt := ""
	var chosen := nearest_drop(body)
	if not local_blocked() and chosen != null:
		prompt = "E — Recolher %d %s (compartilhado)" % [chosen.quantity, ItemCatalog.title(chosen.resource)]
	$HUD.show_pickup(prompt)
	$HUD.get_node("Controls/Rows/Time").text = "%s · jogadores %d/2 · dano entre jogadores: %s" % ["Anfitrião" if local_id() == 1 else "Convidado", actors.size(), "ligado" if friendly_fire else "desligado"]

func _feedback(message: String, id: int) -> void:
	if id == 1: $HUD.show_message(message)
	else: feedback.rpc_id(id, message)

@rpc("authority", "call_remote", "reliable")
func feedback(message: String) -> void:
	$HUD.show_message(message)

func make_snapshot() -> Dictionary:
	var state := {"revision": revision, "friendly_fire": friendly_fire, "actors": {}, "mob": {"alive": false}, "drop": {"quantity": 0}}
	for id in actors:
		var actor: Dictionary = actors[id]
		state.actors[id] = {"position": actor.body.position, "facing": actor.body.facing, "health": actor.body.health, "dead": actor.body.dead, "flash": actor.body.damage_flash, "inventory": actor.inventory.network_state()}
		state.actors[id].hunger = actor.body.get_node("Needs").hunger
		state.actors[id].thirst = actor.body.get_node("Needs").thirst
	if is_instance_valid(enemy) and not enemy.dead:
		state.mob = {"alive": true, "position": enemy.position, "health": enemy.health, "flash": enemy.flash_time, "combat_visible": enemy.combat_visible, "attack_visual": enemy.attack_visual, "attack_direction": enemy.attack_direction}
	if is_instance_valid(drop) and drop.quantity > 0:
		state.drop = {"quantity": drop.quantity, "position": drop.position}
	state.drops = {}
	for id in dropped_items:
		var object = dropped_items[id]
		if is_instance_valid(object) and object.quantity > 0:
			state.drops[id] = {"item": object.resource, "quantity": object.quantity, "attributes": object.attributes.duplicate(true), "position": object.position}
	return state

@rpc("authority", "call_remote", "reliable")
func initial_snapshot(state: Dictionary) -> void:
	apply_snapshot(state)
	$HUD.show_message("Conectado. Estado atual recebido do anfitrião.")

@rpc("authority", "call_remote", "reliable", 1)
func receive_snapshot(state: Dictionary) -> void:
	apply_snapshot(state)

func apply_snapshot(state: Dictionary) -> void:
	if not is_inside_tree(): return
	if multiplayer.is_server() or int(state.revision) <= last_revision: return
	last_revision = state.revision
	for id in dropped_items.keys():
		if not state.get("drops", {}).has(id):
			if is_instance_valid(dropped_items[id]): dropped_items[id].queue_free()
			dropped_items.erase(id)
	for id in state.get("drops", {}):
		var data: Dictionary = state.drops[id]
		if not dropped_items.has(id):
			var object := DROP.instantiate() as ResourceDrop
			$Objects.add_child(object)
			dropped_items[id] = object
		var object: ResourceDrop = dropped_items[id]
		object.resource = data.item
		object.quantity = data.quantity
		object.attributes = data.attributes.duplicate(true)
		object.position = data.position
		object.queue_redraw()
	friendly_fire = state.friendly_fire
	for id in actors.keys():
		if not state.actors.has(id): remove_peer(id)
	for id in state.actors:
		if not actors.has(id): add_actor(id, false)
		var data: Dictionary = state.actors[id]
		var actor: Dictionary = actors[id]
		actor.body.position = data.position
		actor.body.facing = data.facing
		actor.body.health = data.health
		actor.body.dead = data.dead
		actor.body.damage_flash = data.flash
		actor.body.get_node("Needs").hunger = data.get("hunger", 100.0)
		actor.body.get_node("Needs").thirst = data.get("thirst", 100.0)
		actor.body.collision_layer = 0 if data.dead else 2
		actor.inventory.apply_network_state(data.inventory)
		actor.body.queue_redraw()
	if state.mob.alive:
		if not is_instance_valid(enemy): create_enemy()
		enemy.position = state.mob.position
		enemy.health = state.mob.health
		enemy.flash_time = state.mob.flash
		enemy.combat_visible = state.mob.get("combat_visible", 0)
		enemy.attack_visual = state.mob.get("attack_visual", 0)
		enemy.attack_direction = state.mob.get("attack_direction", Vector2.RIGHT)
		enemy.queue_redraw()
	elif is_instance_valid(enemy):
		enemy.queue_free()
		enemy = null
	if state.drop.quantity > 0:
		if not is_instance_valid(drop):
			drop = DROP.instantiate() as ResourceDrop
			$Objects.add_child(drop)
		drop.position = state.drop.position
		drop.quantity = state.drop.quantity
		drop.queue_redraw()
	elif is_instance_valid(drop):
		drop.queue_free()
		drop = null

func _shot_fired(point: Vector2, direction: Vector2, weapon: String, owner_id: int) -> void:
	shot_sequence += 1
	for id in actors:
		if id != 1: shot_effect.rpc_id(id, shot_sequence, owner_id, point, direction, weapon)

@rpc("authority", "call_remote", "reliable")
func shot_effect(sequence: int, owner_id: int, point: Vector2, direction: Vector2, weapon: String) -> void:
	if sequence <= last_shot or not actors.has(owner_id): return
	last_shot = sequence
	var bullet = preload("res://scenes/projectile.tscn").instantiate()
	var rule: Dictionary = GunRules.WEAPONS[weapon]
	bullet.position = point
	bullet.direction = direction
	bullet.speed = rule.speed
	bullet.remaining = rule.range
	bullet.damage = 0
	bullet.arrow = weapon == "arco"
	bullet.hit_players = true
	bullet.simulation_authority = false # Efeito não confirma dano nem consome munição.
	bullet.shooter = actors[owner_id].body.get_rid()
	$Objects.add_child(bullet)
	actors[owner_id].body.show_swing(direction, 20, "arrow" if weapon == "arco" else "shot")

func send_combat_feedback(point: Vector2, effect: String, aim: Vector2) -> void:
	for id in multiplayer.get_peers(): combat_feedback.rpc_id(id, point, effect, aim)

@rpc("authority", "call_remote", "reliable")
func combat_feedback(point: Vector2, effect: String, aim: Vector2) -> void:
	CombatEffect.emit_at(self, point, effect, aim, false)
