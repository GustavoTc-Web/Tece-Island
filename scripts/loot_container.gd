extends Node2D

const DROP := preload("res://scenes/resource_drop.tscn")
var contents: Dictionary = {}
var released := false
var highlighted := false

func prompt() -> String:
	return "E — Recipiente vazio" if released else "E — Vasculhar recipiente"

func set_highlighted(value: bool) -> void:
	highlighted = value
	queue_redraw()

func interact(_inventory: ResourceInventory) -> String:
	if released:
		return "Já vasculhado — vazio"
	# Marca primeiro: revisitar ou reentrar por sinais não sorteia/libera novamente.
	released = true
	var index := 0
	for item in contents:
		var drop := DROP.instantiate() as ResourceDrop
		drop.resource = item
		drop.quantity = contents[item]
		drop.position = global_position + Vector2((index % 3 - 1) * 24, 28 + (index / 3) * 24)
		get_parent().get_parent().add_child(drop)
		index += 1
	queue_redraw()
	return "Conteúdo no chão — E para recolher" if not contents.is_empty() else "Recipiente vazio"

func _draw() -> void:
	draw_rect(Rect2(-16, -15, 32, 26), Color("5f4635") if released else Color("a08048"))
	draw_rect(Rect2(-12, -11, 24, 18), Color("332c27") if released else Color("c2a35c"))
	if highlighted:
		draw_arc(Vector2.ZERO, 23, 0, TAU, 32, Color("f2d786"), 2)
