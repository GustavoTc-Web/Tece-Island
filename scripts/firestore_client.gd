class_name FirestoreClient
extends Node

const API := "https://firestore.googleapis.com/v1/"
var api_base := API

func database() -> String:
	return "projects/" + str(get_tree().root.get_node("FirebaseAuth").config.get("projectId", "")) + "/databases/(default)"

func root_path(uid: String, id: String = "") -> String:
	return database() + "/documents/users/" + uid + "/worlds" + ("/" + id if id != "" else "")

func request(uid: String, path: String, method: int = HTTPClient.METHOD_GET, body: Dictionary = {}) -> Dictionary:
	var auth: Node = get_tree().root.get_node("FirebaseAuth")
	var generation: int = auth.session_generation()
	var token: String = auth.access_token(uid)
	if token == "": return {"ok": false, "error": "Sessão indisponível. Entre novamente para sincronizar."}
	var http := HTTPRequest.new()
	http.timeout = 20
	http.accept_gzip = not OS.has_feature("web")
	add_child(http)
	var error := http.request(api_base + path, PackedStringArray(["Authorization: Bearer " + token, "Content-Type: application/json"]), method, JSON.stringify(body) if not body.is_empty() else "")
	token = ""
	if error != OK:
		http.queue_free()
		return {"ok": false, "status": 0, "error": "Sem conexão. Save local preservado."}
	var response: Array = await http.request_completed
	http.queue_free()
	if auth.account_uid() != uid or auth.session_generation() != generation: return {"ok": false, "error": "A conta mudou. Operação cancelada."}
	if response[0] != HTTPRequest.RESULT_SUCCESS: return {"ok": false, "status": 0, "error": "Sem conexão. Save local preservado."}
	var data: Variant = JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
	return classify(int(response[1]), data, method)

static func classify(status: int, data: Variant, method: int = HTTPClient.METHOD_GET) -> Dictionary:
	var code := ""
	if data is Dictionary and data.get("error", {}) is Dictionary:
		code = str(data.get("error", {}).get("status", ""))
	if method == HTTPClient.METHOD_GET and status == 404 and code == "NOT_FOUND":
		# Only a successful service response declaring NOT_FOUND means absent.
		return {"ok": true, "missing": true, "status": status}
	if status < 200 or status >= 300 or not data is Dictionary:
		var message := "Sincronização falhou. Save local preservado; tente novamente."
		if status == 429: message = "Limite temporário do serviço. Save local preservado; tente mais tarde."
		if status == 401: message = "Sessão expirada ou inválida. Salve neste aparelho e entre novamente para sincronizar."
		if status == 403: message = "Sem permissão para sincronizar. Confirme o e-mail, entre novamente e confira as regras do Firebase. Save local preservado."
		if status == 404: message = "Banco remoto ou endereço indisponível. Save local preservado; confira a configuração do Firestore."
		return {"ok": false, "status": status, "code": code, "conflict": status in [409, 412], "error": message}
	return {"ok": true, "data": data}

static func fields(data: Dictionary) -> Dictionary:
	var result := {}
	for key in data:
		var value: Variant = data[key]
		result[key] = {"integerValue": str(int(value))} if value is int or value is float else {"stringValue": str(value)}
	return result

static func unpack(document: Dictionary) -> Dictionary:
	var result := {}
	for key in document.get("fields", {}):
		var value: Dictionary = document.fields[key]
		result[key] = int(value.integerValue) if value.has("integerValue") else value.get("stringValue", "")
	result.update_time = document.get("updateTime", "")
	return result

func head(uid: String, id: String) -> Dictionary:
	var result := await request(uid, root_path(uid, id))
	if not result.get("ok", false) or result.get("missing", false): return result
	var state := unpack(result.data)
	if not CloudCodec.valid_head(state, uid, id) or state.update_time == "": return {"ok": false, "error": "Registro remoto incompatível. Cópias locais preservadas."}
	return {"ok": true, "head": state}

