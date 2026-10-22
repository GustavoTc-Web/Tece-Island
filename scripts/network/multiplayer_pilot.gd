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
var drops := {}
var drop_target := ""
var target_clock := 0.0
var previous_target := ""
var previous_well := ""
var previous_drop := ""
var server_offset := 0.0
var name_clock := 0.0
var controls_clock := 0.0
var diagnostic: Label
var connection_phase := "connection"
var failed_phase := ""
var phase_started := 0
var last_close_code := 0
var web_online := -1
var last_apply_us := 0
var connection_generation := 0
var endpoint_request: HTTPRequest
const CLIENT_VERSION := "0.9.0-multiplayer-pilot.7"
var prediction := preload("res://scripts/network/multiplayer_prediction.gd").new()
var metrics := preload("res://scripts/network/multiplayer_metrics.gd").new()
var last_input_ack := 0
var pending_state := {}
var remote_time := 0.0
var remote_delay := 0.12
var metrics_clock := 0.0
var metrics_button: Button
var metrics_panel: PanelContainer
var metrics_text: Label
var prediction_button: Button
var last_movement := Vector2.ZERO
var last_input_sent := 0
var last_needs := Vector4(-1, -1, -1, -1)
var server_version := ""
var economical := true
var graphics_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	account_owner = FirebaseAuth.account_uid()
	endpoint = str(CONFIG.read_config().get("url", ""))
	world_view = preload("res://scripts/network/multiplayer_world.gd").new()
	add_child(world_view)
	prediction.configure(world_view.data)
	nodes = world_view.resources
	projected_inventory = ResourceInventory.new()
	add_child(projected_inventory)
	hud = preload("res://scenes/hud.tscn").instantiate()
	hud.network_mode = true
	add_child(hud)
	hud.initialize(projected_inventory)
	hud.network_action_requested.connect(request_action)
	hud.menu_view.leave_action = func(): menu_requested.emit()
	hud.panel_toggled.connect(func(_open): touch_vector = Vector2.ZERO; held = false; MobileInput.reset(); refresh_controls())
	for name in ["HealthLabel", "EquipmentKeys"]: hud.get_node("Controls/Rows/" + name).hide()
	hud.needs_bars["Proteção"].hide()
	hud.needs_bars.Fome.tooltip_text = "Fome estável neste piloto: alimentos ainda não disponíveis."
	for item in hud.inventory_actions.get_children(): item.visible = item.text in ["Mover / trocar", "Usar"]
	hud.get_node("InventoryPanel/Panel/Scroll/Rows/BackpackSlot").hide()
	hud.get_node("InventoryPanel/Panel/Scroll/Rows/ArmorSlot").hide()
	var layer := CanvasLayer.new()
	add_child(layer)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", IslandTheme.panel(Color(0.05, 0.13, 0.10, 0.96)))
	layer.add_child(panel)
	metrics_button = Button.new()
	metrics_button.focus_mode = Control.FOCUS_NONE
	metrics_button.text = "FPS / rede"
	metrics_button.tooltip_text = "Diagnóstico de desempenho · F3 ou toque"
	hud.get_node("Controls/Rows").add_child(metrics_button)
	metrics_button.pressed.connect(func(): metrics_panel.visible = not metrics_panel.visible)
	metrics_panel = PanelContainer.new()
	metrics_panel.add_theme_stylebox_override("panel", IslandTheme.panel(Color(0.05, 0.13, 0.10, 0.97)))
	layer.add_child(metrics_panel)
	metrics_panel.hide()
	var metrics_rows := VBoxContainer.new()
	metrics_panel.add_child(metrics_rows)
	metrics_text = label(metrics_rows, "Aguardando amostras…")
	prediction_button = button(metrics_rows, "Previsão local: ligada", toggle_prediction)
	graphics_button = button(metrics_rows, "Gráficos: econômicos (1×)", toggle_graphics)
	graphics_button.visible = OS.has_feature("web")
	button(metrics_rows, "Fechar diagnóstico", func(): metrics_panel.hide())
	var rows := VBoxContainer.new()
	panel.add_child(rows)
	status = label(rows, "Conectando à sala de teste…")
	diagnostic = label(rows, "")
	counts = label(rows, "Seu inventário · aguardando servidor")
	prompt = label(rows, "WASD / setas · F cortar/minerar · E pegar / poço · I inventário")
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
		JavaScriptBridge.eval("document.body.classList.add('tc-multiplayer'); if (!document.getElementById('tc-mp-style')) {const s=document.createElement('style');s.id='tc-mp-style';s.textContent='body.tc-multiplayer #chat-launch{top:max(8px,env(safe-area-inset-top));bottom:auto;}body.tc-mp-connecting #chat-launch{left:auto;right:max(8px,env(safe-area-inset-right));width:80px;}body.tc-multiplayer #pilot-badge{display:none;}';document.head.appendChild(s);}")
		JavaScriptBridge.eval("if(window.tcMpSetDensity) window.tcMpSetDensity(1);")
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
	for actor in actors.values():
		actor.body.identity_label_size = name_font
		actor.body.queue_redraw()
	var unit := (44.0 if MobileInput.enabled else 36.0) / scale
	var font := int(ceilf(15 / scale))
	var margin := 8.0 / scale
	var width := minf(view.x - margin * 2, (620.0 if online else 520.0) / scale)
	# The offline card reserves a full touch row above it for the HTML Chat button.
	panel.position = Vector2(margin if online else (view.x - width) / 2, margin if online else 64.0 / scale)
	panel.size = Vector2(width, 0)
	var style := IslandTheme.panel(Color(0.05, 0.13, 0.10, 0.96))
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = 6 / scale
	style.content_margin_bottom = 6 / scale
	panel.add_theme_stylebox_override("panel", style)
	for item in [status, counts, prompt, notice]: item.add_theme_font_size_override("font_size", font)
	diagnostic.add_theme_font_size_override("font_size", ceili(12 / scale))
	for item in toolbar.get_children():
		item.custom_minimum_size = Vector2(unit * 1.65, unit)
		item.add_theme_font_size_override("font_size", font)
	for i in tool_buttons.size():
		tool_buttons[i].text = (["Machado", "Picareta", "Mãos"] if MobileInput.enabled else ["1 Machado", "2 Picareta", "3 Mãos"])[i]
	if is_instance_valid(overlay): overlay.layout()
	metrics_button.custom_minimum_size.y = (44.0 if MobileInput.enabled else 20.0) / scale
	metrics_button.add_theme_font_override("font", IslandTheme.BODY)
	metrics_button.add_theme_font_size_override("font_size", ceili(12 / scale))
	var metric_style := StyleBoxFlat.new()
	metric_style.bg_color = Color(0.04, 0.10, 0.08, 0.75)
	metric_style.content_margin_top = 2 / scale
	metric_style.content_margin_bottom = 2 / scale
	for kind in ["normal", "hover", "pressed"]: metrics_button.add_theme_stylebox_override(kind, metric_style)
	metrics_panel.position = Vector2(maxf(margin, (view.x - 350 / scale) / 2), 50 / scale)
	metrics_panel.size = Vector2(minf(view.x - 2 * margin, 350 / scale), 0)
	metrics_text.add_theme_font_size_override("font_size", ceili(12 / scale))
	metrics_text.add_theme_font_override("font", IslandTheme.BODY)
	for item in metrics_panel.get_child(0).get_children():
		if item is Button:
			item.custom_minimum_size.y = unit
			item.add_theme_font_size_override("font_size", ceili(12 / scale))
	refresh_controls()

