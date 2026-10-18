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
	check(spawner.kinds_for_day(1) == ["criatura"], "Primeira noite só roxos")
	check(spawner.kinds_for_day(2) == ["criatura", "esqueleto", "aranha"], "Segunda noite acrescenta esqueleto e aranha")
	check("cacador" not in spawner.kinds_for_day(2) and "cacador" in spawner.kinds_for_day(3), "Caçador entra na terceira noite")
	check("brutamonte" not in spawner.kinds_for_day(5) and "brutamonte" in spawner.kinds_for_day(6) and "uivador" in spawner.kinds_for_day(6), "Brutamonte e Uivador entram na sexta noite")
	check("guardiao_ilha" not in spawner.kinds_for_day(100), "Chefe nunca entra no sorteio comum")
	check("sentinela" not in spawner.kinds_for_day(100) and "acolito" not in spawner.kinds_for_day(100), "Ameaças dos templos não se espalham pelo mundo aberto")
	var sentinel := spawn(world, "sentinela", Vector2(950, 768))
	check(sentinel.max_health == 65 and sentinel.try_attack() and sentinel.windup_remaining >= 1.2, "Sentinela anuncia golpe forte sem inflar vida")
	sentinel.origin = "templo"
	sentinel.home = Vector2(950, 768)
	check(not sentinel.within_territory(Vector2(1400, 768)) and sentinel.within_territory(Vector2(1000, 768)), "Inimigo de templo permanece no recinto")
	sentinel.queue_free()
	var acolyte := spawn(world, "acolito", Vector2(820, 768))
	check(acolyte.try_attack() and acolyte.windup_remaining == 0.85 and acolyte.skeleton_arrow_speed == 265, "Acólito usa tiro visível, antecipação moderada e mais tempo de esquiva")
	acolyte.queue_free()
	var howler := spawn(world, "uivador", Vector2(900, 768))
	howler.reinforcement_handler = spawner.summon_for_howler
	howler.call_cooldown = 0
	howler._physics_process(0.01)
	check(howler.special_attack == "call" and howler.windup_remaining == 2 and player.health == 100, "Uivador anuncia chamado por dois segundos")
	howler.receive_damage(1)
	check(howler.windup_remaining == 0 and howler.call_cooldown == 12, "Qualquer golpe interrompe chamado e adia nova tentativa")
	howler.origin = "campanha"
	howler.add_to_group("final_encounter")
	var count: int = spawner.summon_for_howler(howler)
	check(count == 2 and spawner.summon_for_howler(howler) == 0, "Reforços limitados a dois simultâneos")
	howler.special_attack = "call"
	howler.release_special()
	check(howler.call_cooldown == 18, "Chamados completos respeitam intervalo de dezoito segundos")
	for mob in world.campaign.final_enemies(): mob.queue_free()
	var inv: ResourceInventory = world.get_node("Inventory")
	inv.reset()
	inv.add_resource("madeira", 30)
	inv.add_resource("pedra", 26)
	inv.add_resource("linha", 7)
	inv.add_resource("carne_crua", 6)
	check(inv.craft("armadura_pedra"), "Reserva de preparo fabrica armadura antes dos templos")
	for index in range(inv.capacity):
		if inv.slot_data(index).get("item") == "armadura_pedra": inv.equip_armor(index); break
	check(inv.craft("espada_pedra") and inv.craft("arco"), "Espada e arco cabem na bolsa inicial junto à armadura equipada")
	var arrows_ok := true
	for i in range(4): arrows_ok = inv.craft("flecha") and arrows_ok
	inv.cooking_available = true
	var food_ok := true
	for i in range(6): food_ok = inv.craft("carne_cozida") and food_ok
	check(arrows_ok and inv.count_item("flecha") == 16 and food_ok and inv.count_item("carne_cozida") == 6, "Preparo reserva 16 flechas e seis comidas com recursos comuns")
	world.queue_free()
	await step()
	print("%d verificações, %d falhas" % [checks, failures])
	quit(1 if failures else 0)
