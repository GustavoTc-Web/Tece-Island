extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS: " if ok else "FAIL: ", label)
func run() -> void:
	var uid := "export-test-account-a"
	var other := "export-test-account-b"
	var id := "export-test-world"
	var prefix := "account/" + uid.sha256_text() + "/"
	var other_prefix := "account/" + other.sha256_text() + "/"
	var world: Node2D = load("res://scenes/world.tscn").instantiate()
	world.owner_uid = uid
	world.world_id = id
	root.add_child(world)
	await physics_frame
	world.get_node("DayNight").set_physics_process(false)
	var inv: ResourceInventory = world.get_node("Inventory")
	inv.reset()
	for item in [{"item":"espada_pedra","quantity":1},{"item":"pistola","quantity":1,"loaded":4},{"item":"cantil","quantity":1,"water":2}]: inv.add_item(item)
	inv.equip_slot(1)
	world.campaign.map_found = true
	world.objectives.campaign_tasks.record_crafted("espada_pedra")
	var capture := WorldProgress.new()
	capture.world = world
	var state: Dictionary = capture.capture()
	state.world_name = "Teste de recuperação"
	state._sync = {"revision":2, "hash":CloudCodec.hash_state(state), "update_time":"2026-11-02T12:00:00Z", "intent":{"revision":3, "hash":CloudCodec.hash_state(state)}}
	check(SaveValidation.valid(state,uid,id), "Prepared actual v9 world is valid before export")
	check(AccountSaveExport.shape(JSON.parse_string(JSON.stringify(state)),AccountSaveExport.world_schema()), "All serialized fields in an actual v9 world are recognized")
	var content := JSON.stringify(state)
	var foreign := state.duplicate(true)
	foreign.owner_uid = other
	var library := WorldLibrary.new()
	library.configure(uid)
	var catalog := library.data.duplicate(true)
	catalog.worlds = [{"id":id,"name":"Meu mundo","last_access":123,"uninitialized":false}]
	catalog.servers = [{"name":"Teste","address":"test.invalid","port":7000,"last_access":12}]
	var rows := [{"key":prefix+"world/"+id,"value":content}, {"key":prefix+"worlds","value":JSON.stringify(catalog)}, {"key":other_prefix+"world/"+id,"value":JSON.stringify(foreign)}, {"key":other_prefix+"worlds:backup","value":JSON.stringify({"owner_uid":other})}]
	var selected := AccountSaveExport.select_entries(rows,uid)
	check(selected.ok and selected.entries.size()==2, "A cannot export B primary, catalog or backup")
	check(AccountSaveExport.select_entries(rows,other).entries.size()==1, "B receives only B recognized save, never A")
	check(not AccountSaveExport.select_entries(rows,"").ok, "No connected identity cannot select a general backup")
	check(JSON.stringify(JSON.parse_string(selected.entries[0].value))==JSON.stringify(JSON.parse_string(content)), "World state and sync hashes survive normalized serialization")
	check(JSON.parse_string(selected.entries[1].value).servers.is_empty(), "Non-world server history is absent from the backup, retained in source")
	check(not catalog.servers.is_empty(), "Selection never modifies the source catalog")
	for suffix in [":backup",":backup-2",":before-v9",":before-v8",":before-cloud",":conflict-"+"a".repeat(32),":conflict-original-"+"a".repeat(32),":recovery-original-"+"a".repeat(32),":resolved-original-"+"a".repeat(32)]:
		check(AccountSaveExport.select_entries([{"key":prefix+"world/"+id+suffix,"value":content}],uid).entries.size()==1, "Recognized owned recovery copy is exportable: "+suffix.split("-")[0])
	for suffix in [":unreadable-"+"a".repeat(32),":unknown",":conflict-foreign",":before-v99"]:
		check(AccountSaveExport.select_entries([{"key":prefix+"world/"+id+suffix,"value":content}],uid).entries.is_empty(), "Unknown or unreadable preservation class stays outside normal backup")
	for data in [foreign, {"version":9,"inventory":{}}, {"owner_uid":uid,"world_id":id,"inventory":{},"version":10}]:
		check(AccountSaveExport.select_entries([{"key":prefix+"world/"+id,"value":JSON.stringify(data)}],uid).entries.is_empty(), "Foreign, ownerless or future-format contents cannot bypass an owned key")
	for place in ["root","player","slot","sync","encoded"]:
		var bad := state.duplicate(true)
		match place:
			"root": bad.refresh_token = "synthetic-only"
			"player": bad.player.email = "synthetic-only"
			"slot": bad.inventory.slots[0].session = "synthetic-only"
			"sync": bad._sync.access_token = "synthetic-only"
			"encoded": bad.opaque = Marshalls.raw_to_base64("synthetic-only".to_utf8_buffer().compress())
		check(AccountSaveExport.select_entries([{"key":prefix+"world/"+id,"value":JSON.stringify(bad)}],uid).entries.is_empty(), "Unknown authentication/opaque fields are rejected at "+place)
	var repeated := "{\"player\":{\"health\":\"synthetic-private-value\"}," + content.trim_prefix("{")
	var cleaned := AccountSaveExport.select_entries([{"key":prefix+"world/"+id,"value":repeated}],uid)
	check(cleaned.entries.size()==1 and not str(cleaned.entries[0].value).contains("synthetic-private-value"), "Ignored duplicate JSON members cannot leak through raw text")
	check(AccountSaveExport.select_entries([{"key":prefix+"world/"+id,"value":"unreadable"},{"key":"legacy-original-v4","value":content},{"key":"account/"+uid.sha256_text(),"value":content}],uid).entries.is_empty(), "Unattributed legacy and unreadable records are not copied")
	var original_v8 := FileAccess.get_file_as_string("res://tests/fixtures/solo_v08.json")
	var v8: Dictionary = JSON.parse_string(original_v8)
	v8.owner_uid=uid
	v8.world_id=id
	check(AccountSaveExport.select_entries([{"key":prefix+"world/"+id+":before-v9","value":JSON.stringify(v8)}],uid).entries.size()==1, "Historical owned v8 fixture remains available for recovery")
	var exported: Dictionary = JSON.parse_string(selected.entries[0].value)
	var folder := "res://.tools/export-restore-%d" % Time.get_ticks_usec()
	var account := AccountProgress.new()
	account.configure(uid,folder,id)
	account.native_only=true
	await account.read(self)
	check(await account.write(exported,self), "Compatible v9 client accepts an exported copy in a separate test location")
	var restored: Dictionary = await account.read(self)
	check(JSON.stringify(restored)==JSON.stringify(JSON.parse_string(content)), "Export/read roundtrip preserves inventory, campaign and sync metadata")
	world.queue_free()
	await process_frame
	world=load("res://scenes/world.tscn").instantiate()
	world.owner_uid=uid
	world.world_id=id
	world.account_store=account
	world.persistence_enabled=true
	world.initial_progress=restored
	root.add_child(world)
	await physics_frame
	check(world.get_node("Inventory").selected_data().loaded==4 and world.get_node("Inventory").slots[2].water==2 and world.campaign.map_found, "Actual world reopens exported inventory attributes and campaign map")
	world.queue_free()
	await process_frame
	print("ACCOUNT EXPORT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