func toggle_prediction() -> void:
	prediction.enabled = not prediction.enabled
	if actors.has(self_id): prediction.reset(actors[self_id].target)
	prediction_button.text = "Previsão local: " + ("ligada" if prediction.enabled else "desligada")

func toggle_graphics() -> void:
	economical = not economical
	if OS.has_feature("web"): JavaScriptBridge.eval("if(window.tcMpSetDensity) window.tcMpSetDensity(" + ("1" if economical else "2") + ");")
	graphics_button.text = "Gráficos: " + ("econômicos (1×)" if economical else "nativos (até 2×)")

func update_metrics() -> void:
	var info := metrics.summary()
	metrics_button.text = "%d FPS · RTT %d ms" % [roundi(info.fps), roundi(info.rtt)]
	metrics_text.text = "Cliente .7 · servidor %s / protocolo 3\nFPS %d · quadro p95 %.1f ms\nRTT med/p95 %.0f/%.0f ms · var p95 %.0f ms\nEstado p95 %.0f ms · aplicar p95 %.2f ms\nRecebe %.1f KB/s · envia %.1f KB/s\nEstados %.1f/s · entradas %.1f/s\nFila máx %d · estados reunidos %d\nCorreção %.1f u · buffer remoto %.0f ms" % [server_version.trim_prefix("0.9.0-multiplayer-pilot"), roundi(info.fps), info.frame_p95, info.rtt, info.rtt_p95, info.jitter, info.gap_p95, info.apply_p95 / 1000, info.rates.down / 1024, info.rates.up / 1024, info.rates.states, info.rates.inputs, info.queue_peak, info.coalesced, prediction.correction_size, remote_delay * 1000]

