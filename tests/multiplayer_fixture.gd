# Test-only bridge, excluded from the regular pilot export.
extends Node
var pilot: Node2D
var session: Node
var callback: JavaScriptObject
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
		"disconnect": pilot.socket.close(1000, "test_disconnect")
		"offline": pilot.disconnected("server_unavailable"); pilot.retry_in = 999
		"retry": pilot.connect_room()
		"touch": MobileInput.set_enabled(bool(data.enabled))
		"chat": GlobalChat.opened = bool(data.opened)
		"full": pilot.disconnected("room_full", true)
func box(control: Control) -> Array:
	var rect := control.get_global_rect()
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
func _process(_delta: float) -> void:
	if is_instance_valid(session) and is_instance_valid(session.menu) and not is_instance_valid(pilot):
		JavaScriptBridge.eval("window.tcMpState=" + JSON.stringify({"ready":true,"menu":true,"busy":session.menu.worlds_busy,"transitioning":session.transitioning,"status":session.menu.status.text}))
		return
	if not is_instance_valid(pilot): return
	var buttons := {}
	for control in pilot.find_children("*", "Button", true, false):
		if control.is_visible_in_tree(): buttons[control.text] = box(control)
	var players := []
	for id in pilot.actors:
		var body: CharacterBody2D = pilot.actors[id].body
		players.append({"id":id,"x":body.position.x,"y":body.position.y,"nickname":body.identity_label})
	var value := {"ready":true,"online":pilot.online,"fatal":pilot.fatal,"self":pilot.self_id,"room":pilot.room_id,"inventory":pilot.inventory,"players":players,"snapshot":pilot.snapshot,"status":pilot.status.text,"notice":pilot.notice.text,"prompt":pilot.prompt.text,"panel":box(pilot.panel),"buttons":buttons,"touch":MobileInput.enabled,"move":[pilot.touch_vector.x,pilot.touch_vector.y],"stick":[pilot.overlay.center.x,pilot.overlay.center.y,pilot.overlay.radius],"viewport":[get_viewport().get_visible_rect().size.x,get_viewport().get_visible_rect().size.y]}
	JavaScriptBridge.eval("window.tcMpState=" + JSON.stringify(value))
