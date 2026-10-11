extends Node2D

@export_range(0.0, 1.0) var loot_chance: float = 0.70
@export_range(0.0, 1.0) var guardian_chance: float = 0.30
@export_range(0.0, 1.0) var two_guardian_chance: float = 0.02
@export_range(0.0, 1.0) var weapon_chance: float = 0.05
@export_range(0.0, 1.0) var pistol_weight: float = 0.75
@export_range(0.0, 1.0) var external_weapon_chance: float = 0.01
@export var development_weapons: bool = false
@export var random_seed: int = 0
var player: CharacterBody2D
var container: Node2D
var external_rolls: Array[bool] = []
var external_weapon := ""
var initialized := false
const BUILDINGS := [preload("res://scenes/buildings/broken_house.tscn"), preload("res://scenes/buildings/abandoned_castle.tscn"), preload("res://scenes/buildings/mysterious_farm.tscn")]
const LOCATIONS := [Vector2(550, 1250), Vector2(2800, 460), Vector2(3250, 1120), Vector2(4230, 460), Vector2(4780, 1120), Vector2(4930, 430), Vector2(5680, 440), Vector2(6200, 1120), Vector2(6580, 400)]
const EXTERNAL_POINTS := [Vector2(500, 768), Vector2(900, 768), Vector2(1600, 768), Vector2(2100, 768), Vector2(2600, 768), Vector2(3100, 768), Vector2(3600, 768), Vector2(4100, 768), Vector2(4600, 768), Vector2(5100, 768)]

func initialize() -> void:
	if initialized:
		return
	initialized = true
	var random := RandomNumberGenerator.new()
	if random_seed == 0: random.randomize()
	else: random.seed = random_seed
	for i in range(LOCATIONS.size()):
		var building := BUILDINGS[i % 3].instantiate() as AbandonedBuilding
		if i >= 6: building.kind = "posto" if i == 8 else "barro"
		building.position = LOCATIONS[i]
		container.add_child(building)
		building.populate(random, self)
	for point in EXTERNAL_POINTS:
		var found := random.randf() < external_weapon_chance
		external_rolls.append(found)
		if found and external_weapon == "":
			external_weapon = "pistola" if random.randf() < pistol_weight else "espingarda"
			spawn_weapon(external_weapon, point)
	if development_weapons:
		spawn_weapon("pistola", Vector2(1090, 768))
		spawn_weapon("espingarda", Vector2(1210, 768))

func spawn_weapon(item: String, point: Vector2) -> void:
	spawn_drop(item, 1, point)
	var rule: Dictionary = GunRules.WEAPONS[item]
	spawn_drop(rule.ammo, rule.magazine, point + Vector2(0, 30))

func spawn_drop(item: String, amount: int, point: Vector2) -> void:
	var drop := preload("res://scenes/resource_drop.tscn").instantiate() as ResourceDrop
	drop.resource = item
	drop.quantity = amount
	drop.position = point
	container.add_child(drop)
