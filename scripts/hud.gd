extends CanvasLayer

signal panel_toggled(open: bool)
signal respawn_requested
signal placement_requested(index: int)
signal discard_requested(index: int, whole: bool)
signal use_requested(index: int)
signal network_action_requested(action: String, argument: Variant)
var network_mode: bool = false

var inventory: ResourceInventory
var recipe_buttons: Dictionary = {}
var slot_buttons: Array[Button] = []
var selected_slot: int = -1
var current_panel: String = ""
var showing_death: bool = false
var quick_buttons: Array[Button] = []
var moving_slot := -1
var active_well: WaterWell
var needs_bars: Dictionary = {}
var crafting_view: CraftingView
var storage_view: StorageView


func initialize(source: ResourceInventory) -> void:
	inventory = source
	inventory.changed.connect(_refresh_recipes)
	inventory.changed.connect(_refresh_inventory)
	inventory.changed.connect(func(_wood, _stone): show_equipment(inventory.equipped_tool()))
	inventory.equipment_changed.connect(show_equipment)
	crafting_view = CraftingView.new()
	crafting_view.initialize(self, inventory)
	_sync_slots()
	var backpack_row := HBoxContainer.new()
	backpack_row.name = "BackpackSlot"
	$InventoryPanel/Panel/Scroll/Rows.add_child(backpack_row)
	$InventoryPanel/Panel/Scroll/Rows.move_child(backpack_row, 1)
	var backpack_label := Label.new()
	backpack_label.text = "Bolsa: "
	backpack_row.add_child(backpack_label)
	var backpack_button := Button.new()
	backpack_button.name = "Remove"
	backpack_button.focus_mode = Control.FOCUS_NONE
	backpack_button.pressed.connect(_remove_backpack)
	backpack_row.add_child(backpack_button)
	var drop_bag := Button.new()
	drop_bag.text = "Jogar bolsa"
	drop_bag.focus_mode = Control.FOCUS_NONE
	drop_bag.pressed.connect(func(): discard_requested.emit(-2, true))
	backpack_row.add_child(drop_bag)
	var actions := GridContainer.new()
	actions.columns = 3
	$InventoryPanel/Panel/Scroll/Rows.add_child(actions)
	var place := Button.new()
	place.text = "Colocar selecionado"
	place.focus_mode = Control.FOCUS_NONE
	place.pressed.connect(func():
		if current_panel == "inventory":
			placement_requested.emit(selected_slot))
	actions.add_child(place)
	for whole in [false, true]:
		var drop_button := Button.new()
		drop_button.text = "Jogar pilha" if whole else "Jogar 1"
		drop_button.focus_mode = Control.FOCUS_NONE
		drop_button.pressed.connect(func():
			if network_mode: network_action_requested.emit("discard", {"index": selected_slot, "whole": whole})
			else: discard_requested.emit(selected_slot, whole))
		actions.add_child(drop_button)
	var move := Button.new()
	move.text = "Mover / trocar"
	move.focus_mode = Control.FOCUS_NONE
	move.pressed.connect(func():
		moving_slot = selected_slot
		show_message("Clique no espaço de destino para mover ou trocar"))
	actions.add_child(move)
	var use := Button.new()
	use.text = "Usar"
	use.focus_mode = Control.FOCUS_NONE
	use.pressed.connect(func():
		if network_mode: network_action_requested.emit("use", selected_slot)
		else: use_requested.emit(selected_slot))
	actions.add_child(use)
	var quick := HBoxContainer.new()
	quick.name = "Quickbar"
	quick.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	quick.position = Vector2(-260, -68)
	add_child(quick)
	for index in range(5):
		var button := Button.new()
		button.custom_minimum_size = Vector2(100, 54)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 12)
		button.clip_text = true
		button.pressed.connect(func():
			if current_panel != "" or showing_death: return
			if network_mode: network_action_requested.emit("select", index)
			else: inventory.select_quick(index))
		quick.add_child(button)
		quick_buttons.append(button)
	$Controls/Rows/EquipmentKeys.text = "1–5 / scroll: barra · Q / Shift+Q: jogar 1 / pilha\nR recarregar · C receitas · I inventário · E interagir"
	$InventoryPanel/Panel/Scroll/Rows/Equip.text = "Equipar este item"
	_create_needs_ui()
	_create_well_ui()
	_refresh_recipes(inventory.wood, inventory.stone)
	_refresh_inventory(inventory.wood, inventory.stone)
	show_equipment(inventory.equipped_tool())
	for panel in ["Crafting", "InventoryPanel"]:
		var close := Button.new()
		close.text = "Fechar"
		close.custom_minimum_size = Vector2(150, 52)
		close.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		close.position = Vector2(-75, 16)
		close.pressed.connect(func(): set_panel(""))
		get_node(panel).add_child(close)

