# Only included by export-chat-pilot.ps1 -Emulated, never in the real pilot.
extends Node
var session: Node
var callback: JavaScriptObject
var clock := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GlobalChat.client.api_base = "http://127.0.0.1:8085/v1/"
	session = load("res://scenes/main.tscn").instantiate()
	add_child(session)
	callback = JavaScriptBridge.create_callback(command)
	JavaScriptBridge.get_interface("window").tcChatFixture = callback

func url64(value: Dictionary) -> String:
	return Marshalls.utf8_to_base64(JSON.stringify(value)).replace("+", "-").replace("/", "_").replace("=", "")

func command(args: Array) -> void:
	var request: Dictionary = JSON.parse_string(str(args[0]))
	match str(request.action):
		"login":
			# Explicit unsigned emulator identity. Rejected by production Firebase.
			FirebaseAuth._forget_tokens()
			var now := int(Time.get_unix_time_from_system())
			FirebaseAuth._user_id = str(request.uid)
			FirebaseAuth._verified = true
			FirebaseAuth._expires_at = now + 3600
			FirebaseAuth._id_token = url64({"alg": "none", "typ": "JWT"}) + "." + url64({"sub": request.uid, "user_id": request.uid, "aud": "demo-tece-island", "iss": "https://securetoken.google.com/demo-tece-island", "iat": now, "exp": now + 3600, "auth_time": now, "email_verified": true, "firebase": {"sign_in_provider": "password"}}) + "."
			FirebaseAuth.authenticated.emit()
		"logout": FirebaseAuth.logout()
		"play":
			if session.library != null and is_instance_valid(session.menu) and session.menu.selected_world == "":
				var id: String = await session.library.create_world("Ilha do chat", get_tree())
				session.menu.selected_world = id
			session.start_solo()
		"lobby": session.return_to_menu("")
		"poll": GlobalChat.next_poll = 0
		"refresh": GlobalChat.next_full = 0; GlobalChat.next_poll = 0
		"force_send": GlobalChat.cooldown_until = 0; GlobalChat.send_text(str(request.text))
		"cancel_requests": GlobalChat.client.cancel()

func _process(delta: float) -> void:
	clock += delta
	if clock < 0.1: return
	clock = 0
	var snapshot := {"uid": GlobalChat.uid, "opened": GlobalChat.opened, "busy": GlobalChat.busy, "reading": GlobalChat.reading, "ready": GlobalChat.initialized, "sequence": GlobalChat.sequence, "requests": GlobalChat.client.pending.size(), "status": GlobalChat.status, "playing": is_instance_valid(session.game), "paused": get_tree().paused}
	if is_instance_valid(session.game):
		var player: CharacterBody2D = session.game.get_node("WorldObjects/Player")
		snapshot.position = [player.position.x, player.position.y]
		snapshot.panel = session.game.get_node("HUD").current_panel
		snapshot.attacking = player.get_node("Interaction").mouse_held or player.get_node("Interaction").key_held
	JavaScriptBridge.eval("window.tcChatSnapshot=" + JSON.stringify(snapshot))
