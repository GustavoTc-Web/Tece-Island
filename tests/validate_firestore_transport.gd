extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS: " if ok else "FAIL: ", label)
func url64(data: Dictionary) -> String:
	return Marshalls.utf8_to_base64(JSON.stringify(data)).replace("+", "-").replace("/", "_").replace("=", "")
func run() -> void:
	if OS.get_environment("FIRESTORE_EMULATOR_HOST") != "127.0.0.1:8085":
		push_error("Este teste exige o emulador local; produção proibida.")
		quit(1)
		return
	var auth := root.get_node("FirebaseAuth")
	# Unsigned fixture tokens are accepted ONLY by the local emulator. Never real auth.
	var now := int(Time.get_unix_time_from_system())
	auth.config.projectId = "demo-tece-island"
	auth._user_id = "native-emulator-uid"
	auth._verified = true
	auth._expires_at = now + 3600
	auth._id_token = url64({"alg": "none", "typ": "JWT"}) + "." + url64({"sub": auth._user_id, "user_id": auth._user_id, "aud": "demo-tece-island", "iss": "https://securetoken.google.com/demo-tece-island", "iat": now, "exp": now + 3600, "auth_time": now, "email_verified": true, "firebase": {"sign_in_provider": "password"}}) + "."
	var client := FirestoreClient.new()
	client.api_base = "http://127.0.0.1:8085/v1/"
	root.add_child(client)
	var uid: String = auth._user_id
	var id := "native-" + Crypto.new().generate_random_bytes(8).hex_encode()
	var inv := ResourceInventory.new()
	inv.reset()
	inv.add_resource("pedra", 28)
	var data := {"version": 5, "owner_uid": uid, "world_id": id, "inventory": inv.network_state(), "world_seed": 117, "player": {"health": 73, "position": [640, 720]}}
	inv.free()
	var missing := await client.head(uid, id)
	check(missing.get("ok", false) and missing.get("missing", false), "REST distingue NOT_FOUND confirmado de erro de rede")
	var first := await client.publish(uid, id, data, {}, "Ilha REST")
	if not first.get("ok", false): print("REST FAILURE: ", first)
	check(first.get("ok", false), "Commit nativo atômico passa pelas regras com token de fixture")
	if not first.get("ok", false): quit(1); return
	var listing := await client.list_worlds(uid)
	check(listing.get("ok", false) and listing.worlds.size() == 1, "REST lista mundos pelo UID autenticado")
	var downloaded := await client.download(uid, id, first.head)
	check(downloaded.get("ok", false) and downloaded.data.player.health == 73 and downloaded.data.inventory.slots.size() == 7 and downloaded.data.inventory.slots[0].quantity == 15 and downloaded.data.inventory.slots[1].quantity == 13, "Deflate/base64 do Godot atravessa Firestore e restaura progresso completo")
	data.player.health = 91
	var second := await client.publish(uid, id, data, first.head, "Ilha REST")
	check(second.get("ok", false) and second.head.revision == 2, "Atualização condicional usa updateTime real do serviço")
	var stale := await client.publish(uid, id, data, first.head, "Ilha REST")
	check(not stale.get("ok", false), "FireStore rejeita updateTime antigo numa disputa real de commits")
	var remote := await client.head(uid, id)
	check(remote.get("ok", false) and remote.head.revision == 2, "Commit recusado mantém a revisão confirmada")
	data.player.health = 97
	var third := await client.publish(uid, id, data, second.head, "Ilha REST")
	check(third.get("ok", false), "Terceira versão confirmada permite limpeza segura")
	await client.prune(uid, id)
	var obsolete := await client.request(uid, client.root_path(uid, id) + "/versions/" + first.head.snapshot)
	var previous := await client.request(uid, client.root_path(uid, id) + "/versions/" + second.head.snapshot)
	check(obsolete.get("missing", false) and previous.get("ok", false) and not previous.get("missing", false), "Limpeza preserva versão atual e predecessor; remove apenas versão já substituída")
	var stress := data.duplicate(true)
	stress.world_id = "parts-" + id
	stress.test_payload = Crypto.new().generate_random_bytes(450000).hex_encode()
	var encoded := CloudCodec.encode(stress)
	check(encoded.ok and encoded.chunks.size() > 1, "Fixture incompressível exige divisão real em múltiplas partes")
	var multipart := await client.publish(uid, stress.world_id, stress, {}, "Mundo multipartes")
	var restored: Dictionary = await client.download(uid, stress.world_id, multipart.head) if multipart.get("ok", false) else {"ok": false}
	check(multipart.get("ok", false) and restored.get("ok", false) and restored.data.test_payload == stress.test_payload, "Commit e download nativos conservam uma versão completa dividida em partes")
	var too_large := data.duplicate(true)
	too_large.test_payload = "x".repeat(CloudCodec.MAX_RAW_BYTES)
	check(not CloudCodec.encode(too_large).ok, "Save acima do limite é recusado antes de qualquer envio")
	auth._forget_tokens()
	print("FIRESTORE REST: %d verificações, %d falhas" % [checks, failures])
	quit(1 if failures else 0)
