extends Node2D

signal menu_requested
const PLAYER := preload("res://scripts/player.gd")
const TREE := preload("res://scenes/obstacles/tree.tscn")
const ROCK := preload("res://scenes/obstacles/rock.tscn")
const CONFIG := preload("res://scripts/network/multiplayer_config.gd")
const TOUCH := preload("res://scripts/network/multiplayer_touch.gd")
var socket: WebSocketPeer
var endpoint := ""
var self_id := ""
var account_owner := ""
var room_id := ""
var actors := {}
var nodes := {}
var snapshot := {}
var inventory := {}
var online := false
var greeted := false
var fatal := false
var focused := true
var elapsed := 0.0
var retry_in := 0.0
var attempts := 0
var input_clock := 0.0
var input_seq := 0
var action_seq := 0
var last_token := ""
var last_state_at := 0
var notice_until := 0
var connection_text := ""
var tool_buttons: Array[Button] = []
var status: Label
var counts: Label
var prompt: Label
var notice: Label
var retry: Button
var toolbar: HFlowContainer
var panel: PanelContainer
var overlay: Control
var camera: Camera2D
var touch_vector := Vector2.ZERO
var target := ""
var well_target := ""
var world_view: Node2D
var hud: CanvasLayer
var projected_inventory: ResourceInventory
var minimap: IslandMinimap
var account_store: AccountProgress = null
var progress_store: WorldProgress = null
var held := false
var hit_clock := 0.0
var name_font := 14

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	account_owner = FirebaseAuth.account_uid()
	endpoint = str(CONFIG.read_config().get("url", ""))
	world_view = preload("res://scripts/network/multiplayer_world.gd").new()
	add_child(world_view)
	nodes = world_view.resources
	projected_inventory = ResourceInventory.new()
	add_child(projected_inventory)
	hud = preload("res://scenes/hud.tscn").instantiate()
	hud.network_mode = true
	add_child(hud)
	hud.initialize(projected_inventory)
	hud.network_action_requested.connect(request_action)
	hud.menu_view.leave_action = func(): menu_requested.emit()
	hud.panel_toggled.connect(func(_open): touch_vector = Vector2.ZERO; held = false; MobileInput.reset())
	for name in ["Health", "HealthLabel", "EquipmentKeys"]: hud.get_node("Controls/Rows/" + name).hide()
	for name in ["Fome", "Proteção"]: hud.needs_bars[name].hide()
	for item in hud.inventory_actions.get_children(): item.visible = item.text in ["Mover / trocar", "Usar"]
	hud.get_node("InventoryPanel/Panel/Scroll/Rows/BackpackSlot").hide()
	hud.get_node("InventoryPanel/Panel/Scroll/Rows/ArmorSlot").hide()
	var layer := CanvasLayer.new()
	add_child(layer)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", IslandTheme.panel(Color(0.05, 0.13, 0.10, 0.96)))
	layer.add_child(panel)
	var rows := VBoxContainer.new()
	panel.add_child(rows)
	status = label(rows, "Conectando à sala de teste…")
	counts = label(rows, "Seu inventário · aguardando servidor")
	prompt = label(rows, "WASD / setas · 1 machado · 2 picareta · 3 mãos · F/E coletar")
	notice = label(rows, "Mundo de teste · reiniciar o servidor reinicia esta sala")
	toolbar = HFlowContainer.new()
	rows.add_child(toolbar)
	button(toolbar, "Menu", func(): menu_requested.emit())
	retry = button(toolbar, "Reconectar", connect_room)
	camera = Camera2D.new()
	camera.position = Vector2(1152, 768)
	camera.limit_left = int(WorldTerrain.BOUNDS.position.x)
	camera.limit_top = int(WorldTerrain.BOUNDS.position.y)
	camera.limit_right = int(WorldTerrain.BOUNDS.end.x)
	camera.limit_bottom = int(WorldTerrain.BOUNDS.end.y)
	add_child(camera)
	overlay = TOUCH.new()
	overlay.arena = self
	layer.add_child(overlay)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("document.body.classList.add('tc-multiplayer'); if (!document.getElementById('tc-mp-style')) {const s=document.createElement('style');s.id='tc-mp-style';s.textContent='body.tc-multiplayer #chat-launch{top:max(10px,env(safe-area-inset-top));bottom:auto;}body.tc-multiplayer #pilot-badge{display:none;}';document.head.appendChild(s);}")
	get_viewport().size_changed.connect(layout)
	MobileInput.mode_changed.connect(layout)
	layout()
	connect_room()
	queue_redraw()

