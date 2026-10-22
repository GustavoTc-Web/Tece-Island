class_name ResourceInventory
extends Node

signal changed(wood: int, stone: int)
signal equipment_changed(tool: String)
signal resource_collected(item: String, amount: int)
signal crafted(id: String)
@export_range(5, 64) var capacity: int = 7
@export var stack_limit: int = 15
@export var backpack_bonus: int = 2
var base_capacity: int = 7
var backpack: Dictionary = {}
var armor: Dictionary = {}

func armor_protection() -> float:
	return clampf(float(ResourceRules.RECIPES.get(armor.get("item", ""), {}).get("protection", 0)), 0, 100)

func equip_armor(index: int) -> bool:
	if slot_data(index).get("item", "") != "armadura_pedra": return false
	var previous := armor.duplicate(true)
	armor = _slots[index].duplicate(true)
	_slots[index] = previous
	_notify()
	return true

func remove_armor() -> bool:
	if armor.is_empty(): return false
	for index in range(_slots.size()):
		if _slots[index].is_empty():
			_slots[index] = armor.duplicate(true)
			armor = {}
			_notify()
			return true
	return false
var _slots: Array[Dictionary] = []
var selected_index: int = 0
var selected_category := "maos"
var selected_weapon_uid := 0
var next_weapon_uid := 1
var cooking_available := false
var wood: int:
	get: return count_item("madeira")
var stone: int:
	get: return count_item("pedra")
var slots: Array[Dictionary]:
	get: return _slots.duplicate(true)
var tools: Dictionary:
	get:
		var result := {}
		for slot in _slots:
			if ItemCatalog.is_equippable(slot.get("item", "")): result[slot.item] = true
		return result

func _ready() -> void:
	base_capacity = capacity
	reset()

func calculated_capacity(equipped: bool = true) -> int:
	return base_capacity + (backpack_bonus * maxi(1, ItemCatalog.bag_level(backpack.get("item", ""))) if equipped else 0)

func reset() -> void:
	backpack = {}
	armor = {}
	capacity = calculated_capacity(false)
	_slots.clear()
	_slots.resize(capacity)
	for i in range(capacity): _slots[i] = {}
	selected_index = 0
	selected_weapon_uid = 0
	next_weapon_uid = 1
	_notify()

func _notify() -> void:
	var item := equipped_tool()
	selected_category = ItemCatalog.category(item) if item != "maos" else "maos"
	selected_weapon_uid = int(selected_data().get("uid", 0))
	changed.emit(wood, stone)
	equipment_changed.emit(item)

func selected_data() -> Dictionary:
	return slot_data(selected_index)

func slot_data(index: int) -> Dictionary:
	return _slots[index].duplicate(true) if index >= 0 and index < _slots.size() else {}

func count_item(item: String) -> int:
	var total := 0
	for slot in _slots:
		if slot.get("item", "") == item: total += int(slot.quantity)
	return total

func add_resource(item: String, amount: int = 1) -> int:
	return add_item({"item": item, "quantity": amount})

func add_item(data: Dictionary) -> int:
	var item: String = data.get("item", "")
	var remaining: int = data.get("quantity", 0)
	if remaining <= 0 or (not ItemCatalog.NAMES.has(item) and not ResourceRules.RECIPES.has(item)): return 0
	var total := remaining
	var limit := stack_limit if item in ItemCatalog.STACKABLE else 1
	if limit > 1:
		for slot in _slots:
			if slot.get("item", "") == item:
				var amount := mini(remaining, limit - int(slot.quantity))
				slot.quantity += amount
				remaining -= amount
	for i in range(_slots.size()):
		if remaining == 0: break
		if _slots[i].is_empty():
			_slots[i] = data.duplicate(true)
			_slots[i].quantity = mini(remaining, limit)
			if GunRules.WEAPONS.has(item):
				_slots[i].uid = next_weapon_uid
				next_weapon_uid += 1
			if item == "cantil": _slots[i].water = clampi(int(data.get("water", 0)), 0, 3)
			remaining -= int(_slots[i].quantity)
	if remaining < total: _notify()
	return total - remaining

