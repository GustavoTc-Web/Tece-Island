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
var combat_options: CombatOptions
var utility_buttons: HBoxContainer
var base_view: BaseView
var journal_view: JournalView
var journal_button: Button
var objective_button: Button
var save_button: Button
var save_notice: Label
var poison_status: Label
var menu_view: GameMenu
var menu_button: Button
var quick_icons: Array[Control] = []
var saved_timer: Timer
var compact_ready := false
var touch_goal_initialized := false
var inventory_actions: GridContainer
var feedback_notice: Label


func initialize(source: ResourceInventory) -> void:
	ThemeDB.get_default_theme().default_font = IslandTheme.BODY
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
	var bag_icon := ItemIcon.new()
	bag_icon.name = "ItemIcon"
	backpack_row.add_child(bag_icon)
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
	var armor_row := HBoxContainer.new()
	armor_row.name = "ArmorSlot"
	$InventoryPanel/Panel/Scroll/Rows.add_child(armor_row)
	$InventoryPanel/Panel/Scroll/Rows.move_child(armor_row, 2)
	var armor_icon := preload("res://scripts/recipe_icon.gd").new()
	armor_icon.item = "armadura_pedra"
	armor_row.add_child(armor_icon)
	var armor_button := Button.new()
	armor_button.name = "Remove"
	armor_button.pressed.connect(func():
		if network_mode: show_message("Armaduras disponíveis no solo")
		elif not inventory.remove_armor(): show_message("Reserve um espaço livre para retirar a armadura."))
	armor_row.add_child(armor_button)
	var actions := GridContainer.new()
	inventory_actions = actions
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
	for caption in ["Fabricação", "Base"]:
		var button := Button.new()
		button.text = caption
		button.pressed.connect(func():
			if caption == "Base": open_base()
			elif not network_mode: set_panel("crafting")
			else: show_message("Fabricação fora da arena de teste"))
		actions.add_child(button)
	var quick := HBoxContainer.new()
	quick.name = "Quickbar"
	quick.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	quick.position = Vector2(-260, -68)
	add_child(quick)
	for index in range(5):
		var button := preload("res://scripts/item_slot.gd").new()
		button.compact = true
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
		quick_icons.append(button.item_icon)
	$Controls/Rows/EquipmentKeys.text = "1–5 / scroll: barra · Q / Shift+Q: jogar 1 / pilha\nR recarregar · C receitas · I inventário · E interagir"
	$InventoryPanel/Panel/Scroll/Rows/Equip.text = "Equipar este item"
	_create_needs_ui()
	_create_well_ui()
	poison_status = Label.new()
	poison_status.add_theme_font_size_override("font_size", 20)
	poison_status.add_theme_color_override("font_color", Color("c7eda4"))
	poison_status.visible = false
	$Controls/Rows.add_child(poison_status)
	$Controls/Rows.move_child(poison_status, $Controls/Rows/Health.get_index() + 1)
	_refresh_recipes(inventory.wood, inventory.stone)
	_refresh_inventory(inventory.wood, inventory.stone)
	show_equipment(inventory.equipped_tool())
	utility_buttons = HBoxContainer.new()
	utility_buttons.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	utility_buttons.position = Vector2(-48, 16)
	add_child(utility_buttons)
	var sound := Button.new()
	sound.text = "Som"
	sound.custom_minimum_size = Vector2(84, 52)
	sound.pressed.connect(func():
		if combat_options == null:
			combat_options = CombatOptions.new()
			combat_options.hud = self
			add_child(combat_options)
		set_panel("sound"))
	utility_buttons.add_child(sound)
	var base := Button.new()
	base.text = "Base"
	base.custom_minimum_size = Vector2(84, 52)
	base.pressed.connect(func(): open_base())
	utility_buttons.add_child(base)
	utility_buttons.position.x = -92
	for panel in ["Crafting", "InventoryPanel"]:
		var close := Button.new()
		close.text = "Fechar"
		close.custom_minimum_size = Vector2(150, 52)
		close.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		close.offset_left = -75
		close.offset_right = 75
		close.offset_top = 16
		close.offset_bottom = 68
		close.pressed.connect(func(): set_panel(""))
		get_node(panel).add_child(close)
	_create_compact_ui()
	get_viewport().size_changed.connect(func(): mobile_layout(MobileInput.enabled))

