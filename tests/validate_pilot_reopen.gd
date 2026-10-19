# Synthetic checkpoints exercise file/account/world/codec round trips. They do
# not claim a second human campaign or replace the user's day-seven report.
extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS: " if ok else "FAIL: ", label)
func same(a: Variant, b: Variant) -> bool:
	return JSON.stringify(JSON.parse_string(JSON.stringify(a))) == JSON.stringify(JSON.parse_string(JSON.stringify(b)))
func step() -> void:
	await process_frame
	await physics_frame
func checkpoint(stage: String) -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/solo_v08.json"))
	var c := SoloCampaign.new()
	if stage != "map_pending": c.discovered = true; c.map_found = true
	if stage == "temple_partial":
		c.temples.lens.started = true
		c.temples.lens.cleared = CampaignEncounters.enemy_ids("lens").slice(0, 1)
		c.temples.lens.health[CampaignEncounters.enemy_ids("lens")[1]] = 42
	if stage in ["active", "awaiting_dawn", "won"]:
		for id in SoloCampaign.COMPONENTS:
			c.temples[id].started = true
			c.temples[id].cleared = CampaignEncounters.enemy_ids(id)
			c.collect(id)
		c.repaired = true
		c.attempts = 2
		c.rescue_night = 6
		c.encounter = stage
		c.final_wave = 1 if stage == "active" else 2
		if stage == "won": c.victory_day = 7
	data.campaign = c.capture()
	c.free()
	data.elapsed = 3610 if stage == "won" else (3310 if stage in ["active", "awaiting_dawn"] else 2110)
	data.owner_uid = "release-reopen-fixture"
	data.world_id = "checkpoint-" + stage.replace("_", "-")
	data.world_name = "Reteste " + stage
	data.objectives.campaign_tasks = {"version":1,"crafted":["fogueira","arco","machado_madeira"],"inferred":[],"collapsed":true}
	return data
func open_world(account: AccountProgress, data: Dictionary) -> Node2D:
	var world: Node2D = load("res://scenes/world.tscn").instantiate()
	world.persistence_enabled = true
	world.account_store = account
	world.initial_progress = data
	world.owner_uid = account.uid
	world.world_id = account.world_id
	world.world_name = data.world_name
	root.add_child(world)
	for id in ["EnemySpawner", "Animals", "DayNight", "WorldObjects/Player"]: world.get_node(id).set_physics_process(false)
	return world
func round_trip(stage: String, folder: String) -> void:
	var original := checkpoint(stage)
	var account := AccountProgress.new()
	account.configure(original.owner_uid, folder, original.world_id)
	account.native_only = true
	check(SaveValidation.valid(original, account.uid, account.world_id), stage + ": checkpoint v8 válido")
	check(await account.write(original, self), stage + ": gravação inicial pela conta confirma bytes")
	var read := await account.read(self)
	var world := open_world(account, read)
	await step()
	var state: Dictionary = world.progress_store.capture()
	var expected: Dictionary = original.campaign.duplicate(true)
	if stage == "active": expected.encounter = "retry"; expected.final_wave = 0
	check(same(state.campaign, expected), stage + ": carregamento conserva campanha e retentativa prevista")
	check(same(state.inventory, original.inventory) and same(state.structures, original.structures), stage + ": bolsa, baú, IDs e construções exatos")
	check(state.world_seed == original.world_seed and state.player.position == original.player.position and state.player.health == original.player.health, stage + ": semente, posição e vida preservadas")
	check(world.objectives.campaign_tasks.collapsed and world.objectives.campaign_tasks.ever("fogueira"), stage + ": fabricação gasta e painel recolhido sobrevivem")
	check(world.get_node("HUD").current_panel != "victory" and world.campaign.final_enemies().is_empty(), stage + ": reabertura não repete vitória nem duplica invasores")
	check(await world.save_progress(true), stage + ": snapshot atual salvo sem bloquear a conta")
	world.queue_free()
	await step()
	read = await account.read(self)
	check(same(read.campaign, expected), stage + ": disco mantém campanha após fechar")
	var encoded := CloudCodec.encode(read)
	var head := {"schema":1,"owner_uid":account.uid,"world_id":account.world_id,"name":read.world_name,"revision":1,"snapshot":"release-reopen","chunk_count":encoded.chunks.size(),"raw_bytes":encoded.raw_bytes,"encoded_bytes":encoded.encoded_bytes,"hash":encoded.hash}
	var decoded := CloudCodec.decode(head, encoded.chunks, account.uid, account.world_id)
	check(decoded.ok and same(decoded.data.campaign, expected), stage + ": protocolo de sincronização conserva checkpoint")
	world = open_world(account, read)
	await step()
	check(same(world.campaign.capture(), expected), stage + ": segunda reabertura é idempotente")
	if stage == "won":
		check(world.campaign.victory_day == 7 and world.objectives.campaign_tasks.task("rescue").done, "Vitória do dia 7 continua concluída")
	if stage == "map_pending": check(not world.campaign.map_found and not world.minimap.tower_navigation().is_empty(), "Mapa pendente continua alcançável e não é concedido ao reabrir")
	world.queue_free()
	await step()
func run() -> void:
	var folder := "res://.tools/reopen-%d" % Time.get_ticks_usec()
	for stage in ["map_pending", "temple_partial", "active", "awaiting_dawn", "won"]: await round_trip(stage, folder)
	print("PILOT REOPEN: %d verificações, %d falhas" % [checks, failures])
	quit(1 if failures else 0)
