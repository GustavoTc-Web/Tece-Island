extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1
	print("PASS: " if value else "FAIL: ", label)
func run() -> void:
	root.size = Vector2i(960, 540)
	var auth := root.get_node("FirebaseAuth")
	var original: Dictionary = auth.config.duplicate(true)
	# Fixture de configuração ausente; nenhuma resposta de login é simulada.
	auth.config = {"enabled": false, "configured": false, "error": "Firebase ainda não configurado."}
	check(not auth.enabled() and not auth.configured() and not auth.has_session(), "Configuração ausente mantém login desativado, sem simular sessão")
	auth.login("test@example.invalid", "local-test-value")
	check(not auth.has_session() and not auth.busy, "Login sem configuração não autentica e não inicia requisição")
	var screen := load("res://scenes/auth.tscn").instantiate() as Control
	root.add_child(screen)
	for i in range(3): await process_frame
	check(screen.primary.disabled and screen.email.editable, "Tela informa configuração pendente e permite revisar formulário")
	screen.email.text = "inválido"
	screen.submit()
	check(screen.status.text.contains("e-mail válido"), "Formulário valida e-mail sem chamar serviço")
	screen.set_mode("register")
	screen.email.text = "test@example.invalid"
	screen.password.text = "123456"
	screen.confirmation.text = "abcdef"
	screen.submit()
	check(screen.status.text.contains("iguais") and not auth.has_session(), "Senha divergente bloqueia cadastro")
	screen.show_password.button_pressed = true
	check(not screen.password.secret and not screen.confirmation.secret, "Mostrar senha aplica aos dois campos")
	screen.show_password.button_pressed = false
	check(screen.password.secret and screen.confirmation.secret, "Ocultar senha aplica aos dois campos")
	screen.set_mode("recover")
	check(not screen.password.visible and screen.primary.text == "Enviar recuperação", "Recuperação exige apenas e-mail")
	auth.config.enabled = true
	var session: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(session)
	for i in range(3): await process_frame
	check(session.auth_screen != null and session.menu == null and session.game == null, "Login obrigatório sem sessão mantém interface de entrada")
	session.start_solo()
	check(session.game == null and session.auth_screen != null, "Chamadas diretas ao solo respeitam autenticação")
	session.host_game()
	check(session.game == null and session.auth_screen != null, "Anfitrião também respeita autenticação")
	check(auth._error_message("INVALID_LOGIN_CREDENTIALS") == "E-mail ou senha inválidos.", "Erro de credenciais usa mensagem compreensível")
	auth.logout()
	check(not auth.has_session() and auth._id_token.is_empty() and auth._refresh_token.is_empty(), "Logout limpa memória sem persistência")
	auth.config.enabled = false
	session.return_to_menu("Teste")
	check(session.menu != null, "Publicação sem Firebase continua com menu jogável")
	session.queue_free()
	screen.queue_free()
	auth.config = original
	for i in range(3): await process_frame
	print("AUTH LOCAL: ", checks, " verificações, ", failures, " falhas; validação local sem autenticação simulada")
	quit(1 if failures else 0)
