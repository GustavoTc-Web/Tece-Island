extends Node

const PROJECTILE := preload("res://scenes/projectile.tscn")
var inventory: ResourceInventory
var player: CharacterBody2D
var container: Node2D
var reload_remaining: float = 0.0
var reloading := ""
var reloading_uid: int = 0
signal message_requested(text: String)
signal shot_fired(point: Vector2, direction: Vector2, weapon: String)
var hit_players: bool = false
var friendly_fire: bool = true
var shot_remaining := 0.0

func fire(direction: Vector2) -> bool:
	var tool := inventory.equipped_tool()
	if get_tree().paused or player.dead or player.controls_blocked or shot_remaining > 0 or direction.is_zero_approx() or not GunRules.WEAPONS.has(tool):
		return false
	if reload_remaining > 0:
		message_requested.emit("Recarregando…")
		return false
	var rule: Dictionary = GunRules.WEAPONS[tool]
	if tool == "arco" and inventory.count_item("flecha") <= 0:
		message_requested.emit("Sem flechas — fabrique ou colete flechas para usar o arco")
		return false
	if tool != "arco" and inventory.loaded_ammo(tool) <= 0:
		message_requested.emit("Sem munição carregada — R para recarregar")
		return false
	if tool == "arco": inventory.remove_item("flecha", 1)
	else: inventory.set_loaded_ammo(tool, inventory.loaded_ammo(tool) - 1)
	shot_remaining = rule.interval
	for index in range(rule.pellets):
		var bullet = PROJECTILE.instantiate()
		# Espingarda distribui os chumbos no cone; não usa sorteios de loot.
		var offset: float = lerpf(-rule.spread, rule.spread, float(index) / (rule.pellets - 1)) if rule.pellets > 1 else randf_range(-rule.spread, rule.spread)
		bullet.direction = direction.normalized().rotated(offset)
		bullet.position = player.global_position
		bullet.speed = rule.speed
		bullet.remaining = rule.range
		bullet.damage = rule.damage
		bullet.arrow = tool == "arco"
		bullet.shooter = player.get_rid()
		bullet.hit_players = hit_players
		bullet.friendly_fire = friendly_fire
		container.add_child(bullet)
	shot_fired.emit(player.global_position, direction.normalized(), tool)
	player.show_swing(direction, 20)
	return true

func reload() -> bool:
	var tool := inventory.equipped_tool()
	if tool == "arco":
		message_requested.emit("O arco usa uma flecha por disparo; não precisa recarregar")
		return false
	if get_tree().paused or player.dead or player.controls_blocked or reload_remaining > 0 or not GunRules.WEAPONS.has(tool):
		return false
	var rule: Dictionary = GunRules.WEAPONS[tool]
	if inventory.loaded_ammo(tool) >= rule.magazine or inventory.count_item(rule.ammo) == 0:
		message_requested.emit("Carregador cheio ou sem munição de reserva")
		return false
	reloading = tool
	reloading_uid = inventory.equipped_weapon_id()
	reload_remaining = rule.reload
	message_requested.emit("Recarregando…")
	return true

func _physics_process(delta: float) -> void:
	shot_remaining = maxf(0, shot_remaining - delta)
	if reload_remaining <= 0:
		return
	if inventory.equipped_tool() != reloading or inventory.equipped_weapon_id() != reloading_uid or player.dead:
		reload_remaining = 0
		reloading = ""
		return
	reload_remaining = maxf(0, reload_remaining - delta)
	if reload_remaining == 0:
		var rule: Dictionary = GunRules.WEAPONS[reloading]
		var amount := mini(rule.magazine - inventory.loaded_ammo(reloading), inventory.count_item(rule.ammo))
		if amount > 0 and inventory.remove_item(rule.ammo, amount):
			inventory.set_loaded_ammo(reloading, inventory.loaded_ammo(reloading) + amount)
		message_requested.emit("Arma recarregada")
		reloading = ""
