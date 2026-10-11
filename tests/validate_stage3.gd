extends SceneTree

var failures := 0
var checks := 0
var world: Node2D
var player: CharacterBody2D
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
	else: print("PASS: ", label)
func step(frames: int = 2) -> void:
	for i in range(frames):
		await physics_frame
		await process_frame
func ray_clear(from: Vector2, to: Vector2) -> bool:
	var ray := PhysicsRayQueryParameters2D.create(from, to, 1)
	return player.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()
func enemy(point: Vector2) -> ForestCreature:
	var node := load("res://scenes/forest_creature.tscn").instantiate() as ForestCreature
	node.player = player
	node.position = point
	world.get_node("WorldObjects").add_child(node)
	node.set_physics_process(false)
	return node
func run() -> void:
	world = load("res://scenes/world.tscn").instantiate()
	world.get_node("Exploration").random_seed = 12345
	root.add_child(world)
	player = world.get_node("WorldObjects/Player")
	world.get_node("EnemySpawner").set_physics_process(false)
	await step()
	var inv: ResourceInventory = world.get_node("Inventory")
	var weapons = world.get_node("Weapons")
	var interaction = player.get_node("Interaction")
	var exploration = world.get_node("Exploration")
	check(player.get_node("Camera2D").limit_right == 6912, "Câmera cobre mapa com deserto")
	check(ray_clear(Vector2(2340, 730), Vector2(5320, 730)), "Caminho conecta pântano e campos contornando poços")
	check(get_nodes_in_group("buildings").size() == 9, "Nove construções reutilizáveis distribuídas")
	for building in get_nodes_in_group("buildings"):
		var entry: Vector2 = building.position + Vector2(0, building.footprint.y / 2 + 40)
		check(ray_clear(entry, building.position), "Entrada utilizável: " + building.name)
		var contents: Dictionary = building.loot.contents.duplicate(true)
		var guard_before: bool = building.has_guardian
		var rng := RandomNumberGenerator.new()
		building.populate(rng, exploration)
		check(contents == building.loot.contents and guard_before == building.has_guardian, "Revisita não sorteia: " + building.name)
	var sample: AbandonedBuilding = get_nodes_in_group("buildings")[0]
	sample.loot.contents = {"madeira": 3, "fibra": 2}
	inv.add_resource("pedra", 105)
	var count := get_nodes_in_group("resource_drops").size()
	sample.loot.interact(inv)
	check(get_nodes_in_group("resource_drops").size() == count + 2 and inv.wood == 0, "Loot cheio permanece no chão")
	sample.loot.interact(inv)
	check(get_nodes_in_group("resource_drops").size() == count + 2, "Recipiente libera conteúdo uma vez")
	var rolls: Array = exploration.external_rolls.duplicate()
	exploration.initialize()
	check(rolls == exploration.external_rolls and rolls.size() == 10, "Pontos externos sorteados uma vez")
	check(not exploration.development_weapons, "Opção de armas de desenvolvimento desligada")
	inv.reset()
	check(inv.add_resource("pistola", 1) == 1 and inv.add_resource("espingarda", 1) == 1, "Armas não empilham e ocupam espaços")
	inv.add_resource("municao_pistola", 17)
	inv.add_resource("cartucho", 5)
	check(inv.slots[2].quantity == 15 and inv.slots[3].quantity == 2, "Munição empilha 15+2")
	check(not ResourceRules.RECIPES.has("pistola") and inv.equip("pistola"), "Pistola equipável, não fabricável")
	check(not weapons.fire(Vector2.RIGHT), "Sem munição não dispara")
	check(weapons.reload() and not weapons.reload(), "Recarga única em andamento")
	weapons._physics_process(2)
	check(inv.loaded_ammo("pistola") == 8 and inv.count_item("municao_pistola") == 9, "Recarga transfere 8 sem duplicar")
	player.position = Vector2(2600, 768)
	var first := enemy(Vector2(2680, 768))
	var second := enemy(Vector2(2750, 768))
	await step()
	interaction.key_held = true
	player.facing = Vector2.RIGHT
	interaction.cooldown = 0
	check(interaction.strike_target() and not interaction.strike_target(), "Disparo F respeita cadência única")
	interaction.key_held = false
	check(get_nodes_in_group("projectiles").size() == 1 and inv.loaded_ammo("pistola") == 7, "Pistola gera um projétil e consome um tiro")
	await step(12)
	check(first.health == 12 and second.health == 30, "Projétil não atravessa múltiplos alvos")
	first.queue_free()
	second.queue_free()
	await step()
	# Parede no trajeto impede acertar a criatura e não extrai a árvore.
	var obstacle = load("res://scenes/obstacles/tree.tscn").instantiate()
	obstacle.position = Vector2(2670, 768)
	world.get_node("WorldObjects").add_child(obstacle)
	var behind := enemy(Vector2(2750, 768))
	await step()
	weapons.fire(Vector2.RIGHT)
	await step(15)
	check(behind.health == 30 and obstacle.progress == 0, "Projétil bloqueado por árvore, sem extração")
	obstacle.queue_free()
	behind.queue_free()
	await step()
	inv.equip("espingarda")
	weapons.reload()
	weapons._physics_process(2)
	check(inv.loaded_ammo("espingarda") == 2 and inv.count_item("cartucho") == 3, "Recarga da espingarda usa cartuchos separados")
	var close := enemy(Vector2(2650, 768))
	await step()
	check(weapons.fire(Vector2.RIGHT) and get_nodes_in_group("projectiles").size() == 6 and inv.loaded_ammo("espingarda") == 1, "Espingarda: seis projéteis, um cartucho")
	await step(8)
	check(not is_instance_valid(close), "Cone causa dano próximo suficiente")
	var far := enemy(Vector2(2920, 768))
	weapons.fire(Vector2.RIGHT)
	await step(28)
	check(far.health == 30, "Espingarda respeita alcance curto")
	inv.equip("pistola")
	weapons.fire(Vector2.UP)
	await step()
	var projectile: Node2D = get_nodes_in_group("projectiles")[0]
	var position := projectile.position
	world.get_node("HUD").set_panel("inventory")
	var time: float = world.get_node("DayNight").elapsed
	await step(4)
	check(projectile.position == position and world.get_node("DayNight").elapsed == time, "Painel pausa projéteis e relógio")
	world.get_node("HUD").set_panel("")
	check(not interaction.mouse_held and not interaction.key_held, "Retomada sem ataque acidental")
	await step()
	check(projectile.position != position, "Projétil retoma após fechar")
	for node in get_nodes_in_group("enemies"):
		if node.origin == "guardiao":
			var old_position: Vector2 = node.position
			node.begin_dawn()
			check(not node.fading and old_position == node.position, "Guardião da construção permanece ao amanhecer")
	print("ETAPA 3: %d verificações, %d falhas" % [checks, failures])
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