func mobile_layout(value: bool) -> void:
	for label in [$Controls/Rows/Instructions, $Controls/Rows/EquipmentKeys, $Controls/Rows/Counts, $Controls/Rows/HealthLabel]: label.hide()
	$Controls/Rows/Prompt.visible = not value and not $Controls/Rows/Prompt.text.is_empty()
	$Controls/Rows/Pickup.visible = not value and not $Controls/Rows/Pickup.text.is_empty()
	var unit := MobileInput.touch_minimum()
	if value:
		for panel in [$InventoryPanel, $Crafting, get_node("WellPanel")]: touch_sizes(panel)
	var view := get_viewport().get_visible_rect().size
	var display_scale := maxf(1, 0.9 / MobileInput.css_scale()) if value else 1.0
	$Controls.scale = Vector2.ONE * display_scale
	for button in quick_buttons:
		button.custom_minimum_size = Vector2(unit, unit)
		button.add_theme_font_size_override("font_size", int(maxf(16, ceilf(12 / MobileInput.css_scale()))) if value else 14)
	for index in range(quick_icons.size()):
		quick_buttons[index].layout()
	if has_node("Quickbar"):
		var gap := ceilf(8 / MobileInput.css_scale()) if value else 8.0
		$Quickbar.add_theme_constant_override("separation", int(gap))
		$Quickbar.offset_left = -(5 * unit + 4 * gap) / 2
		$Quickbar.offset_right = (5 * unit + 4 * gap) / 2
		$Quickbar.offset_top = -unit - gap
		$Quickbar.offset_bottom = -gap
	if inventory_actions != null: inventory_actions.columns = 2 if view.y > view.x else 3
	if value:
		for grid in [inventory_actions, $InventoryPanel/Panel/Scroll/Rows/Slots]:
			grid.add_theme_constant_override("h_separation", int(ceilf(8 / MobileInput.css_scale())))
			grid.add_theme_constant_override("v_separation", int(ceilf(8 / MobileInput.css_scale())))
	$InventoryPanel/Panel/Scroll/Rows/Slots.columns = 2 if view.y > view.x and value else 4
	for button in slot_buttons:
		button.custom_minimum_size.x = 200
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if menu_button != null:
		menu_button.custom_minimum_size = Vector2(unit * 1.15, unit)
		menu_button.size = menu_button.custom_minimum_size
		menu_button.position = Vector2(view.x - unit * 1.15 - 12, 12)
		menu_button.add_theme_font_size_override("font_size", int(maxf(18, 14 / MobileInput.css_scale())))
	if menu_view != null: menu_view.layout()
	if objective_button != null:
		objective_button.position = Vector2(224 * display_scale, 4)
		objective_button.custom_minimum_size = Vector2(240, unit)
		objective_button.size = objective_button.custom_minimum_size
		objective_button.add_theme_font_size_override("font_size", int(maxf(16, 13 / MobileInput.css_scale())))
	if save_button != null:
		save_button.custom_minimum_size.y = unit if not save_button.disabled else 28
		save_button.custom_minimum_size.x = 210 if not save_button.disabled else 110
		save_button.size = save_button.custom_minimum_size
		save_button.position = Vector2(view.x - save_button.size.x - 16, unit + 22 if value else unit + 170)
		if value and not save_button.disabled: save_button.position = Vector2((view.x - 210) / 2, unit + 24)
		save_button.add_theme_font_size_override("font_size", int(maxf(12, ceilf(11 / MobileInput.css_scale()))))
		save_notice.hide()
	for panel in [$InventoryPanel, $Crafting]: _fit_modal(panel)
	if feedback_notice != null:
		feedback_notice.position = Vector2(224 * display_scale, unit + 14)
		feedback_notice.size.x = minf(380, view.x - feedback_notice.position.x - 170)
	if current_panel != "" and value:
		for panel in [journal_view, base_view, storage_view, combat_options]:
			if panel != null and panel.visible: touch_sizes(panel); _fit_modal(panel)

