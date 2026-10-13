class_name GameMenu
extends Control
var hud: CanvasLayer
var rows: VBoxContainer
var title: Label
var copy_button: Button
var text: Label
var menu_actions: Array[Button] = []
var leave_action: Callable
var area := "menu"
var scroll: ScrollContainer
var retry_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.055, 0.04, 0.95)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	rows = VBoxContainer.new()
	rows.custom_minimum_size.x = 540
	rows.add_theme_constant_override("separation", 10)
	center.add_child(rows)
	title = Label.new()
	title.text = "TC Island · Menu"
	title.add_theme_font_size_override("font_size", 26)
	rows.add_child(title)
	for caption in ["Continuar", "Diário e objetivos", "Configurações", "Ajuda e suporte", "Dados e salvamento", "Voltar ao menu principal", "Sair da conta"]:
		var button := Button.new()
		button.text = caption
		button.pressed.connect(invoke.bind(caption))
		rows.add_child(button)
		menu_actions.append(button)
	text = Label.new()
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(text)
	copy_button = Button.new()
	copy_button.text = "Copiar informações para relatar problema"
	copy_button.pressed.connect(func(): DisplayServer.clipboard_set(diagnostic()); hud.show_message("Informações copiadas. Envie junto da descrição do problema."))
	rows.add_child(copy_button)
	retry_button = Button.new()
	retry_button.text = "Tentar salvar novamente"
	retry_button.pressed.connect(func(): if hud.save_button != null: hud.save_button.pressed.emit())
	rows.add_child(retry_button)
	var back := Button.new()
	back.name = "Back"
	back.text = "Voltar"
	back.pressed.connect(func(): open("menu"))
	rows.add_child(back)
	visible = false

func open(value: String = "menu") -> void:
	area = value
	scroll.scroll_vertical = 0
	title.text = {"menu":"TC Island · Menu", "help":"Ajuda e suporte", "data":"Dados e salvamento"}[value]
	for button in menu_actions:
		button.visible = value == "menu"
		button.disabled = button.text == "Diário e objetivos" and hud.journal_view == null or button.text == "Sair da conta" and not FirebaseAuth.enabled()
	text.visible = value != "menu"
	copy_button.visible = value == "help"
	retry_button.visible = value == "data" and hud.save_button != null and not hud.save_button.disabled
	rows.get_node("Back").visible = value != "menu"
	if value == "help":
		var controls := "Use os joysticks para andar e mirar/atacar. Toque Interagir para coletar ou abrir o alvo próximo. Toque nos cinco slots para selecionar; Inventário permite usar, equipar e jogar itens." if MobileInput.enabled else "WASD/setas: andar. Mouse/F: atacar. E: coletar/interagir. 1–5/scroll: selecionar. I: inventário; C: fabricação; J: diário; R: recarregar."
		text.text = controls + "\n\nFabricação e Base ficam no inventário. Para construir, selecione cama, fogueira ou peça e use Colocar selecionado; escolha terreno próximo e livre. " + ("Toque no mapa para ajustar e use Confirmar/Cancelar." if MobileInput.enabled else "Clique confirma, Esc cancela, R gira peças.") + "\n\nComida e cantil: Usar no inventário ou botão contextual. Poços permitem beber e encher o cantil. Cozinhe perto de uma fogueira.\n\nO solo salva automaticamente neste aparelho. Confira Dados e salvamento se houver uma falha. Para relatar um problema, copie as informações abaixo e envie manualmente com sua descrição; não inclua senha."
	elif value == "data":
		text.text = "O progresso solo é salvo localmente por conta neste aparelho/navegador. Outro aparelho não sincroniza. Limpar dados do navegador pode apagar o progresso local.\n\n" + (hud.save_button.text if hud.save_button != null else "A arena multiplayer não usa o save do mundo solo.")
	layout()

func invoke(caption: String) -> void:
	match caption:
		"Continuar": hud.set_panel("")
		"Diário e objetivos": hud.set_panel("journal")
		"Configurações": hud.open_settings()
		"Ajuda e suporte": open("help")
		"Dados e salvamento": open("data")
		"Voltar ao menu principal": if leave_action.is_valid(): leave_action.call()
		"Sair da conta": FirebaseAuth.logout()

func layout() -> void:
	var unit := MobileInput.touch_minimum()
	rows.add_theme_constant_override("separation", int(ceilf(8 / MobileInput.css_scale())) if MobileInput.enabled else 10)
	rows.custom_minimum_size.x = minf(640, get_viewport_rect().size.x - 48)
	var font := int(maxf(20, ceilf(15 / MobileInput.css_scale()))) if MobileInput.enabled else 20
	text.add_theme_font_size_override("font_size", font)
	title.add_theme_font_size_override("font_size", font + 4)
	for button in rows.get_children():
		if button is Button:
			button.custom_minimum_size.y = unit
			button.add_theme_font_size_override("font_size", font)
			button.clip_text = true

func diagnostic() -> String:
	var stamp := {"version":"0.8.1-atalhos-mobile", "commit":"desenvolvimento"}
	if FileAccess.file_exists("res://config/build-public.json"):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://config/build-public.json"))
		if data is Dictionary: stamp = data
	var screen := DisplayServer.window_get_size()
	if OS.has_feature("web"):
		screen = Vector2i(int(JavaScriptBridge.eval("innerWidth")), int(JavaScriptBridge.eval("innerHeight")))
	return "TC Island %s\nCommit: %s\nPlataforma: %s\nResolução: %d×%d\nOrientação: %s" % [str(stamp.get("version", "0.8.1-atalhos-mobile")), str(stamp.get("commit", "desenvolvimento")), "Web" if OS.has_feature("web") else OS.get_name(), screen.x, screen.y, "retrato" if screen.y > screen.x else "paisagem"]