func mobile_layout(value: bool) -> void:
	$Controls/Rows/Instructions.visible = not value
	$Controls/Rows/EquipmentKeys.visible = not value
	for label in [$Controls/Rows/Equipment, $Controls/Rows/Prompt, $Controls/Rows/Pickup, $Controls/Rows/Feedback]:
		label.custom_minimum_size.x = 360
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if value:
		touch_sizes(self)
		for button in quick_buttons: button.add_theme_font_size_override("font_size", 16)
		for button in slot_buttons: button.add_theme_font_size_override("font_size", 18)

func touch_sizes(node: Node) -> void:
	if node is Button:
		node.custom_minimum_size.y = maxf(node.custom_minimum_size.y, 64)
		node.add_theme_font_size_override("font_size", 20)
		node.clip_text = true
	if node is Label:
		node.add_theme_font_size_override("font_size", 18)
	for child in node.get_children(): touch_sizes(child)


func _sync_slots() -> void:
	while slot_buttons.size() > inventory.capacity:
		var button: Button = slot_buttons.pop_back()
		button.get_parent().remove_child(button)
		button.queue_free()
	for index in range(slot_buttons.size(), inventory.capacity):
		var button := Button.new()
		button.custom_minimum_size = Vector2(130, 52)
		button.add_theme_font_size_override("font_size", 12)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(select_slot.bind(index))
		$InventoryPanel/Panel/Scroll/Rows/Slots.add_child(button)
		slot_buttons.append(button)


func _remove_backpack() -> void:
	if network_mode:
		show_message("Mochilas fora da arena de teste")
		return
	if not inventory.remove_backpack():
		show_message("Remoção bloqueada: esvazie os espaços extras e reserve espaço para a bolsa.")


func _input(event: InputEvent) -> void:
	if showing_death or event.is_echo():
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit: return
	if event.is_action_pressed("crafting"):
		if network_mode:
			show_message("Fabricação fora da arena de teste")
			get_viewport().set_input_as_handled()
			return
		set_panel("" if current_panel in ["crafting", "cooking"] else "crafting")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory"):
		set_panel("" if current_panel == "inventory" else "inventory")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("close_panel") and current_panel != "":
		set_panel("")
		get_viewport().set_input_as_handled()


func set_panel(panel: String) -> void:
	if showing_death and panel != "":
		return
	current_panel = panel
	moving_slot = -1
	if has_node("Quickbar"): $Quickbar.visible = panel == "" and not showing_death
	$Crafting.visible = panel in ["crafting", "cooking"]
	if $Crafting.visible: crafting_view.open(panel == "cooking")
	$InventoryPanel.visible = panel == "inventory"
	if has_node("WellPanel"): $WellPanel.visible = panel == "well"
	if storage_view != null: storage_view.visible = panel == "chest"
	panel_toggled.emit(panel != "")


func open_cooking() -> void:
	set_panel("cooking")

func open_chest(chest: PlacedStructure) -> void:
	if storage_view == null:
		storage_view = StorageView.new()
		storage_view.hud = self
		storage_view.inventory = inventory
		add_child(storage_view)
	storage_view.open(chest)
	set_panel("chest")


func update_health(current: int, maximum: int) -> void:
	$Controls/Rows/Health.max_value = maximum
	$Controls/Rows/Health.value = current
	$Controls/Rows/HealthLabel.text = "Vida: %d / %d" % [current, maximum]


