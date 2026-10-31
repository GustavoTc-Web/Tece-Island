extends Button
var compact := false
var item_icon: ItemIcon
var quantity: Label
var caption: Label
var slot_number: Label
var drag_hud: CanvasLayer
var drag_inventory: ResourceInventory
var drag_index := -1
var rendered_active := false
func _ready() -> void:
	item_icon = ItemIcon.new()
	add_child(item_icon)
	quantity = Label.new()
	quantity.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quantity.add_theme_color_override("font_color", IslandTheme.AMBER)
	quantity.add_theme_color_override("font_outline_color", Color("14251d"))
	quantity.add_theme_constant_override("outline_size", 4)
	caption = Label.new()
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	slot_number = Label.new()
	slot_number.add_theme_color_override("font_color", Color("aab39b"))
	for label in [quantity, caption, slot_number]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
	resized.connect(layout)
	mouse_exited.connect(func(): IslandTheme.decorate(self, rendered_active))
	layout()
func render(data: Dictionary, index: int, active: bool) -> void:
	rendered_active = active
	IslandTheme.decorate(self, active)
	for type in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color", "font_hover_pressed_color"]: add_theme_color_override(type, Color.TRANSPARENT)
	var item: String = data.get("item", "")
	text = "" if compact else "%d\n%s" % [index + 1, ItemCatalog.quick_title(item) if not item.is_empty() else "Vazio"]
	item_icon.item = item
	item_icon.visible = not item.is_empty()
	caption.text = "Vazio" if item.is_empty() else ItemCatalog.title(item)
	caption.visible = not compact
	quantity.text = ""
	if not data.is_empty():
		quantity.text = "%d/3" % int(data.get("water", 0)) if item == "cantil" else "×%d" % int(data.get("quantity", 1))
		if GunRules.WEAPONS.has(item) and item != "arco": quantity.text = "%d" % int(data.get("loaded", 0))
	slot_number.text = str(index + 1)
	tooltip_text = caption.text + (" · " + quantity.text if not quantity.text.is_empty() else "")
	layout()
func layout() -> void:
	if item_icon == null: return
	var font := int(maxf(14, ceilf(12 / MobileInput.css_scale()))) if MobileInput.enabled else 14
	quantity.add_theme_font_size_override("font_size", font)
	slot_number.add_theme_font_size_override("font_size", font - 2)
	caption.add_theme_font_size_override("font_size", font)
	var square := minf(48, size.y - (font + 10 if compact else 16))
	item_icon.custom_minimum_size = Vector2.ZERO
	item_icon.size = Vector2.ONE * square
	item_icon.position = Vector2((size.x - square) / 2, 2) if compact else Vector2(8, (size.y - square) / 2)
	quantity.position = Vector2(maxf(4, size.x - 58), size.y - font - 5)
	quantity.size = Vector2(52, font + 3)
	slot_number.position = Vector2(5, 2)
	caption.position = Vector2(square + 20, 3)
	caption.size = Vector2(maxf(40, size.x - square - 26), maxf(30, size.y - font - 8))

func drag_available() -> bool:
	return drag_hud != null and drag_inventory != null and not MobileInput.enabled and not GlobalChat.opened and drag_hud.current_panel == "inventory" and drag_index >= 0 and drag_index < drag_inventory.capacity

func _get_drag_data(_point: Vector2) -> Variant:
	if not drag_available(): return null
	var stack := drag_inventory.slot_data(drag_index)
	if stack.is_empty(): return null
	drag_hud.inventory_drag_active = true
	drag_hud.moving_slot = -1
	var preview := PanelContainer.new()
	preview.add_theme_stylebox_override("panel", IslandTheme.panel())
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	preview.add_child(row)
	var icon := ItemIcon.new()
	icon.item = stack.item
	icon.custom_minimum_size = Vector2(48, 48)
	row.add_child(icon)
	var title := Label.new()
	title.text = "%s ×%d" % [ItemCatalog.title(stack.item), int(stack.get("quantity", 1))]
	row.add_child(title)
	set_drag_preview(preview)
	return {"kind":"solo-inventory-slot", "owner":drag_inventory.get_instance_id(), "source":drag_index, "stack":JSON.stringify(stack)}

func _can_drop_data(_point: Vector2, data: Variant) -> bool:
	if not drag_available() or not data is Dictionary or data.get("kind") != "solo-inventory-slot" or data.get("owner") != drag_inventory.get_instance_id(): return false
	var source := int(data.get("source", -1))
	var valid: bool = source >= 0 and source < drag_inventory.capacity and not drag_inventory.slot_data(source).is_empty() and JSON.stringify(drag_inventory.slot_data(source)) == data.get("stack", "")
	if valid: IslandTheme.decorate(self, true)
	return valid

func _drop_data(point: Vector2, data: Variant) -> void:
	if not _can_drop_data(point, data): return
	if drag_inventory.swap_slots(int(data.source), drag_index):
		drag_hud.moving_slot = -1
		drag_hud.select_slot(drag_index)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and drag_hud != null:
		drag_hud.inventory_drag_active = false
		IslandTheme.decorate(self, rendered_active)
