# Visual tests only. No requests are mocked and no session is created.
extends Node
var screen: Control
var snapshot_time := 0.0
func _ready() -> void:
	screen = load("res://scenes/auth.tscn").instantiate()
	add_child(screen)
func rect(control: Control) -> Array:
	var box := control.get_global_rect()
	return [box.position.x, box.position.y, box.size.x, box.size.y]
func _process(delta: float) -> void:
	snapshot_time += delta
	if snapshot_time < 0.1: return
	snapshot_time = 0
	var buttons := {}
	for button in screen.find_children("*", "Button", true, false):
		if button.is_visible_in_tree(): buttons[button.text] = rect(button)
	var data := {"mode": screen.mode, "buttons": buttons, "email_rect": rect(screen.email), "password_rect": rect(screen.password), "confirmation_rect": rect(screen.confirmation), "email_valid": screen.email.text.contains("@"), "password_hidden": screen.password.secret, "confirmation_hidden": screen.confirmation.secret, "session": FirebaseAuth.has_session(), "configured": FirebaseAuth.configured(), "status": screen.status.text, "viewport": [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y]}
	data.password_present = not screen.password.text.is_empty()
	JavaScriptBridge.eval("window.tcAuthUiState = " + JSON.stringify(data))
