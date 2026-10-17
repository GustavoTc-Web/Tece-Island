class_name WorldLibrary
extends RefCounted
var uid := ""
var folder := "user://"
var error := ""
var native_only := false
var data := {}
var warning := ""
var expected: Variant = null

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
	warning = ""
	var content: Variant = null
	if web():
		var result: Dictionary = await tree.root.get_node("BrowserPersistence").request("read", index_key())
		if not result.get("ok", false):
			error = str(result.get("error", "Falha ao carregar mundos."))
			return false
		content = result.get("value")
	elif FileAccess.file_exists(index_path()): content = FileAccess.get_file_as_string(index_path())
	expected = content
	if content == null: await restore_index_backup(tree)
	if content != null:
		var parsed: Variant = SaveStore.parse(str(content))
		if not valid(parsed):
			if not await restore_index_backup(tree):
				# Rebuild only when actual saves exist; archive the damaged catalog first.
				var originals := await discover(tree)
				if originals.is_empty():
					error = "Lista de mundos incompatível. Original preservado."
					return false
				if not await preserve_index(tree): return false
				data.worlds = originals
				warning = "Lista reconstruída a partir dos saves deste aparelho."
		else: data = parsed
	if not await reconcile(tree): return false
	var migrated := await migrate(tree)
	if not migrated and not data.worlds.is_empty():
		warning = error + " Os outros mundos continuam disponíveis."
		error = ""
		return true
	return migrated

func preserve_index(tree: SceneTree) -> bool:
	if web():
		var result: Dictionary = await tree.root.get_node("BrowserPersistence").request("preserve", index_key(), "", "catalog-original")
		error = str(result.get("error", ""))
		return result.get("ok", false)
	var store := SaveStore.new()
	store.path = index_path()
	return not FileAccess.file_exists(store.path) or store.preserve(FileAccess.get_file_as_string(store.path), "catalog-original") != ""

func restore_index_backup(tree: SceneTree) -> bool:
	var entries := []
	if web():
		var result: Dictionary = await tree.root.get_node("BrowserPersistence").request("scan", index_key() + ":")
		if not result.get("ok", false): return false
		entries = result.get("value", [])
	else:
		for suffix in [".backup.json", ".backup-2.json"]:
			if FileAccess.file_exists(index_path() + suffix): entries.append({"value": FileAccess.get_file_as_string(index_path() + suffix)})
	for entry in entries:
		var candidate: Variant = SaveStore.parse(str(entry.value))
		if valid(candidate):
			if not await preserve_index(tree): return false
			data = candidate
			warning = "Lista recuperada de backup; originais preservados."
			return true
	return false

func discover(tree: SceneTree) -> Array:
	var entries := []
	var prefix := "account/" + uid.sha256_text() + "/world/"
	if web():
		var result: Dictionary = await tree.root.get_node("BrowserPersistence").request("scan", prefix)
		if not result.get("ok", false):
			error = str(result.get("error", "Falha ao procurar mundos locais."))
			return []
		for entry in result.get("value", []):
			var id := str(entry.key).trim_prefix(prefix).split(":")[0]
			entries.append({"id": id, "value": entry.value, "backup": str(entry.key).contains(":")})
	else:
		var directory := DirAccess.open(folder.path_join("accounts").path_join(uid.sha256_text()).path_join("worlds"))
		if directory != null:
			for id in directory.get_directories():
				if not safe_id(id): continue
				var path := account(id).store.path
				var files := DirAccess.open(path.get_base_dir())
				for file in files.get_files():
					if file == "progress.json" or file.begins_with("progress.json."):
						entries.append({"id": id, "value": FileAccess.get_file_as_string(path.get_base_dir().path_join(file)), "backup": file != "progress.json"})
	var found := {}
	for entry in entries:
		var id := str(entry.id)
		if not safe_id(id): continue
		var state: Variant = SaveStore.parse(str(entry.value))
		# An invalid file remains visible for explicit recovery. Never infer its owner.
		if state is Dictionary and state.get("owner_uid", "") != uid: continue
		if state is Dictionary and state.get("world_id", "") != id: continue
		if not found.has(id): found[id] = {"id": id, "name": "Mundo recuperado · " + id.left(12), "last_access": 0, "uninitialized": false, "needs_recovery": true}
		if SaveValidation.valid(state, uid, id) and not entry.backup:
			found[id].name = str(state.get("world_name", found[id].name))
			found[id].needs_recovery = false
	return found.values()

