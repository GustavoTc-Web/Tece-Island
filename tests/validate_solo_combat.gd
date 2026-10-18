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
func spawn(world: Node2D, kind: String, point: Vector2) -> ForestCreature:
	var mob: ForestCreature = load("res://scenes/forest_creature.tscn").instantiate()
	mob.kind = kind
	mob.origin = "campanha" if kind == "guardiao_ilha" else "guardiao"
	mob.position = point
	mob.safe_radius = 0
	mob.player = world.get_node("WorldObjects/Player")
	world.get_node("WorldObjects").add_child(mob)
	mob.set_physics_process(false)
	return mob
func run() -> void:
	var world: Node2D = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await step()
	world.get_node("EnemySpawner").set_physics_process(false)
	world.get_node("Animals").set_physics_process(false)
	var player: CharacterBody2D = world.get_node("WorldObjects/Player")
	player.set_physics_process(false)
	player.position = Vector2(1000, 768)
	var skeleton := spawn(world, "esqueleto", Vector2(820, 768))
	await step()
	check(skeleton.chase_speed > 75 and skeleton.skeleton_arrow_speed > 240, "Esqueleto ganha velocidade moderada")
	player.velocity = Vector2(0, 160)
	check(skeleton.try_attack() and skeleton.shot_direction.y > 0, "Mira antecipa movimento lateral")
	player.velocity = Vector2.ZERO
	skeleton.windup_remaining = 0
	skeleton.attack_cooldown = 0
	skeleton.try_attack()
	skeleton.release_arrow()
	await step(45)
	check(player.health == 90, "Flecha atinge alvo parado no centro da colisão")
	player.respawn(Vector2(1000, 768))
	skeleton.windup_remaining = 0
	skeleton.attack_cooldown = 0
	skeleton.position = Vector2(950, 768)
	skeleton._physics_process(0.1)
	check(skeleton.windup_remaining > 0 and skeleton.velocity == Vector2.ZERO, "Esqueleto para para anunciar tiro")
	skeleton.windup_remaining = 0
	skeleton.attack_cooldown = 5
	skeleton.chasing = true
	skeleton._physics_process(0.1)
	check(skeleton.velocity.x < 0, "Esqueleto recua se alvo está perto demais")
	skeleton.queue_free()
	await step()
	var hunter := spawn(world, "cacador", Vector2(900, 768))
	await step()
	check(hunter.max_health == 22 and hunter.chase_speed == 135, "Caçador rápido tem pouca resistência")
	check(hunter.try_attack() and hunter.windup_remaining >= 0.6 and player.health == 100, "Investida do caçador tem preparação sem dano instantâneo")
	player.position = Vector2(1000, 850)
	hunter.windup_remaining = 0
	hunter.release_special()
	for i in range(20): hunter._physics_process(1.0 / 60)
	check(player.health == 100 and hunter.recovery > 0, "Investida fixa permite esquiva e deixa recuperação")
	hunter.queue_free()
	await step()
	player.position = Vector2(1000, 768)
	var brute := spawn(world, "brutamonte", Vector2(950, 768))
	await step()
	check(brute.max_health == 100 and brute.chase_speed == 58, "Brutamonte lento é resistente")
	check(brute.try_attack() and brute.windup_remaining >= 1.2 and player.health == 100, "Golpe pesado anuncia por 1,2 segundo")
	player.position = Vector2(1050, 768)
	brute.windup_remaining = 0
	brute.release_special()
	check(player.health == 100 and brute.recovery >= 1, "Sair do alcance evita golpe pesado")
	brute.attack_cooldown = 0
	player.position = Vector2(1000, 768)
	player.invulnerability = 0
	brute.try_attack()
	brute.windup_remaining = 0
	brute.release_special()
	check(player.health == 76, "Golpe pesado pune alvo que permanece no alcance")
	brute.queue_free()
	await step()
	player.respawn(Vector2(1000, 768))
	var boss := spawn(world, "guardiao_ilha", Vector2(850, 768))
	await step()
	check(boss.try_attack() and boss.special_attack == "charge", "Guardião anuncia aproximação")
	boss.windup_remaining = 0
	boss.release_special()
	check(boss.charge_remaining > 0, "Primeiro padrão executa investida")
	boss.charge_remaining = 0
	boss.attack_cooldown = 0
	check(boss.try_attack() and boss.special_attack == "volley", "Segundo padrão anuncia pressão à distância")
	boss.windup_remaining = 0
	boss.release_special()
	check(get_nodes_in_group("campaign_projectiles").size() == 3, "Salva cria três trajetórias fixas")
	for arrow in get_nodes_in_group("campaign_projectiles"): arrow.queue_free()
	var hits := ceili(float(boss.health) / ResourceRules.combat_damage("espada_pedra"))
	for i in range(hits): boss.receive_damage(ResourceRules.combat_damage("espada_pedra"))
	check(boss.dead and hits == 20, "Espada fabricável derrota chefe em 20 acertos")
	var spawner: Node = world.get_node("EnemySpawner")
	check("cacador" not in spawner.kinds_for_day(1) and "cacador" in spawner.kinds_for_day(2), "Caçador entra na segunda noite")
	check("brutamonte" not in spawner.kinds_for_day(3) and "brutamonte" in spawner.kinds_for_day(4), "Brutamonte entra na quarta noite")
	check("guardiao_ilha" not in spawner.kinds_for_day(100), "Chefe nunca entra no sorteio comum")
	world.queue_free()
	await step()
	print("%d verificações, %d falhas" % [checks, failures])
	quit(1 if failures else 0)
