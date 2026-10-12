extends RefCounted

static func read_config() -> Dictionary:
	var path := "res://config/firebase-public.json"
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or not data.get("enabled") is bool:
		return {"enabled": true, "configured": false, "error": "Configuração pública do Firebase inválida."}
	var api_key: String = str(data.get("apiKey", ""))
	var domain: String = str(data.get("authDomain", ""))
	var project: String = str(data.get("projectId", ""))
	var redirect: String = str(data.get("continueUrl", ""))
	var key_pattern := RegEx.create_from_string("^AIza[A-Za-z0-9_-]{35}$")
	var domain_pattern := RegEx.create_from_string("^[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$")
	data.configured = key_pattern.search(api_key) != null and domain_pattern.search(domain) != null and not project.is_empty() and redirect.begins_with("https://") and redirect.ends_with("/Tece-Island/")
	data.error = "" if data.configured else "Firebase ainda não configurado. Aguarde a configuração do projeto."
	return data
