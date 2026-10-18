# Test build only: excluded from the published preset.
extends Node
var session: Node
var callback: JavaScriptObject
var snapshot_time := 0.0
var account_checks := {}
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Reproducible offline gameplay data, never authentication/session data.
	if not FileAccess.file_exists("user://solo-progress.json"):
		SaveStore.new().write({"version": SaveStore.VERSION, "inventory": {"slots": [], "backpack": {}, "selected": 0}, "world_seed": 77})
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
		"campaign_visit":
			world.get_node("HUD").set_panel("")
			player.position = world.campaign.points[str(request.id)].position + Vector2(0, 40)
			world.get_node("EnemySpawner").set_physics_process(false)
			world.get_node("DayNight").set_physics_process(false)
		"campaign_night":
			world.get_node("DayNight").elapsed = 6 * 600 + 320
			world.get_node("DayNight").refresh()
		"campaign_win":
			if is_instance_valid(world.campaign.boss): world.campaign.boss.receive_damage(300)
		"campaign_journal": world.get_node("HUD").set_panel("journal")
		"icon_gallery":
			var gallery := CanvasLayer.new()
			gallery.name = "IconGallery"
			gallery.layer = 50
			gallery.process_mode = Node.PROCESS_MODE_ALWAYS
			world.add_child(gallery)
			var shade := ColorRect.new()
			shade.color = Color("172f27")
			shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			gallery.add_child(shade)
			var grid := GridContainer.new()
			grid.columns = 7
			grid.position = Vector2(16, 10)
			gallery.add_child(grid)
			for id in ItemIcon.IDS:
				var cell := VBoxContainer.new()
				cell.custom_minimum_size = Vector2(128, 100)
				grid.add_child(cell)
				var icon := ItemIcon.new()
				icon.item = id
				cell.add_child(icon)
				var title := Label.new()
				title.text = ItemCatalog.title(id)
				title.add_theme_font_size_override("font_size", 13)
				title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				cell.add_child(title)
			get_tree().paused = true
		"close_gallery":
			world.get_node("IconGallery").queue_free()
			get_tree().paused = false
		"drop_probe":
			for drop in get_tree().get_nodes_in_group("resource_drops"): drop.queue_free()
			var drop: ResourceDrop = load("res://scenes/resource_drop.tscn").instantiate()
			drop.resource = "madeira"
			drop.quantity = 5
			drop.position = player.position + Vector2(0, 35)
			world.get_node("WorldObjects").add_child(drop)
		"save_error":
			world.save_controller.set_process(false)
			world.get_node("HUD").show_save_state("Erro de teste", true)
		"save_ok": world.get_node("HUD").show_save_state("Progresso salvo.", false)
		"account_probe": account_probe(world, str(request.seed), str(request.get("phase", "write")))
		"record":
			for enemy in get_tree().get_nodes_in_group("enemies"): enemy.set_physics_process(false)
			for note in get_tree().get_nodes_in_group("expedition_records"):
				if note.journal == world.journal and note.record_id == request.id:
					player.position = note.position + Vector2(0, 35)
		"combat_probe":
			for node in get_tree().get_nodes_in_group("enemies"): node.set_physics_process(false)
			var enemy: ForestCreature = load("res://scenes/forest_creature.tscn").instantiate()
			enemy.origin = "guardiao"
			enemy.safe_radius = 0
			enemy.player = player
			enemy.set_meta("combat_probe", true)
			enemy.position = player.position + Vector2(40, 0)
			world.get_node("WorldObjects").add_child(enemy)
			enemy.set_physics_process(false)
			player.apply_poison(3)
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
		"health": player.health = float(request.value); world.get_node("HUD").update_health(player.health, player.max_health)
		"goals":
			world.objectives.collected("madeira", 10)
			world.objectives.collected("pedra", 10)
			for id in IslandObjectives.STONE_TOOLS: world.objectives.crafted(id)
			world.objectives.crafted("fogueira")
			world.objectives.crafted("mochila_3")
		"save": world.save_progress(true)
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
			if bool(request.get("open", true)): chest.interact(inv)
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
func account_probe(world: Node, seed_value: String, phase: String) -> void:
	account_checks = {"busy": true}
	var folder := "user://account-fixture-" + seed_value
	var a := AccountProgress.new()
	a.configure("fixture-web-A-" + seed_value, folder)
	var b := AccountProgress.new()
	b.configure("fixture-web-B-" + seed_value, folder)
	if phase == "write":
		var progress := WorldProgress.new()
		progress.world = world
		var data := progress.capture()
		data.owner_uid = a.uid
		data.player.health = 87
		var other := data.duplicate(true)
		other.owner_uid = b.uid
		other.player.health = 62
		other.journal = {"discovered": ["trail"], "unread": {"trail": true}}
		var ok_a := await a.write(data, get_tree())
		var ok_b := await b.write(other, get_tree())
		var legacy := SaveStore.new()
		DirAccess.make_dir_recursive_absolute(folder)
		legacy.path = folder.path_join("solo-progress.json")
		data.erase("owner_uid")
		data.version = 3
		legacy.write(data)
		var original := FileAccess.get_file_as_string(legacy.path)
		var c := AccountProgress.new()
		c.configure("fixture-web-C-" + seed_value, folder)
		var imported := await c.import_legacy(get_tree())
		var d := AccountProgress.new()
		d.configure("fixture-web-D-" + seed_value, folder)
		var rejected := not await d.import_legacy(get_tree())
		account_checks = {"written": ok_a and ok_b, "imported": imported, "second_import_blocked": rejected, "legacy_preserved": FileAccess.get_file_as_string(legacy.path) == original}
	else: account_checks = {}
	var one := await a.read(get_tree())
	var two := await b.read(get_tree())
	account_checks.isolated = not one.is_empty() and not two.is_empty() and one.player.health == 87 and two.player.health == 62 and one.owner_uid == a.uid and two.owner_uid == b.uid and two.journal.discovered == ["trail"]
	account_checks.busy = false