func refresh_controls() -> void:
	panel.visible = not online
	world_view.visible = online
	if OS.has_feature("web") and web_online != int(online):
		web_online = int(online)
		JavaScriptBridge.eval("document.body.classList.toggle('tc-mp-connecting', " + ("false" if online else "true") + ");")
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
		diagnostic.text = "Etapa: %s · cliente .7 / protocolo 3\n%s · tentativa %d%s" % [phase_name(failed_phase if failed_phase != "" else connection_phase), endpoint.trim_prefix("wss://").trim_prefix("ws://").get_slice("/", 0), maxi(1, attempts), " · código %d" % last_close_code if last_close_code > 0 else ""]
	if is_instance_valid(overlay):
		overlay.visible = MobileInput.enabled and online and hud.current_panel == ""
		overlay.collect.disabled = blocked() or drop_target == "" and well_target == ""
		overlay.harvest_button.disabled = blocked() or target == ""

func show_notice(text: String) -> void:
	notice.text = text
	notice_until = Time.get_ticks_msec() + 4500
	if is_instance_valid(hud) and online: hud.show_message(text)

func connect_room() -> void:
	if socket != null: socket.close()
	socket = null
	connection_generation += 1
	var generation := connection_generation
	if is_instance_valid(endpoint_request):
		endpoint_request.cancel_request()
		endpoint_request.queue_free()
	online = false
	greeted = false
	fatal = false
	elapsed = 0
	retry_in = 0
	input_seq = 0
	last_input_ack = 0
	pending_state.clear()
	metrics.sent_times.clear()
	last_movement = Vector2.ZERO
	last_token = ""
	last_state_at = 0
	failed_phase = ""
	set_connection_phase("connection")
	MobileInput.reset()
	layout()
	if account_owner == "" or FirebaseAuth.account_uid() != account_owner:
		fatal = true
		status.text = "Entre novamente na conta para acessar o multiplayer."
		return
	var discovery := str(CONFIG.read_config().get("discovery_url", ""))
	if discovery != "":
		endpoint = ""
		last_close_code = 0
		set_connection_phase("discovery")
		status.text = "Conferindo endereço atual do servidor…"
		endpoint_request = HTTPRequest.new()
		endpoint_request.timeout = 8
		endpoint_request.body_size_limit = 4096
		add_child(endpoint_request)
		var request := endpoint_request
		var requested := request.request(discovery + "?t=" + str(int(Time.get_unix_time_from_system())) + "-" + str(Time.get_ticks_msec()))
		if requested != OK:
			request.queue_free()
			disconnected("endpoint_unavailable")
			return
		var result: Array = await request.request_completed
		request.queue_free()
		if generation != connection_generation or not is_inside_tree(): return
		if result[0] == HTTPRequest.RESULT_SUCCESS and result[1] == 200:
			endpoint = CONFIG.endpoint_from_manifest(JSON.parse_string(result[3].get_string_from_utf8()))
		if endpoint == "":
			disconnected("endpoint_unavailable")
			return
	set_connection_phase("connection")
	if not endpoint.begins_with("wss://") and not endpoint.begins_with("ws://127.0.0.1:") and not endpoint.begins_with("ws://localhost:"):
		fatal = true
		status.text = "Servidor indisponível · endereço WSS ainda não configurado."
		return
	socket = WebSocketPeer.new()
	socket.inbound_buffer_size = 262144
	socket.max_queued_packets = 128
	var error := socket.connect_to_url(endpoint)
	status.text = "Conectando à sala de teste…"
	if error != OK: disconnected("server_unavailable")

