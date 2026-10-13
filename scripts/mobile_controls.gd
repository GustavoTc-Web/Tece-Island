extends Control

var player: CharacterBody2D
var hud: CanvasLayer
var structures: Node2D
var session: Node
var fingers := {"move": -1, "aim": -1}
var vectors := {"move": Vector2.ZERO, "aim": Vector2.ZERO}
var centers := {"move": Vector2.ZERO, "aim": Vector2.ZERO}
var actions: HBoxContainer
var interact_button: Button
var placement: HBoxContainer
var rotate: Label
var portrait := false
var rotate_piece: Button
var use_button: Button
var reload_button: Button
var radius := RADIUS
const RADIUS := 68.0
const DEADZONE := 0.22

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	MobileInput.overlay = self
	MobileInput.mode_changed.connect(layout)
	get_viewport().size_changed.connect(layout)
	hud.panel_toggled.connect(func(_open): reset())
	actions = HBoxContainer.new()
	add_child(actions)
	for action in ["Interagir", "Usar item", "Recarregar", "Inventário"]:
		var button := Button.new()
		button.text = action
		button.set_meta("gameplay_action", action)
		button.custom_minimum_size = Vector2(112, 64)
		button.add_theme_font_size_override("font_size", 20)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(invoke.bind(action))
		actions.add_child(button)
		if action == "Interagir": interact_button = button
		if action == "Usar item": use_button = button
		if action == "Recarregar": reload_button = button
	player.get_node("Interaction").pickup_changed.connect(update_interaction_label)
	placement = HBoxContainer.new()
	add_child(placement)
	for action in ["Confirmar", "Cancelar", "Girar"]:
		var button := Button.new()
		button.text = action
		button.custom_minimum_size = Vector2(140, 64)
		button.add_theme_font_size_override("font_size", 20)
		if action == "Girar": rotate_piece = button
		button.pressed.connect(func():
			if action == "Confirmar":
				if not structures.confirm(): hud.show_message("Escolha terreno livre, perto do jogador.")
			elif action == "Girar": structures.rotate_placement()
			else: structures.cancel())
		placement.add_child(button)
	rotate = Label.new()
	rotate.text = "Gire o aparelho para jogar na horizontal"
	rotate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotate.add_theme_font_size_override("font_size", 26)
	rotate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rotate)
	hud.touch_goal_initialized = false
	layout()

func update_interaction_label(_message: String) -> void:
	var pickup: Node = player.get_node("Interaction").pickup
	var caption := "Interagir"
	if is_instance_valid(pickup):
		if pickup is ResourceDrop: caption = "Coletar"
		elif pickup is ExpeditionRecord: caption = "Ler registro"
		elif pickup is WaterWell: caption = "Beber"
		elif pickup is PlacedStructure: caption = {"cama": "Usar cama", "fogueira": "Cozinhar", "bau": "Abrir", "porta_madeira": "Fechar" if pickup.door_open else "Abrir"}.get(pickup.kind, "Interagir")
		else: caption = "Abrir"
	interact_button.text = caption

func layout() -> void:
	reset()
	var viewport_size := get_viewport_rect().size
	portrait = viewport_size.y > viewport_size.x
	visible = MobileInput.enabled
	var unit := MobileInput.touch_minimum()
	var gap := ceilf(8 / MobileInput.css_scale())
	radius = maxf(RADIUS, unit * 0.78)
	centers.move = Vector2(radius + 24, viewport_size.y - unit * 2 - gap * 3 - radius)
	centers.aim = Vector2(viewport_size.x - radius - 24, centers.move.y)
	for container in [actions, placement]:
		container.add_theme_constant_override("separation", int(gap))
		for button in container.get_children():
			button.custom_minimum_size = Vector2(unit * 1.75, unit)
			button.add_theme_font_size_override("font_size", int(maxf(20, ceilf(14 / MobileInput.css_scale()))))
		container.size = container.get_combined_minimum_size()
	actions.position.y = viewport_size.y - unit * 2 - gap * 2
	placement.position.y = actions.position.y
	rotate.position = Vector2(0, viewport_size.y / 2)
	rotate.size.x = viewport_size.x
	rotate.visible = false
	player.controls_blocked = hud.current_panel != "" or player.dead or OrientationGuard.blocked
	hud.mobile_layout(MobileInput.enabled)
	queue_redraw()

