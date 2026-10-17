extends Node

signal authenticated
signal signed_out(reason: String)
signal message_changed(text: String)
signal busy_changed(value: bool)
signal verification_required

const CONFIG := preload("res://scripts/auth/firebase_config.gd")
const AUTH_API := "https://identitytoolkit.googleapis.com/v1/accounts:"
const TOKEN_API := "https://securetoken.googleapis.com/v1/token"
var config: Dictionary = {}
var busy := false
var user_email := ""
var _user_id := ""
var _id_token := ""
var _refresh_token := ""
var _expires_at := 0.0
var _verified := false
var _generation := 0
var _retry_at := 0.0
var before_logout: Callable
var logging_out := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	config = CONFIG.read_config()

func enabled() -> bool:
	return bool(config.get("enabled", true))

func configured() -> bool:
	return bool(config.get("configured", false))

func has_session() -> bool:
	return _verified and not _id_token.is_empty() and Time.get_unix_time_from_system() < _expires_at

func can_play() -> bool:
	return not logging_out and (not enabled() or has_session())

func account_uid() -> String:
	return _user_id if has_session() and not logging_out else ""

func access_token(owner: String) -> String:
	return _id_token if owner != "" and account_uid() == owner else ""

func session_generation() -> int: return _generation

func _begin() -> bool:
	if busy: return false
	if not configured():
		message_changed.emit(str(config.get("error", "Firebase ainda não configurado.")))
		return false
	busy = true
	busy_changed.emit(true)
	message_changed.emit("Aguarde…")
	return true

func _end() -> void:
	busy = false
	busy_changed.emit(false)

func _error_message(code: String) -> String:
	match code.split(":")[0].strip_edges():
		"INVALID_LOGIN_CREDENTIALS", "INVALID_PASSWORD", "EMAIL_NOT_FOUND":
			return "E-mail ou senha inválidos."
		"INVALID_EMAIL": return "Informe um e-mail válido."
		"EMAIL_EXISTS": return "Não foi possível criar a conta. Tente entrar ou recuperar a senha."
		"WEAK_PASSWORD": return "Use uma senha com pelo menos 6 caracteres."
		"PASSWORD_DOES_NOT_MEET_REQUIREMENTS": return "A senha não atende aos requisitos do projeto Firebase."
		"USER_DISABLED": return "Esta conta está desativada."
		"TOO_MANY_ATTEMPTS_TRY_LATER", "QUOTA_EXCEEDED":
			return "Limite temporário de tentativas ou e-mails. Tente novamente mais tarde."
		"INVALID_ID_TOKEN", "TOKEN_EXPIRED", "INVALID_REFRESH_TOKEN", "USER_NOT_FOUND":
			return "Sua sessão expirou. Entre novamente."
		"OPERATION_NOT_ALLOWED", "API_KEY_INVALID", "INVALID_API_KEY", "PROJECT_NUMBER_MISMATCH", "API_KEY_SERVICE_BLOCKED", "SERVICE_DISABLED":
			return "O serviço de autenticação precisa de configuração. Tente mais tarde."
		"API_KEY_HTTP_REFERRER_BLOCKED", "PERMISSION_DENIED":
			return "O Firebase bloqueou o acesso deste endereço. Confira a autorização do endereço e da chave no projeto. Seus saves locais foram preservados."
		"UNAUTHORIZED_DOMAIN", "INVALID_CONTINUE_URI":
			return "O endereço de retorno precisa ser autorizado no Firebase."
	return "Não foi possível concluir a autenticação. Tente novamente."

func _request(endpoint: String, payload: Dictionary, refresh: bool = false) -> Dictionary:
	var generation := _generation
	var http := HTTPRequest.new()
	http.timeout = 15
	# Fetch entrega o corpo já descomprimido na Web; evite descompressão dupla.
	http.accept_gzip = not OS.has_feature("web")
	add_child(http)
	var url: String = (TOKEN_API if refresh else AUTH_API + endpoint) + "?key=" + str(config.apiKey).uri_encode()
	var content_type := "application/x-www-form-urlencoded" if refresh else "application/json"
	var body := "grant_type=refresh_token&refresh_token=" + str(payload.get("refresh_token", "")).uri_encode() if refresh else JSON.stringify(payload)
	var error := http.request(url, PackedStringArray(["Content-Type: " + content_type, "X-Firebase-Locale: pt"]), HTTPClient.METHOD_POST, body)
	body = ""
	if error != OK:
		http.queue_free()
		return {"ok": false, "status": 0, "message": "Sem conexão com o serviço. Verifique a rede e tente novamente."}
	var response: Array = await http.request_completed
	http.queue_free()
	if generation != _generation: return {"ok": false, "cancelled": true}
	if response[0] != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "status": 0, "message": "Sem conexão com o serviço. Verifique a rede e tente novamente."}
	var data = JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
	if not data is Dictionary:
		return {"ok": false, "status": int(response[1]), "message": "Resposta inesperada do serviço. Tente novamente."}
	if int(response[1]) < 200 or int(response[1]) >= 300:
		var code: String = str(data.get("error", {}).get("message", ""))
		return {"ok": false, "status": int(response[1]), "message": _error_message(code)}
	return {"ok": true, "status": int(response[1]), "data": data}

func _report_failure(result: Dictionary) -> void:
	if not result.get("cancelled", false):
		message_changed.emit(str(result.get("message", "Não foi possível concluir. Tente novamente.")))

