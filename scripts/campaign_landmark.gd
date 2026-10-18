class_name CampaignLandmark
extends Node2D
var campaign: SoloCampaign
var kind := "beacon"
var highlighted := false

func _ready() -> void:
	# The original expedition page is the house clue, with the same E action.
	if kind != "clue": add_to_group("interactables")
func set_highlighted(value: bool) -> void:
	highlighted = value
	queue_redraw()
func can_interact() -> bool:
	return kind == "beacon" or (not campaign.clues if kind == "clue" else kind not in campaign.components)
func prompt() -> String:
	if kind == "beacon": return "E — Sinalizador · " + ("ativar" if campaign.repaired else "examinar / reparar")
	return "E — Pistas do resgate" if kind == "clue" else "E — Recuperar " + SoloCampaign.TITLES[kind]
func interact(_inventory: ResourceInventory) -> String: return campaign.interact(kind)
func _draw() -> void:
	if kind == "clue": return
	if kind != "beacon" and not can_interact(): return
	var color := Color("8ce0d3") if kind != "beacon" or campaign.repaired else Color("e5b270")
	draw_circle(Vector2.ZERO, 22, Color("283e3d"))
	if kind == "beacon":
		draw_rect(Rect2(-17, -18, 34, 30), Color("676e6c"))
		draw_line(Vector2(0, -15), Vector2(0, -52), color, 4)
		draw_arc(Vector2(0, -52), 17, -PI * 0.8, -PI * 0.2, 12, color, 4)
		draw_circle(Vector2(0, -24), 5, color)
	else:
		draw_rect(Rect2(-12, -15, 24, 24), color)
		draw_line(Vector2(-7, -5), Vector2(7, -5), Color("354947"), 3)
	draw_arc(Vector2.ZERO, 27, 0, TAU, 24, color, 3 if highlighted else 1)
