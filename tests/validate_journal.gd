extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1
	print("PASS: " if value else "FAIL: ", label)
func step() -> void:
	for i in range(4): await physics_frame
func run() -> void:
	var world: Node2D = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await step()
	var inv: ResourceInventory = world.get_node("Inventory")
	var player: CharacterBody2D = world.get_node("WorldObjects/Player")
	player.set_physics_process(false)
	var notes := get_nodes_in_group("expedition_records")
	check(notes.size() == 3, "Três registros únicos em construções existentes")
	for id in IslandJournal.RECORDS:
		var words: int = IslandJournal.RECORDS[id].text.split(" ", false).size()
		check(words >= 40 and words <= 80, "Registro original de 40–80 palavras: " + id)
	for i in range(7): inv.add_resource("cama", 1)
	var original := inv.network_state()
	for note in notes:
		var query := PhysicsShapeQueryParameters2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 10
		query.shape = shape
		query.collision_mask = 9
		query.transform = Transform2D(0, note.position)
		var clear_record := player.get_world_2d().direct_space_state.intersect_shape(query).is_empty()
		query.transform = Transform2D(0, note.position + Vector2(0, 35))
		var entry_path := true
		if note.record_id == "signal":
			var transform := Transform2D(0, world.ruins.temples[0].global_position + Vector2(-35, 280))
			for motion in [Vector2(0, -100), Vector2(-55, 0), Vector2(0, -65)]:
				if player.test_move(transform, motion): entry_path = false
				transform.origin += motion
		check(clear_record and entry_path and player.get_world_2d().direct_space_state.intersect_shape(query).is_empty(), "Registro e aproximação em chão livre, com entrada do templo acessível: " + note.record_id)
		player.position = note.position + Vector2(0, 35)
		await step()
		player.get_node("Interaction").collect_nearest()
		check(note.record_id in world.journal.discovered, "Coleta existente encontra registro sem mouse: " + note.record_id)
		await process_frame
	check(inv.network_state() == original, "Diário não ocupa inventário cheio")
	check(not world.journal.collect("arrival") and world.journal.discovered.size() == 3, "Identidade impede descoberta duplicada")
	world.journal.read_page("trail")
	check(not world.journal.unread.has("trail") and world.journal.unread.size() == 2, "Ler retira indicação de página nova")
	var progress := WorldProgress.new()
	progress.world = world
	var data := progress.capture()
	var second: Node2D = load("res://scenes/world.tscn").instantiate()
	root.add_child(second)
	await step()
	var restored := WorldProgress.new()
	restored.world = second
	restored.store.path = "res://.tools/journal-save.json"
	check(restored.store.write(data), "Diário grava no save")
	restored.load_progress()
	await process_frame
	check(second.journal.discovered == world.journal.discovered and second.journal.unread == world.journal.unread, "Reload preserva ordem e novas páginas")
	var remaining := 0
	for note in get_nodes_in_group("expedition_records"):
		if note.journal == second.journal: remaining += 1
	check(remaining == 0, "Páginas descobertas não reaparecem")
	var hud: CanvasLayer = second.get_node("HUD")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_J
	event.pressed = true
	hud._input(event)
	check(hud.current_panel == "journal", "J abre diário sem conflito com controles")
	hud.journal_view.selected = "signal"
	hud.journal_view.goals_mode = false
	hud.journal_view.refresh()
	check(hud.journal_view.text.text.contains("Raul") and hud.journal_view.text.autowrap_mode != TextServer.AUTOWRAP_OFF, "Leitura legível com texto e rolagem")
	hud.set_panel("")
	world.queue_free()
	second.queue_free()
	await process_frame
	print("JOURNAL: %d verificações, %d falhas" % [checks, failures])
	quit(1 if failures else 0)
