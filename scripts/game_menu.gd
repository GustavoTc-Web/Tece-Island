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
	retry_button.text = "Salvar e tentar sincronizar"
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
	retry_button.visible = value == "data" and hud.save_button != null
	rows.get_node("Back").visible = value != "menu"
	if value == "help":
		var controls := "Use os joysticks para andar e mirar/atacar. Toque Interagir para coletar ou abrir o alvo próximo. Toque nos cinco slots para selecionar; Inventário permite usar, equipar e jogar itens." if MobileInput.enabled else "WASD/setas: andar. Mouse/F: atacar. E: coletar/interagir. 1–5/scroll: selecionar. I: inventário; C: fabricação; J: diário; R: recarregar."
		text.text = controls + "\n\nFabricação e Base ficam no inventário. Para construir, selecione cama, fogueira ou peça e use Colocar selecionado; escolha terreno próximo e livre. " + ("Toque no mapa para ajustar e use Confirmar/Cancelar." if MobileInput.enabled else "Clique confirma, Esc cancela, R gira peças.") + "\n\nComida e cantil: Usar no inventário ou botão contextual. Poços permitem beber e encher o cantil. Cozinhe perto de uma fogueira.\n\nO solo salva automaticamente neste aparelho. Confira Dados e salvamento se houver uma falha. Para relatar um problema, copie as informações abaixo e envie manualmente com sua descrição; não inclua senha."
		text.text += "\n\nCampanha solo: acompanhe as tarefas no HUD e no Diário. Mapa na torre da Serra a partir da noite 3; templos nas noites 4 e 5 ou posteriores; ataque final na noite 6 ou posterior. Atrasos não encerram a campanha. Após o resgate, você pode continuar explorando.\n\nBeta solo · multiplayer indisponível, sem data anunciada. Chat e sincronização entre aparelhos continuam restritos às contas do teste fechado. As demais contas jogam com salvamento local.\n\nCréditos: feito com Godot Engine. Fontes Bree Serif e Atkinson Hyperlegible, sob SIL Open Font License 1.1; licenças incluídas no pacote. Arte e efeitos do jogo são desenhados/gerados pelo projeto."
	elif value == "data":
		refresh_save_details()
	layout()

func save_details() -> String:
	var world := hud.get_parent()
	var account: AccountProgress = world.get("account_store")
	if account == null: return "Abra um mundo solo para consultar seu salvamento. Multiplayer indisponível nesta beta."
	var sync := get_tree().root.get_node("WorldSync")
	if not sync.enabled(account.uid): return "Mundo: " + account.world_id + "\nSalvo somente neste navegador e aparelho, separado por conta. Chat e sincronização entre aparelhos estão restritos às contas do teste fechado. Exporte uma cópia antes de limpar os dados do site."
	var detail := "Mundo: " + account.world_id + "\nÚltima revisão confirmada: " + str(account.sync_state.get("revision", 0))
	if world.progress_store != null:
		var unchanged: bool = CloudCodec.hash_state(world.progress_store.capture()) == account.sync_state.get("hash", "")
		detail += "\nProgresso local: " + ("igual à última versão sincronizada." if unchanged else "alterações ainda não sincronizadas.")
	var notice := str(sync.states.get(sync.key(account), {}).get("detail", ""))
	if notice != "": detail += "\n" + notice
	var failure: Dictionary = sync.last_errors.get(sync.key(account), {})
	if not failure.is_empty(): detail += "\n" + str(failure.error) + "\nHTTP: " + str(failure.status) + " " + str(failure.code)
	return detail

func refresh_save_details() -> void:
	if area != "data": return
	var account: AccountProgress = hud.get_parent().get("account_store")
	var cloud := account != null and WorldSync.enabled(account.uid)
	var instructions := "O progresso é salvo automaticamente neste aparelho. Para esta conta, não há cópia automática entre aparelhos."
	if cloud: instructions = "O progresso é salvo neste aparelho. Aguarde Sincronizado antes de trocar de aparelho. Tentativas automáticas: pelo menos 2 minutos; tentativa manual: pelo menos 10 segundos."
	retry_button.text = "Salvar e tentar sincronizar" if cloud else "Salvar neste aparelho"
	text.text = instructions + "\n\n" + (hud.save_button.text if hud.save_button != null else "Abra um mundo para salvar.") + "\n\n" + save_details()

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
	var stamp := {"version":"0.9.1-beta-rc.2", "commit":"desenvolvimento"}
	if FileAccess.file_exists("res://config/build-public.json"):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://config/build-public.json"))
		if data is Dictionary: stamp = data
	var screen := DisplayServer.window_get_size()
	if OS.has_feature("web"):
		screen = Vector2i(int(JavaScriptBridge.eval("innerWidth")), int(JavaScriptBridge.eval("innerHeight")))
	var info := "TC Island %s\nCommit: %s\nPlataforma: %s\nResolução: %d×%d\nOrientação: %s" % [str(stamp.get("version", "0.9.1-beta-rc.2")), str(stamp.get("commit", "desenvolvimento")), "Web" if OS.has_feature("web") else OS.get_name(), screen.x, screen.y, "retrato" if screen.y > screen.x else "paisagem"]
	if OS.has_feature("web"): info += "\nOrigem: " + str(JavaScriptBridge.eval("location.origin"))
	var world := hud.get_parent()
	if world.get("account_store") != null and world.get("progress_store") != null:
		info += "\nHash local: " + CloudCodec.hash_state(world.progress_store.capture()) + "\nHash confirmado: " + str(world.account_store.sync_state.get("hash", ""))
	return info + "\n" + (hud.save_button.text if hud.save_button != null else "") + "\n" + save_details()
