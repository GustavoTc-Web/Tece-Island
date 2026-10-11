extends SceneTree

var failures := 0
var checks := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
	else:
		print("PASS: ", label)
func step() -> void:
	await physics_frame
	await process_frame
func run() -> void:
	var world = load("res://scenes/world.tscn").instantiate()
	world.get_node("Exploration").external_weapon_chance = 0
	root.add_child(world)
	await step()
	world.get_node("EnemySpawner").set_physics_process(false)
	var inv: ResourceInventory = world.get_node("Inventory")
	var player = world.get_node("WorldObjects/Player")
	var system = world.get_node("Structures")
	var cycle = world.get_node("DayNight")
	cycle.set_physics_process(false)
	check(inv.capacity == 7 and inv.wood == 0, "Partida inicia limpa com 7 espaços")
	inv.add_resource("fibra", 17)
	check(inv.slots[0].quantity == 15 and inv.slots[1].quantity == 2, "Fibra empilha 15+2")
	inv.add_resource("madeira", 4)
	check(inv.craft("mochila") and inv.count_item("fibra") == 5 and inv.wood == 0, "Receita da mochila desconta fibra/madeira")
	var index := -1
	for i in range(inv.slots.size()):
		if inv.slots[i].get("item", "") == "mochila": index = i
	check(not inv.backpack.is_empty() and inv.capacity == 9 and inv.count_item("mochila") == 0, "Bolsa automaticamente equipada fora dos espaços comuns")
	check(world.get_node("HUD").slot_buttons.size() == 9, "HUD acompanha nove espaços")
	check(not inv.equip_backpack(index) and inv.capacity == 9, "Bônus não acumula")
	inv.add_resource("pedra", 150)
	var before := inv.slots
	check(not inv.remove_backpack() and before == inv.slots and inv.capacity == 9, "Remoção cheia é atômica")
	inv.remove_item("pedra", inv.count_item("pedra"))
	check(inv.remove_backpack() and inv.capacity == 7 and inv.count_item("mochila") == 1, "Remoção conserva mochila e itens")
	inv.reset()
	check(not inv.craft("cama") and inv.wood == 0, "Fabricação sem ingredientes não desconta")
	inv.add_resource("madeira", 8)
	inv.add_resource("fibra", 6)
	check(inv.craft("cama"), "Fabricação da cama")
	index = 0
	check(system.start_placement(index), "Colocação fecha painel e inicia prévia")
	check(not system.can_place(player.position), "Não sobrepõe jogador")
	check(not system.can_place(Vector2(10, 10)), "Não sobrepõe bordas")
	system.cancel()
	check(inv.count_item("cama") == 1, "Cancelar preserva item")
	system.start_placement(index)
	system.update_preview(player.position + Vector2(85, 0))
	check(system.valid and system.confirm() and inv.count_item("cama") == 0, "Colocação válida consome uma vez")
	await step()
	var bed: PlacedStructure = get_nodes_in_group("structures")[0]
	check(not system.can_place(bed.position), "Não sobrepõe outra estrutura")
	check(system.use_bed(bed).contains("definido") and system.respawn_bed == bed, "Cama define reaparecimento de dia")
	cycle.elapsed = cycle.day_duration + 60
	cycle.refresh()
	var enemy = load("res://scenes/forest_creature.tscn").instantiate()
	enemy.player = player
	enemy.position = bed.position + Vector2(100, 0)
	world.get_node("WorldObjects").add_child(enemy)
	enemy.set_physics_process(false)
	check(system.use_bed(bed).contains("bloqueado") and cycle.is_night(), "Inimigo próximo bloqueia sono")
	enemy.position += Vector2(500, 0)
	check(system.use_bed(bed).contains("dormiu") and not cycle.is_night() and enemy.fading, "Dormir atualiza dia e monstros")
	check(system.respawn_point(Vector2.ZERO) != Vector2.ZERO, "Reaparecimento ao lado da cama livre")
	bed.queue_free()
	await step()
	check(system.respawn_point(Vector2(1152, 768)) == Vector2(1152, 768), "Cama indisponível usa ponto inicial")
	inv.add_resource("madeira", 4)
	inv.add_resource("pedra", 5)
	check(inv.craft("fogueira"), "Fabricação da fogueira")
	for i in range(inv.slots.size()):
		if inv.slots[i].get("item", "") == "fogueira": index = i
	system.start_placement(index)
	system.update_preview(player.position + Vector2(-85, 0))
	check(system.confirm(), "Colocação da fogueira")
	await step()
	var fire: PlacedStructure = get_nodes_in_group("structures")[0]
	check(fire.light != null and fire.light.texture != null and fire.light.texture_scale == 2, "Fogueira tem luz radial local")
	var animation := fire.animation_time
	world.get_node("HUD").set_panel("inventory")
	await step()
	check(paused and fire.animation_time == animation, "Painel pausa animação e simulação")
	world.get_node("HUD").set_panel("")
	check(not player.get_node("Interaction").mouse_held, "Fechar painel não inicia golpe")
	var bush = load("res://scenes/obstacles/bush.tscn").instantiate()
	bush.position = player.position + Vector2(60, 0)
	bush.depleted.connect(world._spawn_drop)
	world.get_node("WorldObjects").add_child(bush)
	bush.apply_hit("maos")
	bush.apply_hit("maos")
	check(inv.count_item("fibra") == 0 and get_nodes_in_group("resource_drops").size() == 1, "Fibra cai no chão sem crédito automático")
	check(player.get_node("Interaction").collect_nearest() == 4 and inv.count_item("fibra") == 4, "E recolhe fibra")
	print("ETAPA 2: %d verificações, %d falhas" % [checks, failures])
	paused = false
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