func rect(control: Control) -> Array:
	var box := control.get_global_rect()
	return [box.position.x, box.position.y, box.size.x, box.size.y]
func _process(_delta: float) -> void:
	snapshot_time += _delta
	if snapshot_time < 0.1: return
	snapshot_time = 0.0
	var data := {"menu": session.menu != null, "paused": get_tree().paused, "viewport":[get_viewport().get_visible_rect().size.x,get_viewport().get_visible_rect().size.y]}
	data.auth = session.auth_screen != null
	data.orientation_blocked = OrientationGuard.blocked
	if session.library != null: data.library = session.library.data
	if session.menu != null:
		data.world_name = rect(session.menu.world_name)
		data.lobby_page = session.menu.page
		data.dialog_mode = session.menu.dialog_mode
		data.continue_caption = session.menu.continue_caption.text
		data.primary_caption = session.menu.primary.text
		data.selected_world = session.menu.selected_world
		data.transitioning = session.transitioning
	var buttons := {}
	var clips := {}
	for button in session.find_children("*", "Button", true, false):
		if button.is_visible_in_tree():
			buttons[button.text] = rect(button)
			var bounds := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
			var parent: Node = button.get_parent()
			while parent != null:
				if parent is Control and parent.clip_contents: bounds = bounds.intersection(parent.get_global_rect())
				parent = parent.get_parent()
			clips[button.text] = [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y]
			if button.has_meta("gameplay_action"): buttons[button.get_meta("gameplay_action")] = rect(button)
	data.buttons = buttons
	data.button_clips = clips
	data.account_checks = account_checks
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
		data.crafting_scroll = rect(hud.get_node("Crafting/Panel/Rows/Scroll"))
		data.open_item_panels = {"inventory": hud.get_node("InventoryPanel").visible, "crafting": hud.get_node("Crafting").visible}
		data.capacity = inv.capacity
		data.swimming = player.swimming
		data.dark = world.get_node("DayNight").local_darkness
		data.minimap = rect(world.minimap)
		data.explored = world.minimap.explored.size()
		data.region = WorldTerrain.region_at(player.global_position).get("id", "")
		data.wells = []
		for node in world.get_node("WorldObjects").get_children():
			if node is WaterWell: data.wells.append([node.position.x, node.position.y])
		data.temples = []
		for temple in world.ruins.temples: data.temples.append([temple.position.x, temple.position.y])
		data.player_screen = [player.get_global_transform_with_canvas().origin.x, player.get_global_transform_with_canvas().origin.y]
		data.backpack = inv.backpack
		data.journal = world.journal.capture()
		data.objectives = world.objectives.capture()
		data.campaign = world.campaign.capture()
		data.campaign_text = hud.journal_view.campaign_text.text
		data.campaign_objective_rect = rect(hud.objective_button)
		data.world_id = world.world_id
		data.health = player.health
		data.dead = player.dead
		data.armor = inv.armor
		data.protection = player.protection
		data.regeneration_ticks = player.regeneration_ticks
		data.clock_text = hud.get_node("Controls/Rows/Time").text
		data.objective_text = hud.objective_button.text
		data.quick_details = []
		for button in hud.quick_buttons: data.quick_details.append({"icon": rect(button.item_icon), "quantity": rect(button.quantity), "text": button.quantity.text, "item": button.item_icon.item, "border": button.get_theme_stylebox("normal").border_width_left})
		data.building_labels = []
		for building in world.get_node("WorldObjects").get_children():
			if building is AbandonedBuilding: data.building_labels.append({"x": building.position.x, "y": building.position.y, "visible": building.name_visible})
		data.status_bars = [rect(hud.get_node("Controls/Rows/Health"))]
		for kind in ["Sede", "Fome", "Proteção"]: data.status_bars.append(rect(hud.needs_bars[kind]))
		data.poison = player.poison_remaining
		data.poison_text = hud.poison_status.text if hud.poison_status != null and hud.poison_status.visible else ""
		if hud.poison_status != null: data.poison_rect = rect(hud.poison_status)
		data.effects = get_tree().get_nodes_in_group("combat_effects").size()
		for node in world.get_node("WorldObjects").get_children():
			if node is ForestCreature and node.has_meta("combat_probe"):
				var point: Vector2 = node.get_global_transform_with_canvas().origin
				data.combat_enemy = {"health": node.health, "bar": node.combat_visible, "screen": [point.x, point.y]}
		data.sound = {"muted": CombatAudio.muted, "volume": CombatAudio.volume}
		if hud.combat_options != null:
			for slider in hud.combat_options.find_children("*", "HSlider", true, false): data.volume_slider = rect(slider)
		if hud.journal_view != null: data.journal_text = hud.journal_view.text.text
		if hud.base_view != null:
			data.base_status = hud.base_view.status.text
			data.base_confirm_enabled = not hud.base_view.confirm.disabled
		if hud.save_button != null: data.save_status = hud.save_button.text
		data.save_visible = hud.save_button.visible if hud.save_button != null else false
		data.diagnostic = hud.menu_view.diagnostic()
		if hud.storage_view != null and is_instance_valid(hud.storage_view.chest):
			data.storage_slots = hud.storage_view.chest.storage.slots
			data.storage_buttons = []
			for button in hud.storage_view.grid.get_children(): data.storage_buttons.append(rect(button))
			data.storage_status = hud.storage_view.status.text
			data.chest_name_input = rect(hud.storage_view.name_input)
		data.recipe_descriptions = {}
		for id in hud.crafting_view.labels:
			data.recipe_descriptions[id] = hud.crafting_view.labels[id].text
		for structure in world.get_node("WorldObjects").get_children():
			if structure is PlacedStructure: data.structures.append({"id":structure.structure_id,"chest_name":structure.chest_name,"kind":structure.kind,"x":structure.position.x,"y":structure.position.y,"rotation":structure.rotation,"door_open":structure.door_open})
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
			data.stick_radius = MobileInput.overlay.radius
			data.action_shortcuts = []
			for shortcut in MobileInput.overlay.actions.get_children():
				data.action_shortcuts.append({"caption": shortcut.text, "icon": shortcut.icon.resource_path, "rect": rect(shortcut)})
			data.sticks = {"move":[MobileInput.overlay.centers.move.x, MobileInput.overlay.centers.move.y], "aim":[MobileInput.overlay.centers.aim.x, MobileInput.overlay.centers.aim.y]}
	JavaScriptBridge.eval("window.tcState = " + JSON.stringify(data))
