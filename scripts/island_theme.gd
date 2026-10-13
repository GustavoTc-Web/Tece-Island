class_name IslandTheme
extends RefCounted
static var _body: FontFile
static var _title: FontFile
static var BODY: FontFile:
	get:
		if _body == null: _body = load("res://assets/fonts/AtkinsonHyperlegible-Regular.ttf")
		return _body
static var TITLE: FontFile:
	get:
		if _title == null: _title = load("res://assets/fonts/BreeSerif-Regular.ttf")
		return _title
const AMBER := Color("e9bb70")

static func panel(color: Color = Color("172f27"), border: Color = Color("52644c")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

static func selected() -> StyleBoxFlat:
	var style := panel(Color("3e5138"), AMBER)
	style.set_border_width_all(2)
	return style

static func decorate(button: Button, active: bool = false) -> void:
	button.add_theme_stylebox_override("normal", selected() if active else panel(Color("213c30"), Color("50644c")))
	button.add_theme_stylebox_override("hover", panel(Color("354f38"), AMBER))
	button.add_theme_stylebox_override("pressed", selected())
	button.add_theme_stylebox_override("focus", selected())
	button.add_theme_color_override("font_color", Color("f5eddb"))
