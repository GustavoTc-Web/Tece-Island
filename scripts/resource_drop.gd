class_name ResourceDrop
extends Node2D

@export var resource: String = "madeira":
	set(value):
		resource = value
		if is_instance_valid(item_visual): item_visual.item = value
@export var quantity: int = 1
var highlighted: bool = false
var collecting: bool = false
var attributes: Dictionary = {}
var item_visual: ItemIcon

func _ready() -> void:
	item_visual = ItemIcon.new()
	item_visual.item = resource
	add_child(item_visual)
	item_visual.custom_minimum_size = Vector2.ZERO
	item_visual.size = Vector2(32, 32)
	item_visual.position = Vector2(-16, -16)


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
	if accepted > 0: inventory.resource_collected.emit(resource, accepted)
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
	if highlighted:
		draw_string(IslandTheme.BODY, Vector2(-12, -17), ItemCatalog.title(resource), HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	draw_string(IslandTheme.BODY, Vector2(-8, 31), str(quantity), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("f3ebce"))
