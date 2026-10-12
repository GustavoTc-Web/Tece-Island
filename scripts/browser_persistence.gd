extends Node
var sequence := 0
var pending := {}
var callbacks := {}

func _ready() -> void: process_mode = Node.PROCESS_MODE_ALWAYS

func request(operation: String, key: String, payload: String = "", claim: String = "") -> Dictionary:
	if not OS.has_feature("web"): return {"ok": false, "error": "Armazenamento Web indisponível."}
	var bridge = JavaScriptBridge.get_interface("tcLocalProgress")
	if bridge == null: return {"ok": false, "error": "Armazenamento do navegador indisponível. Recarregue e tente novamente."}
	sequence += 1
	var id := sequence
	callbacks[id] = JavaScriptBridge.create_callback(func(args):
		if not callbacks.has(id): return
		var data = JSON.parse_string(str(args[0])) if args.size() > 0 else null
		pending[id] = data if data is Dictionary else {"ok": false, "error": "Resposta inválida do armazenamento."})
	bridge.request(operation, key, payload, claim, callbacks[id])
	var deadline := Time.get_ticks_msec() + 15000
	while not pending.has(id) and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.05, true).timeout
	var result: Dictionary = pending.get(id, {"ok": false, "error": "O navegador não confirmou a gravação. Tente novamente."})
	pending.erase(id)
	callbacks.erase(id)
	return result
