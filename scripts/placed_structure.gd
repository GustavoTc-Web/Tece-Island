class_name PlacedStructure
extends StaticBody2D

@export_enum("cama", "fogueira") var kind: String = "cama"
var system: Node2D
var highlighted := false
var animation_time := 0.0
var light: PointLight2D

func _ready() -> void:
	if kind == "fogueira":
		add_to_group("campfires")
		var gradient := Gradient.new()
		gradient.set_color(0, Color.WHITE)
		gradient.set_color(1, Color(1, 1, 1, 0))
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.width = 256
		texture.height = 256
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(0.5, 1)
		light = PointLight2D.new()
		light.texture = texture
		light.texture_scale = 2.0
		light.color = Color(1, 0.78, 0.42)
		light.energy = 0.9
		add_child(light)

func prompt() -> String:
	return "E — Definir reaparecimento / dormir" if kind == "cama" else "E — Preparar carne na fogueira"

func set_highlighted(value: bool) -> void:
	highlighted = value
	queue_redraw()

func interact(_inventory: ResourceInventory) -> String:
	if kind == "cama": return system.use_bed(self)
	_inventory.cooking_available = system.near_fire(system.player.global_position)
	system.hud.open_cooking()
	return "Receita: 1 carne crua + 1 madeira → 1 carne cozida"

func _process(delta: float) -> void:
	if kind == "fogueira":
		animation_time += delta
		light.energy = 0.9 + sin(animation_time * 8) * 0.07
		queue_redraw()

func _draw() -> void:
	if kind == "cama":
		draw_rect(Rect2(-26, -18, 52, 36), Color("6b4931"))
		draw_rect(Rect2(-22, -14, 44, 28), Color("c7b580"))
		draw_rect(Rect2(-20, -12, 12, 24), Color("eee2bd"))
	else:
		for i in range(8):
			draw_circle(Vector2.from_angle(i * TAU / 8) * 18, 6, Color("939d91"))
		draw_line(Vector2(-12, 8), Vector2(12, -8), Color("735038"), 6)
		var height := 24 + sin(animation_time * 9) * 4
		draw_colored_polygon(PackedVector2Array([Vector2(-12, 4), Vector2(0, -height), Vector2(12, 4)]), Color("eb923b"))
		draw_circle(Vector2(0, -5), 6, Color("ffe697"))
	if highlighted:
		draw_arc(Vector2.ZERO, 34, 0, TAU, 32, Color("f2d786"), 2)