func send(data: Dictionary) -> void:
	if socket != null and socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var text := JSON.stringify(data)
		metrics.sent_bytes += text.to_utf8_buffer().size()
		socket.send_text(text)

func blocked() -> bool:
	return not online or not focused or GlobalChat.opened or OrientationGuard.blocked or hud.current_panel != "" or FirebaseAuth.account_uid() != account_owner

func set_connection_phase(value: String) -> void:
	connection_phase = value
	phase_started = Time.get_ticks_msec()

func phase_name(value: String) -> String:
	return {"discovery":"endereço atual", "connection":"conexão WSS", "authentication":"autenticação", "initial_state":"estado inicial da sala", "playing":"partida"}.get(value, "conexão")

func _process(delta: float) -> void:
	if online:
		metrics.frame(delta)
		metrics_clock -= delta
		if metrics_clock <= 0:
			metrics_clock = 0.5
			update_metrics()
	# Autowrapped labels settle their minimum height after the first layout pass.
	# Shrink again instead of retaining the temporary full-screen panel height.
	camera.offset.y = -40.0 if MobileInput.enabled else 0.0
	controls_clock -= delta
	if controls_clock <= 0:
		controls_clock = 0.1
		panel.size.y = panel.get_combined_minimum_size().y
		metrics_panel.size.y = metrics_panel.get_combined_minimum_size().y
		refresh_controls()
	if fatal: return
	if retry_in > 0:
		retry_in -= delta
		status.text = connection_text + " · nova tentativa em %ds" % maxi(1, ceili(retry_in))
		if retry_in <= 0: connect_room()
		return
	if socket == null: return
	socket.poll()
	var state := socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not greeted:
			last_token = FirebaseAuth.access_token(account_owner)
			send({"type": "hello", "protocol": 3, "client_version": CLIENT_VERSION, "token": last_token})
			greeted = true
			set_connection_phase("authentication")
			status.text = "Validando conta no servidor…"
		metrics.queue_peak = maxi(metrics.queue_peak, socket.get_available_packet_count())
		var packet_budget := 96
		while socket.get_available_packet_count() > 0 and packet_budget > 0:
			packet_budget -= 1
			var packet := socket.get_packet()
			metrics.received_bytes += packet.size()
			var data: Variant = JSON.parse_string(packet.get_string_from_utf8())
			if data is Dictionary: receive(data)
		if not pending_state.is_empty():
			apply_state(pending_state)
			pending_state = {}
		if online:
			if Time.get_ticks_msec() - last_state_at > 5000:
				disconnected("state_timeout")
				return
			var token := FirebaseAuth.access_token(account_owner)
			if token != "" and token != last_token:
				last_token = token
				send({"type": "refresh", "token": token})
			var movement := Vector2.ZERO if blocked() or Time.get_ticks_msec() - last_state_at > 500 else (Input.get_vector("move_left", "move_right", "move_up", "move_down") + touch_vector).limit_length(1)
			input_clock -= delta
			if movement != last_movement and Time.get_ticks_msec() - last_input_sent >= 40: input_clock = 0
			if prediction.enabled and actors.has(self_id):
				actors[self_id].body.position = prediction.advance(movement, delta, input_seq + 1)
				var swimming := prediction.water(prediction.position)
				var redraw: bool = actors[self_id].body.swimming != swimming
				actors[self_id].body.swimming = swimming
				if movement.length() > 0.1 and actors[self_id].body.facing != movement:
					actors[self_id].body.facing = movement
					redraw = true
				if redraw: actors[self_id].body.queue_redraw()
			if input_clock <= 0:
				input_clock = 0.05 if movement.length() > 0.01 else 0.25
				input_seq += 1
				metrics.input_sent(input_seq)
				last_input_sent = Time.get_ticks_msec()
				send({"type": "input", "seq": input_seq, "x": movement.x, "y": movement.y})
				last_movement = movement
	elif state == WebSocketPeer.STATE_CLOSED:
		last_close_code = socket.get_close_code()
		disconnected(socket.get_close_reason())
	if not online:
		elapsed += delta
		if Time.get_ticks_msec() - phase_started > 15000: disconnected("server_unavailable")
	for id in actors:
		var actor: Dictionary = actors[id]
		if id == self_id and prediction.enabled: continue
		var frames: Array = actor.frames
		# Render a continuous server timeline rather than chasing a new target
		# every 100 ms. Never extrapolate through authoritative collisions.
		var desired := Time.get_ticks_msec() / 1000.0 - server_offset - remote_delay
		remote_time = maxf(remote_time, desired)
		var at := remote_time
		while frames.size() > 2 and frames[1].time <= at: frames.pop_front()
		if frames.size() >= 2:
			var ratio: float = clampf((at - frames[0].time) / maxf(0.001, frames[1].time - frames[0].time), 0, 1)
			actor.body.position = frames[0].position.lerp(frames[1].position, ratio)
		else: actor.body.position = actor.target
	name_clock -= delta
	if name_clock <= 0:
		name_clock = 0.1
		separate_names()
	if actors.has(self_id):
		camera.position = actors[self_id].body.position
		world_view.show_area(Rect2(camera.position + camera.offset - get_viewport_rect().size / 2, get_viewport_rect().size).grow(64))
		target_clock -= delta
		if target_clock <= 0:
			target_clock = 0.05
			update_target()
		hit_clock -= delta
		if held and not blocked() and hit_clock <= 0:
			hit_clock = ResourceRules.hit_interval(str(snapshot.get("tool", "maos")))
			harvest()

