extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1
	print("PASS: " if value else "FAIL: ", label)
func step(frames: int = 3) -> void:
	for i in range(frames): await physics_frame
func run() -> void:
	var world: Node2D = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await step()
	var player: CharacterBody2D = world.get_node("WorldObjects/Player")
	var objects: Node2D = world.get_node("WorldObjects")
	var spawner: Node = world.get_node("EnemySpawner")
	world.get_node("Animals").set_physics_process(false)
	spawner.set_physics_process(false)
	player.position = Vector2(1000, 768)
	var skeleton: ForestCreature = load("res://scenes/forest_creature.tscn").instantiate()
	skeleton.kind = "esqueleto"
	skeleton.origin = "guardiao"
	skeleton.position = Vector2(850, 768)
	skeleton.safe_radius = 0
	skeleton.player = player
	objects.add_child(skeleton)
	skeleton.set_physics_process(false)
	await step()
	check(skeleton.attack_interval >= 2.5 and skeleton.attack_damage == 10, "Esqueleto respeita dano e intervalo")
	check(skeleton.try_attack() and skeleton.windup_remaining > 0 and player.health == 100, "Ataque tem aviso antes de causar dano")
	var direction := skeleton.shot_direction
	player.position.y += 80
	check(skeleton.shot_direction == direction, "Direção fixada não persegue alvo")
	check(skeleton.release_arrow(), "Aviso libera projétil visível")
	await step(40)
	check(player.health == 100, "Desvio evita flecha sem homing")
	skeleton.attack_cooldown = 0
	player.position = Vector2(1000, 768)
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.position = Vector2(930, 768)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(8, 90)
	collision.shape = shape
	wall.add_child(collision)
	objects.add_child(wall)
	await step()
	check(not skeleton.try_attack() and not skeleton.release_arrow(), "Parede bloqueia início e liberação do disparo")
	wall.queue_free()
	await step()
	var spider: ForestCreature = load("res://scenes/forest_creature.tscn").instantiate()
	spider.kind = "aranha"
	spider.origin = "guardiao"
	spider.safe_radius = 0
	spider.player = player
	spider.position = player.position + Vector2(25, 0)
	objects.add_child(spider)
	spider.set_physics_process(false)
	player.set_physics_process(false)
	await step()
	check(spider.attack_interval == 1.5 and spider.attack_damage == 4, "Aranha respeita dano e intervalo")
	player.invulnerability = 0
	check(spider.try_attack() and player.health == 96 and player.poison_remaining == 3, "Aranha aplica quatro danos e veneno")
	player.step_poison(1)
	check(player.health == 95 and player.poison_remaining == 2, "Veneno aplica um dano por segundo")
	player.apply_poison(3)
	player.step_poison(1)
	check(player.health == 94 and player.poison_remaining == 2, "Renovar não empilha instâncias")
	player.step_poison(2)
	check(player.health == 92 and player.poison_remaining == 0, "Veneno termina após duração renovada")
	player.apply_poison(3)
	paused = true
	player.step_poison(1)
	check(player.health == 92 and player.poison_remaining == 3, "Pausa congela veneno")
	paused = false
	player.respawn(Vector2(1000, 768))
	check(player.poison_remaining == 0, "Respawn limpa veneno")
	var arrows := [0, 0, 0]
	var threads := [0, 0]
	for i in range(1000):
		arrows[ForestCreature.drop_quantity("esqueleto", float(i) / 1000) - 1] += 1
		threads[ForestCreature.drop_quantity("aranha", float(i) / 1000) - 1] += 1
	check(arrows == [700, 250, 50] and threads == [750, 250], "Distribuições exatas nos limites dos sorteios")
	skeleton.receive_damage(100)
	spider.receive_damage(100)
	await step()
	var found_arrow := false
	var found_thread := false
	for drop in get_nodes_in_group("resource_drops"):
		found_arrow = found_arrow or drop.resource == "flecha"
		found_thread = found_thread or drop.resource == "linha"
	check(found_arrow and found_thread, "Drops caem no chão usando coleta existente")
	check(world.get_node("DayNight").day_duration == 300 and world.get_node("DayNight").night_duration == 300, "Ciclo de cinco minutos preservado")
	check(spawner.current_limit() == 0 and spawner.try_spawn() == null, "Dia não gera monstros noturnos")
	world.get_node("DayNight").elapsed = 940
	world.get_node("DayNight").refresh()
	var spawned := []
	for i in range(8):
		var enemy: ForestCreature = spawner.try_spawn()
		if is_instance_valid(enemy): spawned.append(enemy.kind)
		await step()
	check(spawner.alive_count() <= 4 and spawned.has("esqueleto") and spawned.has("aranha"), "Novos tipos compartilham limite da segunda noite")
	world.queue_free()
	await process_frame
	print("%d verificações, %d falhas" % [checks, failures])
	quit(1 if failures else 0)