func label(parent: Node, text: String) -> Label:
	var item := Label.new()
	item.text = text
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(item)
	return item

func button(parent: Node, text: String, callback: Callable) -> Button:
	var item := Button.new()
	item.text = text
	item.focus_mode = Control.FOCUS_NONE
	IslandTheme.decorate(item)
	item.pressed.connect(callback)
	parent.add_child(item)
	return item

func layout() -> void:
	var view := get_viewport_rect().size
	var scale := MobileInput.css_scale()
	name_font = maxi(14, ceili(12 / scale)) if MobileInput.enabled else 14
	for actor in actors.values(): actor.body.identity_label_size = name_font
	var unit := (44.0 if MobileInput.enabled else 36.0) / scale
	var font := int(ceilf(15 / scale))
	var margin := 8.0 / scale
	var width := minf(view.x - margin * 2, (620.0 if online else 520.0) / scale)
	panel.position = Vector2(margin if online else (view.x - width) / 2, margin)
	panel.size = Vector2(width, 0)
	var style := IslandTheme.panel(Color(0.05, 0.13, 0.10, 0.96))
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = 6 / scale
	style.content_margin_bottom = 6 / scale
	panel.add_theme_stylebox_override("panel", style)
	for item in [status, counts, prompt, notice]: item.add_theme_font_size_override("font_size", font)
	for item in toolbar.get_children():
		item.custom_minimum_size = Vector2(unit * 1.65, unit)
		item.add_theme_font_size_override("font_size", font)
	for i in tool_buttons.size():
		tool_buttons[i].text = (["Machado", "Picareta", "Mãos"] if MobileInput.enabled else ["1 Machado", "2 Picareta", "3 Mãos"])[i]
	if is_instance_valid(overlay): overlay.layout()
	refresh_controls()

func refresh_controls() -> void:
	panel.visible = not online
	hud.visible = online
	hud.set_process_input(online)
	var hud_panel: Control = hud.get_node("Controls")
	hud_panel.size = hud_panel.get_combined_minimum_size()
	for item in tool_buttons:
		item.visible = online
		item.disabled = blocked()
	counts.visible = online
	notice.visible = Time.get_ticks_msec() < notice_until
	if not online:
		prompt.text = "A sala só carrega após validar a conexão. O mundo solo permanece no menu."
	if is_instance_valid(overlay):
		overlay.visible = MobileInput.enabled and online and hud.current_panel == ""
		overlay.collect.disabled = blocked() or target == "" and well_target == ""

func show_notice(text: String) -> void:
	notice.text = text
	notice_until = Time.get_ticks_msec() + 4500
	if is_instance_valid(hud) and online: hud.show_message(text)

func connect_room() -> void:
	if socket != null: socket.close()
	online = false
	greeted = false
	fatal = false
	elapsed = 0
	retry_in = 0
	input_seq = 0
	last_token = ""
	last_state_at = 0
	MobileInput.reset()
	layout()
	if account_owner == "" or FirebaseAuth.account_uid() != account_owner:
		fatal = true
		status.text = "Entre novamente na conta para acessar o multiplayer."
		return
	if not endpoint.begins_with("wss://") and not endpoint.begins_with("ws://127.0.0.1:") and not endpoint.begins_with("ws://localhost:"):
		fatal = true
		status.text = "Servidor indisponível · endereço WSS ainda não configurado."
		return
	socket = WebSocketPeer.new()
	socket.inbound_buffer_size = 65536
	socket.max_queued_packets = 64
	var error := socket.connect_to_url(endpoint)
	status.text = "Conectando à sala de teste…"
	if error != OK: disconnected("server_unavailable")

func send(data: Dictionary) -> void:
	if socket != null and socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.send_text(JSON.stringify(data))

func blocked() -> bool:
	return not online or not focused or GlobalChat.opened or OrientationGuard.blocked or hud.current_panel != "" or FirebaseAuth.account_uid() != account_owner

