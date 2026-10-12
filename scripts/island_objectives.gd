class_name IslandObjectives
extends Node
signal changed
signal completed(title: String)
var values := {"wood": 0, "tool": 0, "base": 0, "meal": 0, "record": 0, "temple": 0}
var placed := {"cama": false, "fogueira": false}
var tracked := "wood"
var enabled := true
var collapsed := false
const GOALS := {
	"wood": {"title": "Coletar dez madeiras", "target": 10},
	"tool": {"title": "Fabricar uma ferramenta", "target": 1},
	"base": {"title": "Colocar cama e fogueira", "target": 2},
	"meal": {"title": "Cozinhar uma refeição", "target": 1},
	"record": {"title": "Encontrar o primeiro registro", "target": 1},
	"temple": {"title": "Explorar um templo das Ruínas", "target": 1}
}
func advance(id: String, amount: int, quiet: bool = false) -> void:
	var before: int = values[id]
	values[id] = mini(int(GOALS[id].target), before + maxi(0, amount))
	if values[id] == before: return
	if not quiet and values[id] == GOALS[id].target: completed.emit(GOALS[id].title)
	changed.emit()
func collected(item: String, amount: int) -> void:
	if item == "madeira": advance("wood", amount)
func crafted(id: String) -> void:
	if ResourceRules.RECIPES[id].category in ["machado", "picareta", "espada", "arco"]: advance("tool", 1)
	if ResourceRules.crafting_group(id) == "Fogueira": advance("meal", 1)
func structure_placed(kind: String, quiet: bool = false) -> void:
	if not placed.has(kind) or placed[kind]: return
	placed[kind] = true
	advance("base", 1, quiet)
func reconcile(world: Node2D) -> void:
	for node in world.get_node("WorldObjects").get_children():
		if node is PlacedStructure and not node.is_queued_for_deletion(): structure_placed(node.kind, true)
	if "arrival" in world.journal.discovered: advance("record", 1, true)
	visit(world, true)
func visit(world: Node2D, quiet: bool = false) -> void:
	if values.temple > 0: return
	for temple in world.ruins.temples:
		if Rect2(-340, -230, 680, 460).has_point(temple.to_local(world.get_node("WorldObjects/Player").global_position)):
			advance("temple", 1, quiet)
			return
func capture() -> Dictionary:
	return {"values": values.duplicate(), "placed": placed.duplicate(), "tracked": tracked, "enabled": enabled, "collapsed": collapsed}
func restore(data: Dictionary) -> bool:
	if not data.get("values", {}) is Dictionary or not data.get("placed", {}) is Dictionary: return false
	for id in values:
		var value = data.get("values", {}).get(id, 0)
		if not (value is int or value is float) or not is_finite(float(value)) or value < 0 or value > GOALS[id].target: return false
	for id in values: values[id] = int(data.get("values", {}).get(id, 0))
	for id in placed: placed[id] = bool(data.get("placed", {}).get(id, false))
	tracked = str(data.get("tracked", "wood"))
	if not GOALS.has(tracked): tracked = "wood"
	enabled = bool(data.get("enabled", true))
	collapsed = bool(data.get("collapsed", false))
	changed.emit()
	return true
