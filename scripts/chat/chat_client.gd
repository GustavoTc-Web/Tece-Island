class_name ChatClient
extends FirestoreClient

var pending: Array[HTTPRequest] = []

# Uses the existing verified session, never administrative credentials.
func call_api(uid: String, path: String, method: int = HTTPClient.METHOD_GET, body: Dictionary = {}) -> Dictionary:
	var auth: Node = get_tree().root.get_node("FirebaseAuth")
	var generation: int = auth.session_generation()
	var token: String = auth.access_token(uid)
	if token == "": return {"ok": false, "cancelled": true}
	var http := HTTPRequest.new()
	http.process_mode = Node.PROCESS_MODE_ALWAYS
	http.timeout = 12
	http.accept_gzip = not OS.has_feature("web")
	add_child(http)
	pending.append(http)
	var error := http.request(api_base + path, PackedStringArray(["Authorization: Bearer " + token, "Content-Type: application/json"]), method, JSON.stringify(body) if not body.is_empty() else "")
	token = ""
	var response: Array = [HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray()]
	if error == OK: response = await http.request_completed
	pending.erase(http)
	http.queue_free()
	if auth.account_uid() != uid or auth.session_generation() != generation: return {"ok": false, "cancelled": true}
	var status := int(response[1])
	if response[0] != HTTPRequest.RESULT_SUCCESS: return {"ok": false, "status": 0, "code": "TRANSPORT_" + str(response[0])}
	var data: Variant = JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
	# Streaming REST may carry an error inside a successful HTTP array.
	var api_error: Dictionary = data.get("error", {}) if data is Dictionary else {}
	if data is Array:
		for row in data:
			if row is Dictionary and row.get("error") is Dictionary: api_error = row.error
	var code := str(api_error.get("status", ""))
	if not (data is Dictionary or data is Array): code = "INVALID_RESPONSE"
	return {"ok": status >= 200 and status < 300 and code == "", "status": int(api_error.get("code", status)), "code": code, "data": data}

func cancel() -> void:
	for http in pending.duplicate():
		http.cancel_request()
		http.request_completed.emit(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray())

func document_path(collection: String, id: String) -> String:
	return database() + "/documents/" + collection + "/" + id

static func decode(document: Dictionary) -> Dictionary:
	var data := FirestoreClient.unpack(document)
	for key in document.get("fields", {}):
		var value: Dictionary = document.fields[key]
		if value.has("timestampValue"): data[key] = str(value.timestampValue)
	data.id = str(document.get("name", "")).get_file()
	return data

func read_document(uid: String, collection: String, id: String) -> Dictionary:
	var result := await call_api(uid, document_path(collection, id))
	if result.get("status", 0) == 404: return {"ok": true, "missing": true}
	if result.ok: result.document = decode(result.data)
	return result

func settings(uid: String) -> Dictionary:
	return await call_api(uid, document_path("chatSettings", "global"))

func recent(uid: String, after_sequence: int = 0) -> Dictionary:
	var query := {"from": [{"collectionId": "globalMessages"}], "orderBy": [{"field": {"fieldPath": "sequence"}, "direction": "DESCENDING"}], "limit": 50}
	if after_sequence > 0: query.where = {"fieldFilter": {"field": {"fieldPath": "sequence"}, "op": "GREATER_THAN", "value": {"integerValue": str(after_sequence)}}}
	var result := await call_api(uid, database() + "/documents:runQuery", HTTPClient.METHOD_POST, {"structuredQuery": query})
	if result.ok:
		if not result.data is Array: return {"ok": false, "status": 0}
		result.messages = []
		for row in result.data:
			if row is Dictionary and row.get("document") is Dictionary:
				var message := decode(row.document)
				if message.has_all(["sequence", "sent_at", "uid", "nickname", "text"]): result.messages.append(message)
	return result

func set_nickname(uid: String, nickname: String) -> Dictionary:
	return await call_api(uid, database() + "/documents:commit", HTTPClient.METHOD_POST, {"writes": [{"update": {"name": document_path("chatProfiles", uid), "fields": fields({"nickname": nickname})}}]})

func send_message(uid: String, nickname: String, text: String) -> Dictionary:
	# Preconditions make concurrent senders contend safely for the next ring slot.
	# A rate document and the slot MUST advance atomically with the global counter.
	for attempt in range(2):
		var head := await read_document(uid, "chatRuntime", "global")
		if not head.ok: return head
		var sequence := int(head.get("document", {}).get("sequence", 0)) + 1
		var condition := {"exists": false} if head.get("missing", false) else {"updateTime": head.document.update_time}
		var stamp := [{"fieldPath": "sent_at", "setToServerValue": "REQUEST_TIME"}]
		var writes := [
			{"update": {"name": document_path("chatRuntime", "global"), "fields": fields({"sequence": sequence})}, "updateTransforms": stamp, "currentDocument": condition},
			{"update": {"name": document_path("chatRates", uid), "fields": fields({"sequence": sequence})}, "updateTransforms": stamp},
			{"update": {"name": document_path("globalMessages", str(sequence % 100)), "fields": fields({"sequence": sequence, "uid": uid, "nickname": nickname, "text": text})}, "updateTransforms": stamp}
		]
		var result := await call_api(uid, database() + "/documents:commit", HTTPClient.METHOD_POST, {"writes": writes})
		if result.get("status", 0) not in [409, 412]: return result
	return {"ok": false, "status": 409}

func remove_message(uid: String, id: String, update_time: String) -> Dictionary:
	# Avoid deleting a newer message which has reused the same ring position.
	return await call_api(uid, database() + "/documents:commit", HTTPClient.METHOD_POST, {"writes": [{"delete": document_path("globalMessages", id), "currentDocument": {"updateTime": update_time}}]})
