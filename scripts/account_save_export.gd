class_name AccountSaveExport
extends RefCounted

# Export is read-only and fail-closed. Keep valid state and canonical cloud
# hashes; unknown/opaque records stay in storage for explicit recovery.
static func collect(uid: String, tree: SceneTree) -> Dictionary:
	if uid.is_empty(): return {"ok":false, "error":"Entre novamente para exportar seus mundos."}
	var prefix := "account/" + uid.sha256_text() + "/"
	var result: Dictionary = await tree.root.get_node("BrowserPersistence").request("scan", prefix)
	if not result.get("ok", false): return {"ok":false, "error":"Não foi possível ler seus mundos. Dados preservados."}
	return select_entries(result.get("value", []), uid)

static func suffix_allowed(suffix: String, catalog: bool) -> bool:
	if suffix in ["", ":backup", ":backup-2"]: return true
	if catalog: return RegEx.create_from_string("^:(catalog-original|conflict)-[a-f0-9]{32}$").search(suffix) != null
	if suffix in [":before-v5", ":before-v6", ":before-v7", ":before-v8", ":before-v9", ":before-campaign-v1", ":before-campaign-v2", ":before-worlds", ":before-cloud"]: return true
	return RegEx.create_from_string("^:(conflict|conflict-original|recovery-original|resolved-original)-[a-f0-9]{32}$").search(suffix) != null

static func select_entries(rows: Array, uid: String) -> Dictionary:
	if uid.is_empty(): return {"ok":false, "error":"Entre novamente para exportar seus mundos."}
	var prefix := "account/" + uid.sha256_text() + "/"
	var entries := []
	var catalogs := []
	var owned_worlds := {}
	var excluded := 0
	for row in rows:
		if not row is Dictionary or not row.get("key") is String or not row.get("value") is String: continue
		var key: String = row.key
		# Never return foreign names/keys/counts, even if a caller supplied mixed rows.
		if not key.begins_with(prefix): continue
		var tail := key.trim_prefix(prefix)
		var pieces := tail.split(":", true, 1)
		var suffix := ":" + pieces[1] if pieces.size() == 2 else ""
		var catalog := pieces[0] == "worlds"
		var world_id: String = str(pieces[0]).trim_prefix("world/")
		var valid_key := catalog or str(pieces[0]).begins_with("world/") and SaveStore.safe_world_id(world_id)
		var value: Variant = SaveStore.parse(row.value)
		if not valid_key or not suffix_allowed(suffix, catalog) or not value is Dictionary or value.get("owner_uid") != uid:
			excluded += 1
			continue
		if catalog:
			var library := WorldLibrary.new()
			library.configure(uid)
			# Server history is outside a backup of worlds, and is not required to
			# restore the catalog. It is left untouched in the browser.
			var copy: Dictionary = value.duplicate(true)
			copy.servers = []
			if not library.valid(value) or not shape(copy, catalog_schema()): excluded += 1; continue
			catalogs.append({"key":key, "data":copy})
		elif value.get("world_id") == world_id and shape(value, world_schema()) and SaveValidation.valid(value, uid, world_id):
			# Serialize the validated object, not raw text with ignored duplicate
			# JSON members. Cloud hashes already use canonical parsed JSON.
			entries.append({"key":key, "value":JSON.stringify(value)})
			owned_worlds[world_id] = true
		else: excluded += 1
	# A catalog's owner alone does not prove ownership of every reference in it.
	# Keep only references backed by an eligible owned primary/recovery copy.
	for catalog in catalogs:
		var copy: Dictionary = catalog.data
		var worlds: Array = copy.worlds.filter(func(entry): return owned_worlds.has(str(entry.id)))
		excluded += copy.worlds.size() - worlds.size()
		copy.worlds = worlds
		entries.append({"key":catalog.key, "value":JSON.stringify(copy)})
	return {"ok":true, "entries":entries, "excluded":excluded}

# Descriptors reject unrecognized keys at every depth, including encoded data
# smuggled into an otherwise valid record. Free text is limited to game names.
static func shape(value: Variant, schema: Variant) -> bool:
	if schema is Array:
		if not value is Array: return false
		for item in value:
			if not shape(item, schema[0]): return false
		return true
	if schema is Dictionary:
		if not value is Dictionary: return false
		for key in value:
			if not key is String: return false
			var rule: Variant = schema.get(key)
			if rule == null and schema.has("@coordinate") and RegEx.create_from_string("^-?[0-9]+,-?[0-9]+$").search(key) != null: rule = schema["@coordinate"]
			if rule == null or not shape(value[key], rule): return false
		return true
	match schema:
		"number": return (value is int or value is float) and is_finite(float(value))
		"bool": return value is bool
		"point": return SaveStore.vector(value, Vector2.INF).is_finite()
		"name": return value is String and value.length() <= 40
		"id": return value is String and RegEx.create_from_string("^[a-z0-9_,.-]{0,128}$").search(value) != null
		"owner": return value is String and not value.is_empty() and value.length() <= 128
		"hash": return value is String and RegEx.create_from_string("^[a-f0-9]{64}$").search(value) != null
		"time": return value is String and RegEx.create_from_string("^[0-9TZ:.+-]{1,64}$").search(value) != null
		"item": return value is String and (ItemCatalog.NAMES.has(value) or ResourceRules.RECIPES.has(value))
	return false