func _process(delta: float) -> void:
	# Autowrapped labels settle their minimum height after the first layout pass.
	# Shrink again instead of retaining the temporary full-screen panel height.
	panel.size.y = panel.get_combined_minimum_size().y
	camera.offset.y = -40.0 if MobileInput.enabled else 0.0
	refresh_controls()
	if socket == null: return
	socket.poll()
	if fatal: return
	if retry_in > 0:
		retry_in -= delta
		status.text = connection_text + " · nova tentativa em %ds" % maxi(1, ceili(retry_in))
		if retry_in <= 0: connect_room()
		return
	var state := socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not greeted:
			last_token = FirebaseAuth.access_token(account_owner)
			send({"type": "hello", "protocol": 2, "token": last_token})
			greeted = true
			status.text = "Validando conta no servidor…"
		while socket.get_available_packet_count() > 0:
			var data: Variant = JSON.parse_string(socket.get_packet().get_string_from_utf8())
			if data is Dictionary: receive(data)
		if online:
			if Time.get_ticks_msec() - last_state_at > 5000:
				disconnected("state_timeout")
				return
			var token := FirebaseAuth.access_token(account_owner)
			if token != "" and token != last_token:
				last_token = token
				send({"type": "refresh", "token": token})
			input_clock -= delta
			if input_clock <= 0:
				input_clock = 0.05
				var movement := Vector2.ZERO if blocked() else (Input.get_vector("move_left", "move_right", "move_up", "move_down") + touch_vector).limit_length(1)
				input_seq += 1
				send({"type": "input", "seq": input_seq, "x": movement.x, "y": movement.y})
	elif state == WebSocketPeer.STATE_CLOSED:
		disconnected(socket.get_close_reason())
	if not online:
		elapsed += delta
		if elapsed > 24: disconnected("server_unavailable")
	for id in actors:
		var actor: Dictionary = actors[id]
		actor.body.position = actor.body.position.lerp(actor.target, 1 - exp(-delta * 24))
	separate_names()
	if actors.has(self_id):
		camera.position = actors[self_id].body.position
		update_target()
		hit_clock -= delta
		if held and not blocked() and hit_clock <= 0:
			hit_clock = ResourceRules.hit_interval(str(snapshot.get("tool", "maos")))
			harvest()

func receive(data: Dictionary) -> void:
	match str(data.get("type", "")):
		"welcome":
			if int(data.get("protocol", 0)) != 2 or str(data.world.get("hash", "")) != FileAccess.get_sha256(world_view.FILE):
				disconnected("client_outdated", true)
				return
			if room_id != "" and room_id != str(data.room): show_notice("Servidor reiniciado · uma nova sala de teste começou")
			room_id = str(data.room)
			self_id = str(data.self)
			action_seq = int(data.nextAction) - 1
			online = true
			attempts = 0
			apply_state(data, true)
			if minimap == null:
				minimap = IslandMinimap.new()
				minimap.player = actors[self_id].body
				hud.add_child(minimap)
			layout()
		"state":
			if online: apply_state(data)
		"ack":
			if not data.get("ok", false) and str(data.get("action", "")) != "input":
				show_notice(error_text(str(data.get("code", ""))))
			elif data.get("ok", false) and data.get("action", "") == "well":
				hud.show_message("Cantil cheio · 3 doses" if data.get("effect", "") == "filled" else "Água potável · +40 água")
			elif data.get("ok", false) and data.get("action", "") == "use": hud.show_message("Você bebeu uma dose do cantil")
		"error":
			var code := str(data.get("code", ""))
			if code in ["not_authorized", "auth_failed", "auth_required", "room_full", "client_outdated"]: disconnected(code, true)

