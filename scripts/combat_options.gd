class_name CombatOptions
extends Control
var hud: CanvasLayer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.06, 0.04, 0.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-240, -160)
	panel.custom_minimum_size = Vector2(480, 320)
	add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 18)
	panel.add_child(rows)
	var title := Label.new()
	title.text = "Sons do combate"
	title.add_theme_font_size_override("font_size", 24)
	rows.add_child(title)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.value = CombatAudio.volume * 100
	slider.custom_minimum_size = Vector2(450, 60)
	rows.add_child(slider)
	var label := Label.new()
	label.text = "Volume: %d%%" % slider.value
	rows.add_child(label)
	var mute := CheckButton.new()
	mute.text = "Silenciar"
	mute.button_pressed = CombatAudio.muted
	mute.custom_minimum_size.y = 56
	rows.add_child(mute)
	slider.value_changed.connect(func(value): label.text = "Volume: %d%%" % value; CombatAudio.configure(value / 100, mute.button_pressed))
	mute.toggled.connect(func(value): CombatAudio.configure(slider.value / 100, value))
	var close := Button.new()
	close.text = "Fechar"
	close.custom_minimum_size.y = 56
	close.pressed.connect(func(): hud.set_panel(""))
	rows.add_child(close)
	if MobileInput.enabled: hud.touch_sizes(self)