static func inventory_schema() -> Dictionary:
	var slot := {"item":"item", "quantity":"number", "uid":"number", "loaded":"number", "water":"number"}
	return {"slots":[slot], "category":"id", "weapon_uid":"number", "selected":"number", "backpack":slot, "armor":slot}

static func catalog_schema() -> Dictionary:
	# Servers are checked only for their container type, then excluded entirely.
	return {"version":"number", "owner_uid":"owner", "migration_done":"bool", "worlds":[{"id":"id", "name":"name", "last_access":"number", "uninitialized":"bool", "needs_recovery":"bool"}], "servers":[{"name":"name", "address":"name", "port":"number", "last_access":"number"}]}

static func keyed(keys: Array, rule: Variant) -> Dictionary:
	var result := {}
	for key in keys: result[str(key)] = rule
	return result

static func world_schema() -> Dictionary:
	var coordinates := {"@coordinate":"number"}
	var flags := keyed(IslandObjectives.STONE_TOOLS, "bool")
	var loot := {"contents":keyed(ItemCatalog.NAMES.keys()+ResourceRules.RECIPES.keys(),"number"), "released":"bool"}
	var tasks := {"version":"number", "crafted":["item"], "inferred":["item"], "collapsed":"bool", "completed_stages":["number"], "sleep_credits":["number"], "sleep_used":["number"]}
	var objectives := {"sequence_version":"number", "values":keyed(IslandObjectives.ORDER,"number"), "crafted_tools":flags, "presented":["id"], "tracked":"id", "enabled":"bool", "collapsed":"bool", "campaign_tasks":tasks}
	var temples := {}
	for id in SoloCampaign.COMPONENTS: temples[id] = {"started":"bool", "cleared":["id"], "health":keyed(CampaignEncounters.enemy_ids(id),"number"), "elapsed":"number", "credit":"bool"}
	var campaign := {"version":"number", "discovered":"bool", "clues":"bool", "map_found":"bool", "components":["id"], "repaired":"bool", "encounter":"id", "attempts":"number", "victory_day":"number", "deaths":"number", "rescue_night":"number", "final_wave":"number", "temples":temples, "legacy_migrated":"bool"}
	var wells := {}
	var buildings := {}
	var building_loot := {}
	for region in WorldTerrain.regions():
		wells[region.id] = {"has_well":"bool", "position":"point"}
		buildings[region.id] = [{"id":"id", "kind":"id", "position":"point"}]
		building_loot["campaign-building-"+str(region.id)] = loot
		for index in range(3): building_loot["region-"+str(region.id)+"-%d" % index] = loot
	var structure := {"kind":"id", "position":"point", "id":"id", "chest_name":"name", "rotation":"number", "door_open":"bool", "storage":inventory_schema()}
	return {"version":"number", "owner_uid":"owner", "world_id":"id", "world_name":"name", "world_seed":"number", "inventory":inventory_schema(), "player":{"position":"point", "health":"number", "hunger":"number", "thirst":"number", "poison":"number", "poison_tick":"number"}, "elapsed":"number", "bed":"point", "structures":[structure], "drops":[{"item":"item", "quantity":"number", "attributes":{"uid":"number", "loaded":"number", "water":"number"}, "position":"point"}], "resources":coordinates, "loot":{"@coordinate":loot}, "wells":["point"], "explored":{"@coordinate":"bool"}, "generated_regions":["id"], "region_wells":wells, "region_buildings":buildings, "building_loot":building_loot, "building_interiors":{"@coordinate":{"revealed":"bool", "cleared":["number"], "health":keyed(["0","1","2","3"],"number")}}, "wells_policy":"id", "journal":{"discovered":["id"], "unread":keyed(IslandJournal.RECORDS.keys(),"bool")}, "objectives":objectives, "campaign":campaign, "_sync":{"revision":"number", "hash":"hash", "update_time":"time", "intent":{"hash":"hash", "revision":"number"}}}
