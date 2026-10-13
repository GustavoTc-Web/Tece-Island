class_name ItemIcon
extends Control
var item := "":
	set(value):
		item = value
		queue_redraw()
const IDS := ["madeira", "pedra", "fibra", "linha", "vidro", "mochila", "mochila_2", "mochila_3", "mochila_4", "cama", "fogueira", "bau", "parede_madeira", "porta_madeira", "vidraca", "pistola", "espingarda", "municao_pistola", "cartucho", "carne_crua", "carne_cozida", "carne_peixe", "peixe_cozido", "cantil", "arco", "flecha", "armadura_pedra", "machado_madeira", "machado_pedra", "picareta_madeira", "picareta_pedra", "espada_madeira", "espada_pedra"]
const OUTLINE := Color("222f2a")
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(48, 48)
	resized.connect(queue_redraw)
static func supports(id: String) -> bool: return id in IDS
func polygon(points: Array, color: Color) -> void:
	var shape := PackedVector2Array(points)
	draw_colored_polygon(shape, color)
	shape.append(shape[0])
	draw_polyline(shape, OUTLINE, 2, true)
func _draw() -> void:
	if item.is_empty(): return
	var factor := minf(size.x, size.y) / 48
	draw_set_transform((size - Vector2(48, 48) * factor) / 2, 0, Vector2.ONE * factor)
	var center := Vector2(24, 24)
	var category := ItemCatalog.category(item)
	if item == "madeira":
		for offset in [Vector2(-3, 7), Vector2(4, -4)]:
			draw_line(Vector2(11, 14) + offset, Vector2(34, 30) + offset, OUTLINE, 15)
			draw_line(Vector2(11, 14) + offset, Vector2(34, 30) + offset, Color("98633a"), 11)
			draw_circle(Vector2(34, 30) + offset, 6, Color("ddb577"))
			draw_arc(Vector2(34, 30) + offset, 3, 0, TAU, 16, Color("98633a"), 1.5)
	elif item == "pedra":
		polygon([Vector2(4, 31), Vector2(11, 12), Vector2(28, 6), Vector2(42, 20), Vector2(39, 37), Vector2(18, 42)], Color("9ca9a8"))
		draw_line(Vector2(11, 12), Vector2(20, 27), Color("d3d8cc"), 3)
		draw_line(Vector2(20, 27), Vector2(39, 37), Color("667776"), 5)
	elif item == "fibra":
		for x in [12, 23, 35]:
			polygon([Vector2(24, 41), Vector2(x - 6, 20), Vector2(x, 5), Vector2(x + 5, 23)], Color("82a86a"))
		draw_line(Vector2(17, 34), Vector2(32, 32), Color("dfc898"), 3)
	elif item == "linha":
		draw_rect(Rect2(12, 9, 24, 30), Color("ddd8bc"))
		for y in range(14, 36, 4): draw_line(Vector2(12, y), Vector2(36, y - 1), Color("929e92"), 2)
		draw_rect(Rect2(8, 7, 32, 6), Color("a3754d"))
		draw_rect(Rect2(8, 36, 32, 6), Color("a3754d"))
	elif item == "vidro":
		polygon([Vector2(7, 32), Vector2(18, 6), Vector2(39, 14), Vector2(32, 39)], Color("87becb"))
		draw_line(Vector2(16, 28), Vector2(24, 13), Color("e2f4ee"), 3)
	elif category in ["machado", "picareta", "espada"]:
		draw_line(Vector2(10, 39), Vector2(32, 10), OUTLINE, 8)
		draw_line(Vector2(10, 39), Vector2(32, 10), Color("ab7647"), 5)
		var material := Color("c0c9c2") if item.ends_with("pedra") else Color("d2a468")
		if category == "machado": polygon([Vector2(25, 8), Vector2(39, 9), Vector2(44, 23), Vector2(28, 23)], material)
		elif category == "picareta":
			draw_polyline(PackedVector2Array([Vector2(17, 8), Vector2(30, 9), Vector2(43, 20)]), OUTLINE, 8)
			draw_polyline(PackedVector2Array([Vector2(17, 8), Vector2(30, 9), Vector2(43, 20)]), material, 5)
		else:
			polygon([Vector2(17, 28), Vector2(31, 7), Vector2(40, 4), Vector2(38, 13), Vector2(23, 33)], material)
			draw_line(Vector2(12, 25), Vector2(26, 37), Color("d7bd7a"), 4)
	elif item == "pistola":
		polygon([Vector2(6, 10), Vector2(43, 10), Vector2(43, 20), Vector2(29, 21), Vector2(25, 40), Vector2(13, 38), Vector2(16, 21), Vector2(6, 21)], Color("8eaaa8"))
		draw_rect(Rect2(15, 24, 9, 13), Color("866143"))
		draw_line(Vector2(10, 13), Vector2(39, 13), Color("d1ded3"), 2)
	elif item == "espingarda":
		polygon([Vector2(3, 33), Vector2(16, 23), Vector2(42, 7), Vector2(46, 13), Vector2(24, 28), Vector2(13, 42)], Color("a4794d"))
		draw_line(Vector2(19, 24), Vector2(43, 9), Color("a3b6b3"), 5)
		draw_line(Vector2(26, 22), Vector2(45, 10), OUTLINE, 2)
	elif item in ["municao_pistola", "cartucho"]:
		for x in ([9, 20, 31] if item == "municao_pistola" else [11, 28]):
			draw_rect(Rect2(x, 14, 9 if item == "municao_pistola" else 12, 25), Color("c19b52") if item == "municao_pistola" else Color("b85d4b"))
			draw_circle(Vector2(x + 4.5 if item == "municao_pistola" else x + 6, 14), 4.5 if item == "municao_pistola" else 6, Color("e7c784"))
			draw_rect(Rect2(x, 35, 9 if item == "municao_pistola" else 12, 5), Color("dfbf72"))
	elif item in ["carne_crua", "carne_cozida"]:
		draw_line(Vector2(10, 39), Vector2(30, 20), Color("eae1bd"), 7)
		draw_circle(Vector2(8, 39), 4, Color("eae1bd"))
		draw_circle(Vector2(12, 43), 4, Color("eae1bd"))
		draw_circle(Vector2(28, 20), 15, OUTLINE)
		draw_circle(Vector2(28, 20), 13, Color("c66e63") if item == "carne_crua" else Color("ad7846"))
		for y in [13, 20, 27]: draw_line(Vector2(22, y), Vector2(33, y - 3), Color("efb3a0") if item == "carne_crua" else Color("67472f"), 2)
	elif item in ["carne_peixe", "peixe_cozido"]:
		polygon([Vector2(5, 13), Vector2(18, 24), Vector2(5, 35)], Color("7ab1b7") if item == "carne_peixe" else Color("c49553"))
		draw_set_transform((size - Vector2(48, 48) * factor) / 2 + Vector2(28, 24) * factor, 0, Vector2(factor * 1.2, factor * 0.7))
		draw_circle(Vector2.ZERO, 14, OUTLINE)
		draw_circle(Vector2.ZERO, 12, Color("9cc7c8") if item == "carne_peixe" else Color("e0b477"))
		draw_circle(Vector2(8, -3), 2, OUTLINE)
		draw_line(Vector2(-3, -8), Vector2(-3, 8), Color("456f77") if item == "carne_peixe" else Color("79502f"), 2)
	elif item == "armadura_pedra":
		polygon([Vector2(7, 9), Vector2(17, 5), Vector2(24, 13), Vector2(31, 5), Vector2(41, 9), Vector2(36, 23), Vector2(35, 43), Vector2(13, 43), Vector2(12, 23)], Color("a6a3b3"))
		draw_line(Vector2(24, 16), Vector2(24, 40), Color("665e7b"), 3)
		draw_line(Vector2(14, 26), Vector2(35, 26), Color("665e7b"), 2)
	elif item == "arco":
		draw_arc(center, 18, -PI / 2, PI / 2, 16, OUTLINE, 6)
		draw_arc(center, 18, -PI / 2, PI / 2, 16, Color("c49659"), 3)
		draw_line(Vector2(24, 6), Vector2(24, 42), Color("e5d8ae"), 2)
	elif item == "flecha":
		draw_line(Vector2(8, 40), Vector2(40, 8), Color("d9bd80"), 3)
		polygon([Vector2(41, 6), Vector2(28, 12), Vector2(36, 21)], Color("c7d3d2"))
		for offset in [0, 5]: draw_line(Vector2(8 + offset, 34 - offset), Vector2(15 + offset, 39 - offset), Color("d5dcca"), 3)
	elif item in ["parede_madeira", "porta_madeira", "vidraca"]:
		draw_rect(Rect2(6, 5, 36, 38), Color("7eb8c0") if item == "vidraca" else Color("a88350"))
		draw_rect(Rect2(6, 5, 36, 38), OUTLINE, false, 3)
		for x in [16, 30]: draw_line(Vector2(x, 8), Vector2(x, 40), Color("674c35"), 2)
		if item == "vidraca":
			draw_line(Vector2(7, 24), Vector2(41, 24), Color("785b3a"), 4)
			draw_line(Vector2(14, 19), Vector2(21, 10), Color("d1f0e8"), 2)
		elif item == "porta_madeira": draw_circle(Vector2(35, 28), 3, Color("f1cb74"))
		else: draw_line(Vector2(9, 15), Vector2(39, 15), Color("d1a96f"), 4)
	elif item == "bau":
		polygon([Vector2(4, 16), Vector2(12, 9), Vector2(39, 9), Vector2(44, 16), Vector2(44, 40), Vector2(4, 40)], Color("a08048"))
		draw_rect(Rect2(5, 16, 38, 9), Color("c2a35c"))
		for x in [12, 34]: draw_rect(Rect2(x, 13, 3, 27), Color("e1c27a"))
		draw_rect(Rect2(21, 22, 6, 9), Color("e1d180"))
	elif item == "cantil":
		polygon([Vector2(14, 13), Vector2(35, 13), Vector2(38, 22), Vector2(36, 41), Vector2(12, 41), Vector2(10, 22)], Color("578796"))
		draw_rect(Rect2(20, 6, 9, 8), Color("d6ca99"))
		draw_line(Vector2(17, 21), Vector2(17, 33), Color("add4d3"), 3)
	elif item.begins_with("mochila"):
		polygon([Vector2(10, 14), Vector2(17, 8), Vector2(31, 8), Vector2(38, 14), Vector2(39, 41), Vector2(9, 41)], Color("ac834c"))
		draw_rect(Rect2(16, 4, 16, 10), Color("d4ae71"), false, 3)
		draw_rect(Rect2(15, 25, 18, 11), Color("e4c18a"), false, 2)
		for i in range(ItemCatalog.bag_level(item)): draw_circle(Vector2(15 + i * 6, 19), 2, Color("e4c18a"))
	elif item == "cama":
		draw_rect(Rect2(4, 12, 40, 26), Color("6b4931"))
		draw_rect(Rect2(7, 15, 34, 20), Color("84936b"))
		draw_rect(Rect2(8, 16, 10, 18), Color("eee2bd"))
		for x in [5, 40]: draw_rect(Rect2(x, 35, 4, 8), Color("aa7d4c"))
	elif item == "fogueira":
		IslandArt.fire(self, 0, size / 2 + Vector2(0, 8) * factor, factor * 0.85)
