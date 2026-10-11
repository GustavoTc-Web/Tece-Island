class_name ResourceDrop
extends Node2D

@export var resource: String = "madeira"
@export var quantity: int = 1
var highlighted: bool = false
var collecting: bool = false
var attributes: Dictionary = {}


func collect(inventory: ResourceInventory) -> int:
	# Guarda também contra reentrada por sinais enquanto o inventário muda.
	if collecting or quantity <= 0:
		return 0
	collecting = true
	var data := attributes.duplicate(true)
	data.item = resource
	data.quantity = quantity
	var accepted := inventory.add_item(data)
	quantity -= accepted
	collecting = false
	queue_redraw()
	if quantity == 0:
		visible = false
		remove_from_group("resource_drops")
		queue_free()
	return accepted


func set_highlighted(value: bool) -> void:
	if highlighted != value:
		highlighted = value
		queue_redraw()


func _draw() -> void:
	if highlighted:
		draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 32, Color("f2d786"), 2.0)
	if resource == "madeira":
		for y in [-5, 2, 9]:
			draw_line(Vector2(-13, y), Vector2(13, y - 6), Color("573d29"), 6.0)
			draw_line(Vector2(-12, y - 1), Vector2(12, y - 7), Color("b58b55"), 3.0)
	elif resource == "pedra":
		draw_circle(Vector2(-7, 3), 8.0, Color("b6c5be"))
		draw_circle(Vector2(7, 1), 7.0, Color("d3dcd0"))
		draw_circle(Vector2(0, -8), 6.0, Color("98a7a2"))
	elif resource == "fibra":
		for x in [-8, 0, 8]:
			draw_line(Vector2(x, 8), Vector2(x + 5, -13), Color("b2c778"), 4)
	else:
		draw_rect(Rect2(-14, -10, 28, 20), Color("c9ad6c"))
		draw_string(ThemeDB.fallback_font, Vector2(-12, -17), ItemCatalog.title(resource), HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	draw_string(ThemeDB.fallback_font, Vector2(-8, 31), str(quantity), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("f3ebce"))
