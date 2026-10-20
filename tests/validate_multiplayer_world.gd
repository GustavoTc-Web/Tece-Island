extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, caption: String) -> void:
	checks += 1
	if not value: failures += 1
	print("PASS: " if value else "FAIL: ", caption)
func run() -> void:
	var pilot: Node2D = load("res://scenes/network/multiplayer_pilot.tscn").instantiate()
	root.add_child(pilot)
	await process_frame
	var data: Dictionary = pilot.world_view.data
	check(data.regions.size() == WorldTerrain.regions().size(), "Same eighteen solo regions")
	check(data.bounds == [-3072.0, -2560.0, 9984.0, 5632.0], "Same full world bounds")
	check(pilot.nodes.size() == 274, "Existing resource scenes populated across full map")
	check(pilot.world_view.wells.size() == 18, "One shared-world well in every region")
	check(data.buildings.size() == 39, "Existing houses and ruined buildings retained as scenery")
	check(pilot.camera.limit_left == -3072 and pilot.camera.limit_top == -2560 and pilot.camera.limit_right == 6912 and pilot.camera.limit_bottom == 3072, "Camera follows expanded world bounds")
	check(pilot.hud.network_mode and pilot.hud.inventory == pilot.projected_inventory, "Existing HUD uses server inventory projection")
	check(pilot.hud.quick_buttons.size() == 5 and pilot.hud.slot_buttons.size() == 7, "Same five quick slots and seven inventory slots")
	check(pilot.world_view.campaign == null and pilot.get_node_or_null("DayNight") == null, "Seven-day campaign and solo clock absent from multiplayer")
	check(pilot.hud.get_node_or_null("CampaignTaskPanel") == null, "No solo objective gates imported")
	var requests := []
	pilot.hud.network_action_requested.connect(func(action, argument): requests.append({"action": action, "argument": argument}))
	pilot.projected_inventory.add_resource("cantil", 1)
	var before: Dictionary = pilot.projected_inventory.network_state()
	pilot.hud.open_well(pilot.world_view.wells["well:forest"])
	pilot.hud._well_action("Encher cantil")
	check(requests.size() == 1 and requests[0].action == "well" and requests[0].argument == {"well":"well:forest", "action":"fill"}, "Existing well panel emits a server request with stable well ID")
	check(pilot.projected_inventory.network_state() == before, "Well UI cannot fill local canteen")
	pilot.hud._well_action("Beber")
	check(requests.size() == 2 and requests[1].argument.action == "drink", "Drink is also a server request")
	pilot.hud.menu_view.open("data")
	check(pilot.hud.menu_view.text.text.contains("memória") and not pilot.hud.menu_view.retry_button.visible, "Menu describes server memory without offering solo save actions")
	pilot.hud.menu_view.open("help")
	check(pilot.hud.menu_view.text.text.contains("poços") or pilot.hud.menu_view.text.text.contains("Poços"), "Multiplayer help documents existing world interactions")
	for well in pilot.world_view.wells.values():
		check(well.collision_layer == 0 and well.get_meta("network_id", "") != "", "Well is a non-authoritative visual: " + str(well.get_meta("network_id", "")))
	pilot.queue_free()
	await process_frame
	print("MULTIPLAYER WORLD: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