func _consume(plan: Array[Dictionary], item: String, amount: int) -> void:
	if amount <= 0: return
	var indices: Array[int] = []
	for i in range(plan.size()):
		if plan[i].get("item", "") == item: indices.append(i)
	indices.sort_custom(func(a, b): return int(plan[a].quantity) < int(plan[b].quantity))
	for i in indices:
		var used := mini(amount, int(plan[i].quantity))
		plan[i].quantity -= used
		amount -= used
		if plan[i].quantity == 0: plan[i] = {}
		if amount == 0: break

func craft_error(id: String) -> String:
	if not ResourceRules.RECIPES.has(id): return "Receita desconhecida"
	if ResourceRules.crafting_group(id) == "Fogueira" and not cooking_available: return "Prepare perto de uma fogueira acesa"
	if ItemCatalog.is_equippable(id) and count_item(id) > 0: return "Ferramenta já fabricada"
	if id == "mochila" and not backpack.is_empty(): return "Bolsa nível 1 já equipada"
	var recipe: Dictionary = ResourceRules.RECIPES[id]
	if recipe.has("previous_bag") and backpack.get("item", "") != recipe.previous_bag:
		return "Equipe %s para melhorar" % ItemCatalog.title(recipe.previous_bag)
	for ingredient in ResourceRules.ingredients(id):
		if ingredient == recipe.get("previous_bag", ""): continue
		if count_item(ingredient) < ResourceRules.ingredients(id)[ingredient]: return "Materiais insuficientes"
	if _craft_plan(id).is_empty(): return "Inventário cheio"
	return ""

func _craft_plan(id: String) -> Array[Dictionary]:
	var plan: Array[Dictionary] = _slots.duplicate(true)
	var recipe: Dictionary = ResourceRules.RECIPES[id]
	for ingredient in ResourceRules.ingredients(id):
		if ingredient != recipe.get("previous_bag", ""): _consume(plan, ingredient, ResourceRules.ingredients(id)[ingredient])
	if ItemCatalog.bag_level(id) > 0: return plan
	var remaining: int = int(recipe.get("quantity", 1))
	if id in ItemCatalog.STACKABLE:
		for slot in plan:
			if slot.get("item", "") == id and slot.quantity < stack_limit:
				var accepted := mini(remaining, stack_limit - int(slot.quantity))
				slot.quantity += accepted
				remaining -= accepted
				if remaining == 0: return plan
	for i in range(plan.size()):
		if plan[i].is_empty():
			var quantity := mini(remaining, stack_limit if id in ItemCatalog.STACKABLE else 1)
			plan[i] = {"item": id, "quantity": quantity}
			if id == "cantil": plan[i].water = 0
			remaining -= quantity
			if remaining == 0: return plan
	return []


func transfer_to(destination: ResourceInventory, index: int, whole: bool = true) -> int:
	if destination == self: return 0
	var data := slot_data(index)
	if data.is_empty(): return 0
	if not whole: data.quantity = 1
	# Prepare on an isolated inventory. Commit both arrays before either signal.
	var planner := ResourceInventory.new()
	planner._slots = destination.slots
	planner.stack_limit = destination.stack_limit
	planner.next_weapon_uid = destination.next_weapon_uid
	var accepted := planner.add_item(data)
	if accepted == 0:
		planner.free()
		return 0
	destination._slots = planner.slots
	destination.next_weapon_uid = planner.next_weapon_uid
	_slots[index].quantity -= accepted
	if _slots[index].quantity == 0: _slots[index] = {}
	planner.free()
	_notify()
	destination._notify()
	return accepted

func can_craft(id: String) -> bool:
	return craft_error(id) == ""

func craft(id: String) -> bool:
	if not can_craft(id): return false
	_slots = _craft_plan(id)
	if ItemCatalog.bag_level(id) > 0:
		backpack = {"item": id, "quantity": 1}
		_resize_capacity()
	_notify()
	crafted.emit(id)
	return true