func touch_sizes(node: Node) -> void:
	if node is Button:
		node.custom_minimum_size.y = maxf(node.custom_minimum_size.y, MobileInput.touch_minimum())
		node.custom_minimum_size.x = maxf(node.custom_minimum_size.x, MobileInput.touch_minimum())
		if node.get_parent() is Container: node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		node.add_theme_font_size_override("font_size", int(maxf(20, ceilf(15 / MobileInput.css_scale()))))
		node.clip_text = true
	if node is Label:
		node.add_theme_font_size_override("font_size", int(maxf(18, ceilf(14 / MobileInput.css_scale()))))
	if node is LineEdit:
		node.custom_minimum_size.y = MobileInput.touch_minimum()
		node.add_theme_font_size_override("font_size", int(maxf(20, ceilf(15 / MobileInput.css_scale()))))
	for child in node.get_children(): touch_sizes(child)


func _sync_slots() -> void:
	while slot_buttons.size() > inventory.capacity:
		var button: Button = slot_buttons.pop_back()
		button.get_parent().remove_child(button)
		button.queue_free()
	for index in range(slot_buttons.size(), inventory.capacity):
		var button := preload("res://scripts/item_slot.gd").new()
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
	if GlobalChat.opened: return
	if showing_death or event.is_echo():
		return
	if current_panel == "saving":
		get_viewport().set_input_as_handled()
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit: return
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_J and journal_button != null:
		set_panel("" if current_panel == "journal" else "journal")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("crafting"):
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
	MobileInput.reset()
	moving_slot = -1
	if has_node("Quickbar"): $Quickbar.visible = panel == "" and not showing_death
	$Crafting.visible = panel in ["crafting", "cooking"]
	if $Crafting.visible: crafting_view.open(panel == "cooking")
	$InventoryPanel.visible = panel == "inventory"
	if has_node("WellPanel"): $WellPanel.visible = panel == "well"
	if panel == "well": _fit_modal($WellPanel)
	if storage_view != null: storage_view.visible = panel == "chest"
	if combat_options != null: combat_options.visible = panel == "sound"
	if base_view != null: base_view.visible = panel == "base"
	if journal_view != null: journal_view.visible = panel == "journal"
	if utility_buttons != null: utility_buttons.hide()
	if menu_button != null: menu_button.visible = panel == "" and not showing_death
	if menu_view != null:
		menu_view.visible = panel == "menu"
		if panel == "menu": menu_view.open()
	if objective_button != null: refresh_objective()
	if save_button != null:
		save_button.visible = not save_button.disabled or panel == "" and not saved_timer.is_stopped()
		save_notice.hide()
	if MobileInput.enabled:
		for view in [storage_view, combat_options, base_view, journal_view]:
			if view != null and view.visible: touch_sizes(view); _fit_modal(view)
	panel_toggled.emit(panel != "")

