extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, caption: String) -> void:
	checks += 1
	if not value: failures += 1
	print("PASS: " if value else "FAIL: ", caption)
func run() -> void:
	var pilot: Node2D = load("res://scenes/network/multiplayer_pilot.tscn").instantiate()
	root.add_child(pilot)
	await process_frame
	pilot.self_id = "player-1"
	var slots := ResourceInventory.new()
	root.add_child(slots)
	var state := {"time":1000,"inventory":{},"slots":slots.network_state(),"health":83,"max_health":100,"hunger":72,"thirst":45,"tool":"maos","resources":[],"drops":[{"id":"drop-1","kind":"madeira","quantity":5,"x":1152,"y":768}],"players":[{"id":"player-1","nickname":"Teste","x":1152,"y":768,"dx":0,"dy":0,"online":true,"tool":"maos"}]}
	pilot.apply_state(state, true)
	check(pilot.hud.get_node("Controls/Rows/Health").value == 83, "Health reflects server value, without a client constant")
	check(pilot.hud.needs_bars.Fome.value == 72 and pilot.hud.needs_bars.Sede.value == 45, "Hunger and water reflect independent server values")
	check(pilot.hud.get_node("Controls/Rows/Health").visible and pilot.hud.needs_bars.Fome.visible and pilot.hud.needs_bars.Sede.visible, "All three solo-style status bars visible")
	check(pilot.drops.size() == 1 and pilot.drops["drop-1"] is ResourceDrop and pilot.drops["drop-1"].quantity == 5, "Ground stack reuses the solo item visual and quantity")
	check(pilot.projected_inventory.count_item("madeira") == 0, "Rendering a drop does not credit inventory")
	pilot.update_target()
	check(pilot.drop_target == "drop-1" and pilot.prompt.text.contains("Pegar"), "Nearby drop exposes explicit pickup guidance")
	pilot.apply_state(state, true)
	check(pilot.drops.size() == 1, "Reopening state does not duplicate ground visuals")
	state.drops[0].quantity = 4
	pilot.apply_state(state)
	check(pilot.drops["drop-1"].quantity == 4, "Partial pickup updates the exact quantity still on the ground")
	var unchanged: Dictionary = state.duplicate(true)
	unchanged.erase("drops")
	unchanged.erase("resources")
	pilot.apply_state(unchanged)
	check(pilot.drops["drop-1"].quantity == 4, "Compact snapshots preserve unchanged world state")
	state.drops = []
	pilot.apply_state(state)
	check(pilot.drops.is_empty(), "Authoritative pickup removes remaining client visual")
	var scenery: Node2D = pilot.world_view.scenery
	for region in WorldTerrain.regions():
		var area := Rect2(region.rect.get_center() - Vector2(576, 324), Vector2(1152, 648))
		scenery.show_area(area)
		var count := 0
		for tile in scenery.chunks.values():
			if tile.visible: count += 1
		check(count > 0 and count <= 12, "Spatial scenery remains available in " + str(region.id))
	pilot.queue_free()
	slots.queue_free()
	await process_frame
	print("MULTIPLAYER DROPS/NEEDS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
