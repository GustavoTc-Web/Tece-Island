# Test-only bridge, excluded from the regular pilot export.
extends Node
var pilot: Node2D
var session: Node
var callback: JavaScriptObject
var sample_clock := 0.0
var reference: Node2D
class ReferenceGround extends Node2D:
	func _draw() -> void: WorldScenery.draw_ground(self)
func _ready() -> void:
	callback = JavaScriptBridge.create_callback(invoke)
	JavaScriptBridge.get_interface("window").tcMpFixture = callback
	JavaScriptBridge.eval("window.tcMpState = {ready:true};")
func invoke(args: Array) -> void:
	var data: Dictionary = JSON.parse_string(str(args[0]))
	match str(data.get("action", "")):
		"connect":
			FirebaseAuth._user_id = str(data.uid)
			FirebaseAuth._id_token = str(data.token)
			FirebaseAuth._verified = true
			FirebaseAuth._expires_at = Time.get_unix_time_from_system() + 3500
			if data.get("entry", false):
				session = load("res://scenes/main.tscn").instantiate()
				add_child(session)
				while not is_instance_valid(session.menu) or session.menu.worlds_busy or session.transitioning: await get_tree().process_frame
				for control in session.menu.find_children("*", "Button", true, false):
					if control.text == "Multiplayer — teste": control.pressed.emit(); break
				await get_tree().process_frame
				pilot = session.game
			else:
				pilot = load("res://scenes/network/multiplayer_pilot.tscn").instantiate()
				add_child(pilot)
				if data.has("endpoint"):
					pilot.endpoint = str(data.endpoint)
					pilot.connect_room()
		"disconnect": pilot.socket.close(1000, "test_disconnect")
		"offline": pilot.disconnected("server_unavailable"); pilot.retry_in = 999
		"retry": pilot.connect_room()
		"endpoint": pilot.endpoint = str(data.value); pilot.connect_room()
		"touch": MobileInput.set_enabled(bool(data.enabled))
		"chat": GlobalChat.opened = bool(data.opened)
		"full": pilot.disconnected("room_full", true)
		"render": pilot.world_view.visible = bool(data.visible)
		"reference":
			if not is_instance_valid(reference):
				reference = ReferenceGround.new()
				pilot.world_view.add_child(reference)
				pilot.world_view.move_child(reference, 0)
				reference.add_child(WorldTerrain.new())
				reference.add_child(load("res://scripts/biomes.gd").new())
				reference.add_child(CampaignTerrain.new())
			reference.visible = bool(data.enabled)
			pilot.world_view.scenery.visible = not bool(data.enabled)
func box(control: Control) -> Array:
	var rect := control.get_global_rect()
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
func _process(_delta: float) -> void:
	sample_clock += _delta
	if sample_clock < 0.1: return
	sample_clock = 0.0
	if is_instance_valid(session) and is_instance_valid(session.menu) and not is_instance_valid(pilot):
		JavaScriptBridge.eval("window.tcMpState=" + JSON.stringify({"ready":true,"menu":true,"busy":session.menu.worlds_busy,"transitioning":session.transitioning,"status":session.menu.status.text}))
		return
	if not is_instance_valid(pilot): return
	var buttons := {}
	for control in pilot.find_children("*", "Button", true, false):
		if control.is_visible_in_tree(): buttons[control.text] = box(control)
	for index in pilot.hud.quick_buttons.size():
		if pilot.hud.quick_buttons[index].is_visible_in_tree(): buttons["Slot " + str(index + 1)] = box(pilot.hud.quick_buttons[index])
	for index in pilot.hud.slot_buttons.size():
		if pilot.hud.slot_buttons[index].is_visible_in_tree(): buttons["Inventory slot " + str(index + 1)] = box(pilot.hud.slot_buttons[index])
	var players := []
	for id in pilot.actors:
		var body: CharacterBody2D = pilot.actors[id].body
		var screen := body.get_global_transform_with_canvas().origin
		var label_size := IslandTheme.BODY.get_string_size(body.identity_label, HORIZONTAL_ALIGNMENT_LEFT, -1, body.identity_label_size)
		var label_position: Vector2 = screen + Vector2(-27, -53 - body.identity_label_size) + body.identity_label_offset
		players.append({"id":id,"x":body.position.x,"y":body.position.y,"nickname":body.identity_label,"screen":[screen.x,screen.y],"name_box":[label_position.x,label_position.y,label_size.x,body.identity_label_size + 4]})
	var value := {"ready":true,"online":pilot.online,"fatal":pilot.fatal,"self":pilot.self_id,"room":pilot.room_id,"inventory":pilot.inventory,"players":players,"snapshot":pilot.snapshot,"status":pilot.status.text,"notice":pilot.notice.text,"prompt":pilot.prompt.text,"panel":box(pilot.panel),"buttons":buttons,"touch":MobileInput.enabled,"move":[pilot.touch_vector.x,pilot.touch_vector.y],"stick":[pilot.overlay.center.x,pilot.overlay.center.y,pilot.overlay.radius],"viewport":[get_viewport().get_visible_rect().size.x,get_viewport().get_visible_rect().size.y]}
	value["fingers"] = pilot.overlay.fingers.duplicate()
	value["gui"] = MobileInput.gui_touches.keys()
	value["focused"] = pilot.focused
	value["panel"] = box(pilot.hud.get_node("Controls")) if pilot.online else box(pilot.panel)
	value["selected"] = pilot.projected_inventory.selected_index
	value["slots"] = pilot.projected_inventory.network_state()
	value["thirst"] = pilot.snapshot.get("thirst", 100)
	value["active_panel"] = pilot.hud.current_panel
	value["overlay_visible"] = pilot.overlay.visible
	value["target"] = pilot.target
	value["well_target"] = pilot.well_target
	value["regions"] = pilot.world_view.data.regions.size()
	value["total_resources"] = pilot.nodes.size()
	value["wells"] = pilot.world_view.wells.size()
	value["phase"] = pilot.connection_phase
	value["failed_phase"] = pilot.failed_phase
	value["diagnostic"] = pilot.diagnostic.text
	value["diagnostic_box"] = box(pilot.diagnostic)
	value["drop_count"] = pilot.drops.size()
	value["needs"] = {"health": pilot.hud.get_node("Controls/Rows/Health").value, "hunger":pilot.hud.needs_bars.Fome.value,"water":pilot.hud.needs_bars.Sede.value,"visible":pilot.hud.get_node("Controls/Rows/Health").visible and pilot.hud.needs_bars.Fome.visible and pilot.hud.needs_bars.Sede.visible}
	value["swings"] = pilot.actors.values().map(func(actor): return actor.swing)
	value["fps"] = Engine.get_frames_per_second()
	value["process_ms"] = Performance.get_monitor(Performance.TIME_PROCESS) * 1000
	value["draw_calls"] = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	value["primitives"] = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	JavaScriptBridge.eval("window.tcMpState=" + JSON.stringify(value))
