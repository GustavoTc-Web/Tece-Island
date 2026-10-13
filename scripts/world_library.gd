class_name WorldLibrary
extends RefCounted
var uid := ""
var folder := "user://"
var error := ""
var native_only := false
var data := {}

func configure(owner: String, root: String = "user://") -> void:
	uid = owner
	folder = root
	data = {"version": 1, "owner_uid": uid, "worlds": [], "servers": [], "migration_done": false}

func account(id: String = "") -> AccountProgress:
	var result := AccountProgress.new()
	result.configure(uid, folder, id)
	result.native_only = native_only
	return result

func index_path() -> String:
	return folder.path_join("accounts").path_join(uid.sha256_text()).path_join("worlds.json")

func index_key() -> String:
	return "account/" + uid.sha256_text() + "/worlds"

func web() -> bool: return OS.has_feature("web") and not native_only

func load_index(tree: SceneTree) -> bool:
	error = ""
	var content: Variant = null
	if web():
		var result: Dictionary = await tree.root.get_node("BrowserPersistence").request("read", index_key())
		if not result.get("ok", false):
			error = str(result.get("error", "Falha ao carregar mundos."))
			return false
		content = result.get("value")
	elif FileAccess.file_exists(index_path()): content = FileAccess.get_file_as_string(index_path())
	if content != null:
		var parsed: Variant = JSON.parse_string(str(content))
		if not valid(parsed):
			error = "Lista de mundos incompatível. Original preservado."
			return false
		data = parsed
	return await migrate(tree)

func valid(value: Variant) -> bool:
	if not value is Dictionary or value.get("owner_uid", "") != uid or int(value.get("version", 0)) != 1 or not value.get("worlds") is Array or not value.get("servers") is Array: return false
	var ids := {}
	for world in value.worlds:
		if not world is Dictionary or not safe_id(str(world.get("id", ""))) or ids.has(world.id) or str(world.get("name", "")).strip_edges().is_empty(): return false
		ids[world.id] = true
	for server in value.servers:
		if not server is Dictionary or str(server.get("address", "")).is_empty() or int(server.get("port", 0)) < 1024 or int(server.get("port", 0)) > 65535: return false
	return true

static func safe_id(id: String) -> bool:
	return SaveStore.safe_world_id(id)

func commit(next: Dictionary, tree: SceneTree) -> bool:
	error = ""
	if not valid(next):
		error = "Dados da lista inválidos. Original preservado."
		return false
	var ok := false
	if web():
		var result: Dictionary = await tree.root.get_node("BrowserPersistence").request("write", index_key(), JSON.stringify(next))
		ok = bool(result.get("ok", false))
		if not ok: error = str(result.get("error", "Falha ao salvar lista."))
	else:
		if DirAccess.make_dir_recursive_absolute(index_path().get_base_dir()) != OK:
			error = "Não foi possível preparar lista local."
			return false
		var store := SaveStore.new()
		store.path = index_path()
		ok = store.write(next)
		error = store.error
	if ok: data = next
	return ok

func migrate(tree: SceneTree) -> bool:
	if data.get("migration_done", false): return true
	var old := account()
	var previous := await old.read(tree)
	if old.error != "":
		error = old.error
		return false
	var next := data.duplicate(true)
	if not previous.is_empty():
		# Deterministic destination allows retry after interruption before index commit.
		var target := account("first-world")
		var existing := await target.read(tree)
		if target.error != "":
			error = target.error
			return false
		if existing.is_empty():
			if not web():
				var backup := old.store.path + ".before-worlds.json"
				if not FileAccess.file_exists(backup) and DirAccess.copy_absolute(old.store.path, backup) != OK:
					error = "Falha no backup; migração cancelada."
					return false
			previous.world_id = "first-world"
			previous.version = SaveStore.VERSION
			if web():
				var result: Dictionary = await tree.root.get_node("BrowserPersistence").request("migrate", target.browser_key(), JSON.stringify(previous), old.browser_key())
				if not result.get("ok", false):
					error = str(result.get("error", "Migração não concluída."))
					return false
			elif not await target.write(previous, tree):
				error = target.error
				return false
			var verified := await target.read(tree)
			if verified != JSON.parse_string(JSON.stringify(previous)):
				error = "Migração não confirmada. Save original preservado."
				return false
		var found := false
		for world in next.worlds:
			if world.id == "first-world": found = true
		if not found: next.worlds.append({"id": "first-world", "name": "Meu primeiro mundo", "last_access": 0})
	next.migration_done = true
	return await commit(next, tree)

func create_world(title: String, tree: SceneTree) -> String:
	var name := title.strip_edges().left(40)
	if name.is_empty():
		error = "Informe um nome para o mundo."
		return ""
	var id := "w-" + Crypto.new().generate_random_bytes(12).hex_encode()
	var next := data.duplicate(true)
	next.worlds.append({"id": id, "name": name, "last_access": 0})
	return id if await commit(next, tree) else ""

func rename_world(id: String, title: String, tree: SceneTree) -> bool:
	var next := data.duplicate(true)
	var name := title.strip_edges().left(40)
	if name.is_empty():
		error = "Informe um nome para o mundo."
		return false
	for world in next.worlds:
		if world.id == id:
			world.name = name
			return await commit(next, tree)
	error = "Selecione um mundo."
	return false

func touch_world(id: String, tree: SceneTree) -> bool:
	var next := data.duplicate(true)
	for world in next.worlds:
		if world.id == id:
			world.last_access = Time.get_unix_time_from_system()
			return await commit(next, tree)
	return false

func record_server(address: String, port: int, tree: SceneTree) -> bool:
	var next := data.duplicate(true)
	var entry := {"name": address + ":%d" % port, "address": address, "port": port, "last_access": Time.get_unix_time_from_system()}
	var matches := false
	for server in next.servers:
		if server.address == address and int(server.port) == port:
			server.last_access = entry.last_access
			matches = true
	if not matches: next.servers.append(entry)
	return await commit(next, tree)
