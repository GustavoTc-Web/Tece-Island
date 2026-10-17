extends Node

signal panel_changed
signal changed
const POLL_SECONDS := 5.0
const IDLE_POLL_SECONDS := 15.0
const IDLE_AFTER_SECONDS := 60.0
const REFRESH_SECONDS := 120.0
var client: ChatClient
var config := {}
var uid := ""
var opened := false
var nickname := ""
var editing_nickname := false
var connection_error := ""
var last_sync := ""
var last_attempt := -5000
var session_epoch := -1
var was_foreground := true
var messages: Array = []
var muted: Array = []
var admin := false
var busy := false
var reading := false
var initialized := false
var status := ""
var cooldown_until := 0
var clear_draft := 0
var next_poll := 0
var next_full := 0
var next_metadata := 0
var last_activity := 0
var sequence := 0
var failures := 0
var web_callback: JavaScriptObject
var native_panel: CanvasLayer
var last_countdown := -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://config/global-chat.json"))
	config = parsed if parsed is Dictionary else {}
	client = ChatClient.new()
	client.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(client)
	FirebaseAuth.signed_out.connect(func(_reason): reset_session())
	if OS.has_feature("web"):
		web_callback = JavaScriptBridge.create_callback(_web_action)
		JavaScriptBridge.get_interface("window").tcChat.mount(web_callback)
	else:
		native_panel = preload("res://scripts/chat/chat_panel.gd").new()
		add_child(native_panel)
	changed.connect(render)
	# Exactly one timer, owned by the service, independent of panel/game pause.
	var timer := Timer.new()
	timer.process_mode = Node.PROCESS_MODE_ALWAYS
	timer.wait_time = 0.5
	timer.timeout.connect(poll_due)
	add_child(timer)
	timer.start()

func available() -> bool:
	return config.get("enabled", false) == true and uid != "" and uid in config.get("allowed_uids", [])

func reset_session() -> void:
	uid = ""
	session_epoch = -1
	opened = false
	client.cancel()
	nickname = ""
	editing_nickname = false
	connection_error = ""
	last_sync = ""
	last_attempt = -5000
	messages.clear()
	muted.clear()
	admin = false
	busy = false
	reading = false
	initialized = false
	status = ""
	cooldown_until = 0
	next_poll = 0
	next_full = 0
	next_metadata = 0
	last_activity = 0
	sequence = 0
	failures = 0
	clear_draft += 1
	MobileInput.reset()
	panel_changed.emit()
	changed.emit()

func _process(_delta: float) -> void:
	var account := FirebaseAuth.account_uid()
	if account != uid or (account != "" and session_epoch != FirebaseAuth.session_generation()):
		reset_session()
		uid = account
		session_epoch = FirebaseAuth.session_generation()
		if uid != "":
			var path := mute_path()
			if OS.has_feature("web") or FileAccess.file_exists(path):
				var saved: Variant = JSON.parse_string(str(JavaScriptBridge.eval("(()=>{try{return localStorage.getItem(" + JSON.stringify("tc-chat-mutes/" + uid.sha256_text()) + ")||'[]';}catch(e){return '[]';}})()"))) if OS.has_feature("web") else JSON.parse_string(FileAccess.get_file_as_string(path))
				if saved is Array: muted = saved.slice(0, 100)
		changed.emit()
	if not available(): return
	var visible := foreground()
	if visible and not was_foreground: wake()
	was_foreground = visible
	var countdown := remaining()
	if countdown != last_countdown:
		last_countdown = countdown
		changed.emit()

func poll_due() -> void:
	if not available() or not opened or reading or busy or not foreground(): return
	if Time.get_ticks_msec() < next_poll: return
	last_attempt = Time.get_ticks_msec()
	if initialized: refresh()
	else: initialize()

func wake() -> void:
	# Focus, online and pageshow events coalesce; retain quota/permission backoff.
	if failures == 0 or connection_error.begins_with("Sem conexão"):
		last_activity = Time.get_ticks_msec()
		next_poll = mini(next_poll, maxi(Time.get_ticks_msec(), last_attempt + 5000))

