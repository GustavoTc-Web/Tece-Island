class_name StorageView
extends Control
var hud: CanvasLayer
var inventory: ResourceInventory
var chest: PlacedStructure
var grid: GridContainer
var status: Label
var title: Label
var selected := -1
var from_player := true
var transfer_one: Button
var transfer_all: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.08, 0.06, 0.85)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-295, -215)
	panel.custom_minimum_size = Vector2(590, 430)
	add_child(panel)
	var rows := VBoxContainer.new()
	panel.add_child(rows)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 20)
	rows.add_child(title)
	var tabs := HBoxContainer.new()
	rows.add_child(tabs)
	for name in ["Inventário", "Baú"]:
		var button := Button.new()
		button.text = name
		button.custom_minimum_size.y = 52
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func(): from_player = name == "Inventário"; selected = -1; refresh())
		tabs.add_child(button)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 180
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rows.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	var actions := HBoxContainer.new()
	rows.add_child(actions)
	for whole in [false, true]:
		var button := Button.new()
		button.custom_minimum_size.y = 52
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(transfer.bind(whole))
		actions.add_child(button)
		if whole: transfer_all = button
		else: transfer_one = button
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.x = 570
	rows.add_child(status)
	var footer := HBoxContainer.new()
	rows.add_child(footer)
	for name in ["Desmontar baú", "Fechar"]:
		var button := Button.new()
		button.text = name
		button.custom_minimum_size.y = 52
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func():
			if name == "Fechar": hud.set_panel("")
			elif reachable():
				status.text = chest.dismantle(inventory)
				if chest.is_queued_for_deletion(): hud.set_panel(""))
		footer.add_child(button)
	if MobileInput.enabled: hud.touch_sizes(self)

func open(target: PlacedStructure) -> void:
	chest = target
	from_player = true
	selected = -1
	status.text = "Selecione um item para transferir."
	refresh()

func reachable() -> bool:
	if not is_instance_valid(chest) or chest.is_queued_for_deletion(): return false
	var player: CharacterBody2D = chest.system.player
	if player.global_position.distance_to(chest.global_position) > 90: return false
	var ray := PhysicsRayQueryParameters2D.create(player.global_position, chest.global_position, 1)
	var collision := player.get_world_2d().direct_space_state.intersect_ray(ray)
	return collision.is_empty() or collision.collider == chest

func refresh() -> void:
	if not is_instance_valid(chest): return
	var source: ResourceInventory = inventory if from_player else chest.storage
	title.text = "%s · %d espaços" % ["Inventário" if from_player else "Baú", source.capacity]
	transfer_one.text = ("Guardar" if from_player else "Retirar") + " 1"
	transfer_all.text = ("Guardar" if from_player else "Retirar") + " pilha"
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	for index in range(source.capacity):
		var data := source.slot_data(index)
		var button := Button.new()
		button.custom_minimum_size = Vector2(138, 58)
		button.add_theme_font_size_override("font_size", 14)
		button.clip_text = true
		button.text = "%d\n%s" % [index + 1, "Vazio" if data.is_empty() else ItemCatalog.title(data.item) + " ×" + str(data.quantity)]
		if data.get("item", "") == "cantil": button.text += " · %d/3" % int(data.get("water", 0))
		button.modulate = Color("f2d786") if index == selected else Color.WHITE
		button.pressed.connect(func(): selected = index; refresh())
		grid.add_child(button)
	transfer_one.disabled = source.slot_data(selected).is_empty()
	transfer_all.disabled = transfer_one.disabled

func transfer(whole: bool) -> void:
	if hud.current_panel != "chest": return
	if not reachable():
		status.text = "Aproxime-se do baú para transferir."
		return
	var source: ResourceInventory = inventory if from_player else chest.storage
	var destination: ResourceInventory = chest.storage if from_player else inventory
	var accepted := source.transfer_to(destination, selected, whole)
	status.text = "%d unidade(s) transferida(s)." % accepted if accepted > 0 else "Destino cheio: libere espaço antes de transferir."
	refresh()