func receive(data: Dictionary) -> void:
	match str(data.get("type", "")):
		"authenticated":
			server_version = str(data.get("server_version", ""))
			set_connection_phase("initial_state")
			status.text = "Conta validada · recebendo a sala…"
		"welcome":
			if int(data.get("protocol", 0)) != 3 or str(data.world.get("hash", "")) != FileAccess.get_sha256(world_view.FILE):
				disconnected("client_outdated", true)
				return
			if room_id != "" and room_id != str(data.room): show_notice("Servidor reiniciado · uma nova sala de teste começou")
			room_id = str(data.room)
			self_id = str(data.self)
			action_seq = int(data.nextAction) - 1
			online = true
			set_connection_phase("playing")
			attempts = 0
			apply_state(data, true)
			if minimap == null:
				minimap = IslandMinimap.new()
				minimap.player = actors[self_id].body
				hud.add_child(minimap)
			layout()
		"state":
			if online:
				metrics.state_received()
				data["_input_ack"] = last_input_ack
				if not pending_state.is_empty():
					metrics.coalesced += 1
					for key in ["resources", "drops"]:
						if not data.has(key) and pending_state.has(key): data[key] = pending_state[key]
				pending_state = data
		"ack":
			if str(data.get("action", "")) == "input":
				metrics.acknowledge(int(data.seq))
				if data.get("ok", false): last_input_ack = maxi(last_input_ack, int(data.seq))
			if not data.get("ok", false) and str(data.get("action", "")) != "input":
				show_notice(error_text(str(data.get("code", ""))))
			elif data.get("ok", false) and data.get("action", "") == "well":
				hud.show_message("Cantil cheio · 3 doses" if data.get("effect", "") == "filled" else "Água potável · +40 água")
			elif data.get("ok", false) and data.get("action", "") == "use": hud.show_message("Você bebeu uma dose do cantil")
		"error":
			var code := str(data.get("code", ""))
			if code in ["not_authorized", "auth_failed", "auth_required", "room_full", "client_outdated"]: disconnected(code, true)

