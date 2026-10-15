extends Node

signal panel_changed
signal changed
const POLL_SECONDS := 15.0
const REFRESH_SECONDS := 120.0
var client: ChatClient
var config := {}
var uid := ""
var opened := false
var nickname := ""
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
	add_child(client)
	FirebaseAuth.signed_out.connect(func(_reason): reset_session())
	if OS.has_feature("web"):
		web_callback = JavaScriptBridge.create_callback(_web_action)
		JavaScriptBridge.get_interface("window").tcChat.mount(web_callback)
	else:
		native_panel = preload("res://scripts/chat/chat_panel.gd").new()
		add_child(native_panel)
	changed.connect(render)

func available() -> bool:
	return config.get("enabled", false) == true and uid != "" and uid in config.get("allowed_uids", [])

func reset_session() -> void:
	uid = ""
	opened = false
	client.cancel()
	nickname = ""
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
	sequence = 0
	failures = 0
	clear_draft += 1
	MobileInput.reset()
	panel_changed.emit()
	changed.emit()

func _process(_delta: float) -> void:
	var account := FirebaseAuth.account_uid()
	if account != uid:
		reset_session()
		uid = account
		if uid != "":
			var path := mute_path()
			if OS.has_feature("web") or FileAccess.file_exists(path):
				var saved: Variant = JSON.parse_string(str(JavaScriptBridge.eval("(()=>{try{return localStorage.getItem(" + JSON.stringify("tc-chat-mutes/" + uid.sha256_text()) + ")||'[]';}catch(e){return '[]';}})()"))) if OS.has_feature("web") else JSON.parse_string(FileAccess.get_file_as_string(path))
				if saved is Array: muted = saved.slice(0, 100)
		changed.emit()
	if not available(): return
	var countdown := remaining()
	if countdown != last_countdown:
		last_countdown = countdown
		changed.emit()
	if opened and not reading and Time.get_ticks_msec() >= next_poll and foreground():
		if initialized: refresh()
		else: initialize()

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
	if opened and not initialized and not reading: initialize()
	elif opened and Time.get_ticks_msec() >= next_poll and not reading: refresh(true)

func initialize() -> void:
	if reading or uid == "": return
	var owner := uid
	var epoch := FirebaseAuth.session_generation()
	reading = true
	status = "Conectando ao chat…"
	changed.emit()
	var settings := await client.settings(owner)
	if owner != uid or epoch != FirebaseAuth.session_generation(): return
	if not settings.ok:
		reading = false
		failures = mini(4, failures + 1)
		next_poll = Time.get_ticks_msec() + int(POLL_SECONDS * pow(2, failures) * 1000)
		status = failure(settings)
		changed.emit()
		return
	var raw: Dictionary = settings.data.get("fields", {})
	admin = owner in raw.get("admin_uids", {}).get("arrayValue", {}).get("values", []).map(func(v): return str(v.get("stringValue", "")))
	var profile := await client.read_document(owner, "chatProfiles", owner)
	if owner != uid or epoch != FirebaseAuth.session_generation(): return
	if not profile.ok:
		reading = false
		failures = mini(4, failures + 1)
		next_poll = Time.get_ticks_msec() + int(POLL_SECONDS * pow(2, failures) * 1000)
		status = failure(profile)
		changed.emit()
		return
	nickname = str(profile.get("document", {}).get("nickname", ""))
	reading = false
	initialized = true
	await refresh(true)

func refresh(full: bool = false) -> void:
	if reading or not initialized or uid == "": return
	reading = true
	var owner := uid
	var epoch := FirebaseAuth.session_generation()
	full = full or Time.get_ticks_msec() >= next_full
	var result := await client.recent(owner, 0 if full else sequence)
	if owner != uid or epoch != FirebaseAuth.session_generation(): return
	reading = false
	if result.ok:
		if full: messages.clear()
		for item in result.messages:
			messages = messages.filter(func(old): return old.id != item.id)
			messages.append(item)
			sequence = maxi(sequence, int(item.sequence))
		messages.sort_custom(func(a, b): return int(a.sequence) < int(b.sequence))
		messages = messages.slice(maxi(0, messages.size() - 50))
		if full: next_full = Time.get_ticks_msec() + int(REFRESH_SECONDS * 1000)
		failures = 0
		if not busy: status = "Chat global · até 50 mensagens recentes"
	else:
		failures = mini(4, failures + 1)
		status = failure(result)
	next_poll = Time.get_ticks_msec() + int(POLL_SECONDS * pow(2, failures) * 1000)
	changed.emit()

static func valid_nickname(value: String) -> bool:
	return RegEx.create_from_string("^[A-Za-z0-9_À-ÖØ-öø-ÿ -]{2,20}$").search(value) != null and value == value.strip_edges()

func save_nickname(value: String) -> void:
	if busy or not initialized or nickname != "": return
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
	var result := await client.set_nickname(owner, value)
	if owner != uid or epoch != FirebaseAuth.session_generation(): return
	# Another tab may already have chosen the account's immutable nickname.
	if result.ok: nickname = value
	else:
		var existing := await client.read_document(owner, "chatProfiles", owner)
		if owner != uid or epoch != FirebaseAuth.session_generation(): return
		nickname = str(existing.get("document", {}).get("nickname", ""))
	busy = false
	status = "Apelido definido. Você já pode conversar." if nickname != "" else failure(result)
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
	var result := await client.send_message(owner, nickname, value)
	if owner != uid or epoch != FirebaseAuth.session_generation(): return
	busy = false
	if result.ok:
		clear_draft += 1
		cooldown_until = Time.get_ticks_msec() + 5000
		status = "Mensagem enviada."
		# A full refresh also reconciles ambiguous prior sends and moderation.
		changed.emit()
		if not reading: await refresh(true)
	else:
		if result.get("status", 0) == 403: cooldown_until = Time.get_ticks_msec() + 5000
		status = failure(result) + " Texto preservado. Confira o histórico antes de reenviar."
	changed.emit()

func failure(result: Dictionary) -> String:
	match int(result.get("status", 0)):
		401: return "Sessão do chat expirada. Entre novamente."
		403: return "Envio/acesso negado. Aguarde 5 s entre mensagens; confira e-mail verificado e acesso ao piloto."
		404: return "Chat ainda não configurado no Firebase. A partida continua disponível."
		429: return "Limite gratuito do chat atingido. Tente mais tarde."
		409, 412: return "Outra mensagem chegou ao mesmo tempo. Tente novamente."
	return "Chat sem conexão. Tentaremos reconectar enquanto estiver aberto."

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
		"nickname": save_nickname(value)
		"send": send_text(value)
		"mute": mute(value)
		"unmute": muted.clear(); persist_mutes()
		"remove": remove_message(value)
		"retry":
			if not initialized: initialize()
			elif not reading and Time.get_ticks_msec() >= next_poll: refresh(true)

func view_state() -> Dictionary:
	return {"uid": uid, "available": available(), "opened": opened, "nickname": nickname, "messages": messages.filter(func(m): return not str(m.uid) in muted), "muted": muted.size(), "admin": admin, "busy": busy, "ready": initialized, "status": status, "remaining": remaining(), "clear_draft": clear_draft}

func render() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.tcChat.render(" + JSON.stringify(view_state()) + ")")
