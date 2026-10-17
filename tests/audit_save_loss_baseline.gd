extends SceneTree
# Run only against the pre-change checkout to reproduce the historical risks.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var library := WorldLibrary.new()
	library.configure("baseline-own-data", "res://.tools/baseline-data")
	library.native_only = true
	await library.load_index(self)
	var id := await library.create_world("Mundo original", self)
	var inventory := ResourceInventory.new()
	inventory.reset()
	inventory.add_resource("madeira", 29)
	var data := {"version": 5, "owner_uid": library.uid, "world_id": id, "inventory": inventory.network_state(), "world_seed": 29}
	inventory.free()
	var a := library.account(id)
	await a.write(data, self)
	var bytes := FileAccess.get_file_as_string(a.store.path)
	DirAccess.remove_absolute(library.index_path())
	var reload := WorldLibrary.new()
	reload.configure(library.uid, library.folder)
	reload.native_only = true
	await reload.load_index(self)
	var hidden: bool = reload.data.worlds.is_empty() and FileAccess.get_file_as_string(a.store.path) == bytes
	print("REPRODUCED: catálogo ausente esconde save íntegro = ", hidden)
	var b := library.account(id)
	await a.read(self)
	await b.read(self)
	var newer := data.duplicate(true)
	newer.world_seed = 97
	await a.write(newer, self)
	var stale_overwrite: bool = await b.write(data, self) and (await a.read(self)).world_seed == 29
	print("REPRODUCED: sessão antiga sobrescreve progresso = ", stale_overwrite)
	DirAccess.remove_absolute(a.store.path)
	var missing_blank := (await a.read(self)).is_empty() and a.error == ""
	print("REPRODUCED: arquivo ausente tratado como início vazio = ", missing_blank)
	quit(0 if hidden and stale_overwrite and missing_blank else 1)
