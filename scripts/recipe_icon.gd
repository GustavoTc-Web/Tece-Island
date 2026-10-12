extends Control
# The same compact shapes and palette used by the world's procedural items.
var item := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(48, 48)

func _draw() -> void:
	var center := Vector2(24, 24)
	var category := ItemCatalog.category(item)
	if category in ["machado", "picareta", "espada"]:
		draw_line(center + Vector2(-12, 16), center + Vector2(8, -12), Color("a77a49"), 5)
		var color := Color("b4bcb0") if item.ends_with("pedra") else Color("d1a265")
		if category == "espada": draw_line(center, center + Vector2(14, -17), color, 7)
		elif category == "machado": draw_rect(Rect2(center + Vector2(3, -17), Vector2(17, 13)), color)
		else: draw_line(center + Vector2(-7, -16), center + Vector2(20, -9), color, 6)
	elif item == "cantil":
		draw_rect(Rect2(13, 13, 23, 28), Color("578796"))
		draw_rect(Rect2(20, 6, 9, 8), Color("d6ca99"))
	elif item.begins_with("mochila"):
		draw_rect(Rect2(9, 12, 30, 29), Color("ac834c"))
		draw_rect(Rect2(16, 4, 16, 12), Color("725a3a"), false, 4)
		draw_rect(Rect2(15, 25, 18, 10), Color("e4c18a"), false, 2)
	elif item == "cama":
		draw_rect(Rect2(4, 12, 40, 28), Color("6b4931"))
		draw_rect(Rect2(7, 15, 34, 22), Color("c7b580"))
		draw_rect(Rect2(8, 16, 10, 19), Color("eee2bd"))
	elif item == "fogueira":
		for i in range(6): draw_circle(center + Vector2.from_angle(i * TAU / 6) * 17, 5, Color("939d91"))
		draw_colored_polygon(PackedVector2Array([Vector2(14, 33), Vector2(24, 4), Vector2(35, 33)]), Color("eb923b"))
		draw_circle(Vector2(24, 27), 6, Color("ffe697"))
	elif category == "comida":
		draw_circle(center, 16, Color("b97449"))
		draw_circle(center + Vector2(-6, -4), 6, Color("e6b87c"))
	else:
		draw_rect(Rect2(8, 8, 32, 32), Color("b9975b"))