func _create_compact_ui() -> void:
	utility_buttons.hide()
	menu_view = GameMenu.new()
	menu_view.hud = self
	add_child(menu_view)
	menu_button = Button.new()
	menu_button.text = "Menu"
	menu_button.focus_mode = Control.FOCUS_NONE
	menu_button.pressed.connect(func(): set_panel("menu"))
	add_child(menu_button)
	for path in ["Instructions", "HealthLabel", "Counts", "EquipmentKeys"]: get_node("Controls/Rows/" + path).hide()
	$Controls/Rows/Equipment.hide()
	$Controls/Rows/Health.custom_minimum_size = Vector2(184, 18)
	for path in ["Prompt", "Pickup", "Feedback"]:
		var label: Label = get_node("Controls/Rows/" + path)
		label.custom_minimum_size.x = 180
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$Controls/Rows/Time.add_theme_font_size_override("font_size", 14)
	feedback_notice = Label.new()
	feedback_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_notice.add_theme_font_size_override("font_size", 16)
	feedback_notice.add_theme_color_override("font_color", Color("f6edcb"))
	feedback_notice.add_theme_color_override("font_outline_color", Color("142b24"))
	feedback_notice.add_theme_constant_override("outline_size", 5)
	feedback_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(feedback_notice)
	feedback_notice.hide()
	compact_ready = true
	mobile_layout(MobileInput.enabled)

func open_settings() -> void:
	if combat_options == null:
		combat_options = CombatOptions.new()
		combat_options.hud = self
		add_child(combat_options)
	set_panel("sound")

func _fit_modal(view: Control) -> void:
	# Entire forms can scroll when their content exceeds the available screen.
	if view.name == "WellPanel":
		view.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		view.offset_left = -240
		view.offset_right = 240
		view.offset_top = -MobileInput.touch_minimum() * 2
		view.offset_bottom = MobileInput.touch_minimum() * 2
		return
	if view in [$InventoryPanel, $Crafting]:
		var view_size := get_viewport().get_visible_rect().size
		var fixed_panel: Control = view.get_node("Panel")
		fixed_panel.offset_left = -minf(900, view_size.x - 48) / 2
		fixed_panel.offset_right = -fixed_panel.offset_left
		fixed_panel.offset_top = -minf(1400, view_size.y - MobileInput.touch_minimum() - 48) / 2
		fixed_panel.offset_bottom = -fixed_panel.offset_top
		return
	if not view.has_meta("responsive_scroll"):
		for child in view.get_children():
			if not child is PanelContainer: continue
			view.remove_child(child)
			var scroll := ScrollContainer.new()
			scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			view.add_child(scroll)
			var center := CenterContainer.new()
			center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			center.custom_minimum_size.y = get_viewport().get_visible_rect().size.y
			scroll.add_child(center)
			child.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
			center.add_child(child)
			view.set_meta("responsive_scroll", child)
			break
	if view.has_meta("responsive_scroll"):
		var panel: PanelContainer = view.get_meta("responsive_scroll")
		panel.custom_minimum_size.x = minf(900, get_viewport().get_visible_rect().size.x - 48)
		panel.get_parent().custom_minimum_size.y = get_viewport().get_visible_rect().size.y


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


func initialize_journal(source: IslandJournal) -> void:
	journal_view = JournalView.new()
	journal_view.hud = self
	journal_view.journal = source
	add_child(journal_view)
	journal_view.visible = false
	journal_button = Button.new()
	journal_button.text = "Diário · J"
	journal_button.custom_minimum_size = Vector2(84, 52)
	journal_button.add_theme_font_size_override("font_size", 16)
	journal_button.clip_text = true
	journal_button.pressed.connect(func(): set_panel("journal"))
	utility_buttons.add_child(journal_button)
	utility_buttons.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	utility_buttons.position = Vector2(420, 16)
	source.changed.connect(func(): journal_button.text = "Diário · %d" % source.unread.size() if not source.unread.is_empty() else "Diário · J")

