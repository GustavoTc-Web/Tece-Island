extends Button
var compact := false
var item_icon: ItemIcon
var quantity: Label
var caption: Label
var slot_number: Label
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
	layout()
func render(data: Dictionary, index: int, active: bool) -> void:
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
