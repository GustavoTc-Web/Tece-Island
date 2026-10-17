extends SceneTree
var checks := 0
var failures := 0
class VerificationFixture extends "res://scripts/auth/firebase_auth.gd":
	var requests := []
	var server_verified := true
	var offline := false
	func _request(endpoint: String, payload: Dictionary, refresh: bool = false) -> Dictionary:
		requests.append("refresh" if refresh else endpoint)
		if offline: return {"ok": false, "status": 0, "message": "Sem conexão. Save local preservado."}
		if refresh: return {"ok": true, "data": {"id_token": "fresh-fixture", "refresh_token": "refresh-fixture", "user_id": "pilot-fixture", "expires_in": "3600"}}
		if payload.get("idToken", "") != "fresh-fixture": return {"ok": false, "status": 401}
		return {"ok": true, "data": {"users": [{"localId": "pilot-fixture", "emailVerified": server_verified, "email": "fixture@example.invalid"}]}}
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS: " if ok else "FAIL: ", label)
func run() -> void:
	print("TEST: autenticação controlada, sem login real nem escrita em dados de jogadores")
	var auth := VerificationFixture.new()
	root.add_child(auth)
	auth.set_process(false)
	auth.config = {"configured": true, "enabled": true}
	auth._user_id = "pilot-fixture"
	auth._id_token = "stale-fixture"
	auth._refresh_token = "refresh-fixture"
	await auth.check_verification()
	check(auth.requests == ["refresh", "lookup"] and auth.has_session() and auth.access_token("pilot-fixture") == "fresh-fixture", "Já confirmei renova token antes de autorizar a sessão")
	check(auth.access_token("other-fixture").is_empty(), "Token nunca é entregue a outra conta")
	auth.server_verified = false
	await auth.check_verification()
	check(not auth.can_play() and auth.access_token("pilot-fixture").is_empty(), "E-mail ainda não confirmado não autoriza jogo ou Firestore")
	auth.offline = true
	await auth.check_verification()
	check(not auth.has_session() and not auth.busy, "Falha na renovação não autoriza sessão e libera nova tentativa")
	for status in [401, 403, 429, 503]:
		var result := FirestoreClient.classify(status, {"error": {"status": "PERMISSION_DENIED"}})
		check(not result.ok and not result.get("missing", false) and result.status == status and not str(result.error).is_empty(), "HTTP %d mantém falha distinta de mundo ausente" % status)
	var missing := {"error": {"status": "NOT_FOUND"}}
	check(FirestoreClient.classify(404, missing).get("missing", false), "Somente leitura NOT_FOUND confirma documento ausente")
	check(not FirestoreClient.classify(404, missing, HTTPClient.METHOD_POST).ok, "Commit NOT_FOUND é falha, nunca confirmação de gravação")
	check(not FirestoreClient.classify(404, null).get("missing", false), "Página 404 de proxy não significa save ausente")
	var sync := root.get_node("WorldSync")
	var account := AccountProgress.new()
	account.uid = "pilot-fixture"
	account.world_id = "pilot-world"
	sync.report_failure(account, FirestoreClient.classify(403, {"error": {"status": "PERMISSION_DENIED"}}))
	check(sync.last_errors[sync.key(account)].status == 403 and sync.states[sync.key(account)].retry, "Permissão negada fica disponível para diagnóstico e nova tentativa")
	sync.status(account, "Sincronizado")
	check(not sync.last_errors.has(sync.key(account)), "Confirmação posterior remove erro obsoleto")
	auth.queue_free()
	print("SYNC PILOT: %d verificações, %d falhas" % [checks, failures])
	quit(1 if failures else 0)
