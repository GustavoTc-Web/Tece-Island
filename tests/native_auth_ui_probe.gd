extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	print("PASS: " if value else "FAIL: ", label)
	if not value: failures += 1
func click(control: Control) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = control.get_global_rect().get_center()
		event.pressed = pressed
		root.push_input(event, true)
func run() -> void:
	root.size = Vector2i(960, 540)
	var screen := load("res://scenes/auth.tscn").instantiate() as Control
	root.add_child(screen)
	for i in range(5): await process_frame
	check(not screen.primary.disabled, "Configuração real habilita formulário de teste")
	click(screen.email)
	for character in "invalid":
		var event := InputEventKey.new()
		event.unicode = character.unicode_at(0)
		event.keycode = event.unicode
		event.pressed = true
		root.push_input(event, true)
	check(screen.email.text == "invalid", "Teclado recebe foco no campo nativo")
	click(screen.primary)
	check(screen.status.text.contains("e-mail válido"), "Clique nativo valida formulário antes da rede")
	click(screen.show_password)
	check(not screen.password.secret, "Checkbox nativo mostra senha")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.tools/screenshots/auth-native.png")
	check(not root.get_node("FirebaseAuth").has_session(), "Formulário não simula sessão autenticada")
	print("AUTH NATIVE: ", failures, " falhas")
	quit(1 if failures else 0)
