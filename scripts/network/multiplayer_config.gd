extends RefCounted

static func read_config() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://config/multiplayer.json"))
	return parsed if parsed is Dictionary else {}

static func enabled() -> bool:
	return read_config().get("enabled", false) == true
