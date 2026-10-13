class_name IslandObjectives
extends Node
signal changed
signal completed(title: String)
const ORDER := ["wood", "stone", "tools", "fire", "bag"]
const STONE_TOOLS := ["picareta_pedra", "machado_pedra", "espada_pedra"]
const GOALS := {
	"wood": {"title": "Coletar 10 madeiras", "target": 10},
	"stone": {"title": "Coletar 10 pedras", "target": 10},
	"tools": {"title": "Fabricar os 3 equipamentos de pedra", "target": 3},
	"fire": {"title": "Fabricar 1 fogueira", "target": 1},
	"bag": {"title": "Melhorar a bolsa até o nível 3", "target": 3}}
var values := {"wood": 0, "stone": 0, "tools": 0, "fire": 0, "bag": 0}
var crafted_tools := {"picareta_pedra": false, "machado_pedra": false, "espada_pedra": false}
var presented: Array[String] = []
var tracked := "wood"
var enabled := true
var collapsed := false

func refresh_sequence(quiet: bool = false) -> void:
	tracked = ""
	for id in ORDER:
		if values[id] < GOALS[id].target:
			tracked = id
			break
		if id not in presented:
			presented.append(id)
			if not quiet: completed.emit(GOALS[id].title)

func advance(id: String, amount: int, quiet: bool = false) -> void:
	if not GOALS.has(id): return
	var before: int = values[id]
	values[id] = mini(int(GOALS[id].target), before + maxi(0, amount))
	if values[id] == before: return
	refresh_sequence(quiet)
	changed.emit()

func collected(item: String, amount: int) -> void:
	if item == "madeira": advance("wood", amount)
	if item == "pedra": advance("stone", amount)

func crafted(id: String, quiet: bool = false) -> void:
	if id in STONE_TOOLS and not crafted_tools[id]:
		crafted_tools[id] = true
		advance("tools", 1, quiet)
	if id == "fogueira": advance("fire", 1, quiet)
	var level := mini(3, ItemCatalog.bag_level(id))
	if level > values.bag: advance("bag", level - int(values.bag), quiet)

func structure_placed(kind: String, quiet: bool = false) -> void:
	if kind == "fogueira": advance("fire", 1, quiet)

func reconcile(world: Node2D) -> void:
	# Craft-only items and placed campfires are evidence; raw material possession
	# and old generic tool counts never fabricate collection history.
	for inventory in world.find_children("*", "Node", true, false):
		if not inventory is ResourceInventory: continue
		for slot in inventory.slots:
			if not slot.is_empty(): crafted(slot.item, true)
		if not inventory.backpack.is_empty(): crafted(inventory.backpack.item, true)
	for node in world.get_node("WorldObjects").get_children():
		if node is PlacedStructure and not node.is_queued_for_deletion(): structure_placed(node.kind, true)
	refresh_sequence(true)
	changed.emit()

func visit(_world: Node2D, _quiet: bool = false) -> void:
	pass

func tools_description() -> String:
	var parts: Array[String] = []
	for id in STONE_TOOLS:
		parts.append(("✓ " if crafted_tools[id] else "○ ") + ItemCatalog.title(id))
	return " · ".join(parts)

func capture() -> Dictionary:
	return {"sequence_version": 1, "values": values.duplicate(), "crafted_tools": crafted_tools.duplicate(), "presented": presented.duplicate(), "tracked": tracked, "enabled": enabled, "collapsed": false}

func restore(data: Dictionary) -> bool:
	if not data.get("values", {}) is Dictionary: return false
	var next_values := values.duplicate()
	for id in ORDER:
		var value: Variant = data.get("values", {}).get(id, 0) if data.get("sequence_version", 0) == 1 or id == "wood" else 0
		if not (value is int or value is float) or not is_finite(float(value)) or value < 0 or value > GOALS[id].target: return false
		next_values[id] = int(value)
	if not data.get("crafted_tools", {}) is Dictionary or not data.get("presented", []) is Array: return false
	var next_tools := crafted_tools.duplicate()
	for id in STONE_TOOLS:
		var value: Variant = data.get("crafted_tools", {}).get(id, false)
		if not value is bool: return false
		next_tools[id] = value
	var tool_count := 0
	for value in next_tools.values():
		if value: tool_count += 1
	if int(next_values.tools) != tool_count: return false
	values = next_values
	crafted_tools = next_tools
	presented.clear()
	for id in data.get("presented", []):
		if id not in ORDER: return false
		if id not in presented: presented.append(id)
	enabled = bool(data.get("enabled", true))
	collapsed = false
	refresh_sequence(true)
	changed.emit()
	return true
