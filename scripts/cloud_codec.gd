class_name CloudCodec
extends RefCounted

const CHUNK_CHARS := 200000
const MAX_CHUNKS := 8
const MAX_RAW_BYTES := 16 * 1024 * 1024

static func payload(state: Dictionary) -> Dictionary:
	var result := state.duplicate(true)
	result.erase("_sync")
	return result

static func canonical(state: Dictionary) -> String:
	# Normalize numbers the same way after a disk/REST round trip.
	return JSON.stringify(JSON.parse_string(JSON.stringify(payload(state))))

static func hash_state(state: Dictionary) -> String:
	return canonical(state).sha256_text()

static func encode(state: Dictionary) -> Dictionary:
	var text := canonical(state)
	var bytes := text.to_utf8_buffer()
	if bytes.size() > MAX_RAW_BYTES: return {"ok": false, "error": "Mundo maior que o limite de sincronização. Cópia local preservada."}
	var packed := Marshalls.raw_to_base64(bytes.compress(FileAccess.COMPRESSION_DEFLATE))
	var count := ceili(float(packed.length()) / CHUNK_CHARS)
	if count < 1 or count > MAX_CHUNKS: return {"ok": false, "error": "Mundo maior que o limite de sincronização. Cópia local preservada."}
	var chunks := []
	for index in range(count): chunks.append(packed.substr(index * CHUNK_CHARS, CHUNK_CHARS))
	return {"ok": true, "chunks": chunks, "hash": text.sha256_text(), "raw_bytes": bytes.size(), "encoded_bytes": packed.length()}

static func decode(head: Dictionary, chunks: Array, uid: String, id: String) -> Dictionary:
	if not valid_head(head, uid, id) or chunks.size() != int(head.chunk_count): return {"ok": false, "error": "Versão remota incompleta. Cópia local preservada."}
	var joined := ""
	for chunk in chunks:
		if not chunk is String or chunk.length() > CHUNK_CHARS: return {"ok": false, "error": "Parte remota inválida."}
		joined += chunk
	if joined.length() != int(head.encoded_bytes): return {"ok": false, "error": "Tamanho remoto inválido."}
	var bytes := Marshalls.base64_to_raw(joined).decompress(int(head.raw_bytes), FileAccess.COMPRESSION_DEFLATE)
	if bytes.size() != int(head.raw_bytes): return {"ok": false, "error": "Versão remota danificada."}
	var content := bytes.get_string_from_utf8()
	var data: Variant = JSON.parse_string(content)
	if content.sha256_text() != head.hash or not SaveValidation.valid(data, uid, id): return {"ok": false, "error": "Progresso remoto inválido. Original local preservado."}
	return {"ok": true, "data": data}

static func valid_head(head: Dictionary, uid: String, id: String) -> bool:
	return head.get("owner_uid", "") == uid and head.get("world_id", "") == id and int(head.get("schema", 0)) == 1 and int(head.get("revision", 0)) > 0 and int(head.get("chunk_count", 0)) >= 1 and int(head.get("chunk_count", 0)) <= MAX_CHUNKS and int(head.get("raw_bytes", 0)) >= 1 and int(head.get("raw_bytes", 0)) <= MAX_RAW_BYTES and int(head.get("encoded_bytes", 0)) > 0 and int(head.get("encoded_bytes", 0)) <= MAX_CHUNKS * CHUNK_CHARS and SaveStore.safe_world_id(str(head.get("snapshot", ""))) and RegEx.create_from_string("^[a-f0-9]{64}$").search(str(head.get("hash", ""))) != null and head.get("name") is String and head.name.length() >= 1 and head.name.length() <= 40
