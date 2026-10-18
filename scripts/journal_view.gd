class_name JournalView
extends Control
var hud: CanvasLayer
var journal: IslandJournal
var pages: VBoxContainer
var text: Label
var selected := ""
var objectives: IslandObjectives
var goals_mode := false
var campaign: SoloCampaign
var campaign_text: Label
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.06, 0.04, 0.92)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-300, -240)
	panel.custom_minimum_size = Vector2(600, 480)
	add_child(panel)
	var rows := VBoxContainer.new()
	panel.add_child(rows)
	var title := Label.new()
	title.text = "Diário · O Último Sinal"
	title.add_theme_font_size_override("font_size", 24)
	rows.add_child(title)
	var tabs := HBoxContainer.new()
	rows.add_child(tabs)
	for mode in [false, true]:
		var tab := Button.new()
		tab.text = "Objetivos" if mode else "Registros"
		tab.custom_minimum_size = Vector2(280, 52)
		tab.pressed.connect(func(): goals_mode = mode; refresh())
		tabs.add_child(tab)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(580, 300)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rows.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	campaign_text = Label.new()
	campaign_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	campaign_text.custom_minimum_size.x = 550
	campaign_text.add_theme_font_size_override("font_size", 20)
	content.add_child(campaign_text)
	pages = VBoxContainer.new()
	content.add_child(pages)
	text = Label.new()
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 550
	text.add_theme_font_size_override("font_size", 22)
	content.add_child(text)
	var close := Button.new()
	close.text = "Fechar"
	close.custom_minimum_size.y = 56
	close.pressed.connect(func(): hud.set_panel(""))
	rows.add_child(close)
	if MobileInput.enabled: hud.touch_sizes(self)
	journal.changed.connect(refresh)
	refresh()
func refresh() -> void:
	if campaign_text != null:
		campaign_text.text = campaign.journal_text() if campaign != null else ""
	for child in pages.get_children():
		pages.remove_child(child)
		child.queue_free()
	if campaign != null:
		for id in SoloCampaign.LOCATIONS:
			if not campaign.blocked_by_base(id) or not campaign.points[id].can_interact(): continue
			var recover := Button.new()
			recover.text = "Acessar sinalizador pela base" if id == "beacon" else ("Acessar mapa pela base" if id == "map" else ("Reaver pistas pela base" if id == "clue" else "Acessar " + CampaignEncounters.NAMES[id]))
			recover.custom_minimum_size.y = 56
			recover.pressed.connect(func():
				if not campaign.blocked_by_base(id): return
				hud.set_panel("")
				hud.show_message(campaign.interact(id)))
			pages.add_child(recover)
		if campaign.encounter == "won":
			var summary := Button.new()
			summary.text = "Ver resumo da jornada"
			summary.custom_minimum_size.y = 56
			summary.pressed.connect(hud.show_victory)
			pages.add_child(summary)
	if goals_mode and objectives != null:
		var toggle := CheckButton.new()
		toggle.text = "Mostrar objetivo na HUD"
		toggle.custom_minimum_size.y = 56
		toggle.button_pressed = objectives.enabled
		toggle.toggled.connect(func(value): objectives.enabled = value; objectives.changed.emit())
		pages.add_child(toggle)
		for id in IslandObjectives.ORDER:
			var goal: Dictionary = IslandObjectives.GOALS[id]
			var button := Button.new()
			var done: bool = id in objectives.presented
			button.text = "%s · %d/%d · %s" % [goal.title, objectives.values[id], goal.target, "Concluído" if done else ("Ativo" if objectives.tracked == id else "Próximo")]
			if id == "tools": button.text += "\n" + objectives.tools_description()
			button.add_theme_font_size_override("font_size", 18)
			button.custom_minimum_size.y = 64
			button.disabled = true
			button.add_theme_color_override("font_disabled_color", Color("e4dec5"))
			pages.add_child(button)
		text.text = "Objetivos iniciais concluídos" if objectives.tracked.is_empty() else "Ações antecipadas ficam registradas. A próxima etapa é liberada automaticamente."
		return
	for i in range(journal.discovered.size()):
		var id := journal.discovered[i]
		var button := Button.new()
		button.text = "%dª descoberta · %s%s" % [i + 1, IslandJournal.RECORDS[id].title, " · Nova" if journal.unread.has(id) else ""]
		button.custom_minimum_size.y = 56
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(func(): selected = id; journal.read_page(id))
		pages.add_child(button)
	text.text = "Nenhum registro descoberto. Procure uma casa abandonada a sudoeste do início, na Floresta. A história é opcional." if selected.is_empty() else IslandJournal.RECORDS[selected].title + "\n\n" + IslandJournal.RECORDS[selected].text