func initialize_save(world: Node2D) -> void:
	save_button = Button.new()
	save_button.custom_minimum_size = Vector2(360, 28)
	save_button.add_theme_font_size_override("font_size", 16)
	save_button.text = "Progresso local"
	save_button.add_theme_color_override("font_disabled_color", Color("dce8ce"))
	var saved_style := StyleBoxFlat.new()
	saved_style.bg_color = Color(0.06, 0.11, 0.085, 0.85)
	saved_style.set_corner_radius_all(6)
	save_button.add_theme_stylebox_override("disabled", saved_style)
	save_button.disabled = true
	save_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	save_button.pressed.connect(func(): world.save_progress(true))
	add_child(save_button)
	save_button.position = Vector2(240, 16)
	saved_timer = Timer.new()
	saved_timer.one_shot = true
	saved_timer.wait_time = 2.0
	saved_timer.timeout.connect(func(): if save_button.disabled: save_button.hide())
	add_child(saved_timer)
	save_button.hide()
	save_notice = Label.new()
	save_notice.custom_minimum_size.x = 360
	save_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	save_notice.add_theme_font_size_override("font_size", 12)
	save_notice.text = "Salvo neste aparelho. Confira a confirmação de sincronização antes de trocar de aparelho."
	save_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Controls/Rows.add_child(save_notice)
	save_notice.hide()

func show_save_state(text: String, retry: bool) -> void:
	if save_button == null: return
	if current_panel == "saving": show_message(text)
	save_button.text = text
	if menu_view != null: menu_view.refresh_save_details()
	save_button.disabled = not retry
	save_button.custom_minimum_size.y = MobileInput.touch_minimum() if retry else 28
	save_button.add_theme_font_size_override("font_size", int(maxf(16, ceilf(14 / MobileInput.css_scale()))) if MobileInput.enabled else 16)
	save_button.mouse_filter = Control.MOUSE_FILTER_STOP if retry else Control.MOUSE_FILTER_IGNORE
	save_button.visible = retry or current_panel == "" and not showing_death
	mobile_layout(MobileInput.enabled)
	if retry or text.begins_with("Salvando") or text == "Sincronizando": saved_timer.stop()
	else: saved_timer.start()
	if menu_view != null and current_panel == "menu" and menu_view.area == "data": menu_view.open("data")

func initialize_objectives(source: IslandObjectives) -> void:
	journal_view.objectives = source
	source.changed.connect(journal_view.refresh)
	objective_button = Button.new()
	objective_button.position = Vector2(420, 76)
	objective_button.custom_minimum_size = Vector2(260, 48)
	objective_button.add_theme_font_size_override("font_size", 14)
	objective_button.clip_text = true
	objective_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	objective_button.add_theme_stylebox_override("hover", IslandTheme.panel(Color(0.08, 0.16, 0.11, 0.5)))
	objective_button.add_theme_color_override("font_color", Color("f4dfac"))
	objective_button.add_theme_color_override("font_outline_color", Color("14281e"))
	objective_button.add_theme_constant_override("outline_size", 3)
	objective_button.pressed.connect(func(): journal_view.goals_mode = true; journal_view.refresh(); set_panel("journal"))
	add_child(objective_button)
	source.changed.connect(refresh_objective)
	source.completed.connect(func(_title):
		CombatAudio.play("objective")
		objective_button.modulate = Color("f5d879")
		get_tree().create_timer(1.5, true).timeout.connect(func(): if is_instance_valid(objective_button): objective_button.modulate = Color.WHITE))
	refresh_objective()
	mobile_layout(MobileInput.enabled)

func refresh_objective() -> void:
	var source := journal_view.objectives
	objective_button.visible = source.enabled and current_panel == "" and not showing_death
	if source.tracked.is_empty():
		objective_button.text = "Objetivos concluídos"
	else:
		var goal: Dictionary = IslandObjectives.GOALS[source.tracked]
		var short_title: String = {"wood":"Coletar madeiras", "stone":"Coletar pedras", "tools":"Equipamentos de pedra", "fire":"Fabricar fogueira", "bag":"Bolsa nível 3"}[source.tracked]
		objective_button.text = "%s: %d/%d" % [short_title, source.values[source.tracked], goal.target]
		objective_button.tooltip_text = source.tools_description() if source.tracked == "tools" else goal.title

func open_base(target: PlacedStructure = null) -> void:
	if network_mode:
		show_message("Base disponível no mundo solo")
		return
	if base_view == null:
		base_view = BaseView.new()
		base_view.hud = self
		base_view.system = get_parent().get_node("Structures")
		add_child(base_view)
	base_view.open(target)
	set_panel("base")

