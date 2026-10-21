extends Node2D

const FILE := "res://assets/data/multiplayer-world.json"
var data := {}
var objects: Node2D
var resources := {}
var wells := {}
var campaign: SoloCampaign = null
var scenery: Node2D

func _ready() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	scenery = preload("res://scripts/network/multiplayer_scenery.gd").new()
	add_child(scenery)
	objects = Node2D.new()
	objects.name = "WorldObjects"
	objects.y_sort_enabled = true
	add_child(objects)
	for item in data.resources:
		var scene: PackedScene = {"madeira": preload("res://scenes/obstacles/tree.tscn"), "pedra": preload("res://scenes/obstacles/rock.tscn"), "fibra": preload("res://scenes/obstacles/bush.tscn")}[item.kind]
		var node := scene.instantiate() as HarvestResource
		if item.visual in ["burned", "pine"]:
			node.set_script(preload("res://scripts/campaign_tree.gd"))
			node.burned = item.visual == "burned"
		node.position = Vector2(item.x, item.y)
		objects.add_child(node)
		node.modulate = Color(item.tint[0], item.tint[1], item.tint[2])
		node.collision_layer = 0
		node.collision_mask = 0
		node.remove_from_group("harvest_resources")
		node.set_process(false)
		resources[item.id] = node
	for item in data.wells:
		var well := WaterWell.new()
		well.position = Vector2(item.x, item.y)
		well.set_meta("network_id", item.id)
		objects.add_child(well)
		well.collision_layer = 0
		well.collision_mask = 0
		well.remove_from_group("interactables")
		wells[item.id] = well
	for item in data.buildings:
		var building: AbandonedBuilding = RuinedTemple.new() if item.temple else AbandonedBuilding.new()
		building.kind = item.kind
		building.position = Vector2(item.x, item.y)
		building.modulate = Color(item.tint[0], item.tint[1], item.tint[2])
		objects.add_child(building)
		for child in building.get_children():
			if child is StaticBody2D: child.collision_layer = 0; child.collision_mask = 0

func show_area(area: Rect2) -> void:
	scenery.show_area(area)
