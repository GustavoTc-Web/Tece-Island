# Uma chamada real de credenciais inválidas, sem cadastro nem envio de e-mails.
extends SceneTree
var authenticated_count := 0
var message := ""
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var auth := root.get_node("FirebaseAuth")
	if not auth.configured():
		print("LIVE FIREBASE: configuração ausente")
		quit(1)
		return
	auth.authenticated.connect(func(): authenticated_count += 1)
	auth.message_changed.connect(func(text): message = text)
	await auth.login("validation-probe@example.invalid", "invalid-credential-probe")
	var rejected: bool = authenticated_count == 0 and not auth.has_session() and message == "E-mail ou senha inválidos."
	print("LIVE FIREBASE: ", "PASS" if rejected else "FAIL", " — credenciais inválidas rejeitadas pelo backend real")
	if not rejected: print("Diagnóstico: ", message)
	quit(0 if rejected else 1)
