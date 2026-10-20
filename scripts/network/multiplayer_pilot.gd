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
var status: Label
var counts: Label
var prompt: Label
var notice: Label
var retry: Button
var toolbar: HBoxContainer
var panel: PanelContainer
var overlay: Control
var camera: Camera2D
var touch_vector := Vector2.ZERO
var target := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	account_owner = FirebaseAuth.account_uid()
	endpoint = str(CONFIG.read_config().get("url", ""))
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
	toolbar = HBoxContainer.new()
	rows.add_child(toolbar)
	button(toolbar, "1 Machado", equip.bind("machado_madeira"))
	button(toolbar, "2 Picareta", equip.bind("picareta_madeira"))
	button(toolbar, "3 Mãos", equip.bind("maos"))
	button(toolbar, "Menu", func(): menu_requested.emit())
	retry = button(toolbar, "Reconectar", connect_room)
	camera = Camera2D.new()
	camera.position = Vector2(640, 450)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = 1280
	camera.limit_bottom = 900
	add_child(camera)
	overlay = TOUCH.new()
	overlay.arena = self
	layer.add_child(overlay)
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
	var unit := MobileInput.touch_minimum()
	var font := int(maxf(17, ceilf(13 / MobileInput.css_scale()))) if MobileInput.enabled else 18
	panel.position = Vector2(12, 12)
	panel.size = Vector2(view.x - 24, 0)
	for item in [status, counts, prompt, notice]: item.add_theme_font_size_override("font_size", font)
	for item in toolbar.get_children():
		item.custom_minimum_size = Vector2(unit * 1.7, unit)
		item.add_theme_font_size_override("font_size", font)
	if is_instance_valid(overlay): overlay.layout()

func connect_room() -> void:
	if socket != null: socket.close()
	online = false
	greeted = false
	fatal = false
	elapsed = 0
	retry_in = 0
	input_seq = 0
	last_token = ""
	MobileInput.reset()
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
	return not online or not focused or GlobalChat.opened or OrientationGuard.blocked or FirebaseAuth.account_uid() != account_owner

func _process(delta: float) -> void:
	# Autowrapped labels settle their minimum height after the first layout pass.
	# Shrink again instead of retaining the temporary full-screen panel height.
	panel.size.y = panel.get_combined_minimum_size().y
	camera.offset.y = -panel.size.y * 0.4
	if socket == null or fatal: return
	if retry_in > 0:
		retry_in -= delta
		if retry_in <= 0: connect_room()
		return
	socket.poll()
	var state := socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not greeted:
			last_token = FirebaseAuth.access_token(account_owner)
			send({"type": "hello", "protocol": 1, "token": last_token})
			greeted = true
			status.text = "Validando conta no servidor…"
		while socket.get_available_packet_count() > 0:
			var data: Variant = JSON.parse_string(socket.get_packet().get_string_from_utf8())
			if data is Dictionary: receive(data)
		if online:
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
		if elapsed > 12: disconnected("server_unavailable")
	for id in actors:
		var actor: Dictionary = actors[id]
		actor.body.position = actor.body.position.lerp(actor.target, 1 - exp(-delta * 24))
	if actors.has(self_id):
		camera.position = actors[self_id].body.position
		update_target()

func receive(data: Dictionary) -> void:
	match str(data.get("type", "")):
		"welcome":
			if room_id != "" and room_id != str(data.room): notice.text = "Servidor reiniciado · uma nova sala de teste começou"
			room_id = str(data.room)
			self_id = str(data.self)
			action_seq = int(data.nextAction) - 1
			online = true
			attempts = 0
			apply_state(data, true)
		"state":
			if online: apply_state(data)
		"ack":
			if not data.get("ok", false) and str(data.get("action", "")) != "input":
				notice.text = error_text(str(data.get("code", "")))
		"error":
			var code := str(data.get("code", ""))
			if code in ["not_authorized", "auth_failed", "auth_required", "room_full"]: disconnected(code, true)

func apply_state(data: Dictionary, initial: bool = false) -> void:
	snapshot = data
	inventory = data.inventory.duplicate()
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
			add_child(body)
			body.position = Vector2(p.x, p.y)
			actors[id] = {"body": body, "target": body.position}
		var actor: Dictionary = actors[id]
		actor.target = Vector2(p.x, p.y)
		if initial: actor.body.position = actor.target
		actor.body.identity_label = str(p.nickname) + (" · você" if id == self_id else "") + (" · offline" if not p.online else "")
		actor.body.identity_color = Color("d9a441") if id == self_id else Color("71b5d1")
		actor.body.modulate.a = 1.0 if p.online else 0.4
		actor.body.show_equipment(str(p.tool))
		if Vector2(p.dx, p.dy).length() > 0: actor.body.facing = Vector2(p.dx, p.dy)
		actor.body.queue_redraw()
	for id in actors.keys():
		if id not in present: actors[id].body.queue_free(); actors.erase(id)
	for r in data.resources:
		var id := str(r.id)
		if not nodes.has(id):
			var node := (TREE if r.kind == "madeira" else ROCK).instantiate() as HarvestResource
			node.position = Vector2(r.x, r.y)
			node.collision_layer = 0
			node.collision_mask = 0
			node.remove_from_group("harvest_resources")
			add_child(node)
			nodes[id] = node
		var node: HarvestResource = nodes[id]
		node.visible = not r.depleted
		node.exhausted = bool(r.depleted)
		node.progress = float(r.progress)
		node.queue_redraw()
	status.text = "Multiplayer — teste · sala %d/2 · conectado" % connected
	counts.text = "Seu inventário · Madeira %d · Pedra %d · %s" % [int(inventory.get("madeira", 0)), int(inventory.get("pedra", 0)), tool_name(str(data.tool))]
	retry.visible = false

