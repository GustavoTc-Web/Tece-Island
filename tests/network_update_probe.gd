extends Node
var role := "guest"
var port := 17153
var main: Node
var arena: Node
var guest_id := 0
var failures := 0
var checks := 0
var reports := {}
func _ready() -> void:
	FirebaseAuth.config.enabled = false # Test-only offline gameplay, never a mock login.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = arg.trim_prefix("--role=")
		if arg.begins_with("--port="): port = int(arg.trim_prefix("--port="))
	main = load("res://scenes/main.tscn").instantiate()
	main.set_script(load("res://tests/native_fixture_session.gd"))
	add_child(main)
	if role == "host":
		main.host_game(port)
		arena = main.game
		run_host()
	else: main.join_game("127.0.0.1", port)
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1
	print("PASS: " if value else "FAIL: ", label)
func wait_for(condition: Callable, seconds: float = 6) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < end:
		if condition.call(): return true
		await get_tree().create_timer(0.02).timeout
	return false
func command(tag: String, action: String, argument: Variant = null) -> Dictionary:
	reports.erase(tag)
	probe.rpc_id(guest_id, tag, action, argument)
	check(await wait_for(func(): return reports.has(tag)), "Resposta de cliente: " + tag)
	return reports.get(tag, {})
@rpc("authority", "call_remote", "reliable")
func probe(tag: String, action: String, argument: Variant) -> void:
	arena = main.game
	match action:
		"panel": arena.get_node("HUD").set_panel(argument)
		"replay":
			arena.action_sequence += 1
			for i in range(2): arena.action_requested.rpc_id(1, arena.action_sequence, argument.action, argument.value)
		"hold":
			var event := InputEventKey.new()
			event.physical_keycode = KEY_F
			event.keycode = KEY_F
			event.pressed = true
			get_viewport().push_input(event)
			await get_tree().create_timer(0.5).timeout
			event.pressed = false
			get_viewport().push_input(event)
		"shutdown":
			await wait_for(func(): return main.game == null)
			get_tree().quit()
			return
		_: arena.request_action(action, argument)
	await get_tree().create_timer(0.3).timeout
	report.rpc_id(1, tag, arena.make_snapshot())
@rpc("any_peer", "call_remote", "reliable")
func report(tag: String, state: Dictionary) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == guest_id: reports[tag] = state
func run_host() -> void:
	check(await wait_for(func(): return arena.actors.size() == 2, 35), "Duas instâncias conectadas")
	if arena.actors.size() != 2:
		get_tree().quit(1)
		return
	for id in arena.actors:
		if id != 1: guest_id = id
	var actor: Dictionary = arena.actors[guest_id]
	var host: Dictionary = arena.actors[1]
	actor.inventory.add_item({"item": "cantil", "quantity": 1, "water": 2})
	actor.inventory.add_resource("carne_cozida", 3)
	actor.body.get_node("Needs").hunger = 20
	actor.body.get_node("Needs").thirst = 10
	await command("panel", "panel", "inventory")
	check(not get_tree().paused and actor.panel, "Inventário multiplayer não pausa simulação")
	await command("swap", "swap", Vector2i(3, 4))
	check(actor.inventory.slot_data(4).get("water", 0) == 2 and actor.inventory.slot_data(3).item == "carne_cozida", "Servidor troca itens com atributos")
	await command("eat_replay", "replay", {"action": "use", "value": 3})
	check(actor.inventory.count_item("carne_cozida") == 2 and actor.body.get_node("Needs").hunger > 49, "Consumo validado e repetição de sequência não duplica")
	await command("close", "panel", "")
	await command("select", "select", 4)
	var data := await command("hold", "hold")
	check(actor.inventory.slot_data(4).water == 1 and actor.body.get_node("Needs").thirst > 49, "Segurar F usa uma dose, sem repetição automática")
	check(data.actors[guest_id].inventory.slots[4].water == 1, "Snapshot apresenta água confirmada pelo servidor")
	await command("drop_replay", "replay", {"action": "discard", "value": {"index": 4, "whole": true}})
	check(actor.inventory.count_item("cantil") == 0 and arena.dropped_items.size() == 1, "Descarte remoto remove item uma vez")
	var object: ResourceDrop = arena.dropped_items.values()[0]
	check(object.attributes.water == 1, "Drop compartilhado mantém doses")
	await command("pickup", "collect")
	check(actor.inventory.count_item("cantil") == 1 and actor.inventory.slot_data(4).water == 1 and not is_instance_valid(object), "Coleta remota recupera atributos sem duplicação")
	await command("weapon_drop", "discard", {"index": 0, "whole": true})
	object = arena.dropped_items.values()[-1]
	check(object.attributes.loaded == 8, "Arma descartada conserva oito tiros")
	host.body.position = object.position + Vector2(-20, 0)
	probe.rpc_id(guest_id, "race", "collect", null)
	arena.request_action("collect")
	await wait_for(func(): return reports.has("race"))
	check(host.inventory.count_item("pistola") + actor.inventory.count_item("pistola") == 2 and not is_instance_valid(object), "Coleta concorrente da arma não duplica item")
	var before: Array = actor.inventory.slots
	await command("invalid_drop", "discard", {"index": 400, "whole": true})
	await command("invalid_swap", "swap", Vector2i(0, 400))
	await command("give", "give_item", {"item": "carne_cozida", "quantity": 999})
	check(actor.inventory.slots == before, "Servidor rejeita índices inválidos e fornecimento de itens")
	probe.rpc_id(guest_id, "shutdown", "shutdown", null)
	await main.leave_game()
	print("NETWORK UPDATE: ", checks, " verificações, ", failures, " falhas")
	get_tree().quit(1 if failures else 0)