func current(owner: String, epoch: int) -> bool:
	return owner == uid and epoch == FirebaseAuth.session_generation() and epoch == session_epoch

func continue_read(owner: String, epoch: int) -> bool:
	if not current(owner, epoch): return false
	# Let the one in-flight request finish, but don't start the next stage while
	# closed/hidden. Reopening resumes from the cache; writes aren't cancelled.
	if not opened or not foreground():
		reading = false
		changed.emit()
		return false
	return true

func wait_for_read(owner: String, epoch: int) -> bool:
	while reading and current(owner, epoch): await changed
	return current(owner, epoch)

func read_failed(result: Dictionary) -> void:
	reading = false
	failures = mini(6, failures + 1)
	next_poll = Time.get_ticks_msec() + int(minf(240, POLL_SECONDS * pow(2, failures)) * 1000)
	connection_error = failure(result, "Atualização")
	changed.emit()

func foreground() -> bool:
	return not bool(JavaScriptBridge.eval("document.hidden")) if OS.has_feature("web") else true

func remaining() -> int:
	return maxi(0, ceili((cooldown_until - Time.get_ticks_msec()) / 1000.0))

func toggle() -> void:
	if not available(): return
	opened = not opened
	MobileInput.reset()
	panel_changed.emit()
	changed.emit()
	if opened: poll_due()

func initialize() -> void:
	if reading or busy or not available(): return
	var owner := uid
	var epoch := FirebaseAuth.session_generation()
	reading = true
	status = "Conectando ao chat…"
	changed.emit()
	var settings := await client.settings(owner)
	if not continue_read(owner, epoch): return
	if not settings.ok: read_failed(settings); return
	var raw: Dictionary = settings.data.get("fields", {})
	admin = owner in raw.get("admin_uids", {}).get("arrayValue", {}).get("values", []).map(func(v): return str(v.get("stringValue", "")))
	var profile := await client.read_document(owner, "chatProfiles", owner)
	if not continue_read(owner, epoch): return
	if not profile.ok: read_failed(profile); return
	nickname = str(profile.get("document", {}).get("nickname", ""))
	next_metadata = Time.get_ticks_msec() + int(REFRESH_SECONDS * 1000)
	last_activity = Time.get_ticks_msec()
	reading = false
	initialized = true
	await refresh(true)