func update_poison(remaining: float) -> void:
	if poison_status == null: return
	poison_status.text = "Veneno · %.1f s" % (ceilf(remaining * 10) / 10)
	poison_status.visible = remaining > 0

func update_health(current: float, maximum: float) -> void:
	$Controls/Rows/Health.max_value = maximum
	$Controls/Rows/Health.value = current
	_bar_value($Controls/Rows/Health, "Vida", current, maximum)
	$Controls/Rows/HealthLabel.text = "Vida: %d / %d" % [current, maximum]


func update_time(day: int, phase: String) -> void:
	$Controls/Rows/Time.text = "Dia %d · %s" % [day, phase]

func update_clock(day: int, phase: String, remaining: int) -> void:
	var night := phase in ["Noite", "Amanhecer"]
	$Controls/Rows/Time.text = "%s — %s em %02d:%02d" % ["Noite" if night else "Dia", "Amanhece" if night else "Anoitece", maxi(0, remaining) / 60, maxi(0, remaining) % 60]
	$Controls/Rows/Time.tooltip_text = "Dia %d do mundo" % day


func show_death(value: bool) -> void:
	showing_death = value
	$Death.visible = value
	if has_node("Quickbar"): $Quickbar.visible = not value and current_panel == ""
	if utility_buttons != null: utility_buttons.hide()
	if menu_button != null: menu_button.visible = not value and current_panel == ""
	if objective_button != null: refresh_objective()
	if save_button != null:
		save_button.visible = not value and current_panel == ""
		save_notice.hide()


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
	_style_bar($Controls/Rows/Health, Color("d74444"))
	_bar_value($Controls/Rows/Health, "Vida", 100, 100)
	for kind in ["Sede", "Fome", "Proteção"]:
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(184, 18)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.show_percentage = false
		bar.value = 0 if kind == "Proteção" else 100
		$Controls/Rows.add_child(bar)
		$Controls/Rows.move_child(bar, 2 + ["Sede", "Fome", "Proteção"].find(kind))
		_style_bar(bar, {"Sede": Color("287fda"), "Fome": Color("e8bb32"), "Proteção": Color("9864ce")}[kind])
		_bar_value(bar, "Água" if kind == "Sede" else kind, bar.value, 100)
		needs_bars[kind] = bar
	$Controls/Rows.move_child($Controls/Rows/Health, 1)

func _style_bar(bar: ProgressBar, color: Color) -> void:
	for type in ["background", "fill"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("545a60") if type == "background" else color
		style.set_corner_radius_all(4)
		bar.add_theme_stylebox_override(type, style)
	var label := Label.new()
	label.name = "Value"
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color("161b24"))
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(label)

func _bar_value(bar: ProgressBar, title: String, value: float, maximum: float) -> void:
	if bar.has_node("Value"): bar.get_node("Value").text = "%s  %d/%d" % [title, ceili(value), int(maximum)]

func update_protection(value: float) -> void:
	if not needs_bars.has("Proteção"): return
	needs_bars["Proteção"].value = value
	_bar_value(needs_bars["Proteção"], "Proteção", value, 100)

