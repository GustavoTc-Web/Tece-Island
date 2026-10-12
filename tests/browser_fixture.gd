# Test build only: excluded from the published preset.
extends Node
var session: Node
var callback: JavaScriptObject
var snapshot_time := 0.0
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	session = load("res://scenes/main.tscn").instantiate()
	add_child(session)
	callback = JavaScriptBridge.create_callback(command)
	JavaScriptBridge.get_interface("window").tcFixture = callback
func command(args: Array) -> void:
	var request: Dictionary = JSON.parse_string(str(args[0]))
	if session.game == null: return
	var world: Node = session.game
	var inv: ResourceInventory = world.get_node("Inventory")
	var player: CharacterBody2D = world.get_node("WorldObjects/Player")
	match request.action:
		"items":
			inv.reset()
			for item in request.items: inv.add_item(item)
		"add":
			for item in request.items: inv.add_item(item)
		"position": player.position = Vector2(request.x, request.y)
		"clear_drops":
			for drop in get_tree().get_nodes_in_group("resource_drops"): drop.queue_free()
		"needs":
			player.get_node("Needs").hunger = request.hunger
			player.get_node("Needs").thirst = request.thirst
		"night":
			var cycle: DayNightCycle = world.get_node("DayNight")
			cycle.elapsed = cycle.day_duration + 40
			cycle.refresh()
		"fire":
			var fire: PlacedStructure = load("res://scenes/placed_structure.tscn").instantiate()
			fire.kind = "fogueira"
			fire.system = world.get_node("Structures")
			fire.position = player.position + Vector2(65, 0)
			world.get_node("WorldObjects").add_child(fire)
			inv.cooking_available = true
			fire.interact(inv)
		"chest":
			var chest: PlacedStructure = load("res://scenes/placed_structure.tscn").instantiate()
			chest.kind = "bau"
			chest.system = world.get_node("Structures")
			chest.position = player.position + Vector2(65, 0)
			world.get_node("WorldObjects").add_child(chest)
			chest.interact(inv)
		"monsters":
			for kind in ["esqueleto", "aranha"]:
				var enemy: ForestCreature = load("res://scenes/forest_creature.tscn").instantiate()
				enemy.kind = kind
				enemy.origin = "guardiao"
				enemy.safe_radius = 0
				enemy.player = player
				enemy.position = player.position + (Vector2(-160, 0) if kind == "esqueleto" else Vector2(160, 0))
				world.get_node("WorldObjects").add_child(enemy)
				enemy.set_physics_process(false)
				if kind == "esqueleto": enemy.try_attack()
		"aquatic":
			player.position = Vector2(-1000, 300)
			for animal in get_tree().get_nodes_in_group("animals"):
				animal.set_physics_process(false)
				if animal.global_position.distance_to(player.position) < 300: animal.queue_free()
			var fish := NeutralAnimal.new()
			fish.kind = "lambari"
			fish.position = player.position + Vector2(55, 0)
			fish.player = player
			fish.habitat = WorldTerrain.AQUATIC[0].rect
			world.get_node("WorldObjects").add_child(fish)
			fish.set_physics_process(false)
		"bird_art":
			var bird := NeutralAnimal.new()
			bird.kind = "garca_azul"
			bird.position = player.position + Vector2(160, 50)
			bird.player = player
			world.get_node("WorldObjects").add_child(bird)
			bird.set_physics_process(false)
func rect(control: Control) -> Array:
	var box := control.get_global_rect()
	return [box.position.x, box.position.y, box.size.x, box.size.y]
func _process(_delta: float) -> void:
	snapshot_time += _delta
	if snapshot_time < 0.1: return
	snapshot_time = 0.0
	var data := {"menu": session.menu != null, "paused": get_tree().paused}
	var buttons := {}
	for button in session.find_children("*", "Button", true, false):
		if button.is_visible_in_tree():
			buttons[button.text] = rect(button)
			if button.has_meta("gameplay_action"): buttons[button.get_meta("gameplay_action")] = rect(button)
	data.buttons = buttons
	if session.game != null:
		var world: Node = session.game
		var player: CharacterBody2D = world.get_node("WorldObjects/Player")
		var inv: ResourceInventory = world.get_node("Inventory")
		var hud: Node = world.get_node("HUD")
		var structures: Node = world.get_node("Structures")
		var interaction: Node = player.get_node("Interaction")
		data.merge({"position":[player.position.x,player.position.y], "slots":inv.slots, "selected":inv.selected_index, "panel":hud.current_panel, "aim":[interaction.touch_aim.x,interaction.touch_aim.y], "move":[player.touch_movement.x,player.touch_movement.y], "mouse_held":interaction.mouse_held, "hunger":player.get_node("Needs").hunger, "thirst":player.get_node("Needs").thirst, "placing":structures.active, "valid":structures.valid, "structures":[], "quick":[], "inventory_buttons":[], "recipes":{}, "fps":Engine.get_frames_per_second(), "day":world.get_node("DayNight").day_number})
		for index in range(5): data.quick.append(rect(hud.quick_buttons[index]))
		for button in hud.slot_buttons: data.inventory_buttons.append(rect(button))
		for id in hud.recipe_buttons:
			if hud.recipe_buttons[id].is_visible_in_tree(): data.recipes[id] = rect(hud.recipe_buttons[id])
		data.search = rect(hud.crafting_view.search)
		data.capacity = inv.capacity
		data.swimming = player.swimming
		data.dark = world.get_node("DayNight").local_darkness
		data.minimap = rect(world.minimap)
		data.explored = world.minimap.explored.size()
		data.region = WorldTerrain.region_at(player.global_position).get("id", "")
		data.temples = []
		for temple in world.ruins.temples: data.temples.append([temple.position.x, temple.position.y])
		data.player_screen = [player.get_global_transform_with_canvas().origin.x, player.get_global_transform_with_canvas().origin.y]
		data.backpack = inv.backpack
		if hud.storage_view != null and is_instance_valid(hud.storage_view.chest):
			data.storage_slots = hud.storage_view.chest.storage.slots
			data.storage_buttons = []
			for button in hud.storage_view.grid.get_children(): data.storage_buttons.append(rect(button))
			data.storage_status = hud.storage_view.status.text
		data.recipe_descriptions = {}
		for id in hud.crafting_view.labels:
			data.recipe_descriptions[id] = hud.crafting_view.labels[id].text
		for structure in world.get_node("WorldObjects").get_children():
			if structure is PlacedStructure: data.structures.append({"kind":structure.kind,"x":structure.position.x,"y":structure.position.y})
		data.scroll = hud.get_node("InventoryPanel/Panel/Scroll").scroll_vertical
		data.bed_registered = is_instance_valid(structures.respawn_bed)
		data.placement_points = []
		if structures.active:
			for offset in [Vector2(85, 0), Vector2(0, 85), Vector2(-85, 0), Vector2(0, -85)]:
				var point: Vector2 = player.position + offset
				if structures.can_place(point):
					var screen: Vector2 = player.get_canvas_transform() * point
					data.placement_points.append([screen.x, screen.y])
		data.viewport = [get_viewport().get_visible_rect().size.x,get_viewport().get_visible_rect().size.y]
		if is_instance_valid(MobileInput.overlay):
			data.portrait = MobileInput.overlay.portrait
	JavaScriptBridge.eval("window.tcState = " + JSON.stringify(data))
