class_name JournalView
extends Control
var hud: CanvasLayer
var journal: IslandJournal
var pages: VBoxContainer
var text: Label
var selected := ""
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
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(580, 370)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rows.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
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
	journal.changed.connect(refresh)
	refresh()
func refresh() -> void:
	for child in pages.get_children():
		pages.remove_child(child)
		child.queue_free()
	for i in range(journal.discovered.size()):
		var id := journal.discovered[i]
		var button := Button.new()
		button.text = "%dª descoberta · %s%s" % [i + 1, IslandJournal.RECORDS[id].title, " · Nova" if journal.unread.has(id) else ""]
		button.custom_minimum_size.y = 56
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(func(): selected = id; journal.read_page(id))
		pages.add_child(button)
	text.text = "Nenhum registro descoberto. Procure uma casa abandonada a sudoeste do início, na Floresta. A história é opcional." if selected.is_empty() else IslandJournal.RECORDS[selected].title + "\n\n" + IslandJournal.RECORDS[selected].text