func _resize_capacity() -> void:
	capacity = calculated_capacity(not backpack.is_empty())
	while _slots.size() < capacity: _slots.append({})

func select_quick(index: int) -> bool:
	if index < 0 or index >= 5 or index >= _slots.size(): return false
	selected_index = index
	_notify()
	return true

func equip_slot(index: int) -> bool:
	if index < 0 or index >= _slots.size(): return false
	if ItemCatalog.bag_level(_slots[index].get("item", "")) > 0: return equip_backpack(index)
	if _slots[index].get("item", "") == "armadura_pedra": return equip_armor(index)
	selected_index = index
	_notify()
	return true

# Compatibilidade de chamadas internas; teclas selecionam espaços, nunca categorias.
func best_tool(category: String) -> String:
	for material in ["pedra", "madeira", ""]:
		var item: String = category + ("_" + material if material != "" else "")
		if count_item(item) > 0: return item
	return "maos" if category == "maos" else ""

func equip(category: String) -> bool:
	if category == "maos":
		selected_index = -1
		_notify()
		return true
	var item := best_tool(category)
	for i in range(_slots.size()):
		if _slots[i].get("item", "") == item: return equip_slot(i)
	return false

func equip_backpack(index: int) -> bool:
	if not backpack.is_empty() or ItemCatalog.bag_level(slot_data(index).get("item", "")) == 0: return false
	backpack = _slots[index].duplicate(true)
	_slots[index] = {}
	_resize_capacity()
	_notify()
	return true

func backpack_plan(drop: bool = false) -> Array[Dictionary]:
	# Never silently rearrange occupied extra spaces while removing the bag.
	for i in range(base_capacity, _slots.size()):
		if not _slots[i].is_empty(): return []
	var plan: Array[Dictionary] = []
	for slot in _slots:
		if slot.is_empty(): continue
		var remaining: int = slot.quantity
		if slot.item in ItemCatalog.STACKABLE:
			for target in plan:
				if target.item == slot.item:
					var accepted := mini(remaining, stack_limit - int(target.quantity))
					target.quantity += accepted
					remaining -= accepted
		if remaining > 0:
			var copy := slot.duplicate(true)
			copy.quantity = remaining
			plan.append(copy)
	if not drop: plan.append(backpack.duplicate(true))
	if plan.size() > calculated_capacity(false): return []
	while plan.size() < calculated_capacity(false): plan.append({})
	return plan

func remove_backpack(drop: bool = false) -> bool:
	if backpack.is_empty(): return false
	var plan := backpack_plan(drop)
	if plan.is_empty(): return false
	_slots = plan
	backpack = {}
	capacity = calculated_capacity(false)
	selected_index = mini(selected_index, 4)
	_notify()
	return true

func swap_slots(a: int, b: int) -> bool:
	if a < 0 or b < 0 or a >= capacity or b >= capacity: return false
	var temp := _slots[a]
	_slots[a] = _slots[b]
	_slots[b] = temp
	_notify()
	return true

func take_slot(index: int, amount: int) -> Dictionary:
	var data := slot_data(index)
	if data.is_empty() or amount <= 0: return {}
	data.quantity = mini(amount, int(data.quantity))
	_slots[index].quantity -= int(data.quantity)
	if _slots[index].quantity == 0: _slots[index] = {}
	_notify()
	return data

func remove_item(item: String, amount: int) -> bool:
	if amount <= 0 or count_item(item) < amount: return false
	_consume(_slots, item, amount)
	_notify()
	return true

func consume_slot(index: int, expected: String) -> bool:
	if slot_data(index).get("item", "") != expected: return false
	return not take_slot(index, 1).is_empty()

func equipped_tool() -> String:
	var item: String = selected_data().get("item", "")
	return item if ItemCatalog.is_equippable(item) else "maos"

func use_water(index: int) -> bool:
	if slot_data(index).get("item", "") != "cantil" or int(_slots[index].get("water", 0)) <= 0: return false
	_slots[index].water -= 1
	_notify()
	return true

