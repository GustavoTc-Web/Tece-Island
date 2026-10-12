class_name SurvivalNeeds
extends Node
signal changed(hunger: float, thirst: float)
signal alert(message: String)
@export var max_hunger: float = 100.0
@export var max_thirst: float = 100.0
@export var hunger_per_minute: float = 5.0
@export var thirst_per_minute: float = 8.0
@export var warning_threshold: float = 25.0
@export var damage_interval: float = 5.0
@export var food_restores: float = 30.0
@export var water_restores: float = 40.0
var hunger: float = 100.0
var thirst: float = 100.0
var damage_clock: float = 0.0
@onready var player: CharacterBody2D = get_parent()

func _ready() -> void: reset()
func reset() -> void:
	hunger = max_hunger
	thirst = max_thirst
	damage_clock = 0
	changed.emit(hunger, thirst)
func _physics_process(delta: float) -> void: advance(delta)
func advance(delta: float) -> void:
	if get_tree().paused or player.dead or not player.simulation_authority: return
	var old_hunger := hunger
	var old_thirst := thirst
	hunger = maxf(0, hunger - hunger_per_minute * delta / 60)
	thirst = maxf(0, thirst - thirst_per_minute * delta / 60)
	if old_hunger > warning_threshold and hunger <= warning_threshold: alert.emit("Fome baixa — prepare e coma carne")
	if old_thirst > warning_threshold and thirst <= warning_threshold: alert.emit("Sede baixa — procure um poço ou use o cantil")
	if hunger <= 0 or thirst <= 0:
		damage_clock += delta
		while damage_clock >= maxf(0.1, damage_interval) and not player.dead:
			damage_clock -= maxf(0.1, damage_interval)
			player.receive_damage((1 if hunger <= 0 else 0) + (1 if thirst <= 0 else 0), true)
	else: damage_clock = 0
	changed.emit(hunger, thirst)
func drink() -> String:
	if player.dead: return "Você precisa reaparecer"
	thirst = minf(max_thirst, thirst + water_restores)
	changed.emit(hunger, thirst)
	return "Água potável: +%d sede" % water_restores
func use_slot(inventory: ResourceInventory, index: int) -> String:
	if player.dead: return "Você precisa reaparecer"
	var item: String = inventory.slot_data(index).get("item", "")
	if item in ["carne_cozida", "peixe_cozido"]:
		if not inventory.consume_slot(index, item): return "Item indisponível"
		hunger = minf(max_hunger, hunger + food_restores)
		changed.emit(hunger, thirst)
		return "%s: +%d fome" % [ItemCatalog.title(item), food_restores]
	if item == "cantil":
		if not inventory.use_water(index): return "Cantil vazio — encha em um poço"
		return drink()
	return "Selecione carne cozida ou um cantil com água"