func refresh(full: bool = false) -> void:
	if reading or not initialized or uid == "": return
	reading = true
	var owner := uid
	var epoch := FirebaseAuth.session_generation()
	var query_warning := connection_error if connection_error.begins_with("Consulta incremental") else ""
	var recovered_query := false
	# Query directly: an empty incremental costs the same minimum as the old
	# counter heartbeat, without a second request when messages arrive.
	if not full and Time.get_ticks_msec() >= next_full:
		if not messages.is_empty():
			var count_result := await client.window_count(owner, int(messages.front().sequence), int(messages.back().sequence))
			if not continue_read(owner, epoch): return
			if not count_result.ok:
				read_failed(count_result)
				return
			full = int(count_result.count) != messages.size()
		next_full = Time.get_ticks_msec() + int(REFRESH_SECONDS * 1000)
	var result := await client.recent(owner, -1 if full else sequence)
	if not continue_read(owner, epoch): return
	if result.ok and not full: query_warning = ""
	# One bounded recovery on an unsupported incremental query; backoff all
	# transport, quota and permission errors instead of multiplying requests.
	if not result.ok and not full and int(result.get("status", 0)) in [400, 412, 500]:
		recovered_query = true
		query_warning = failure(result, "Consulta incremental") + " Recebimento recuperado pelo histórico."
		result = await client.recent(owner)
		full = true
		if not continue_read(owner, epoch): return
	if not result.ok: read_failed(result); return
	if not result.messages.is_empty(): last_activity = Time.get_ticks_msec()
	if full:
		messages.clear()
		next_full = Time.get_ticks_msec() + int(REFRESH_SECONDS * 1000)
	for item in result.messages:
		messages = messages.filter(func(old): return old.id != item.id)
		messages.append(item)
		sequence = maxi(sequence, int(item.sequence))
	messages.sort_custom(func(a, b): return int(a.sequence) < int(b.sequence))
	messages = messages.slice(maxi(0, messages.size() - 50))
	if Time.get_ticks_msec() >= next_metadata:
		var profile := await client.read_document(owner, "chatProfiles", owner)
		if not continue_read(owner, epoch): return
		if not profile.ok: read_failed(profile); return
		nickname = str(profile.get("document", {}).get("nickname", ""))
		var settings := await client.settings(owner)
		if not continue_read(owner, epoch): return
		if not settings.ok: read_failed(settings); return
		var raw: Dictionary = settings.data.get("fields", {})
		admin = owner in raw.get("admin_uids", {}).get("arrayValue", {}).get("values", []).map(func(v): return str(v.get("stringValue", "")))
		next_metadata = Time.get_ticks_msec() + int(REFRESH_SECONDS * 1000)
	reading = false
	# A persistent index error must not turn every 5 s poll into a 50-document
	# download. Keep receiving via bounded recovery, with the same error backoff.
	failures = mini(6, failures + 1) if recovered_query else 0
	connection_error = query_warning
	last_sync = Time.get_time_string_from_system()
	if not busy: status = "Chat global · até 50 mensagens recentes"
	next_poll = Time.get_ticks_msec() + int(poll_seconds() * 1000)
	if recovered_query:
		next_poll = maxi(next_poll, Time.get_ticks_msec() + int(minf(240, POLL_SECONDS * pow(2, failures)) * 1000))
	changed.emit()

func poll_seconds() -> float:
	return IDLE_POLL_SECONDS if Time.get_ticks_msec() - last_activity >= int(IDLE_AFTER_SECONDS * 1000) else POLL_SECONDS

static func valid_nickname(value: String) -> bool:
	return RegEx.create_from_string("^[A-Za-z0-9_À-ÖØ-öø-ÿ -]{2,20}$").search(value) != null and value == value.strip_edges()

func edit_nickname() -> void:
	if busy or not initialized: return
	editing_nickname = true
	changed.emit()

func cancel_nickname() -> void:
	if busy: return
	editing_nickname = false
	changed.emit()

func save_nickname(value: String) -> void:
	if busy or not initialized or not available(): return
	value = value.strip_edges()
	if not valid_nickname(value):
		status = "Use 2 a 20 letras, números, espaços, _ ou hífen. Evite dados pessoais."
		changed.emit()
		return
	var owner := uid
	var epoch := FirebaseAuth.session_generation()
	busy = true
	status = "Salvando apelido…"
	changed.emit()
	if not await wait_for_read(owner, epoch): return
	var result := await client.set_nickname(owner, value)
	if not current(owner, epoch): return
	busy = false
	if result.ok:
		nickname = value
		editing_nickname = false
		status = "Apelido salvo para esta conta."
	else: status = failure(result, "Salvar apelido")
	changed.emit()

func send_text(value: String) -> void:
	if busy or not initialized or nickname == "" or remaining() > 0 or not available(): return
	value = value.strip_edges()
	if value.is_empty() or value.length() > 200:
		status = "Escreva de 1 a 200 caracteres."
		changed.emit()
		return
	var owner := uid
	var epoch := FirebaseAuth.session_generation()
	busy = true
	status = "Enviando…"
	changed.emit()
	if not await wait_for_read(owner, epoch): return
	# Resolve changes made on another device before stamping the next message.
	var profile := await client.read_document(owner, "chatProfiles", owner)
	if not current(owner, epoch): return
	var result := profile
	if profile.ok:
		nickname = str(profile.get("document", {}).get("nickname", ""))
		result = await client.send_message(owner, nickname, value)
	if not current(owner, epoch): return
	busy = false
	if result.ok:
		clear_draft += 1
		cooldown_until = Time.get_ticks_msec() + 5000
		status = "Mensagem enviada."
		last_activity = Time.get_ticks_msec()
		changed.emit()
		if not reading: await refresh()
	else:
		if result.get("status", 0) == 403: cooldown_until = Time.get_ticks_msec() + 5000
		status = failure(result) + " Texto preservado. Confira o histórico antes de reenviar."
	changed.emit()

