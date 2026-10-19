class_name IslandMinimap
extends Control
var player: CharacterBody2D
var explored := {}
var clock := 0.0
var destination: Label
const CENTER := Vector2(74, 74)
const CELL := 128.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -124
	offset_right = -16
	offset_top = 90
	offset_bottom = 198
	scale = Vector2(0.72, 0.72)
	custom_minimum_size = Vector2(148, 148)
	destination = Label.new()
	destination.position = Vector2(-38, 148)
	destination.size = Vector2(208, 88)
	destination.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	destination.add_theme_font_size_override("font_size", 19)
	destination.add_theme_color_override("font_color", Color("ffe5a1"))
	destination.add_theme_color_override("font_outline_color", Color("142720"))
	destination.add_theme_constant_override("outline_size", 5)
	destination.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(destination)

# Navigation is independent of clue discovery and fog of war. The objective can
# be pending in an old save that never examined the beacon.
func tower_navigation() -> Dictionary:
	if not is_instance_valid(player): return {}
	var campaign: SoloCampaign = player.get_parent().get_parent().get("campaign")
	if campaign == null or campaign.map_found or campaign.encounter == "won": return {}
	if not is_instance_valid(campaign.points.get("map")): return {}
	var difference: Vector2 = campaign.points.map.global_position - player.global_position
	var bearing := "Aqui"
	if difference.length() > 70:
		var compass := ["L", "SE", "S", "SO", "O", "NO", "N", "NE"]
		bearing = compass[posmod(roundi(difference.angle() / (PI / 4)), 8)]
	return {"position": campaign.points.map.global_position, "offset": difference / 8,
		"outside": difference.length() > 59 * 8, "bearing": bearing,
		"nearby": difference.length() <= 70}

func reveal() -> void:
	var origin := player.global_position.snapped(Vector2(CELL, CELL))
	for x in range(-3, 4):
		for y in range(-3, 4):
			var point := origin + Vector2(x, y) * CELL
			if point.distance_to(player.global_position) <= 350 and WorldTerrain.contains(point):
				explored[SaveStore.key(point)] = true

func _process(delta: float) -> void:
	var hud := get_parent()
	visible = hud.current_panel == "" and not hud.showing_death
	if hud.menu_button != null:
		var touch: Node = get_tree().root.get_node("MobileInput")
		offset_top = 16 if touch.enabled else hud.menu_button.size.y + 32
		offset_left = -touch.touch_minimum() * 1.25 - 164 if touch.enabled else -124
		destination.add_theme_font_size_override("font_size", maxi(19, ceili(11 / (touch.css_scale() * scale.x))) if touch.enabled else 19)
	clock += delta
	if clock < 0.2 or not is_instance_valid(player): return
	clock = 0
	reveal()
	var navigation := tower_navigation()
	destination.visible = not navigation.is_empty()
	if not navigation.is_empty(): destination.text = "Torre da Serra\n" + ("Mapa no chão" if navigation.nearby else "Rumo: " + navigation.bearing)
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(player): return
	draw_circle(CENTER, 73, Color("182b29"))
	for x in range(-8, 9):
		for y in range(-8, 9):
			var offset := Vector2(x, y) * 8
			if offset.length() > 66: continue
			var point := player.global_position + offset * 8
			if not explored.has(SaveStore.key(point.snapped(Vector2(CELL, CELL)))): continue
			var region := WorldTerrain.region_at(point)
			if region.is_empty(): continue
			var color: Color = WorldTerrain.COLORS[region.kind]
			if region.kind == "Aquático" and not WorldTerrain.is_water(point): color = Color("819b62")
			draw_rect(Rect2(CENTER + offset - Vector2(4, 4), Vector2(8, 8)), color)
	draw_arc(CENTER, 73, 0, TAU, 64, Color("d0bb81"), 2)
	var world: Node = player.get_parent().get_parent()
	var campaign: SoloCampaign = world.get("campaign")
	if campaign != null:
		if campaign.map_found:
			for index in range(SoloCampaign.COMPONENTS.size()):
				var id: String = SoloCampaign.COMPONENTS[index]
				if CampaignEncounters.complete(id, campaign.temples[id]): continue
				var offset: Vector2 = (SoloCampaign.LOCATIONS[id] - player.position) / 8
				offset = offset.limit_length(59)
				draw_circle(CENTER + offset, 7, Color("77568c"))
				draw_string(IslandTheme.BODY, CENTER + offset + Vector2(-3, 4), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("fff1d7"))
		else:
			var navigation := tower_navigation()
			if not navigation.is_empty():
				var offset: Vector2 = navigation.offset.limit_length(59)
				var point := CENTER + offset
				draw_circle(point, 11, Color("283e3d"))
				# Watchtower silhouette, also visible over unexplored terrain.
				draw_rect(Rect2(point + Vector2(-7, -8), Vector2(14, 5)), Color("ffe5a1"))
				for x in [-4, 4]: draw_line(point + Vector2(x, -3), point + Vector2(x, 7), Color("ffe5a1"), 2)
				if navigation.outside:
					var heading: Vector2 = offset.normalized()
					var tip := CENTER + heading * 72
					draw_colored_polygon(PackedVector2Array([tip, tip - heading * 8 + heading.orthogonal() * 5, tip - heading * 8 - heading.orthogonal() * 5]), Color("ffe5a1"))
	draw_string(IslandTheme.BODY, Vector2(69, 14), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("fff1d7"))
	var direction: Vector2 = player.facing.normalized()
	draw_colored_polygon(PackedVector2Array([CENTER + direction * 9, CENTER - direction * 5 + direction.orthogonal() * 5, CENTER - direction * 5 - direction.orthogonal() * 5]), Color("ffe5a1"))
