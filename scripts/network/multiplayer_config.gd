extends RefCounted

static func read_config() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://config/multiplayer.json"))
	return parsed if parsed is Dictionary else {}

static func enabled() -> bool:
	return read_config().get("enabled", false) == true

# Only public routing metadata is fetched. Firebase credentials are sent later,
# directly to the authenticated game service, never to this discovery address.
static func endpoint_from_manifest(value: Variant) -> String:
	if not value is Dictionary or value.get("schema", 0) != 1 or value.get("protocol", 0) != 3:
		return ""
	var address := str(value.get("url", ""))
	var pattern := RegEx.create_from_string("\\Awss://[a-z0-9-]+\\.trycloudflare\\.com/room\\z")
	return address if pattern.search(address) != null else ""
