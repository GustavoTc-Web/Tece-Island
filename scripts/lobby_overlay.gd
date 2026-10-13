extends CanvasLayer
var menu_view: GameMenu
var combat_options: CombatOptions
var journal_view: JournalView
var save_button: Button
var lobby: Control

func _ready() -> void:
	layer = 20
	menu_view = GameMenu.new()
	menu_view.hud = self
	add_child(menu_view)

func show_message(text: String) -> void: lobby.show_status(text)

func set_panel(panel: String) -> void:
	menu_view.visible = panel == "menu"
	if combat_options != null: combat_options.visible = panel == "sound"
	if panel == "menu": menu_view.open()

func open_help() -> void:
	set_panel("menu")
	menu_view.open("help")

func open_settings() -> void:
	if combat_options == null:
		combat_options = CombatOptions.new()
		combat_options.hud = self
		add_child(combat_options)
	set_panel("sound")

func touch_sizes(node: Node) -> void:
	if node is Button:
		node.custom_minimum_size.y = MobileInput.touch_minimum()
		node.add_theme_font_size_override("font_size", 20)
	for child in node.get_children(): touch_sizes(child)
