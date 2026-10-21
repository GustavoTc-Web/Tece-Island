class_name CampaignTerrain
extends Node2D
# Geometry stays fixed across seeds. Only existing loot rules use a random roll.
var world: Node2D
func initialize(source: Node2D) -> void:
	world = source
	world.move_child(self, 1)
	for region in WorldTerrain.CAMPAIGN_LAND:
		var rect: Rect2 = region.rect
		for i in range(28):
			var point := rect.position + Vector2(120 + posmod(i * 337, int(rect.size.x) - 240), 110 + posmod(i * 191, 800))
			if absf(point.x - rect.get_center().x) < 120 or absf(point.y - rect.get_center().y) < 115: continue
			var tree := world.TREE.instantiate() as HarvestResource
			tree.set_script(preload("res://scripts/campaign_tree.gd"))
			tree.burned = region.id == "burned_forest"
			tree.position = point
			tree.depleted.connect(world._spawn_drop)
			world.get_node("WorldObjects").add_child(tree)
		# Cliffs flank a wide trail; they never cross the central north/south path.
		if region.id == "mist_ridge":
			for x in [rect.get_center().x - 190, rect.get_center().x + 190]:
				for y in [-2380, -2250, -1810, -1680]: world.add_obstacle(world.ROCK, Vector2(x, y))
		var building := AbandonedBuilding.new()
		building.kind = "casa"
		building.position = rect.get_center() + Vector2(350, -210)
		building.modulate = Color("8a9e97") if region.id == "mist_ridge" else Color("71645e")
		world.get_node("WorldObjects").add_child(building)
		var random := RandomNumberGenerator.new()
		random.seed = (str(world.world_seed) + "/campaign/" + str(region.id)).hash()
		building.populate(random, world.get_node("Exploration"))
		building.loot.set_meta("loot_id", "campaign-building-" + str(region.id))
		# Connect the optional building's southern entrance to the central trail.
	queue_redraw()

func _draw() -> void:
	draw_scenery(self)

# Shared drawing commands; multiplayer records them into clipped spatial chunks.
static func draw_scenery(canvas) -> void:
	for region in WorldTerrain.CAMPAIGN_LAND:
		var rect: Rect2 = region.rect
		var center := rect.get_center()
		var trail: Color = Color("8b9786") if region.id == "mist_ridge" else Color("8b7760")
		canvas.draw_line(Vector2(center.x, rect.end.y), Vector2(center.x, rect.position.y + 50), trail, 112)
		canvas.draw_line(Vector2(rect.position.x, center.y), Vector2(rect.end.x, center.y), trail, 112)
		canvas.draw_polyline(PackedVector2Array([center, center + Vector2(350, 0), center + Vector2(350, -110)]), trail, 86)
		canvas.draw_circle(center, 100, trail)
		if region.id == "mist_ridge":
			# The map lies at the watchtower's open base; no climbing required.
			for x in [-55, 55]: canvas.draw_line(center + Vector2(x, -25), center + Vector2(x, -150), Color("494d48"), 10)
			canvas.draw_rect(Rect2(center + Vector2(-72, -165), Vector2(144, 28)), Color("b4b29c"))
			canvas.draw_line(center + Vector2(-55, -120), center + Vector2(55, -55), Color("535a50"), 7)
			for i in range(8):
				# Translucent ground ribbons, cached draw calls, no shader/particles.
				canvas.draw_line(rect.position + Vector2(60, 120 + i * 105), rect.position + Vector2(rect.size.x - 60, 165 + i * 105), Color(0.84, 0.9, 0.88, 0.10), 22)
		else:
			for offset in [Vector2(-65, -70), Vector2(65, -60), Vector2(-45, 65)]:
				canvas.draw_rect(Rect2(center + offset, Vector2(32, 22)), Color("3e4040"))
			canvas.draw_arc(center, 54, 0, TAU, 24, Color("a17657"), 3)
			canvas.draw_line(center + Vector2(-28, -28), center + Vector2(28, 28), Color("a17657"), 3)
		canvas.draw_string(IslandTheme.BODY, center + Vector2(-100, 100), "Torre da Serra" if region.id == "mist_ridge" else "Ruínas do chamado", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("efe3be"))
	# Open ruined courtyards use the existing trails and obstacles. No walls are
	# inserted over old player buildings, resources or routes.
	for id in ["lens", "coil"]:
		var center: Vector2 = CampaignEncounters.CENTERS[id]
		canvas.draw_rect(Rect2(center - Vector2(300, 210), Vector2(600, 420)), Color("383643"))
		canvas.draw_rect(Rect2(center - Vector2(285, 195), Vector2(570, 390)), Color("514958"), false, 6)
		for x in range(-250, 251, 50): canvas.draw_line(center + Vector2(x, -185), center + Vector2(x, 185), Color("48414f"), 2)
		for y in range(-150, 151, 50): canvas.draw_line(center + Vector2(-275, y), center + Vector2(275, y), Color("48414f"), 2)
		canvas.draw_arc(center, 82, 0, TAU, 32, Color("b199cb"), 4)
		canvas.draw_string(IslandTheme.BODY, center + Vector2(-110, 185), CampaignEncounters.NAMES[id], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("e0c7ed"))