func tool_name(tool: String) -> String:
	return {"maos": "Mãos", "machado_madeira": "Machado de madeira", "picareta_madeira": "Picareta de madeira"}.get(tool, tool)

func update_target() -> void:
	target = ""
	var closest := 82.01
	var position_now: Vector2 = actors[self_id].target
	for r in snapshot.get("resources", []):
		if r.depleted: continue
		var distance := position_now.distance_to(Vector2(r.x, r.y))
		if distance < closest:
			target = str(r.id)
			closest = distance
	for id in nodes: nodes[id].set_highlighted(id == target and online)
	if target != "":
		var kind: String = nodes[target].resource
		var valid: bool = str(snapshot.tool) in ResourceRules.EXTRACTION[kind].hits
		prompt.text = ("Toque em Coletar" if MobileInput.enabled else "F / E · Coletar") + (" árvore" if kind == "madeira" else " pedra") if valid else ResourceRules.guidance(kind)
	else: prompt.text = "Aproxime-se de uma árvore ou pedra · WASD / setas" if not MobileInput.enabled else "Arraste o círculo para andar · aproxime-se de uma árvore ou pedra"
	if is_instance_valid(overlay): overlay.collect.disabled = blocked() or target == ""

func equip(tool: String) -> void:
	if blocked(): return
	action_seq += 1
	send({"type": "equip", "seq": action_seq, "tool": tool})

func harvest() -> void:
	if blocked() or target == "": return
	action_seq += 1
	send({"type": "harvest", "seq": action_seq, "resource": target})
	if actors.has(self_id):
		var body: CharacterBody2D = actors[self_id].body
		body.show_swing((nodes[target].position - body.position).normalized(), 55)

func disconnected(reason: String, terminal: bool = false) -> void:
	online = false
	touch_vector = Vector2.ZERO
	MobileInput.reset()
	if socket != null: socket.close()
	fatal = terminal or reason in ["not_authorized", "auth_failed", "auth_required", "room_full", "session_replaced"]
	status.text = error_text(reason)
	retry.visible = true
	if not fatal:
		attempts += 1
		retry_in = minf(8, pow(2, mini(attempts - 1, 3)))
		status.text += " · reconectando…"

func error_text(code: String) -> String:
	return {"not_authorized": "Esta conta não está autorizada para o piloto.", "room_full": "Sala cheia · limite de dois jogadores.", "auth_failed": "Não foi possível validar a conta. Volte ao menu e entre novamente.", "auth_required": "Entre na conta para acessar esta sala.", "session_replaced": "Conta conectada em outro aparelho. Esta conexão foi encerrada.", "too_far": "Aproxime-se do recurso para coletar.", "wrong_tool": "Equipe a ferramenta indicada para este recurso.", "cooldown": "Aguarde o intervalo entre golpes.", "resource_unavailable": "Este recurso já foi coletado.", "invalid_tool": "Ferramenta não disponível no seu inventário.", "replayed_action": "Ação repetida recusada pelo servidor."}.get(code, "Conexão perdida ou servidor indisponível")

func _unhandled_input(event: InputEvent) -> void:
	if blocked() or event.is_echo(): return
	if event.is_action_pressed("equip_1"): equip("machado_madeira")
	elif event.is_action_pressed("equip_2"): equip("picareta_madeira")
	elif event.is_action_pressed("equip_3"): equip("maos")
	elif event.is_action_pressed("use_tool") or event.is_action_pressed("collect") or event.is_action_pressed("hit"): harvest()
	else: return
	get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT: focused = false; touch_vector = Vector2.ZERO
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN: focused = true

func _exit_tree() -> void:
	if socket != null: socket.close(1000, "leave")
	last_token = ""
	if MobileInput.overlay == overlay: MobileInput.overlay = null
	MobileInput.reset()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 900), Color("425d39"))
	draw_rect(Rect2(16, 16, 1248, 868), Color("b5a16c"), false, 4)
	for x in range(40, 1280, 90):
		for y in range(220, 900, 100): draw_line(Vector2(x, y), Vector2(x + 9, y - 7), Color("587546"), 2)