func _store_tokens(data: Dictionary, refresh: bool = false) -> bool:
	var id_token: String = str(data.get("id_token" if refresh else "idToken", ""))
	var refresh_token: String = str(data.get("refresh_token" if refresh else "refreshToken", ""))
	var duration := float(data.get("expires_in" if refresh else "expiresIn", 0))
	var user_id: String = str(data.get("user_id" if refresh else "localId", ""))
	if id_token.is_empty() or refresh_token.is_empty() or user_id.is_empty() or duration <= 0: return false
	if refresh and user_id != _user_id: return false
	_id_token = id_token
	_refresh_token = refresh_token
	_user_id = user_id
	_expires_at = Time.get_unix_time_from_system() + duration
	if not refresh: _verified = false
	return true

func _check_user(announce: bool = true) -> bool:
	var result := await _request("lookup", {"idToken": _id_token})
	if not result.get("ok", false):
		_report_failure(result)
		if result.get("status", 0) in [400, 401, 403]: logout("Sua sessão expirou. Entre novamente.")
		return false
	var users: Array = result.data.get("users", [])
	if users.is_empty() or not users[0] is Dictionary or str(users[0].get("localId", "")) != _user_id:
		logout("Não foi possível validar a conta. Entre novamente.")
		return false
	user_email = str(users[0].get("email", ""))
	_verified = users[0].get("emailVerified", false) is bool and users[0].get("emailVerified", false) == true
	if not _verified:
		message_changed.emit("Confirme seu e-mail pelo link recebido. Depois entre novamente ou use Já confirmei.")
		verification_required.emit()
		return false
	if announce:
		message_changed.emit("Conta validada.")
		authenticated.emit()
	return true

func login(email: String, password: String) -> void:
	if _verified and not await logout(): return
	if not _begin(): return
	_forget_tokens()
	var result := await _request("signInWithPassword", {"email": email.strip_edges(), "password": password, "returnSecureToken": true})
	password = ""
	if result.get("ok", false) and _store_tokens(result.data):
		await _check_user()
	else: _report_failure(result)
	_end()

func register(email: String, password: String) -> void:
	if _verified and not await logout(): return
	if not _begin(): return
	_forget_tokens()
	var result := await _request("signUp", {"email": email.strip_edges(), "password": password, "returnSecureToken": true})
	password = ""
	if result.get("ok", false) and _store_tokens(result.data):
		user_email = email.strip_edges()
		# Cadastro nunca abre o jogo: a confirmação é consultada no servidor depois.
		var sent := await _request("sendOobCode", {"requestType": "VERIFY_EMAIL", "idToken": _id_token, "continueUrl": config.continueUrl})
		message_changed.emit("Conta criada. Confirme seu e-mail pelo link recebido antes de entrar." if sent.get("ok", false) else "Conta criada, mas a confirmação não foi enviada. " + str(sent.get("message", "Tente mais tarde.")) + " Use Reenviar confirmação.")
		verification_required.emit()
	else: _report_failure(result)
	_end()

func resend_verification() -> void:
	if _id_token.is_empty():
		message_changed.emit("Entre com e-mail e senha para reenviar a confirmação.")
		return
	if not _begin(): return
	var result := await _request("sendOobCode", {"requestType": "VERIFY_EMAIL", "idToken": _id_token, "continueUrl": config.continueUrl})
	if result.get("ok", false): message_changed.emit("Confirmação enviada. Confira a caixa de entrada e spam.")
	else: _report_failure(result)
	_end()

func check_verification() -> void:
	if _id_token.is_empty():
		message_changed.emit("Entre novamente para validar a confirmação.")
		return
	if not _begin(): return
	# Lookup alone can report emailVerified=true while the old JWT still carries
	# email_verified=false. Rules inspect the JWT: refresh before authorizing play.
	_verified = false
	var result := await _request("", {"refresh_token": _refresh_token}, true)
	if result.get("ok", false) and _store_tokens(result.data, true):
		await _check_user()
	else: _report_failure(result)
	_end()

func recover_password(email: String) -> void:
	if not _begin(): return
	var result := await _request("sendOobCode", {"requestType": "PASSWORD_RESET", "email": email.strip_edges(), "continueUrl": config.continueUrl})
	if result.get("ok", false): message_changed.emit("Se o e-mail puder receber recuperação, o link será enviado. Confira também spam.")
	else: _report_failure(result)
	_end()

func _forget_tokens() -> void:
	_generation += 1
	_id_token = ""
	_refresh_token = ""
	_expires_at = 0
	_verified = false
	user_email = ""
	_user_id = ""

func logout(reason: String = "Você saiu da conta.") -> bool:
	if logging_out: return false
	logging_out = true
	var saved := true
	if before_logout.is_valid(): saved = await before_logout.call()
	if not saved and reason == "Você saiu da conta.":
		logging_out = false
		message_changed.emit("Falha ao salvar. Tente novamente antes de sair da conta.")
		return false
	if not saved: reason += " A última gravação falhou; o save anterior foi preservado."
	_forget_tokens()
	logging_out = false
	signed_out.emit(reason)
	message_changed.emit(reason)
	return true

func _refresh_session() -> void:
	if not _begin(): return
	var result := await _request("", {"refresh_token": _refresh_token}, true)
	if result.get("ok", false) and _store_tokens(result.data, true):
		await _check_user(false)
		if not _verified: logout("Confirme seu e-mail e entre novamente.")
	else:
		_report_failure(result)
		_retry_at = Time.get_unix_time_from_system() + 10
		if result.get("status", 0) in [400, 401, 403]: logout("Sua sessão expirou. Entre novamente.")
	_end()

func _process(_delta: float) -> void:
	if logging_out: return
	if _id_token.is_empty(): return
	var now := Time.get_unix_time_from_system()
	if now >= _expires_at:
		logout("Sua sessão expirou. Entre novamente.")
	elif _verified and not busy and now >= _retry_at and _expires_at - now <= 60:
		_refresh_session()
