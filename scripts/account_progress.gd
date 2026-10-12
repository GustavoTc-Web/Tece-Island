class_name AccountProgress
extends RefCounted
var uid := ""
var root_path := "user://"
var error := ""
var store := SaveStore.new()
var native_only := false

func configure(owner: String, folder: String = "user://") -> void:
	uid = owner
	root_path = folder
	store.path = folder.path_join("accounts").path_join(uid.sha256_text()).path_join("solo-progress.json")

func browser() -> bool: return OS.has_feature("web") and not native_only
func browser_key() -> String: return "account/" + uid.sha256_text()
func legacy_path() -> String: return root_path.path_join("solo-progress.json")

func read(tree: SceneTree) -> Dictionary:
	error = ""
	if uid.is_empty():
		error = "Conta indisponível. Entre novamente."
		return {}
	var data := {}
	if browser():
		var result: Dictionary = await tree.root.get_node("BrowserPersistence").request("read", browser_key())
		if not result.get("ok", false):
			error = str(result.get("error", "Falha ao carregar progresso local."))
			return {}
		if result.get("value") == null: return {}
		var parser := JSON.new()
		if parser.parse(str(result.value)) != OK or not parser.data is Dictionary:
			error = "Progresso inválido: original preservado."
			return {}
		data = parser.data
	else:
		data = store.read()
		error = store.error
	if not data.is_empty() and str(data.get("owner_uid", "")) != uid:
		error = "Este progresso pertence a outra conta. Arquivo preservado."
		return {}
	if not data.is_empty() and (not data.get("inventory") is Dictionary or int(data.get("version", -1)) < 0 or int(data.get("version", -1)) > SaveStore.VERSION):
		error = "Progresso incompatível: original preservado."
		return {}
	return data

func write(data: Dictionary, tree: SceneTree) -> bool:
	error = ""
	if uid.is_empty() or str(data.get("owner_uid", "")) != uid:
		error = "Conta do progresso inválida. Entre novamente."
		return false
	if browser():
		var result: Dictionary = await tree.root.get_node("BrowserPersistence").request("write", browser_key(), JSON.stringify(data))
		if not result.get("ok", false): error = str(result.get("error", "Falha ao salvar. Tente novamente."))
		return bool(result.get("ok", false))
	if DirAccess.make_dir_recursive_absolute(store.path.get_base_dir()) != OK:
		error = "Não foi possível preparar o armazenamento local. Tente novamente."
		return false
	var ok := store.write(data)
	error = store.error
	return ok

func legacy_available(tree: SceneTree) -> bool:
	if not FileAccess.file_exists(legacy_path()): return false
	if browser():
		var result: Dictionary = await tree.root.get_node("BrowserPersistence").request("read", "legacy-import-v4")
		return result.get("ok", false) and result.get("value") == null
	return not DirAccess.dir_exists_absolute(root_path.path_join("legacy-import-v4"))

func import_legacy(tree: SceneTree) -> bool:
	error = ""
	var existing := await read(tree)
	if error != "" or not existing.is_empty():
		if error == "": error = "Esta conta já possui progresso. Importação cancelada."
		return false
	var legacy := SaveStore.new()
	legacy.path = legacy_path()
	var data := legacy.read()
	if data.is_empty() or legacy.error != "":
		error = legacy.error if legacy.error != "" else "Nenhum progresso antigo disponível."
		return false
	if data.has("owner_uid") and str(data.owner_uid) != uid:
		error = "Save antigo vinculado a outra conta: importação bloqueada."
		return false
	data.owner_uid = uid
	data.version = SaveStore.VERSION
	if browser():
		var result: Dictionary = await tree.root.get_node("BrowserPersistence").request("import", browser_key(), JSON.stringify(data), uid.sha256_text())
		if not result.get("ok", false): error = str(result.get("error", "Importação não concluída."))
		return bool(result.get("ok", false))
	var claim := root_path.path_join("legacy-import-v4")
	if DirAccess.make_dir_absolute(claim) != OK:
		error = "O save antigo já foi importado ou está reservado. Arquivos preservados."
		return false
	var marker := FileAccess.open(claim.path_join("owner.txt"), FileAccess.WRITE)
	if marker == null:
		error = "Falha ao reservar importação. Save antigo preservado."
		DirAccess.remove_absolute(claim)
		return false
	marker.store_string(uid.sha256_text())
	marker.close()
	var ok := await write(data, tree)
	if not ok:
		DirAccess.remove_absolute(claim.path_join("owner.txt"))
		DirAccess.remove_absolute(claim)
	return ok
