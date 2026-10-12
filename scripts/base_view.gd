class_name BaseView
extends Control
var hud: CanvasLayer
var system: Node2D
var selected: PlacedStructure
var list: VBoxContainer
var status: Label
var confirm: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.06, 0.04, 0.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-290, -230)
	panel.custom_minimum_size = Vector2(580, 460)
	add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	panel.add_child(rows)
	var title := Label.new()
	title.text = "Base · desmontar estruturas próximas"
	title.add_theme_font_size_override("font_size", 22)
	rows.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, 170)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	status = Label.new()
	status.custom_minimum_size = Vector2(550, 70)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(status)
	confirm = Button.new()
	confirm.text = "Confirmar desmontagem"
	confirm.custom_minimum_size.y = 56
	confirm.pressed.connect(dismantle)
	rows.add_child(confirm)
	var close := Button.new()
	close.text = "Cancelar / Fechar"
	close.custom_minimum_size.y = 56
	close.pressed.connect(func(): hud.set_panel(""))
	rows.add_child(close)

func reachable(target: PlacedStructure) -> bool:
	if not is_instance_valid(target) or target.is_queued_for_deletion() or target.system != system: return false
	if system.player.global_position.distance_to(target.global_position) > 90: return false
	var ray := PhysicsRayQueryParameters2D.create(system.player.global_position, target.global_position, 9)
	ray.exclude = [system.player.get_rid()]
	var collision: Dictionary = system.player.get_world_2d().direct_space_state.intersect_ray(ray)
	return collision.is_empty() or collision.collider == target

func open(target: PlacedStructure = null) -> void:
	selected = null
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	for node in get_tree().get_nodes_in_group("structures"):
		if not node is PlacedStructure or not reachable(node): continue
		var button := Button.new()
		button.text = node.chest_name if node.kind == "bau" else ItemCatalog.title(node.kind)
		button.custom_minimum_size.y = 56
		button.pressed.connect(select.bind(node))
		list.add_child(button)
	status.text = "Selecione uma peça próxima. Devolve 50% dos materiais; excedentes caem no chão."
	confirm.disabled = true
	if target != null: select(target)
	elif list.get_child_count() == 0: status.text = "Nenhuma estrutura sua ao alcance. Aproxime-se da base."

func select(target: PlacedStructure) -> void:
	selected = target
	var error := target.dismantle_error() if reachable(target) else "Aproxime-se da estrutura."
	status.text = "%s · %s" % [target.chest_name if target.kind == "bau" else ItemCatalog.title(target.kind), error if error != "" else "Confirmar devolve metade dos materiais. Esta ação remove a peça."]
	confirm.disabled = error != ""

func dismantle() -> void:
	if hud.current_panel != "base" or not reachable(selected):
		status.text = "Peça indisponível ou fora de alcance. Selecione novamente."
		return
	status.text = selected.dismantle(system.inventory)
	confirm.disabled = true