func apply_state(data: Dictionary, initial: bool = false) -> void:
	last_state_at = Time.get_ticks_msec()
	snapshot = data
	inventory = data.inventory.duplicate()
	projected_inventory.apply_network_state(data.slots)
	hud.update_needs(100, float(data.thirst))
	if initial:
		for node in nodes.values():
			node.visible = true
			node.exhausted = false
			node.progress = 0.0
			node.queue_redraw()
	var present := []
	var connected := 0
	for p in data.players:
		var id := str(p.id)
		present.append(id)
		if p.online: connected += 1
		if not actors.has(id):
			var body := PLAYER.new()
			body.network_controlled = true
			body.simulation_authority = false
			body.collision_layer = 0
			body.collision_mask = 0
			world_view.objects.add_child(body)
			body.position = Vector2(p.x, p.y)
			actors[id] = {"body": body, "target": body.position, "swing": int(p.get("swing", 0))}
		var actor: Dictionary = actors[id]
		actor.target = Vector2(p.x, p.y)
		if initial:
			actor.body.position = actor.target
			actor.swing = int(p.get("swing", 0))
		actor.body.identity_label = str(p.nickname) + (" · você" if id == self_id else "") + (" · offline" if not p.online else "")
		actor.body.identity_color = Color("d9a441") if id == self_id else Color("71b5d1")
		actor.body.identity_label_size = name_font
		actor.body.modulate.a = 1.0 if p.online else 0.4
		actor.body.show_equipment(str(p.tool))
		actor.body.swimming = bool(p.get("swimming", false))
		if int(p.get("swing", 0)) > actor.swing:
			actor.swing = int(p.swing)
			actor.body.show_swing((Vector2(p.sx, p.sy) - actor.body.position).normalized(), 55)
		if Vector2(p.dx, p.dy).length() > 0: actor.body.facing = Vector2(p.dx, p.dy)
		actor.body.queue_redraw()
	for id in actors.keys():
		if id not in present: actors[id].body.queue_free(); actors.erase(id)
	for r in data.resources:
		var id := str(r.id)
		if not nodes.has(id): continue
		var node: HarvestResource = nodes[id]
		node.visible = not r.depleted
		node.exhausted = bool(r.depleted)
		node.progress = float(r.progress)
		node.queue_redraw()
	status.text = "Multiplayer · sala %d/2 · conectado · piloto .3" % connected
	var region := WorldTerrain.region_at(actors[self_id].target)
	hud.get_node("Controls/Rows/Time").text = "Multiplayer .3 · %d/2\n%s" % [connected, str(region.get("kind", "Ilha"))]
	counts.text = "Seu inventário · Madeira %d · Pedra %d · %s" % [int(inventory.get("madeira", 0)), int(inventory.get("pedra", 0)), tool_name(str(data.tool))]
	retry.visible = false

func tool_name(tool: String) -> String:
	return {"maos": "Mãos", "machado_madeira": "Machado de madeira", "picareta_madeira": "Picareta de madeira"}.get(tool, tool)

func update_target() -> void:
	target = ""
	well_target = ""
	var closest := 82.01
	var position_now: Vector2 = actors[self_id].target
	for id in nodes:
		var node: HarvestResource = nodes[id]
		if node.exhausted: continue
		var distance := position_now.distance_to(node.position)
		if distance < closest:
			target = id
			closest = distance
	var well_distance := 90.01
	for id in world_view.wells:
		var well: WaterWell = world_view.wells[id]
		var distance := position_now.distance_to(well.position)
		if distance < well_distance:
			well_target = id
			well_distance = distance
	for id in world_view.wells: world_view.wells[id].set_highlighted(id == well_target and online)
	for id in nodes: nodes[id].set_highlighted(id == target and online)
	if well_target != "" and well_distance < closest:
		prompt.text = "Interagir · poço: beber / encher cantil" if MobileInput.enabled else "E · poço: beber / encher cantil"
	elif target != "":
		var kind: String = nodes[target].resource
		var valid: bool = str(snapshot.tool) in ResourceRules.EXTRACTION[kind].hits
		prompt.text = ("Toque em Coletar" if MobileInput.enabled else "F / E · Coletar") + (" árvore" if kind == "madeira" else " pedra") if valid else ResourceRules.guidance(kind)
	else: prompt.text = ""
	hud.show_target(prompt.text)
	if is_instance_valid(overlay):
		overlay.collect.text = "Interagir" if well_target != "" and well_distance < closest else "Coletar"
		overlay.collect.disabled = blocked() or target == "" and well_target == ""

func interact() -> void:
	if blocked(): return
	if well_target != "":
		var well: WaterWell = world_view.wells[well_target]
		if target == "" or actors[self_id].target.distance_to(well.position) < actors[self_id].target.distance_to(nodes[target].position):
			hud.open_well(well)
			return
	harvest()

func separate_names() -> void:
	var labels := []
	for actor in actors.values():
		var body: CharacterBody2D = actor.body
		var text_size := IslandTheme.BODY.get_string_size(body.identity_label, HORIZONTAL_ALIGNMENT_LEFT, -1, name_font)
		labels.append({"body": body, "box": Rect2(body.position + Vector2(-27, -53 - name_font), Vector2(text_size.x, name_font + 4)), "offset": Vector2.ZERO})
	if labels.size() == 2 and labels[0].box.grow(4).intersects(labels[1].box):
		labels[1].offset.y = labels[0].box.position.y - labels[1].box.end.y - 4
	for label in labels:
		if label.body.identity_label_offset != label.offset:
			label.body.identity_label_offset = label.offset
			label.body.queue_redraw()