func apply_state(data: Dictionary, initial: bool = false) -> void:
	var apply_began := Time.get_ticks_usec()
	var world_changed := initial or data.has("resources") or data.has("drops")
	last_state_at = Time.get_ticks_msec()
	# Omitted world arrays mean unchanged, while [] explicitly removes all drops.
	if not data.has("resources"): data.resources = snapshot.get("resources", [])
	if not data.has("drops"): data.drops = snapshot.get("drops", [])
	snapshot = data
	inventory = data.inventory.duplicate()
	projected_inventory.apply_network_state(data.slots)
	var needs := Vector4(float(data.health), float(data.max_health), float(data.hunger), float(data.thirst))
	if initial or needs.x != last_needs.x or needs.y != last_needs.y: hud.update_health(needs.x, needs.y)
	if initial or needs.z != last_needs.z or absf(needs.w - last_needs.w) >= 0.1:
		hud.update_needs(needs.z, needs.w)
		last_needs.z = needs.z
		last_needs.w = needs.w
	last_needs.x = needs.x
	last_needs.y = needs.y
	var stamp: float = float(data.time) / 1000.0
	if initial:
		server_offset = Time.get_ticks_msec() / 1000.0 - stamp
		remote_time = stamp - remote_delay
	else:
		var observed := Time.get_ticks_msec() / 1000.0 - stamp
		server_offset = minf(server_offset + 0.001, observed)
		remote_delay = clampf(0.12 + metrics.jitter() / 1000, 0.12, 0.22)
	if initial:
		prediction.depleted.clear()
		for node in nodes.values():
			node.visible = true
			node.exhausted = false
			node.progress = 0.0
			node.queue_redraw()
	if world_changed:
		for r in data.resources:
			if r.depleted: prediction.depleted[str(r.id)] = true
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
			actors[id] = {"body": body, "target": body.position, "swing": int(p.get("swing", 0)), "frames": []}
		var actor: Dictionary = actors[id]
		actor.target = Vector2(p.x, p.y)
		if id == self_id:
			if initial or not prediction.enabled: prediction.reset(actor.target)
			else: prediction.reconcile(actor.target, int(data.get("_input_ack", last_input_ack)))
		if initial:
			actor.body.position = actor.target
			actor.swing = int(p.get("swing", 0))
			actor.frames.clear()
		actor.frames.append({"time": stamp, "position": actor.target})
		while actor.frames.size() > 8: actor.frames.pop_front()
		var identity := str(p.nickname) + (" · você" if id == self_id else "") + (" · offline" if not p.online else "")
		var appearance_changed: bool = actor.body.identity_label != identity
		actor.body.identity_label = identity
		actor.body.identity_color = Color("d9a441") if id == self_id else Color("71b5d1")
		actor.body.identity_label_size = name_font
		actor.body.modulate.a = 1.0 if p.online else 0.4
		if actor.body.equipped != str(p.tool): actor.body.show_equipment(str(p.tool))
		var swimming := bool(p.get("swimming", false))
		if actor.body.swimming != swimming: appearance_changed = true
		actor.body.swimming = swimming
		if int(p.get("swing", 0)) > actor.swing:
			actor.swing = int(p.swing)
			actor.body.show_swing((Vector2(p.sx, p.sy) - actor.body.position).normalized(), 55)
		if Vector2(p.dx, p.dy).length() > 0 and actor.body.facing != Vector2(p.dx, p.dy):
			actor.body.facing = Vector2(p.dx, p.dy)
			appearance_changed = true
		if appearance_changed: actor.body.queue_redraw()
	for id in actors.keys():
		if id not in present: actors[id].body.queue_free(); actors.erase(id)
	if world_changed:
		for r in data.resources:
			var id := str(r.id)
			if not nodes.has(id): continue
			var node: HarvestResource = nodes[id]
			if node.exhausted != bool(r.depleted) or node.progress != float(r.progress):
				node.visible = not r.depleted
				node.exhausted = bool(r.depleted)
				node.progress = float(r.progress)
				node.queue_redraw()
		var remaining := []
		for item in data.drops:
			var id := str(item.id)
			remaining.append(id)
			if not drops.has(id):
				var drop := ResourceDrop.new()
				drop.resource = str(item.kind)
				drop.quantity = int(item.quantity)
				drop.position = Vector2(item.x, item.y)
				world_view.objects.add_child(drop)
				drops[id] = drop
			elif drops[id].quantity != int(item.quantity):
				drops[id].quantity = int(item.quantity)
				drops[id].queue_redraw()
		for id in drops.keys():
			if id not in remaining:
				drops[id].queue_free()
				drops.erase(id)
		snapshot["_applied_world"] = data.get("world_revision", -1)
	status.text = "Multiplayer · sala %d/2 · conectado · piloto .7" % connected
	var region := WorldTerrain.region_at(actors[self_id].target)
	hud.get_node("Controls/Rows/Time").text = "MP .7 · %d/2 · %s" % [connected, str(region.get("kind", "Ilha"))]
	counts.text = "Seu inventário · Madeira %d · Pedra %d · %s" % [int(inventory.get("madeira", 0)), int(inventory.get("pedra", 0)), tool_name(str(data.tool))]
	retry.visible = false
	last_apply_us = Time.get_ticks_usec() - apply_began
	metrics.sample(metrics.apply_times, last_apply_us)