func update_time(day: int, phase: String) -> void:
	$Controls/Rows/Time.text = "Dia %d · %s" % [day, phase]

func update_clock(day: int, phase: String, remaining: int) -> void:
	$Controls/Rows/Time.text = "Dia %d · %s · próxima fase em %02d:%02d" % [day, phase, remaining / 60, remaining % 60]


func show_death(value: bool) -> void:
	showing_death = value
	$Death.visible = value
	if has_node("Quickbar"): $Quickbar.visible = not value and current_panel == ""


func _request_respawn() -> void:
	respawn_requested.emit()


func _craft(recipe_id: String) -> void:
	if network_mode:
		return
	if current_panel not in ["crafting", "cooking"]:
		return
	if ResourceRules.crafting_group(recipe_id) == "Fogueira":
		if current_panel != "cooking": return
		inventory.cooking_available = get_parent().get_node("Structures").near_fire(get_parent().get_node("WorldObjects/Player").global_position)
	if inventory.craft(recipe_id):
		show_message("Fabricado: " + ResourceRules.RECIPES[recipe_id].name)
	else:
		show_message(inventory.craft_error(recipe_id))

func _create_needs_ui() -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Controls/Rows.add_child(row)
	$Controls/Rows.move_child(row, 3)
	for kind in ["Fome", "Sede"]:
		var label := Label.new()
		label.text = kind
		label.add_theme_font_size_override("font_size", 12)
		row.add_child(label)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(125, 12)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.show_percentage = true
		bar.value = 100
		row.add_child(bar)
		needs_bars[kind] = bar

func update_needs(hunger: float, thirst: float) -> void:
	if needs_bars.is_empty(): return
	needs_bars.Fome.value = hunger
	needs_bars.Sede.value = thirst
	needs_bars.Fome.modulate = Color("f0a163") if hunger <= 25 else Color.WHITE
	needs_bars.Sede.modulate = Color("f0a163") if thirst <= 25 else Color.WHITE

func _create_well_ui() -> void:
	var panel := PanelContainer.new()
	panel.name = "WellPanel"
	panel.visible = false
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-160, -70)
	panel.custom_minimum_size = Vector2(320, 140)
	add_child(panel)
	var rows := VBoxContainer.new()
	panel.add_child(rows)
	var title := Label.new()
	title.text = "Poço — água potável"
	rows.add_child(title)
	for action in ["Beber", "Encher cantil", "Fechar"]:
		var button := Button.new()
		button.text = action
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_well_action.bind(action))
		rows.add_child(button)

func open_well(well: WaterWell) -> void:
	active_well = well
	set_panel("well")

func _well_action(action: String) -> void:
	if action == "Fechar":
		set_panel("")
		return
	if not is_instance_valid(active_well) or not active_well.can_interact():
		show_message("Aproxime-se do poço")
		set_panel("")
		return
	if action == "Beber": show_message(active_well.player.get_node("Needs").drink())
	elif inventory.fill_canteen(): show_message("Cantil cheio — 3 doses")
	else: show_message("Tenha um cantil com espaço para água")


func _refresh_recipes(wood: int, stone: int) -> void:
	$Crafting/Panel/Rows/Available.text = "Disponível: %d madeira · %d pedra · %d fibra" % [wood, stone, inventory.count_item("fibra")]
	if crafting_view != null: crafting_view.refresh()