func request_action(action: String, argument: Variant = null) -> void:
	if not online or not focused or GlobalChat.opened or OrientationGuard.blocked or FirebaseAuth.account_uid() != account_owner: return
	action_seq += 1
	var message := {"type": action, "seq": action_seq}
	match action:
		"select", "equip_slot", "use": message.index = int(argument)
		"equip": message.tool = str(argument)
		"swap": message.from = argument.x; message.to = argument.y
		"well": message.well = str(argument.well); message.action = str(argument.action)
		_: return
	send(message)

func equip(tool: String) -> void:
	if blocked(): return
	request_action("equip", tool)

func harvest() -> void:
	if blocked() or target == "": return
	action_seq += 1
	send({"type": "harvest", "seq": action_seq, "resource": target})

func disconnected(reason: String, terminal: bool = false) -> void:
	online = false
	held = false
	hud.set_panel("")
	touch_vector = Vector2.ZERO
	MobileInput.reset()
	if socket != null: socket.close()
	fatal = terminal or reason in ["not_authorized", "auth_failed", "auth_required", "room_full", "session_replaced"]
	status.text = error_text(reason)
	connection_text = status.text
	retry.visible = true
	layout()
	if not fatal:
		attempts += 1
		retry_in = minf(8, pow(2, mini(attempts - 1, 3)))
		status.text += " · reconectando…"

func error_text(code: String) -> String:
	if code == "client_outdated": return "Atualize a página para carregar o piloto .3 e o mesmo mundo do servidor."
	if code == "blocked_path": return "Há um obstáculo no caminho. Aproxime-se pelo acesso livre."
	if code == "inventory_full": return "Inventário cheio · libere espaço antes de coletar."
	if code == "canteen_unavailable": return "Tenha um cantil com espaço para água."
	if code == "canteen_empty": return "Cantil vazio · encha em um poço."
	if code in ["invalid_slot", "invalid_item"]: return "Selecione um item disponível no inventário."
	if code == "state_timeout": return "Sem resposta da sala · controles pausados"
	return {"not_authorized": "Esta conta não está autorizada para o piloto.", "room_full": "Sala cheia · limite de dois jogadores.", "auth_failed": "Não foi possível validar a conta. Volte ao menu e entre novamente.", "auth_required": "Entre na conta para acessar esta sala.", "session_replaced": "Conta conectada em outro aparelho. Esta conexão foi encerrada.", "too_far": "Aproxime-se do recurso para coletar.", "wrong_tool": "Equipe a ferramenta indicada para este recurso.", "cooldown": "Aguarde o intervalo entre golpes.", "resource_unavailable": "Este recurso já foi coletado.", "invalid_tool": "Ferramenta não disponível no seu inventário.", "replayed_action": "Ação repetida recusada pelo servidor."}.get(code, "Conexão perdida ou servidor indisponível")

func _unhandled_input(event: InputEvent) -> void:
	if blocked() or event.is_echo(): return
	for i in range(5):
		if event.is_action_pressed("equip_" + str(i + 1)):
			request_action("select", i)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		request_action("select", posmod(projected_inventory.selected_index + (-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1), 5))
	elif event.is_action_pressed("collect"): interact()
	elif event.is_action_pressed("use_tool") or event.is_action_pressed("hit"):
		if projected_inventory.selected_data().get("item", "") == "cantil": request_action("use", projected_inventory.selected_index)
		else:
			harvest()
			held = true
			hit_clock = ResourceRules.hit_interval(str(snapshot.get("tool", "maos")))
	else: return
	get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if event.is_action_released("use_tool") or event.is_action_released("hit"): held = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT: focused = false; touch_vector = Vector2.ZERO; held = false
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN: focused = true

func _exit_tree() -> void:
	if OS.has_feature("web"): JavaScriptBridge.eval("document.body.classList.remove('tc-multiplayer')")
	if socket != null: socket.close(1000, "leave")
	last_token = ""
	if MobileInput.overlay == overlay: MobileInput.overlay = null
	MobileInput.reset()

func _draw() -> void:
	pass