func tool_name(tool: String) -> String:
	return {"maos": "Mãos", "machado_madeira": "Machado de madeira", "picareta_madeira": "Picareta de madeira"}.get(tool, tool)

func update_target() -> void:
	target = ""
	well_target = ""
	drop_target = ""
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
	var drop_distance := 58.01
	for id in drops:
		var distance := position_now.distance_to(drops[id].position)
		if distance < drop_distance:
			drop_target = id
			drop_distance = distance
	if previous_target != target and nodes.has(previous_target): nodes[previous_target].set_highlighted(false)
	if previous_well != well_target and world_view.wells.has(previous_well): world_view.wells[previous_well].set_highlighted(false)
	if previous_drop != drop_target and drops.has(previous_drop): drops[previous_drop].set_highlighted(false)
	if nodes.has(target): nodes[target].set_highlighted(online)
	if world_view.wells.has(well_target): world_view.wells[well_target].set_highlighted(online)
	if drops.has(drop_target): drops[drop_target].set_highlighted(online)
	previous_target = target
	previous_well = well_target
	previous_drop = drop_target
	if drop_target != "":
		var drop: ResourceDrop = drops[drop_target]
		prompt.text = ("Pegar" if MobileInput.enabled else "E · Pegar") + " %d %s" % [drop.quantity, ItemCatalog.title(drop.resource)]
	elif well_target != "" and well_distance < closest:
		prompt.text = "Interagir · poço" if MobileInput.enabled else "E · Usar poço"
	elif target != "":
		var kind: String = nodes[target].resource
		var valid: bool = str(snapshot.tool) in ResourceRules.EXTRACTION[kind].hits
		prompt.text = ("Toque em Extrair" if MobileInput.enabled else "F · Extrair") + " " + {"madeira": "árvore", "pedra": "pedra", "fibra": "arbusto"}[kind] if valid else ResourceRules.guidance(kind)
	else: prompt.text = ""
	hud.show_target(prompt.text)
	if is_instance_valid(overlay):
		overlay.collect.text = "Pegar" if drop_target != "" else "Interagir"
		overlay.collect.disabled = blocked() or drop_target == "" and well_target == ""