func _refresh_inventory(_wood: int, _stone: int) -> void:
	_sync_slots()
	if selected_slot >= inventory.capacity:
		selected_slot = -1
	$InventoryPanel/Panel/Scroll/Rows/Title.text = "Inventário · %d espaços · I / Esc para fechar" % inventory.capacity
	if $InventoryPanel/Panel/Scroll/Rows.has_node("BackpackSlot"):
		$InventoryPanel/Panel/Scroll/Rows/BackpackSlot/Remove.text = ItemCatalog.title(inventory.backpack.item) + " · Retirar" if not inventory.backpack.is_empty() else "Vazio"
		$InventoryPanel/Panel/Scroll/Rows/BackpackSlot/Remove.disabled = inventory.backpack.is_empty()
	var data := inventory.slots
	for index in range(quick_buttons.size()):
		var slot: Dictionary = data[index]
		var text := "Mãos"
		if not slot.is_empty():
			text = ItemCatalog.quick_title(slot.item)
		quick_buttons[index].text = "%d %s\n%s" % [index + 1, text, ("%d/3 doses" % slot.get("water", 0) if slot.get("item", "") == "cantil" else "×%d" % slot.get("quantity", 0))]
		if slot.is_empty(): quick_buttons[index].text = "%d\nMãos" % (index + 1)
		quick_buttons[index].modulate = Color("f2d786") if inventory.selected_index == index else Color.WHITE
	for index in range(slot_buttons.size()):
		var slot: Dictionary = data[index]
		var title := "Vazio"
		if not slot.is_empty():
			title = ItemCatalog.title(slot.item).replace(" de ", "\n")
			if slot.item in ItemCatalog.STACKABLE:
				title += " × %d" % slot.quantity
			if slot.item == "cantil": title += " · %d/3 doses" % slot.get("water", 0)
			if GunRules.WEAPONS.has(slot.item) and slot.item != "arco": title += " · %d tiros" % slot.get("loaded", 0)
		slot_buttons[index].text = "%d\n%s" % [index + 1, title]
		slot_buttons[index].modulate = Color("f2d786") if index == selected_slot else Color.WHITE
	var item: String = data[selected_slot].get("item", "") if selected_slot >= 0 else ""
	$InventoryPanel/Panel/Scroll/Rows/Equip.disabled = not ItemCatalog.is_equippable(item) and ItemCatalog.bag_level(item) == 0
	$InventoryPanel/Panel/Scroll/Rows/Selection.text = "Selecionado: " + ItemCatalog.title(item) if item != "" else "Selecione ferramenta, mochila ou objeto."


func select_slot(index: int) -> void:
	if moving_slot >= 0:
		if network_mode: network_action_requested.emit("swap", Vector2i(moving_slot, index))
		else: inventory.swap_slots(moving_slot, index)
		moving_slot = -1
	selected_slot = index
	_refresh_inventory(inventory.wood, inventory.stone)


func _equip_selected() -> void:
	if network_mode:
		network_action_requested.emit("equip_slot", selected_slot)
		return
	if current_panel == "inventory" and inventory.equip_slot(selected_slot):
		show_message("Equipamento atualizado")


func _equip_hands() -> void:
	if network_mode:
		network_action_requested.emit("equip", "maos")
		return
	if current_panel == "inventory":
		inventory.equip("maos")


func show_equipment(tool: String) -> void:
	var title: String = "Mãos" if tool == "maos" else ItemCatalog.title(tool)
	$Controls/Rows/Equipment.text = "Equipado: " + title
	if tool == "arco":
		$Controls/Rows/Equipment.text += " · %d flechas" % inventory.count_item("flecha")
	elif GunRules.WEAPONS.has(tool):
		$Controls/Rows/Equipment.text += " · %d/%d carregada · %d reserva · R recarrega" % [inventory.loaded_ammo(tool), GunRules.WEAPONS[tool].magazine, inventory.count_item(GunRules.WEAPONS[tool].ammo)]


func update_counts(wood: int, stone: int) -> void:
	$Controls/Rows/Counts.text = "Madeira: %d · Pedra: %d · Fibra: %d" % [wood, stone, inventory.count_item("fibra")]


func show_target(message: String) -> void:
	if MobileInput.enabled: message = message.trim_prefix("F / mouse — ")
	$Controls/Rows/Prompt.text = message
	$Controls/Rows/Prompt.visible = message != ""


func show_pickup(message: String) -> void:
	if MobileInput.enabled: message = message.trim_prefix("E — ")
	$Controls/Rows/Pickup.text = message
	$Controls/Rows/Pickup.visible = message != ""


func show_message(message: String) -> void:
	$Controls/Rows/Feedback.text = message
	$Controls/Rows/Feedback.visible = true
	$FeedbackTimer.start()


func _on_feedback_timeout() -> void:
	$Controls/Rows/Feedback.text = ""
	$Controls/Rows/Feedback.visible = false
