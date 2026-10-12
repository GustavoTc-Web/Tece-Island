extends Node
@export var temples_per_region := 2
@export var loot_budget_per_temple := 6
@export var guard_limit := 4
var temples: Array[RuinedTemple] = []
var guardians: Array[ForestCreature] = []

func initialize(world: Node2D, seed_value: int) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value + 137
	for region in WorldTerrain.RUINS:
		var rect: Rect2 = region.rect
		for i in range(temples_per_region):
			var temple := RuinedTemple.new()
			temple.position = rect.position + Vector2(rect.size.x / 2, rect.size.y * (i + 0.6) / (temples_per_region + 0.2))
			world.get_node("WorldObjects").add_child(temple)
			temple.populate_temple(random, loot_budget_per_temple)
			temples.append(temple)
			if guardians.size() >= guard_limit: continue
			var guard: ForestCreature = preload("res://scenes/forest_creature.tscn").instantiate()
			guard.kind = ["criatura", "esqueleto", "aranha"][guardians.size() % 3]
			guard.origin = "guardiao"
			guard.safe_radius = 0
			guard.player = world.get_node("WorldObjects/Player")
			guard.territory_radius = 430
			guard.position = temple.position + Vector2(170, -70)
			world.get_node("WorldObjects").add_child(guard)
			guardians.append(guard)
