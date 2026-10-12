extends "res://tests/validate_integration.gd"
var alerts := 0
func run() -> void:
	root.size = Vector2i(960, 540)
	var world := make_world({"guardian_chance": 0.0, "external_weapon_chance": 0.0})
	await step()
	var player: CharacterBody2D = world.get_node("WorldObjects/Player")
	var needs: SurvivalNeeds = player.get_node("Needs")
	needs.set_physics_process(false)
	needs.reset()
	var inv: ResourceInventory = world.get_node("Inventory")
	var hud := world.get_node("HUD")
	check(needs.hunger == 100 and needs.thirst == 100, "Necessidades começam completas")
	needs.advance(60)
	check(is_equal_approx(needs.hunger, 95) and is_equal_approx(needs.thirst, 92), "Um minuto: fome -5, sede -8")
	hud.set_panel("inventory")
	needs.advance(60)
	check(needs.hunger == 95 and needs.thirst == 92, "Painel solo pausa necessidades")
	hud.set_panel("")
	needs.alert.connect(func(_text): alerts += 1)
	needs.hunger = 25.1
	needs.thirst = 25.1
	needs.advance(2)
	check(alerts == 2, "Alerta ao cruzar 25 em cada necessidade")
	needs.hunger = 0
	needs.thirst = 50
	player.health = 100
	needs.damage_clock = 0
	needs.advance(4.9)
	check(player.health == 100, "Necessidade vazia não mata instantaneamente")
	needs.advance(0.1)
	check(player.health == 99, "Uma necessidade vazia: 1 dano a cada 5 segundos")
	needs.thirst = 0
	needs.advance(5)
	check(player.health == 97, "Ambas vazias: total de 2 pontos")
	player.dead = true
	var frozen := Vector2(needs.hunger, needs.thirst)
	needs.advance(120)
	check(Vector2(needs.hunger, needs.thirst) == frozen and player.health == 97, "Tela de morte não reduz valores nem causa dano")
	player.respawn(Vector2(1152, 768))
	check(needs.hunger == 100 and needs.thirst == 100, "Reaparecer restaura necessidades")
	inv.reset()
	inv.add_resource("madeira", 2)
	inv.add_resource("fibra", 2)
	check(inv.craft("cantil") and inv.slot_data(0).get("water", -1) == 0, "Cantil fabricável por 2 madeiras e 2 fibras")
	check(inv.fill_canteen() and inv.slot_data(0).water == 3, "Cantil armazena três doses")
	needs.thirst = 20
	needs.use_slot(inv, 0)
	check(needs.thirst == 60 and inv.slot_data(0).water == 2, "Uma dose restaura 40 sede")
	inv.swap_slots(0, 4)
	check(inv.slot_data(4).water == 2, "Mover cantil conserva água")
	DropRules.discard(inv, 4, true, player, world.get_node("WorldObjects"), world.MAP_SIZE)
	var drop: ResourceDrop = world.get_node("WorldObjects").get_child(-1)
	check(drop.attributes.water == 2 and drop.collect(inv) == 1 and inv.slot_data(0).water == 2, "Descartar e recolher conserva doses")
	needs.use_slot(inv, 0)
	needs.use_slot(inv, 0)
	check(inv.count_item("cantil") == 1 and inv.slot_data(0).water == 0 and needs.thirst == 100, "Cantil vazio permanece e sede respeita máximo")
	var well: WaterWell = get_nodes_in_group("wells")[0]
	player.position = well.position + Vector2(0, 50)
	await step()
	player.get_node("Interaction").collect_nearest()
	check(hud.current_panel == "well" and paused, "E oferece opções do poço, apenas para alvo indicado")
	needs.thirst = 10
	hud._well_action("Beber")
	hud._well_action("Encher cantil")
	check(needs.thirst == 50 and inv.slot_data(0).water == 3, "Opções beber e encher cantil funcionam durante painel")
	hud.set_panel("")
	player.position = Vector2(1152, 768)
	inv.reset()
	inv.add_resource("carne_crua", 2)
	inv.add_resource("madeira", 2)
	check(not inv.craft("carne_cozida") and inv.count_item("carne_crua") == 2, "Não cozinha longe de fogueira, sem perder ingredientes")
	var fire: PlacedStructure = load("res://scenes/placed_structure.tscn").instantiate()
	fire.kind = "fogueira"
	fire.system = world.get_node("Structures")
	fire.position = player.position + Vector2(0, 80)
	world.get_node("WorldObjects").add_child(fire)
	await step()
	check(inv.cooking_available and inv.craft("carne_cozida") and inv.count_item("carne_crua") == 1 and inv.wood == 1, "Fogueira: uma carne + uma madeira produzem uma cozida")
	inv.add_resource("carne_cozida", 2)
	inv.swap_slots(2, 0)
	inv.select_quick(0)
	needs.hunger = 10
	for down in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = KEY_F
		event.keycode = KEY_F
		event.pressed = down
		root.push_input(event)
		if down: await step(30)
	check(needs.hunger == 40 and inv.count_item("carne_cozida") == 2, "F consome exatamente uma unidade por acionamento")
	check(get_nodes_in_group("animals").size() > 0, "Animais neutros presentes")
	var rabbit := NeutralAnimal.new()
	rabbit.player = player
	rabbit.position = player.position + Vector2(40, 0)
	world.get_node("WorldObjects").add_child(rabbit)
	await step()
	check(not rabbit.is_in_group("enemies"), "Animais separados dos monstros hostis")
	rabbit._physics_process(0.1)
	check(rabbit.velocity.dot(rabbit.position - player.position) > 0, "Coelho foge ao se aproximar")
	rabbit.set_physics_process(false)
	rabbit.position = player.position + Vector2(40, 0)
	inv.equip("maos")
	var interaction := player.get_node("Interaction")
	interaction.cooldown = 0
	await step()
	check(interaction.hit_at(rabbit.position + Vector2(0, -8)) and rabbit.health == 10, "Combate existente permite caçar animal")
	rabbit.receive_damage(100)
	drop = world.get_node("WorldObjects").get_child(-1)
	check(drop is ResourceDrop and drop.resource == "carne_crua" and drop.quantity == 1, "Coelho deixa uma carne no chão")
	var cow := NeutralAnimal.new()
	cow.kind = "vaca"
	cow.player = player
	cow.position = player.position + Vector2(-80, 0)
	world.get_node("WorldObjects").add_child(cow)
	check(cow.panic == 0, "Vaca nasce passiva")
	cow.receive_damage(5)
	check(cow.panic > 0, "Vaca foge quando atacada")
	cow.receive_damage(100)
	drop = world.get_node("WorldObjects").get_child(-1)
	check(drop.quantity in [2, 3], "Vaca deixa duas ou três carnes")
	var correct_habitat := true
	for animal in get_nodes_in_group("animals"):
		if animal.is_fish(): correct_habitat = correct_habitat and WorldTerrain.is_water(animal.position)
		elif animal.kind in ["coelho", "vaca"]: correct_habitat = correct_habitat and WorldTerrain.region_at(animal.position).get("kind", "") in ["Floresta", "Campos", "Pântano"]
	check(correct_habitat, "Peixes ficam na água e animais terrestres na vegetação")
	world.queue_free()
	await step()
	print("UPDATE C: ", checks, " verificações, ", failures, " falhas")
	quit(1 if failures else 0)
