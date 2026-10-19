class_name CampaignLandmark
extends Node2D
var campaign: SoloCampaign
var kind := "beacon"
var highlighted := false
var guidance_clock := 0.0

func _ready() -> void:
	# The original expedition page is the house clue, with the same E action.
	if kind != "clue": add_to_group("interactables")
	if kind == "map":
		z_index = 3
		var ink := CanvasItemMaterial.new()
		ink.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = ink
func _process(delta: float) -> void:
	if kind != "map": return
	guidance_clock += delta
	if guidance_clock >= 0.2:
		guidance_clock = 0
		queue_redraw()

func map_instruction() -> String:
	var requirement := campaign.night_requirement(3)
	if not requirement.is_empty():
		return "Aguarde a noite 3 ou posterior" if campaign.world.get_node("DayNight").day_number < 3 else "Aguarde anoitecer · noite 3 ou posterior"
	return "E ou botão Interagir · recuperar mapa"
func set_highlighted(value: bool) -> void:
	highlighted = value
	queue_redraw()
func can_interact() -> bool:
	if kind == "beacon": return true
	if kind == "clue": return not campaign.clues
	if kind == "map": return not campaign.map_found
	return not CampaignEncounters.complete(kind, campaign.temples[kind])
func prompt() -> String:
	if kind == "beacon":
		if campaign.encounter == "won": return "E — Sinalizador · resgate concluído"
		if campaign.encounter == "awaiting_dawn": return "E — Sinalizador · aguarde amanhecer"
		if campaign.encounter == "active": return "E — Sinalizador · ataque em andamento"
		if not campaign.discovered: return "E — Examinar sinalizador quebrado"
		if not campaign.map_found: return "E — Sinalizador bloqueado · falta mapa"
		if campaign.components.size() < 3: return "E — Sinalizador bloqueado · componentes %d/3" % campaign.components.size()
		if not campaign.repaired: return "E — Reparar sinal · dia 6+" if campaign.world.get_node("DayNight").day_number >= 6 else "E — Reparo bloqueado · aguarde dia 6"
		return "E — Ativar ataque final" if campaign.activation_requirement().is_empty() else "E — " + campaign.activation_requirement()
	if kind == "clue": return "E — Pistas do resgate"
	if kind == "map": return "Torre da Serra · " + map_instruction()
	if not campaign.map_found: return "E — Ruínas seladas · falta o mapa"
	return "E — " + CampaignEncounters.NAMES[kind] + (" · iniciar / retomar" if campaign.temple_requirement(kind).is_empty() else " · " + campaign.temple_requirement(kind))
func interact(_inventory: ResourceInventory) -> String: return campaign.interact(kind)
func _draw() -> void:
	if kind == "clue": return
	if kind == "map" and not can_interact(): return
	if kind in SoloCampaign.COMPONENTS and not campaign.map_found: return
	var color := Color("8ce0d3") if kind != "beacon" or campaign.repaired else Color("e5b270")
	draw_circle(Vector2.ZERO, 22, Color("283e3d"))
	if kind == "beacon":
		draw_rect(Rect2(-17, -18, 34, 30), Color("676e6c"))
		draw_line(Vector2(0, -15), Vector2(0, -52), color, 4)
		draw_arc(Vector2(0, -52), 17, -PI * 0.8, -PI * 0.2, 12, color, 4)
		draw_circle(Vector2(0, -24), 5, color)
	elif kind == "map":
		draw_rect(Rect2(-15, -18, 30, 30), Color("e1d1a3"))
		draw_polyline(PackedVector2Array([Vector2(-10, 5), Vector2(-3, -9), Vector2(4, 0), Vector2(10, -11)]), Color("6d7852"), 3)
		var player: Node2D = campaign.world.get_node("WorldObjects/Player")
		if player.global_position.distance_to(global_position) < 320:
			caption("Torre da Serra · mapa no chão", -38)
			caption(map_instruction(), 58)
			if campaign.blocked_by_base("map"):
				caption("Base obstruindo? Diário → Acessar mapa pela base", 100)
	else:
		draw_rect(Rect2(-12, -15, 24, 24), color)
		draw_line(Vector2(-7, -5), Vector2(7, -5), Color("354947"), 3)
	draw_arc(Vector2.ZERO, 27, 0, TAU, 24, color, 3 if highlighted else 1)

func caption(text: String, y: float) -> void:
	var touch: Node = get_tree().root.get_node("MobileInput")
	var font_size := maxi(17, ceili(11 / touch.css_scale())) if touch.enabled else 17
	var width := IslandTheme.BODY.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_rect(Rect2(-width / 2 - 8, y - font_size - 2, width + 16, font_size + 10), Color("142720"))
	draw_string(IslandTheme.BODY, Vector2(-width / 2, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("ffe5a1"))