func interact() -> void:
	if blocked(): return
	# E never harvests: resource rewards require an explicit server pickup.
	if drop_target != "":
		request_action("pickup", drop_target)
		return
	if well_target != "":
		var well: WaterWell = world_view.wells[well_target]
		hud.open_well(well)

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
		"pickup": message.drop = str(argument)
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
	failed_phase = connection_phase
	online = false
	held = false
	hud.set_panel("")
	touch_vector = Vector2.ZERO
	MobileInput.reset()
	if socket != null: socket.close()
	fatal = terminal or reason in ["not_authorized", "auth_failed", "auth_required", "room_full", "session_replaced"]
	status.text = error_text(reason)
	if not fatal and reason != "state_timeout":
		status.text = {"connection":"Servidor inacessível · falha na conexão WSS", "authentication":"Conexão aberta · autenticação não concluída", "initial_state":"Conta validada · sala não recebida", "playing":"Conexão com a sala interrompida"}.get(failed_phase, status.text)
	connection_text = status.text
	retry.visible = true
	layout()
	if not fatal:
		attempts += 1
		retry_in = minf(8, pow(2, mini(attempts - 1, 3)))
		status.text += " · reconectando…"

func error_text(code: String) -> String:
	if code == "endpoint_unavailable": return "Não foi possível consultar o endereço atual · confira a rede e tente novamente."
	if code == "client_outdated": return "Atualize a página para carregar o piloto .7 e o mesmo mundo do servidor."
	if code == "blocked_path": return "Há um obstáculo no caminho. Aproxime-se pelo acesso livre."
	if code == "inventory_full": return "Inventário cheio · libere espaço antes de coletar."
	if code == "drop_unavailable": return "Este item já foi pego."
	if code == "canteen_unavailable": return "Tenha um cantil com espaço para água."
	if code == "canteen_empty": return "Cantil vazio · encha em um poço."
	if code in ["invalid_slot", "invalid_item"]: return "Selecione um item disponível no inventário."
	if code == "state_timeout": return "Sem resposta da sala · controles pausados"
	return {"not_authorized": "Esta conta não está autorizada para o piloto.", "room_full": "Sala cheia · limite de dois jogadores.", "auth_failed": "Não foi possível validar a conta. Volte ao menu e entre novamente.", "auth_required": "Entre na conta para acessar esta sala.", "session_replaced": "Conta conectada em outro aparelho. Esta conexão foi encerrada.", "too_far": "Aproxime-se do recurso para coletar.", "wrong_tool": "Equipe a ferramenta indicada para este recurso.", "cooldown": "Aguarde o intervalo entre golpes.", "resource_unavailable": "Este recurso já foi coletado.", "invalid_tool": "Ferramenta não disponível no seu inventário.", "replayed_action": "Ação repetida recusada pelo servidor."}.get(code, "Conexão perdida ou servidor indisponível")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3:
		metrics_panel.visible = not metrics_panel.visible
		get_viewport().set_input_as_handled()
		return
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
	if OS.has_feature("web"): JavaScriptBridge.eval("document.body.classList.remove('tc-multiplayer', 'tc-mp-connecting')")
	if OS.has_feature("web"): JavaScriptBridge.eval("if(window.tcMpSetDensity) window.tcMpSetDensity(1);")
	if socket != null: socket.close(1000, "leave")
	last_token = ""
	if MobileInput.overlay == overlay: MobileInput.overlay = null
	MobileInput.reset()

func _draw() -> void:
	pass
