class_name ExpeditionRecord
extends Node2D
var record_id := ""
var journal: IslandJournal
var highlighted := false
func _ready() -> void:
	add_to_group("interactables")
	add_to_group("expedition_records")
func can_interact() -> bool: return record_id not in journal.discovered
func set_highlighted(value: bool) -> void:
	highlighted = value
	queue_redraw()
func prompt() -> String: return "E — Coletar registro: " + IslandJournal.RECORDS[record_id].title
func interact(_inventory: ResourceInventory) -> String:
	if not journal.collect(record_id): return "Registro já descoberto."
	queue_free()
	return "Nova página no Diário: " + IslandJournal.RECORDS[record_id].title
func _draw() -> void:
	draw_rect(Rect2(-10, -12, 20, 24), Color("ded0a0"))
	for y in [-6, 0, 6]: draw_line(Vector2(-6, y), Vector2(6, y), Color("70674b"), 2)
	if highlighted: draw_arc(Vector2.ZERO, 19, 0, TAU, 20, Color("f2d786"), 2)
