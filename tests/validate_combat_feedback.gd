extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1
	print("PASS: " if value else "FAIL: ", label)
func step() -> void:
	for i in range(4): await physics_frame
func run() -> void:
	var audio := root.get_node("CombatAudio")
	audio.preferences_path = "res://.tools/test-audio.cfg"
	audio.configure(0.3, true)
	check(not audio.play("shot"), "Silenciar bloqueia áudio")
	check(audio.voices.size() == 4 and audio.sounds.size() == 7 and audio.sounds.has("objective"), "Áudio curto com quatro vozes, combate e conquista de objetivo")
	var world: Node2D = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await step()
	var player: CharacterBody2D = world.get_node("WorldObjects/Player")
	player.set_physics_process(false)
	var interaction: Node = player.get_node("Interaction")
	interaction.set_physics_process(false)
	var enemy: ForestCreature = load("res://scenes/forest_creature.tscn").instantiate()
	enemy.player = player
	enemy.origin = "guardiao"
	enemy.safe_radius = 0
	enemy.position = player.position + Vector2(40, 0)
	world.get_node("WorldObjects").add_child(enemy)
	enemy.set_physics_process(false)
	await step()
	interaction.target = enemy
	check(interaction.strike_target() and enemy.health == 25, "Golpe mantém cinco danos e registra acerto real")
	check(player.swing_time > 0 and enemy.combat_visible > 0, "Movimento de ataque e vida temporária")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.tools/screenshots/signal-combat-native.png")
	check(is_equal_approx(interaction.cooldown, 1.2), "Intervalo de mãos preservado")
	enemy._process(5)
	check(enemy.combat_visible == 0, "Barra some após quatro segundos sem combate")
	interaction.cooldown = 0
	interaction.target = null
	check(not interaction.strike_target() and enemy.health == 25 and player.swing_time > 0, "Erro mostra golpe sem dano fictício")
	var wall := StaticBody2D.new()
	wall.position = player.position + Vector2(20, 0)
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(8, 100)
	shape.shape = rectangle
	wall.add_child(shape)
	world.get_node("WorldObjects").add_child(wall)
	await step()
	interaction.cooldown = 0
	interaction.target = enemy
	check(not interaction.strike_target() and enemy.health == 25, "Parede bloqueia golpe sem efeito de acerto")
	var arrow: Node2D = load("res://scenes/projectile.tscn").instantiate()
	arrow.position = player.position
	arrow.direction = Vector2.RIGHT
	arrow.arrow = true
	arrow.shooter = player.get_rid()
	world.get_node("WorldObjects").add_child(arrow)
	await step()
	check(enemy.health == 25, "Flecha bloqueada conserva vida do alvo")
	var blocked := false
	for effect in get_nodes_in_group("combat_effects"):
		if effect.kind == "blocked": blocked = true
	check(blocked, "Colisão produz efeito de bloqueio, sem acerto fictício")
	wall.queue_free()
	await step()
	var hit_arrow: Node2D = load("res://scenes/projectile.tscn").instantiate()
	hit_arrow.position = player.position
	hit_arrow.direction = Vector2.RIGHT
	hit_arrow.arrow = true
	hit_arrow.damage = 12
	hit_arrow.shooter = player.get_rid()
	world.get_node("WorldObjects").add_child(hit_arrow)
	await step()
	var arrow_hit := false
	for effect in get_nodes_in_group("combat_effects"):
		if effect.kind == "arrow_hit": arrow_hit = true
	check(enemy.health == 13 and arrow_hit, "Flecha acertada aplica doze danos e efeito próprio")
	var miss: Node2D = load("res://scenes/projectile.tscn").instantiate()
	miss.position = player.position
	miss.direction = Vector2.LEFT
	miss.remaining = 10
	miss.shooter = player.get_rid()
	world.get_node("WorldObjects").add_child(miss)
	await step()
	var missed := false
	for effect in get_nodes_in_group("combat_effects"):
		if effect.kind == "miss": missed = true
	check(enemy.health == 13 and missed, "Projétil que erra desvanece sem impacto ou dano")
	player.apply_poison(3)
	player.step_poison(1)
	check(player.health == 99 and is_equal_approx(player.poison_remaining, 2) and world.get_node("HUD").poison_status.text.contains("2.0"), "Veneno mostra duração legível na HUD mantendo um dano por segundo")
	check(GunRules.WEAPONS.arco.damage == 12 and GunRules.WEAPONS.arco.interval == 1, "Equilíbrio do arco preservado")
	for i in range(30): CombatEffect.emit_at(player, player.position, "impact")
	check(get_nodes_in_group("combat_effects").size() <= CombatEffect.LIMIT, "Efeitos limitados para desempenho")
	world.queue_free()
	await process_frame
	print("COMBAT FEEDBACK: %d verificações, %d falhas" % [checks, failures])
	quit(1 if failures else 0)
