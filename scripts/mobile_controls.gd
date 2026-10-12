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
	for action in ["Interagir", "Usar item", "Recarregar", "Inventário", "Fabricação"]:
		var button := Button.new()
		button.text = action
		button.set_meta("gameplay_action", action)
		button.custom_minimum_size = Vector2(112, 64)
		button.add_theme_font_size_override("font_size", 20)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(invoke.bind(action))
		actions.add_child(button)
		if action == "Interagir": interact_button = button
	player.get_node("Interaction").pickup_changed.connect(update_interaction_label)
	placement = HBoxContainer.new()
	add_child(placement)
	for action in ["Confirmar", "Cancelar"]:
		var button := Button.new()
		button.text = action
		button.custom_minimum_size = Vector2(140, 64)
		button.add_theme_font_size_override("font_size", 20)
		button.pressed.connect(func():
			if action == "Confirmar":
				if not structures.confirm(): hud.show_message("Escolha terreno livre, perto do jogador.")
			else: structures.cancel())
		placement.add_child(button)
	rotate = Label.new()
	rotate.text = "Gire o aparelho para jogar na horizontal"
	rotate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotate.add_theme_font_size_override("font_size", 26)
	rotate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rotate)
	layout()

func update_interaction_label(_message: String) -> void:
	var pickup: Node = player.get_node("Interaction").pickup
	var caption := "Interagir"
	if is_instance_valid(pickup):
		if pickup is ResourceDrop: caption = "Coletar"
		elif pickup is WaterWell: caption = "Beber"
		elif pickup is PlacedStructure: caption = {"cama": "Usar cama", "fogueira": "Cozinhar", "bau": "Abrir"}.get(pickup.kind, "Interagir")
		else: caption = "Abrir"
	interact_button.text = caption

func layout() -> void:
	reset()
	var viewport_size := get_viewport_rect().size
	portrait = viewport_size.y > viewport_size.x
	visible = MobileInput.enabled
	centers.move = Vector2(100, viewport_size.y - 115)
	centers.aim = Vector2(viewport_size.x - 100, viewport_size.y - 115)
	actions.position = Vector2((viewport_size.x - 576) / 2, viewport_size.y - 144)
	placement.position = Vector2((viewport_size.x - 284) / 2, viewport_size.y - 144)
	rotate.position = Vector2(0, viewport_size.y / 2)
	rotate.size.x = viewport_size.x
	rotate.visible = portrait
	player.controls_blocked = portrait and MobileInput.enabled or hud.current_panel != "" or player.dead
	hud.mobile_layout(MobileInput.enabled)
	queue_redraw()

func _process(_delta: float) -> void:
	actions.visible = not portrait and hud.current_panel == "" and not hud.showing_death and not structures.active
	placement.visible = not portrait and structures.active

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
			in_stick = in_stick or event.position.distance_to(centers[side]) <= RADIUS * 1.35
		if not in_stick and not structures.active: return false
	var converted := InputEventScreenTouch.new()
	converted.index = -100
	converted.position = event.position
	converted.pressed = event.pressed
	touch(converted)
	return true

func touch(event: InputEvent) -> void:
	if not MobileInput.enabled or portrait or hud.current_panel != "" or player.dead: return
	if event is InputEventScreenTouch and event.pressed:
		if structures.active:
			if MobileInput.button_at(get_tree().root, event.position) == null:
				structures.update_preview(player.get_canvas_transform().affine_inverse() * event.position)
			return
		for side in ["move", "aim"]:
			if fingers[side] == -1 and event.position.distance_to(centers[side]) <= RADIUS * 1.35:
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
	var direction: Vector2 = ((point - centers[side]) / RADIUS).limit_length()
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
	elif hud.current_panel == "" and not player.dead and not portrait and not structures.active:
		var interaction := player.get_node("Interaction")
		match action:
			"Interagir": interaction.collect_nearest()
			"Usar item": interaction.use_requested.emit(hud.inventory.selected_index)
			"Recarregar": interaction.weapons.reload()

func _draw() -> void:
	if portrait or hud.current_panel != "" or hud.showing_death or structures.active: return
	for side in ["move", "aim"]:
		draw_circle(centers[side], RADIUS, Color(0.08, 0.14, 0.11, 0.6))
		draw_arc(centers[side], RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.5), 2)
		draw_circle(centers[side] + vectors[side] * RADIUS * 0.65, 24, Color(0.8, 0.9, 0.7, 0.8))
		draw_string(ThemeDB.fallback_font, centers[side] + Vector2(-32, -85), "Andar" if side == "move" else "Atacar", HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
