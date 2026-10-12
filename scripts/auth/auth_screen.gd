extends Control

var email: LineEdit
var password: LineEdit
var confirmation: LineEdit
var password_label: Label
var confirmation_label: Label
var show_password: CheckBox
var primary: Button
var mode_button: Button
var recovery_button: Button
var resend_button: Button
var confirmed_button: Button
var status: Label
var mode := "login"
var rows: VBoxContainer
var center: CenterContainer
var busy := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)
	center = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 550
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.12, 0.09, 0.95)
	style.set_content_margin_all(20)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	panel.add_child(rows)
	var title := Label.new()
	title.text = "TC Island"
	title.add_theme_font_size_override("font_size", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Floresta · exploração · sobrevivência"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	rows.add_child(subtitle)
	_label("E-mail")
	email = _field("seu@email.com", false)
	password_label = _label("Senha")
	password = _field("Sua senha", true)
	confirmation_label = _label("Confirmar senha")
	confirmation = _field("Repita a senha", true)
	show_password = CheckBox.new()
	show_password.text = "Mostrar senha"
	show_password.custom_minimum_size.y = 48
	show_password.toggled.connect(func(value):
		password.secret = not value
		confirmation.secret = not value)
	rows.add_child(show_password)
	primary = _button("Entrar", submit)
	mode_button = _button("Criar conta", func(): set_mode("register" if mode == "login" else "login"))
	recovery_button = _button("Esqueci minha senha", func(): set_mode("recover"))
	resend_button = _button("Reenviar confirmação", FirebaseAuth.resend_verification)
	confirmed_button = _button("Já confirmei", FirebaseAuth.check_verification)
	resend_button.hide()
	confirmed_button.hide()
	status = _label("")
	status.custom_minimum_size = Vector2(510, 70)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_color_override("font_color", Color("f2d786"))
	FirebaseAuth.message_changed.connect(show_message)
	FirebaseAuth.busy_changed.connect(set_busy)
	FirebaseAuth.verification_required.connect(func():
		resend_button.show()
		confirmed_button.show())
	get_viewport().size_changed.connect(resize)
	set_mode("login")
	set_busy(FirebaseAuth.busy)
	if not FirebaseAuth.configured(): show_message(str(FirebaseAuth.config.error))
	resize()
	email.grab_focus()

func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	rows.add_child(label)
	return label

func _field(placeholder: String, secret: bool) -> LineEdit:
	var field := LineEdit.new()
	field.placeholder_text = placeholder
	field.secret = secret
	field.custom_minimum_size = Vector2(510, 54)
	field.add_theme_font_size_override("font_size", 22)
	field.text_submitted.connect(func(_value): submit())
	rows.add_child(field)
	return field

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 56
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(action)
	rows.add_child(button)
	return button

func resize() -> void:
	center.custom_minimum_size = get_viewport_rect().size
	queue_redraw()

func set_mode(value: String) -> void:
	if busy: return
	mode = value
	password.text = ""
	confirmation.text = ""
	show_password.button_pressed = false
	password.visible = value != "recover"
	password_label.visible = password.visible
	confirmation.visible = value == "register"
	confirmation_label.visible = confirmation.visible
	show_password.visible = password.visible
	primary.text = {"login": "Entrar", "register": "Cadastrar", "recover": "Enviar recuperação"}[value]
	mode_button.text = "Criar conta" if value == "login" else "Voltar para entrar"
	recovery_button.visible = value != "recover"
	show_message("Explore. Construa. Sobreviva." if FirebaseAuth.configured() else str(FirebaseAuth.config.get("error", "")))

func set_busy(value: bool) -> void:
	busy = value
	primary.text = "Aguarde…" if value else {"login": "Entrar", "register": "Cadastrar", "recover": "Enviar recuperação"}[mode]
	for button in [primary, mode_button, recovery_button, resend_button, confirmed_button]:
		button.disabled = value or (button != mode_button and button != recovery_button and not FirebaseAuth.configured())
	email.editable = not value
	password.editable = not value
	confirmation.editable = not value
	show_password.disabled = value

func show_message(text: String) -> void:
	if is_instance_valid(status): status.text = text

func submit() -> void:
	if busy: return
	var address := email.text.strip_edges()
	if not address.contains("@") or address.begins_with("@") or address.ends_with("@"):
		show_message("Informe um e-mail válido.")
		return
	if mode != "recover" and password.text.is_empty():
		show_message("Informe sua senha.")
		return
	if mode == "register" and password.text.length() < 6:
		show_message("Use uma senha com pelo menos 6 caracteres.")
		return
	if mode == "register" and password.text != confirmation.text:
		show_message("As senhas precisam ser iguais.")
		return
	var value := password.text
	password.text = ""
	confirmation.text = ""
	match mode:
		"login": FirebaseAuth.login(address, value)
		"register": FirebaseAuth.register(address, value)
		"recover": FirebaseAuth.recover_password(address)
	value = ""

func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color("263c35"))
	draw_line(Vector2(viewport_size.x * 0.1, viewport_size.y), Vector2(viewport_size.x * 0.85, 0), Color("536448"), 110)
	var random := RandomNumberGenerator.new()
	random.seed = 71
	for i in range(35):
		var point := Vector2(random.randf_range(0, viewport_size.x), random.randf_range(0, viewport_size.y))
		draw_line(point, point + Vector2(0, -40), Color("674e35"), 14)
		draw_circle(point + Vector2(0, -55), 38, Color("345d3c"))
		draw_circle(point + Vector2(-15, -67), 24, Color("456e46"))
