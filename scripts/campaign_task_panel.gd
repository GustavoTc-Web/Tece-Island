class_name CampaignTaskPanel
extends PanelContainer
var hud: CanvasLayer
var tasks: CampaignTasks
var title: Button
var toggle: Button
var rows_box: VBoxContainer
var row_labels: Array[Label] = []
var marks: Array[TaskMark] = []
var detail: Label
var diary: Button
var displayed_rows: Array[Dictionary] = []
var next_task := ""

class TaskMark extends Control:
	var done := false
	var active := false
	func _draw() -> void:
		var tint := Color("a8c8a1") if done else (Color("ffe1a0") if active else Color("a1b09e"))
		draw_rect(Rect2(2, 5, 13, 13), tint, false, 1.5)
		if done: draw_polyline(PackedVector2Array([Vector2(4,11),Vector2(8,15),Vector2(16,6)]),tint,2.5)
		elif active: draw_colored_polygon(PackedVector2Array([Vector2(5,8),Vector2(12,12),Vector2(5,16)]),tint)

func initialize(source_hud: CanvasLayer, source_tasks: CampaignTasks) -> void:
	hud = source_hud
	tasks = source_tasks
	add_theme_stylebox_override("panel", IslandTheme.panel(Color(0.06, 0.13, 0.11, 0.90)))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	title = Button.new()
	title.name = "TaskTitle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	title.pressed.connect(open_diary)
	header.add_child(title)
	toggle = Button.new()
	toggle.name = "TaskCollapse"
	toggle.pressed.connect(func():
		tasks.collapsed = not tasks.collapsed
		tasks.changed.emit())
	header.add_child(toggle)
	rows_box = VBoxContainer.new()
	column.add_child(rows_box)
	for i in range(3):
		var row := HBoxContainer.new()
		rows_box.add_child(row)
		var mark := TaskMark.new()
		mark.custom_minimum_size = Vector2(20, 22)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(mark)
		marks.append(mark)
		var label := Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		row_labels.append(label)
	detail = Label.new()
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.max_lines_visible = 2
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows_box.add_child(detail)
	diary = Button.new()
	diary.name = "TaskDiary"
	diary.text = "Etapas e pendências no Diário"
	diary.pressed.connect(open_diary)
	diary.hide()
	rows_box.add_child(diary)
	tasks.changed.connect(refresh)
	minimum_size_changed.connect(func(): call_deferred("reset_size"))
	refresh()

func open_diary() -> void:
	hud.journal_view.goals_mode = true
	hud.journal_view.refresh()
	hud.set_panel("journal")

func layout() -> void:
	var mobile: bool = MobileInput.enabled
	var unit: float = MobileInput.touch_minimum()
	var view: Vector2 = hud.get_viewport().get_visible_rect().size
	var scale_factor := maxf(1, 0.9 / MobileInput.css_scale()) if mobile else 1.0
	var left := 224 * scale_factor if view.x > view.y else 12.0
	position = Vector2(left, 8 if view.x > view.y else 190 * scale_factor)
	var width := minf(440 if mobile else 370, view.x - left - (180 if mobile else 150))
	if mobile:
		var minimap: Control = tasks.world.minimap
		width = minf(width, view.x + minimap.offset_left - left - 40)
	custom_minimum_size = Vector2(maxf(220, width), 0)
	size.x = custom_minimum_size.x
	var font_size := int(maxf(16, ceilf(11 / MobileInput.css_scale()))) if mobile else 16
	for button in [title, toggle, diary]:
		button.custom_minimum_size.y = unit
		button.add_theme_font_size_override("font_size", font_size)
	toggle.custom_minimum_size.x = unit
	for label in row_labels:
		label.add_theme_font_size_override("font_size", font_size)
		label.size.x = maxf(120, width - 52)
	detail.size.x = maxf(120, width - 28)
	detail.add_theme_font_size_override("font_size", maxi(14, font_size - 2))
	# Container minimum height shrinks again when its rows are collapsed.
	size.y = get_combined_minimum_size().y

func refresh() -> void:
	if tasks == null or not is_instance_valid(tasks.world): return
	visible = tasks.world.objectives.enabled and hud.current_panel == "" and not hud.showing_death
	var stage := tasks.automatic_stage()
	var entries := tasks.rows(stage)
	var done := entries.filter(func(row): return row.done).size()
	var heading: String = ["Dia 1 · Kit", "Dia 2 · Preparação", "Dia 3 · Expedição", "Dia 4 · Névoa", "Dia 5 · Extremos", "Dia 6 · Preparo", "Noite 6+ · Ataque", "Resgate"][stage]
	title.text = "%s · %d/%d ›" % [heading, done, entries.size()]
	title.tooltip_text = "Abra todas as etapas, inclusive pendências anteriores."
	toggle.text = "+" if tasks.collapsed else "−"
	toggle.tooltip_text = "Expandir objetivos" if tasks.collapsed else "Recolher objetivos"
	rows_box.visible = not tasks.collapsed
	var focus := -1
	for i in range(entries.size()):
		if not entries[i].done and entries[i].requirement.is_empty(): focus = i; break
	if focus == -1:
		for i in range(entries.size()):
			if not entries[i].done: focus = i; break
	next_task = entries[focus].id if focus >= 0 else ""
	var first := clampi(focus - 1 if focus >= 0 else entries.size() - 3, 0, maxi(0, entries.size() - 3))
	displayed_rows.clear()
	for i in range(3):
		var index := first + i
		row_labels[i].get_parent().visible = index < entries.size()
		if index >= entries.size(): continue
		var row: Dictionary = entries[index]
		displayed_rows.append(row)
		marks[i].done = row.done
		marks[i].active = index == focus
		marks[i].queue_redraw()
		row_labels[i].text = "%s · %d/%d%s" % [row.title, mini(row.value, row.target), row.target, " agora" if row.mode == "agora" else ""]
		row_labels[i].add_theme_color_override("font_color", Color("a8c8a1") if row.done else (Color("ffe1a0") if index == focus else Color("d8dfce")))
	var information: String = entries[focus].requirement if focus >= 0 else "Etapa atendida · você pode adiantar a próxima."
	if focus >= 0 and information.is_empty(): information = entries[focus].hint
	detail.text = information
	detail.add_theme_color_override("font_color", Color("c7c7ae"))
	layout()