func reconcile(tree: SceneTree) -> bool:
	var next := data.duplicate(true)
	var found := await discover(tree)
	if error != "": return false
	for entry in found:
		var exists := false
		for world in next.worlds:
			if world.id == entry.id: exists = true
		if not exists: next.worlds.append(entry)
	if next != data or expected == null or warning != "":
		return await commit(next, tree)
	return true

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
		var result: Dictionary = await tree.root.get_node("BrowserPersistence").request("write", index_key(), JSON.stringify(next), JSON.stringify({"expected": expected}))
		ok = bool(result.get("ok", false))
		if not ok: error = str(result.get("error", "Falha ao salvar lista."))
	else:
		if DirAccess.make_dir_recursive_absolute(index_path().get_base_dir()) != OK:
			error = "Não foi possível preparar lista local."
			return false
		var store := SaveStore.new()
		store.path = index_path()
		if not SaveStore.acquire_lock(store.path):
			error = "Outra sessão está alterando a lista. Reabra o lobby."
			return false
		var current: Variant = FileAccess.get_file_as_string(store.path) if FileAccess.file_exists(store.path) else null
		if current != expected:
			SaveStore.release_lock(store.path)
			error = "A lista foi alterada por outra sessão. Reabra o lobby."
			return false
		ok = store.write(next)
		SaveStore.release_lock(store.path)
		error = store.error
	if ok:
		data = next
		expected = JSON.stringify(next)
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
		# If a prior interrupted migration found a different destination, keep both.
		var comparable := previous.duplicate(true)
		comparable.world_id = "first-world"
		comparable.version = SaveStore.VERSION
		var destination := existing.duplicate(true)
		for field in ["_sync", "world_name"]:
			comparable.erase(field)
			destination.erase(field)
		if not existing.is_empty() and comparable != destination:
			var alternate_id := "legacy-" + JSON.stringify(comparable).sha256_text().left(24)
			var alternate := account(alternate_id)
			var alternate_data := await alternate.read(tree)
			if alternate.error != "":
				error = alternate.error
				return false
			if alternate_data.is_empty():
				if not await old.preserve(tree, "before-worlds"): return false
				comparable.world_id = alternate_id
				if not await alternate.write(comparable, tree):
					error = alternate.error
					return false
			var listed := false
			for world in next.worlds:
				if world.id == alternate_id: listed = true
			if not listed: next.worlds.append({"id": alternate_id, "name": "Mundo antigo · versão preservada", "last_access": 0})
	next.migration_done = true
	return await commit(next, tree)

func create_world(title: String, tree: SceneTree) -> String:
	var name := title.strip_edges().left(40)
	if name.is_empty():
		error = "Informe um nome para o mundo."
		return ""
	var id := "w-" + Crypto.new().generate_random_bytes(12).hex_encode()
	# Only explicit creation may allocate a pristine world. Save the seed and
	# initial state BEFORE its catalog entry, so even unplayed worlds can sync.
	var initial := {"version": SaveStore.VERSION, "owner_uid": uid, "world_id": id, "world_name": name, "world_seed": randi_range(1, 2147480000), "inventory": {"slots": [], "backpack": {}, "armor": {}, "selected": 0}, "player": {"position": [1152, 768], "health": 100, "hunger": 100, "thirst": 100}, "elapsed": 0, "structures": [], "drops": [], "journal": {}, "objectives": {}}
	var target := account(id)
	if not await target.write(initial, tree):
		error = target.error
		return ""
	var next := data.duplicate(true)
	next.worlds.append({"id": id, "name": name, "last_access": 0, "uninitialized": false})
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
			world.uninitialized = false
			return await commit(next, tree)
	return false

func entry(id: String) -> Dictionary:
	for world in data.worlds:
		if world.id == id: return world
	return {}

func register_world(id: String, title: String, tree: SceneTree, access: int = 0) -> bool:
	if not safe_id(id): return false
	if not entry(id).is_empty(): return true
	var next := data.duplicate(true)
	next.worlds.append({"id": id, "name": title.left(40), "last_access": access, "uninitialized": false})
	return await commit(next, tree)

func fork_local(state: Dictionary, title: String, tree: SceneTree) -> Dictionary:
	var id := "copy-" + Crypto.new().generate_random_bytes(12).hex_encode()
	var copy := account(id)
	var preserved := state.duplicate(true)
	preserved.erase("_sync")
	preserved.world_id = id
	preserved.world_name = title.left(40)
	if not await copy.write(preserved, tree): return {"ok": false, "error": copy.error}
	if not await register_world(id, title, tree): return {"ok": false, "error": error}
	return {"ok": true, "id": id, "account": copy}

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
