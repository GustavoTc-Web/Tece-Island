class_name CraftingView
extends RefCounted

const ICON := preload("res://scripts/recipe_icon.gd")
var hud: CanvasLayer
var inventory: ResourceInventory
var search: LineEdit
var tabs: HBoxContainer
var rows := {}
var labels := {}
var reasons := {}
var group := "Recursos"
var cooking := false
var empty: Label

func initialize(owner_hud: CanvasLayer, source: ResourceInventory) -> void:
	hud = owner_hud
	inventory = source
	var parent: VBoxContainer = hud.get_node("Crafting/Panel/Rows")
	parent.get_node("Available").hide()
	parent.get_node("Note").hide()
	search = LineEdit.new()
	search.placeholder_text = "Buscar receita"
	search.custom_minimum_size.y = 40
	search.text_changed.connect(func(_text): refresh())
	parent.add_child(search)
	parent.move_child(search, 2)
	tabs = HBoxContainer.new()
	parent.add_child(tabs)
	parent.move_child(tabs, 3)
	for name in ["Ferramentas", "Recursos", "Alimentos"]:
		var button := Button.new()
		button.text = name
		button.custom_minimum_size.y = 48
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func(): group = name; refresh())
		tabs.add_child(button)
	var scroll: ScrollContainer = parent.get_node("Scroll")
	scroll.custom_minimum_size.y = 160
	var recipes: VBoxContainer = scroll.get_node("Recipes")
	for id in ResourceRules.RECIPES:
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 100
		var icon: Control = ICON.new()
		icon.item = id
		row.add_child(icon)
		var description := VBoxContainer.new()
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(description)
		var label := Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 210
		label.add_theme_font_size_override("font_size", 16)
		description.add_child(label)
		var reason := Label.new()
		reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		reason.add_theme_color_override("font_color", Color("f0bd83"))
		reason.add_theme_font_size_override("font_size", 14)
		description.add_child(reason)
		var button := Button.new()
		button.text = "Fabricar"
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(110, 52)
		button.pressed.connect(hud._craft.bind(id))
		row.add_child(button)
		recipes.add_child(row)
		rows[id] = row
		labels[id] = label
		reasons[id] = reason
		hud.recipe_buttons[id] = button
	empty = Label.new()
	empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	recipes.add_child(empty)

func open(is_cooking: bool) -> void:
	cooking = is_cooking
	search.text = ""
	search.release_focus()
	hud.get_node("Crafting/Panel/Rows/Title").text = "Fogueira · cozinhar" if cooking else "Fabricação"
	tabs.visible = not cooking
	hud.get_node("Crafting/Panel/Rows/Scroll").scroll_vertical = 0
	refresh()

func refresh() -> void:
	var count := 0
	for button in tabs.get_children():
		button.modulate = Color("f2d786") if button.text == group else Color.WHITE
	for id in rows:
		var recipe: Dictionary = ResourceRules.RECIPES[id]
		var recipe_group := ResourceRules.crafting_group(id)
		var visible: bool = recipe_group == ("Fogueira" if cooking else group) and (search.text.is_empty() or str(recipe.name).to_lower().contains(search.text.to_lower()))
		rows[id].visible = visible
		if visible: count += 1
		var lines := PackedStringArray()
		for item in ResourceRules.ingredients(id):
			var available: int = 1 if inventory.backpack.get("item", "") == item else inventory.count_item(item)
			lines.append("%s: %d/%d" % [ItemCatalog.title(item), available, ResourceRules.ingredients(id)[item]])
		labels[id].text = "%s ×%d\n%s" % [recipe.name, int(recipe.get("quantity", 1)), " · ".join(lines)]
		var error := inventory.craft_error(id)
		hud.recipe_buttons[id].disabled = error != ""
		hud.recipe_buttons[id].tooltip_text = error
		reasons[id].text = error
		reasons[id].visible = error != ""
	empty.visible = count == 0
	empty.text = "Não há receitas sem cozimento. Prepare alimentos na fogueira." if group == "Alimentos" and not cooking and search.text.is_empty() else "Nenhuma receita encontrada."
