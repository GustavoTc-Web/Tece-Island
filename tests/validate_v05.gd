extends SceneTree

var checks: int = 0
var failures: int = 0
var world: Node2D
var player: CharacterBody2D
var interaction: Node
var inventory: ResourceInventory
var hud: CanvasLayer


func _initialize() -> void:
	call_deferred("validate")


func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)


func step(count: int = 2) -> void:
	for i in range(count):
		await physics_frame
		await process_frame


func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	root.push_input(event, true)


func tap(code: Key) -> void:
	key(code, true)
	key(code, false)


func mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	event.pressed = pressed
	root.push_input(event, true)


func creature(point: Vector2) -> ForestCreature:
	var enemy := load("res://scenes/forest_creature.tscn").instantiate() as ForestCreature
	enemy.position = point
	enemy.player = player
	world.get_node("WorldObjects").add_child(enemy)
	enemy.set_physics_process(false)
	return enemy


func remove_enemies() -> void:
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await step()


func validate() -> void:
	var scene := load("res://scenes/world.tscn") as PackedScene
	world = scene.instantiate()
	world.get_node("Exploration").external_weapon_chance = 0
	world.get_node("Exploration").guardian_chance = 0
	root.add_child(world)
	current_scene = world
	await step()
	player = world.get_node("WorldObjects/Player")
	interaction = player.get_node("Interaction")
	inventory = world.get_node("Inventory")
	hud = world.get_node("HUD")
	var cycle := world.get_node("DayNight") as DayNightCycle
	var spawner = world.get_node("EnemySpawner")
	spawner.set_physics_process(false)
	cycle.set_physics_process(false)
	await remove_enemies()
	check(player.health == 100 and inventory.wood == 0 and inventory.tools.is_empty()
		and inventory.slots.size() == 7 and cycle.phase == "Dia", "nova partida limpa, vida 100 e dia inicial")
	check(ResourceRules.INTERVAL == {"maos": 1.2, "madeira": 0.54, "pedra": 0.36}, "intervalos recebem 20% uma única vez")
	check(ResourceRules.EXTRACTION.madeira.hits == {"maos": 6, "machado_madeira": 3, "machado_pedra": 2}
		and ResourceRules.EXTRACTION.pedra.hits == {"picareta_madeira": 6, "picareta_pedra": 3}, "golpes de extração preservados")
	# 0.6: comuns só à noite, com transição de saída ao amanhecer.
	check(spawner.try_spawn() == null, "nenhum surgimento comum diurno")
	cycle.elapsed = cycle.day_duration + 1
	cycle.refresh()
	spawner.spawn_interval = 0.4
	spawner.cooldown = 0
	spawner._physics_process(0.01)
	check(spawner.alive_count() == 1, "primeiro surgimento isolado")
	spawner._physics_process(0.1)
	check(spawner.alive_count() == 1, "não cria todos os inimigos de uma vez")
	spawner._physics_process(0.31)
	check(spawner.alive_count() == 2, "segundo surgimento gradual noturno")
	var safe := true
	var collision_free := true
	var spawn_shape := CircleShape2D.new()
	spawn_shape.radius = 18
	var spawn_query := PhysicsShapeQueryParameters2D.new()
	spawn_query.shape = spawn_shape
	spawn_query.collision_mask = 1
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
		safe = safe and enemy.position.distance_to(spawner.safe_center) > spawner.safe_radius
		safe = safe and enemy.position.distance_to(player.position) >= spawner.minimum_player_distance
		spawn_query.transform = Transform2D(0.0, enemy.position)
		collision_free = collision_free and player.get_world_2d().direct_space_state.intersect_shape(spawn_query).is_empty()
	check(safe, "surgimentos fora do jogador e área segura")
	check(collision_free, "surgimentos não sobrepõem árvores, rochas ou bordas")
	cycle.elapsed = cycle.day_duration + 1
	cycle.refresh()
	for i in range(3): spawner.try_spawn()
	check(spawner.alive_count() == 5 and spawner.try_spawn() == null, "limite noturno de cinco")
	cycle.elapsed = cycle.day_duration + cycle.night_duration
	cycle.refresh()
	spawner._physics_process(0.01)
	check(spawner.alive_count() == 0 and spawner.try_spawn() == null, "amanhecer interrompe comuns e bloqueia novos")
	await remove_enemies()
	# Ciclo curto controlado, sem esperar os doze minutos do padrão.
	cycle.day_duration = 3
	cycle.night_duration = 2
	cycle.transition_duration = 0.5
	cycle.elapsed = 0
	cycle.refresh()
	cycle.advance(2.75)
	check(cycle.phase == "Anoitecer" and cycle.color.r > cycle.night_color.r and cycle.color.r < 1.0,
		"anoitecer gradual entre dia e noite")
	cycle.advance(0.25)
	check(cycle.phase == "Noite" and cycle.is_night() and cycle.color.is_equal_approx(cycle.night_color), "noite atinge iluminação configurada")
	cycle.advance(1.75)
	check(cycle.phase == "Amanhecer" and cycle.color.r > cycle.night_color.r, "amanhecer gradual")
	cycle.advance(0.25)
	check(cycle.day_number == 2 and cycle.phase == "Dia" and cycle.color.is_equal_approx(Color.WHITE), "novo dia e iluminação restaurada")
	check(hud.get_node("Controls/Rows/Time").text.begins_with("Dia 2 · Dia ·"), "HUD recebe número do dia, fase e contagem")
	cycle.time_scale = 30
	var before_time := cycle.elapsed
	cycle.advance(0.1)
	check(is_equal_approx(cycle.elapsed - before_time, 3.0), "aceleração de testes configurável")
	cycle.time_scale = 1
	cycle.day_duration = 480
	cycle.night_duration = 240
	cycle.transition_duration = 30
	cycle.elapsed = 0
	cycle.refresh()
	# Combate real pelo atalho e pelo mouse, incluindo exclusão da árvore.
	inventory.add_resource("madeira", 2)
	check(inventory.craft("espada_madeira"), "receita de espada de madeira preservada")
	tap(KEY_1)
	check(inventory.equipped_tool() == "espada_madeira" and player.equipped == "espada_madeira", "1 seleciona espada no primeiro espaço")
	var enemy := creature(Vector2(500, 768))
	var tree := get_nodes_in_group("harvest_resources")[0] as HarvestResource
	var tree_original := tree.position
	tree.position = Vector2(530, 768)
	player.position = Vector2(455, 768)
	player.facing = Vector2.RIGHT
	await step()
	tap(KEY_F)
	check(enemy.health == 20 and tree.progress == 0, "golpe de espada afeta só o inimigo, sem extração simultânea")
	check(not interaction.hit_at(enemy.anchor()) and enemy.health == 20, "segundo golpe imediato bloqueado pelo intervalo")
	await create_timer(0.6).timeout
	var point: Vector2 = player.get_canvas_transform() * enemy.anchor()
	mouse(point, true)
	mouse(point, false)
	check(enemy.health == 10 and enemy.flash_time > 0, "mouse aplica dano e reação visual ao inimigo")
	interaction.cooldown = 0
	interaction.hit_at(enemy.anchor())
	check(enemy.dead and enemy.collision_layer == 0 and get_nodes_in_group("resource_drops").is_empty(), "inimigo morto sem colisão ou loot")
	await step()
	check(not is_instance_valid(enemy), "inimigo removido corretamente")
	tree.position = tree_original
	player.position = tree.anchor() + Vector2(-45, 0)
	interaction.cooldown = 0
	await step()
	check(not interaction.hit_at(tree.anchor()) and tree.progress == 0, "espada continua sem extrair recursos")
	inventory.add_resource("madeira", 2)
	inventory.add_resource("pedra", 3)
	check(inventory.craft("espada_pedra"), "receita de espada de pedra preservada")
	tap(KEY_KP_4)
	check(inventory.equipped_tool() == "espada_pedra", "teclado numérico seleciona espada exata no quarto espaço")
	player.position = Vector2(455, 768)
	enemy = creature(Vector2(500, 768))
	await step()
	interaction.cooldown = 0
	check(interaction.hit_at(enemy.anchor()) and enemy.health == 15, "espada de pedra causa quinze de dano")
	check(ResourceRules.combat_damage("maos") == 5 and ResourceRules.combat_damage("picareta_pedra") == 5, "mãos e ferramentas causam cinco")
	# Obstáculo físico bloqueia dano nos dois sentidos.
	player.position = Vector2(470, 768)
	var blocker := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 2
	collision.shape = shape
	blocker.add_child(collision)
	blocker.position = Vector2(485, 768)
	world.add_child(blocker)
	await step()
	interaction.cooldown = 0
	check(not interaction.hit_at(enemy.anchor()) and not enemy.try_attack(), "obstáculo impede dano de jogador e inimigo")
	blocker.queue_free()
	await step()
	# A criatura reconhece/persegue e desiste; a física bloqueia o cenário.
	player.position = Vector2(455, 768)
	enemy._physics_process(1.0 / 60.0)
	check(enemy.chasing, "detecta jogador com linha de visão")
	player.position = Vector2(45, 768)
	enemy._physics_process(1.0 / 60.0)
	check(not enemy.chasing, "desiste além da distância configurada")
	enemy.position = tree.anchor() + Vector2(-30, 0)
	await step()
	check(enemy.test_move(enemy.global_transform, Vector2(60, 0)), "colisão da criatura com tronco")
	enemy.velocity = Vector2(2000, 0)
	enemy.move_and_slide()
	check(enemy.position.x <= tree.anchor().x - 26.5, "movimento real não atravessa tronco")
	var rock: HarvestResource
	for resource in get_nodes_in_group("harvest_resources"):
		if resource.resource == "pedra": rock = resource; break
	enemy.position = rock.anchor() + Vector2(-60, 0)
	await step()
	check(enemy.test_move(enemy.global_transform, Vector2(100, 0)), "colisão da criatura com rocha")
	enemy.position = Vector2(60, 768)
	await step()
	check(enemy.test_move(enemy.global_transform, Vector2(-100, 0)), "colisão da criatura com borda")
	# Ataques a cada segundo, nunca por frame, e proteção entre múltiplos contatos.
	player.position = Vector2(500, 768)
	player.invulnerability = 0
	enemy.position = Vector2(530, 768)
	enemy.attack_cooldown = 0
	await step()
	check(enemy.try_attack() and player.health == 90, "criatura causa dez de dano")
	check(not enemy.try_attack() and player.health == 90, "contato imediato não causa novo dano")
	check(not player.receive_damage(10) and player.health == 90, "invulnerabilidade impede múltiplos contatos")
	enemy.set_physics_process(true)
	await create_timer(0.45).timeout
	check(player.health == 90, "sem dano extra antes de um segundo")
	await create_timer(0.65).timeout
	check(player.health == 80, "novo ataque após intervalo mínimo")
	enemy.set_physics_process(false)
	check(hud.get_node("Controls/Rows/Health").value == 80, "barra de vida atualizada por sinal")
	# Morte/reaparecimento preservam inventário e drops, sem inimigos no ponto seguro.
	var kept_slots := inventory.slots
	world._spawn_drop("pedra", 4)
	player.invulnerability = 0
	player.receive_damage(1000)
	check(player.dead and player.health == 0 and paused and hud.showing_death, "morte mostra painel e pausa mundo")
	await step()
	var respawn_point: Vector2 = hud.get_node("Death/Panel/Rows/Respawn").get_global_rect().get_center()
	mouse(respawn_point, true)
	mouse(respawn_point, false)
	check(not player.dead and not paused and player.health == 100 and player.position == Vector2(1152, 768), "botão reaparece com vida completa no início")
	check(inventory.slots == kept_slots and get_nodes_in_group("resource_drops").size() == 1, "reaparecer mantém itens e drops")
	safe = true
	for node in get_nodes_in_group("enemies"):
		safe = safe and node.position.distance_to(player.position) >= spawner.safe_radius
	check(safe, "reaparecimento sem inimigos próximos")
	# Pausa real congela física, dano, intervalos, surgimentos e relógio.
	player.position = Vector2(500, 768)
	enemy.position = Vector2(530, 768)
	enemy.set_physics_process(true)
	cycle.set_physics_process(true)
	spawner.set_physics_process(true)
	spawner.cooldown = 0.1
	interaction.cooldown = 0.2
	tap(KEY_C)
	var saved_position: Vector2 = player.position
	var saved_enemy: Vector2 = enemy.position
	var saved_health: int = player.health
	var saved_time: float = cycle.elapsed
	var saved_spawn: float = spawner.cooldown
	var saved_attack: float = enemy.attack_cooldown
	var saved_invulnerability: float = player.invulnerability
	var saved_count: int = spawner.alive_count()
	Input.action_press("move_right")
	key(KEY_F, true)
	await create_timer(0.4).timeout
	Input.action_release("move_right")
	key(KEY_F, false)
	check(paused and player.position == saved_position and enemy.position == saved_enemy, "painel pausa jogador e inimigo")
	check(player.health == saved_health and not player.receive_damage(10) and not enemy.try_attack(), "painel pausa dano")
	check(cycle.elapsed == saved_time and spawner.cooldown == saved_spawn and spawner.alive_count() == saved_count, "painel pausa relógio e surgimentos")
	check(enemy.attack_cooldown == saved_attack and player.invulnerability == saved_invulnerability and interaction.cooldown == 0.2, "painel pausa intervalos da simulação")
	tap(KEY_I)
	check(paused and hud.current_panel == "inventory", "HUD troca painel enquanto pausado")
	var saved_enemy_health := enemy.health
	var slot_point: Vector2 = hud.slot_buttons[0].get_global_rect().get_center()
	mouse(slot_point, true)
	mouse(slot_point, false)
	tap(KEY_ESCAPE)
	check(not paused and not interaction.mouse_held and not interaction.key_held, "fechar painel limpa entradas de golpe")
	await step()
	check(enemy.health == saved_enemy_health, "clique da interface não vira golpe ao fechar")
	await create_timer(0.1).timeout
	check(cycle.elapsed > saved_time, "relógio continua depois de fechar")
	# Partida completa nova difere do botão Reaparecer: tudo recomeça.
	world.queue_free()
	await step()
	world = scene.instantiate()
	world.get_node("Exploration").external_weapon_chance = 0
	world.get_node("Exploration").guardian_chance = 0
	root.add_child(world)
	current_scene = world
	await step()
	player = world.get_node("WorldObjects/Player")
	inventory = world.get_node("Inventory")
	cycle = world.get_node("DayNight")
	check(player.health == 100 and player.position == Vector2(1152, 768) and inventory.tools.is_empty()
		and inventory.wood == 0 and inventory.stone == 0 and inventory.equipped_tool() == "maos"
		and get_nodes_in_group("resource_drops").is_empty() and cycle.day_number == 1 and not cycle.is_night(), "nova partida restaura estado limpo e dia um")
	print("RESULT: ", checks, " verificações, ", failures, " falhas")
	quit(1 if failures > 0 else 0)