func fill_canteen() -> bool:
	var index := selected_index
	if slot_data(index).get("item", "") != "cantil" or slot_data(index).get("water", 0) >= 3:
		index = -1
		for i in range(capacity):
			if _slots[i].get("item", "") == "cantil" and _slots[i].get("water", 0) < 3:
				index = i
				break
	if index < 0: return false
	_slots[index].water = 3
	_notify()
	return true

func _weapon_slot(weapon: String) -> Dictionary:
	if selected_index >= 0 and selected_index < capacity and _slots[selected_index].get("item", "") == weapon: return _slots[selected_index]
	return {}

func loaded_ammo(weapon: String) -> int:
	return int(_weapon_slot(weapon).get("loaded", 0))

func set_loaded_ammo(weapon: String, amount: int) -> void:
	var slot := _weapon_slot(weapon)
	if not slot.is_empty():
		slot.loaded = clampi(amount, 0, GunRules.WEAPONS[weapon].magazine)
		changed.emit(wood, stone)

func equipped_weapon_id() -> int:
	return int(selected_data().get("uid", 0))

func network_state() -> Dictionary:
	return {"slots": slots, "category": selected_category, "weapon_uid": selected_weapon_uid, "selected": selected_index, "backpack": backpack.duplicate(true), "armor": armor.duplicate(true)}

func apply_network_state(state: Dictionary) -> void:
	# JSON numbers are floats. Compare the projected fields with a normalized
	# index rather than comparing a JSON dictionary to native integer metadata.
	if state.slots == _slots and int(state.get("selected", 0)) == selected_index and state.get("backpack", {}) == backpack and state.get("armor", {}) == armor: return
	_slots.clear()
	for slot in state.slots: _slots.append(slot.duplicate(true))
	capacity = _slots.size()
	backpack = state.get("backpack", {}).duplicate(true)
	armor = state.get("armor", {}).duplicate(true)
	selected_index = int(state.get("selected", 0))
	_notify()


func restore_state(state: Dictionary) -> bool:
	# Validated game state only; authentication tokens never enter this format.
	if not state.get("backpack", {}) is Dictionary or not state.get("slots", []) is Array: return false
	var bag: Dictionary = state.get("backpack", {}).duplicate(true)
	if not state.get("armor", {}) is Dictionary: return false
	var loaded_armor: Dictionary = state.get("armor", {}).duplicate(true)
	if not loaded_armor.is_empty() and (loaded_armor.get("item", "") != "armadura_pedra" or int(loaded_armor.get("quantity", 0)) != 1): return false
	if not bag.is_empty() and ItemCatalog.bag_level(bag.get("item", "")) == 0: return false
	var loaded: Array[Dictionary] = []
	for slot in state.get("slots", []):
		if not slot is Dictionary: return false
		if not slot.is_empty() and (int(slot.get("quantity", 0)) <= 0 or (not ItemCatalog.NAMES.has(slot.get("item", "")) and not ResourceRules.RECIPES.has(slot.get("item", "")))): return false
		loaded.append(slot.duplicate(true))
		if not loaded[-1].is_empty():
			for field in ["quantity", "uid", "loaded", "water"]:
				if loaded[-1].has(field): loaded[-1][field] = int(loaded[-1][field])
	var expected := base_capacity + ItemCatalog.bag_level(bag.get("item", "")) * backpack_bonus
	for i in range(expected, loaded.size()):
		if not loaded[i].is_empty(): return false
	loaded.resize(expected)
	for i in range(loaded.size()):
		if loaded[i] == null: loaded[i] = {}
	backpack = bag
	armor = loaded_armor
	_slots = loaded
	capacity = expected
	selected_index = clampi(int(state.get("selected", 0)), -1, capacity - 1)
	next_weapon_uid = 1
	for slot in _slots: next_weapon_uid = maxi(next_weapon_uid, int(slot.get("uid", 0)) + 1)
	_notify()
	return true