func update_needs(hunger: float, thirst: float) -> void:
	if needs_bars.is_empty(): return
	needs_bars.Fome.value = hunger
	needs_bars.Sede.value = thirst
	_bar_value(needs_bars.Fome, "Fome", hunger, 100)
	_bar_value(needs_bars.Sede, "Água", thirst, 100)

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
	if MobileInput.enabled: $InventoryPanel/Panel/Scroll/Rows/Title.text = "Inventário · %d espaços" % inventory.capacity
	if $InventoryPanel/Panel/Scroll/Rows.has_node("BackpackSlot"):
		$InventoryPanel/Panel/Scroll/Rows/BackpackSlot/ItemIcon.item = inventory.backpack.get("item", "")
		$InventoryPanel/Panel/Scroll/Rows/BackpackSlot/Remove.text = ItemCatalog.title(inventory.backpack.item) + " · Retirar" if not inventory.backpack.is_empty() else "Vazio"
		$InventoryPanel/Panel/Scroll/Rows/BackpackSlot/Remove.disabled = inventory.backpack.is_empty()
	if $InventoryPanel/Panel/Scroll/Rows.has_node("ArmorSlot"):
		$InventoryPanel/Panel/Scroll/Rows/ArmorSlot/Remove.text = "Armadura: vazia" if inventory.armor.is_empty() else "Pedra · 10 proteção · Retirar"
		$InventoryPanel/Panel/Scroll/Rows/ArmorSlot/Remove.disabled = inventory.armor.is_empty()
	update_protection(inventory.armor_protection())
	var data := inventory.slots
	for index in range(quick_buttons.size()):
		var slot: Dictionary = data[index]
		var text := "Mãos"
		if not slot.is_empty():
			text = ItemCatalog.quick_title(slot.item)
		quick_buttons[index].render(slot, index, inventory.selected_index == index)
		quick_buttons[index].tooltip_text = "%d · %s" % [index + 1, text]
		quick_icons[index].item = slot.get("item", "")
		quick_icons[index].visible = not slot.is_empty()
		quick_icons[index].queue_redraw()
	for index in range(slot_buttons.size()):
		var slot: Dictionary = data[index]
		var title := "Vazio"
		if not slot.is_empty():
			title = ItemCatalog.title(slot.item).replace(" de ", "\n")
			if slot.item in ItemCatalog.STACKABLE:
				title += " × %d" % slot.quantity
			if slot.item == "cantil": title += " · %d/3 doses" % slot.get("water", 0)
			if GunRules.WEAPONS.has(slot.item) and slot.item != "arco": title += " · %d tiros" % slot.get("loaded", 0)
		slot_buttons[index].render(slot, index, index == selected_slot)
	var item: String = data[selected_slot].get("item", "") if selected_slot >= 0 else ""
	$InventoryPanel/Panel/Scroll/Rows/Equip.disabled = not ItemCatalog.is_equippable(item) and ItemCatalog.bag_level(item) == 0 and item != "armadura_pedra"
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
		$Controls/Rows/Equipment.text = "%d flechas" % inventory.count_item("flecha")
	elif GunRules.WEAPONS.has(tool):
		$Controls/Rows/Equipment.text = "%d/%d · reserva %d" % [inventory.loaded_ammo(tool), GunRules.WEAPONS[tool].magazine, inventory.count_item(GunRules.WEAPONS[tool].ammo)]
	$Controls/Rows/Equipment.visible = tool in GunRules.WEAPONS


func update_counts(wood: int, stone: int) -> void:
	$Controls/Rows/Counts.text = "Madeira: %d · Pedra: %d · Fibra: %d" % [wood, stone, inventory.count_item("fibra")]


func show_target(message: String) -> void:
	if MobileInput.enabled: message = message.trim_prefix("F / mouse — ")
	$Controls/Rows/Prompt.text = message
	$Controls/Rows/Prompt.visible = message != "" and not MobileInput.enabled


func show_pickup(message: String) -> void:
	if MobileInput.enabled: message = message.trim_prefix("E — ")
	$Controls/Rows/Pickup.text = message
	$Controls/Rows/Pickup.visible = message != "" and not MobileInput.enabled


func show_message(message: String) -> void:
	$Controls/Rows/Feedback.text = message
	$Controls/Rows/Feedback.visible = false
	if feedback_notice != null:
		feedback_notice.text = message
		feedback_notice.visible = true
	$FeedbackTimer.start()


func _on_feedback_timeout() -> void:
	if current_panel == "saving": return
	$Controls/Rows/Feedback.text = ""
	$Controls/Rows/Feedback.visible = false
	if feedback_notice != null: feedback_notice.hide()