func failure(result: Dictionary, operation: String = "Chat") -> String:
	var http := int(result.get("status", 0))
	var code := str(result.get("code", ""))
	# Show safe codes only, never backend payloads, tokens or account identifiers.
	if RegEx.create_from_string("^[A-Z_0-9]{1,60}$").search(code) == null: code = ""
	var detail := " (HTTP %d%s)" % [http, " · " + code if code != "" else ""] if http > 0 else ""
	match int(result.get("status", 0)):
		401: return operation + ": sessão expirada. Entre novamente." + detail
		403: return operation + ": acesso negado. Confira e-mail verificado, acesso e regras; no envio, aguarde 5 s." + detail
		404: return operation + ": chat não configurado no Firebase." + detail
		429: return operation + ": cota do serviço atingida. Tente mais tarde." + detail
		400, 412: return operation + ": consulta recusada. Confira as regras e o índice de sequence." + detail
		409: return operation + ": alteração simultânea. Tente novamente." + detail
		0: return "Sem conexão no chat. Reconexão automática enquanto aberto." + (" (" + code + ")" if code != "" else "")
	return operation + ": falha do serviço. Reconexão automática." + detail

func mute_path() -> String: return "user://chat-mutes-" + uid.sha256_text() + ".json"

func mute(author: String) -> void:
	if author != uid and not author in muted: muted.append(author)
	if muted.size() > 100: muted.pop_front()
	persist_mutes()

func persist_mutes() -> void:
	if uid == "": return
	var file := FileAccess.open(mute_path(), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(muted))
		file.close()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(()=>{try{localStorage.setItem(" + JSON.stringify("tc-chat-mutes/" + uid.sha256_text()) + "," + JSON.stringify(JSON.stringify(muted)) + ");}catch(e){}})()")
	changed.emit()

func remove_message(id: String) -> void:
	if not admin or busy: return
	var found := messages.filter(func(m): return m.id == id)
	if found.is_empty(): return
	var owner := uid
	var epoch := FirebaseAuth.session_generation()
	busy = true
	status = "Removendo mensagem…"
	changed.emit()
	if not await wait_for_read(owner, epoch): return
	var result := await client.remove_message(owner, id, found[0].update_time)
	if owner != uid or epoch != FirebaseAuth.session_generation(): return
	busy = false
	status = "Mensagem removida." if result.ok else failure(result)
	if result.ok: messages = messages.filter(func(m): return m.id != id)
	changed.emit()

func _web_action(args: Array) -> void:
	var action := str(args[0])
	var value := str(args[1]) if args.size() > 1 else ""
	match action:
		"toggle": toggle()
		"edit_nickname": edit_nickname()
		"cancel_nickname": cancel_nickname()
		"nickname": save_nickname(value)
		"send": send_text(value)
		"mute": mute(value)
		"unmute": muted.clear(); persist_mutes()
		"remove": remove_message(value)
		"wake": wake()
		"retry":
			if not connection_error.is_empty() and Time.get_ticks_msec() >= next_poll: poll_due()

func view_state() -> Dictionary:
	return {"uid": uid, "available": available(), "opened": opened, "nickname": nickname, "editing_nickname": editing_nickname, "messages": messages.filter(func(m): return not str(m.uid) in muted), "muted": muted.size(), "admin": admin, "busy": busy, "ready": initialized, "status": status, "connection_error": connection_error, "last_sync": last_sync, "retry_seconds": maxi(0, ceili((next_poll - Time.get_ticks_msec()) / 1000.0)), "remaining": remaining(), "clear_draft": clear_draft}

func render() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.tcChat.render(" + JSON.stringify(view_state()) + ")")