func list_worlds(uid: String) -> Dictionary:
	var heads := []
	var page_token := ""
	while true:
		var result := await request(uid, root_path(uid) + "?pageSize=100" + ("&pageToken=" + page_token.uri_encode() if page_token != "" else ""))
		if not result.get("ok", false) or result.get("missing", false): return {"ok": false, "error": result.get("error", "Banco remoto indisponível.")}
		for doc in result.data.get("documents", []):
			var item := unpack(doc)
			if not CloudCodec.valid_head(item, uid, str(item.get("world_id", ""))): return {"ok": false, "error": "Lista remota incompatível. Cópia local preservada."}
			heads.append(item)
		page_token = str(result.data.get("nextPageToken", ""))
		if page_token == "": break
	return {"ok": true, "worlds": heads}

func download(uid: String, id: String, state: Dictionary) -> Dictionary:
	# Immutable snapshot IDs prevent reading a mixture of two revisions.
	var chunks := []
	for index in range(int(state.chunk_count)):
		var result := await request(uid, root_path(uid, id) + "/versions/" + state.snapshot + "/chunks/%d" % index)
		if not result.get("ok", false) or result.get("missing", false): return {"ok": false, "error": result.get("error", "Versão remota incompleta. Tente novamente.")}
		var chunk := unpack(result.data)
		if int(chunk.get("index", -1)) != index: return {"ok": false, "error": "Ordem das partes remotas inválida."}
		chunks.append(chunk.get("payload", ""))
	return CloudCodec.decode(state, chunks, uid, id)

func publish(uid: String, id: String, state: Dictionary, previous: Dictionary, title: String) -> Dictionary:
	var encoded := CloudCodec.encode(state)
	if not encoded.ok: return encoded
	var version := "v-" + Crypto.new().generate_random_bytes(16).hex_encode()
	var revision := int(previous.get("revision", 0)) + 1
	var metadata := {"schema": 1, "owner_uid": uid, "world_id": id, "name": title.left(40), "revision": revision, "snapshot": version, "previous_snapshot": previous.get("snapshot", ""), "hash": encoded.hash, "chunk_count": encoded.chunks.size(), "raw_bytes": encoded.raw_bytes, "encoded_bytes": encoded.encoded_bytes}
	var path := root_path(uid, id)
	var condition := {"exists": false} if previous.is_empty() else {"updateTime": previous.update_time}
	var writes := [{"update": {"name": path, "fields": fields(metadata)}, "currentDocument": condition}, {"update": {"name": path + "/versions/" + version, "fields": fields(metadata)}, "currentDocument": {"exists": false}}]
	for index in range(encoded.chunks.size()):
		writes.append({"update": {"name": path + "/versions/" + version + "/chunks/%d" % index, "fields": fields({"index": index, "payload": encoded.chunks[index]})}, "currentDocument": {"exists": false}})
	var result := await request(uid, database() + "/documents:commit", HTTPClient.METHOD_POST, {"writes": writes})
	if not result.get("ok", false): return result
	var confirmations: Array = result.data.get("writeResults", [])
	if confirmations.size() != writes.size() or str(confirmations[0].get("updateTime", "")) == "": return {"ok": false, "error": "O serviço não confirmou a versão completa. Save local preservado."}
	metadata.update_time = confirmations[0].updateTime
	return {"ok": true, "head": metadata}

func prune(uid: String, id: String) -> void:
	# Keep the confirmed current version and its predecessor. Failed cleanup is harmless.
	var current := await head(uid, id)
	if not current.get("ok", false) or not current.has("head"): return
	var page := ""
	while true:
		var result := await request(uid, root_path(uid, id) + "/versions?pageSize=20" + ("&pageToken=" + page.uri_encode() if page != "" else ""))
		if not result.get("ok", false): return
		for doc in result.get("data", {}).get("documents", []):
			var version := unpack(doc)
			if version.get("snapshot", "") in [current.head.snapshot, current.head.get("previous_snapshot", "")]: continue
			if not CloudCodec.valid_head(version, uid, id) or int(version.revision) >= int(current.head.revision) - 1: continue
			var path := root_path(uid, id) + "/versions/" + str(version.snapshot)
			var writes := [{"delete": path, "currentDocument": {"updateTime": version.update_time}}]
			for index in range(int(version.chunk_count)): writes.append({"delete": path + "/chunks/%d" % index})
			var removed := await request(uid, database() + "/documents:commit", HTTPClient.METHOD_POST, {"writes": writes})
			if not removed.get("ok", false): return
		page = str(result.get("data", {}).get("nextPageToken", ""))
		if page == "": return
