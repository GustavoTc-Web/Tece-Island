extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1
	print("PASS: " if value else "FAIL: ", label)
func step() -> void:
	for i in range(3): await process_frame
func run() -> void:
	root.size = Vector2i(960, 540)
	var auth := root.get_node("FirebaseAuth")
	check(auth.enabled() and auth.configured(), "Projeto principal carrega Firebase obrigatório sem cópia especial")
	check(auth.config.projectId == "tece-island-285cd" and auth.config.continueUrl == "https://gustavotc-web.github.io/Tece-Island/", "Projeto e retorno corretos")
	check(not auth.has_session() and not auth.can_play(), "Sem sessão: partida bloqueada")
	var session: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(session)
	await step()
	check(session.auth_screen != null and session.menu == null and session.game == null, "Inicialização principal abre autenticação")
	check(not session.auth_screen.primary.disabled, "Formulário permite tentar login real")
	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.tools/screenshots"))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.tools/screenshots/auth-main-native.png")
	session.start_solo()
	check(session.game == null and session.auth_screen != null, "Solo bloqueado sem autenticação")
	session.host_game()
	session.join_game()
	check(session.game == null and session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "Rede bloqueada sem autenticação")
	auth._id_token = "expired-local-fixture"
	auth._refresh_token = "expired-local-fixture"
	auth._expires_at = Time.get_unix_time_from_system() - 1
	auth._verified = false
	auth._process(0)
	check(auth._id_token.is_empty() and auth._refresh_token.is_empty() and not auth.can_play(), "Expiração apaga memória sem autorizar usuário")
	auth.logout()
	await step()
	check(session.auth_screen != null and session.game == null and not auth.has_session(), "Logout mantém entrada e bloqueia partida")
	check(not session.auth_screen.primary.disabled, "Após logout é possível tentar novamente")
	session.queue_free()
	await step()
	print("AUTH RELEASE: ", checks, " verificações, ", failures, " falhas; nenhuma sessão positiva simulada")
	quit(1 if failures else 0)
