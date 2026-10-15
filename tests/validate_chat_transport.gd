extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, name: String) -> void:
	checks += 1
	if not value: failures += 1
	print("PASS: " if value else "FAIL: ", name)
func url64(value: Dictionary) -> String:
	return Marshalls.utf8_to_base64(JSON.stringify(value)).replace("+", "-").replace("/", "_").replace("=", "")
func run() -> void:
	if OS.get_environment("FIRESTORE_EMULATOR_HOST") != "127.0.0.1:8085": quit(1); return
	var auth: Node = root.get_node("FirebaseAuth")
	var now := int(Time.get_unix_time_from_system())
	auth.config.projectId = "demo-tece-island"
	auth._user_id = "chat-a"
	auth._verified = true
	auth._expires_at = now + 3600
	auth._id_token = url64({"alg": "none", "typ": "JWT"}) + "." + url64({"sub": "chat-a", "user_id": "chat-a", "aud": "demo-tece-island", "iss": "https://securetoken.google.com/demo-tece-island", "iat": now, "exp": now + 3600, "auth_time": now, "email_verified": true, "firebase": {"sign_in_provider": "password"}}) + "."
	var client := ChatClient.new()
	client.api_base = "http://127.0.0.1:8085/v1/"
	root.add_child(client)
	var profile := await client.read_document("chat-a", "chatProfiles", "chat-a")
	check(profile.ok, "PC nativo lê perfil pela sessão autenticada no emulador")
	var nickname := str(profile.get("document", {}).get("nickname", "Ana"))
	if profile.get("missing", false): await client.set_nickname("chat-a", nickname)
	var sent := await client.send_message("chat-a", nickname, "Mensagem do Godot nativo")
	check(sent.ok, "PC nativo confirma batch atômico com horário do servidor")
	var recent := await client.recent("chat-a")
	check(recent.ok and recent.messages.size() > 0 and recent.messages[0].text == "Mensagem do Godot nativo", "PC nativo recebe e decodifica mensagens REST")
	var excess := await client.send_message("chat-a", nickname, "Excesso")
	check(not excess.ok and excess.get("status", 0) == 403, "PC nativo recebe rejeição do cooldown no backend")
	check(client.pending.is_empty(), "Requisições finalizadas não deixam conexões registradas")
	var chat: Node = root.get_node("GlobalChat")
	check(chat.valid_nickname("João 7") and not chat.valid_nickname("x@y.com"), "Apelido simples não aceita endereço de e-mail")
	auth._forget_tokens()
	client.queue_free()
	print("CHAT NATIVE: %d verificações, %d falhas" % [checks, failures])
	quit(1 if failures else 0)