func _process(_delta: float) -> void:
	rotate_piece.visible = structures.item in PlacedStructure.PIECES
	var tool: String = hud.inventory.equipped_tool()
	reload_button.visible = tool in GunRules.WEAPONS and tool != "arco"
	var slot: Dictionary = hud.inventory.slots[hud.inventory.selected_index]
	var item: String = slot.get("item", "")
	use_button.visible = item == "cantil" or ItemCatalog.category(item) == "comida"
	use_button.text = "Beber" if item == "cantil" else "Comer"
	actions.position.x = (get_viewport_rect().size.x - actions.get_combined_minimum_size().x) / 2
	placement.position.x = (get_viewport_rect().size.x - placement.get_combined_minimum_size().x) / 2
	actions.visible = hud.current_panel == "" and not hud.showing_death and not structures.active
	placement.visible = structures.active and hud.current_panel == ""

func reset() -> void:
	fingers = {"move": -1, "aim": -1}
	vectors = {"move": Vector2.ZERO, "aim": Vector2.ZERO}
	if is_instance_valid(player):
		player.touch_movement = Vector2.ZERO
		player.get_node("Interaction").set_touch_aim(Vector2.ZERO)
		player.get_node("Interaction").mouse_held = false
		player.get_node("Interaction").key_held = false
	queue_redraw()

func mouse_touch(event: InputEventMouseButton) -> bool:
	if not event.pressed and not fingers.values().has(-100): return false
	if event.pressed:
		if MobileInput.button_at(get_tree().root, event.position) != null: return false
		var in_stick := false
		for side in ["move", "aim"]:
			in_stick = in_stick or event.position.distance_to(centers[side]) <= radius * 1.1
		if not in_stick and not structures.active: return false
	var converted := InputEventScreenTouch.new()
	converted.index = -100
	converted.position = event.position
	converted.pressed = event.pressed
	touch(converted)
	return true

func touch(event: InputEvent) -> void:
	if not MobileInput.enabled or hud.current_panel != "" or player.dead: return
	if event is InputEventScreenTouch and event.pressed:
		if structures.active:
			if MobileInput.button_at(get_tree().root, event.position) == null:
				structures.update_preview(player.get_canvas_transform().affine_inverse() * event.position)
			return
		for side in ["move", "aim"]:
			if fingers[side] == -1 and event.position.distance_to(centers[side]) <= radius * 1.1:
				fingers[side] = event.index
				update_stick(side, event.position)
				return
	elif event is InputEventScreenTouch:
		for side in ["move", "aim"]:
			if fingers[side] == event.index:
				fingers[side] = -1
				update_stick(side, centers[side])
	elif event is InputEventScreenDrag:
		for side in ["move", "aim"]:
			if fingers[side] == event.index: update_stick(side, event.position)

func update_stick(side: String, point: Vector2) -> void:
	var direction: Vector2 = ((point - centers[side]) / radius).limit_length()
	if direction.length() < DEADZONE: direction = Vector2.ZERO
	vectors[side] = direction
	if side == "move": player.touch_movement = direction
	else: player.get_node("Interaction").set_touch_aim(direction)
	queue_redraw()

func invoke(action: String) -> void:
	if action == "Inventário":
		hud.set_panel("inventory")
	elif action == "Fabricação":
		hud.set_panel("crafting")
	elif hud.current_panel == "" and not player.dead and not structures.active:
		var interaction := player.get_node("Interaction")
		match action:
			"Interagir": interaction.collect_nearest()
			"Usar item": interaction.use_requested.emit(hud.inventory.selected_index)
			"Recarregar": interaction.weapons.reload()

func _draw() -> void:
	if hud.current_panel != "" or hud.showing_death or structures.active: return
	for side in ["move", "aim"]:
		draw_circle(centers[side], radius, Color(0.08, 0.14, 0.11, 0.6))
		draw_arc(centers[side], radius, 0, TAU, 48, Color(1, 1, 1, 0.5), 2)
		draw_circle(centers[side] + vectors[side] * radius * 0.65, radius * 0.35, Color(0.8, 0.9, 0.7, 0.8))
		draw_string(IslandTheme.BODY, centers[side] + Vector2(-32, -radius - 17), "Andar" if side == "move" else "Atacar", HORIZONTAL_ALIGNMENT_LEFT, -1, int(maxf(18, 12 / MobileInput.css_scale())))
