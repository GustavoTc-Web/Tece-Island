class_name CampaignTemple
extends Node
var campaign: SoloCampaign
var temple_id := "lens"
var actors := {}
var spawn_retry := 0.0

func center() -> Vector2: return CampaignEncounters.CENTERS[temple_id]

func capture_health() -> void:
	var state: Dictionary = campaign.temples[temple_id]
	for token in actors:
		var actor: ForestCreature = actors[token]
		if is_instance_valid(actor) and not actor.dead: state.health[token] = actor.health

func _physics_process(delta: float) -> void:
	var state: Dictionary = campaign.temples[temple_id]
	if not state.started or CampaignEncounters.complete(temple_id, state): return
	var player: CharacterBody2D = campaign.world.get_node("WorldObjects/Player")
	if player.dead or player.position.distance_to(center()) > 850: return
	state.elapsed += delta
	spawn_retry = maxf(0, spawn_retry - delta)
	if spawn_retry > 0: return
	spawn_retry = 0.5
	for wave in range(CampaignEncounters.WAVES[temple_id].size()):
		var pending := false
		for slot in range(CampaignEncounters.WAVES[temple_id][wave].size()):
			var token := "%d-%d" % [wave, slot]
			if token in state.cleared: continue
			pending = true
			if is_instance_valid(actors.get(token)): continue
			var kind: String = CampaignEncounters.WAVES[temple_id][wave][slot]
			var preferred: Vector2 = center() + CampaignEncounters.OFFSETS[slot]
			var actor: ForestCreature = campaign.spawn_enemy(kind, preferred, "templo", center(), campaign.base_near(center()))
			if actor == null: continue
			actor.set_meta("temple_id", temple_id)
			actor.set_meta("temple_token", token)
			actor.add_to_group("temple_enemies")
			actor.health = mini(actor.max_health, int(state.health.get(token, actor.max_health)))
			actors[token] = actor
			actor.defeated.connect(_defeated.bind(token))
			actor.wounded.connect(campaign.mark_changed)
		if pending: return
	campaign.complete_temple(temple_id)

func _defeated(token: String) -> void:
	var state: Dictionary = campaign.temples[temple_id]
	if token in state.cleared: return
	state.cleared.append(token)
	state.health.erase(token)
	actors.erase(token)
	spawn_retry = 0
	if CampaignEncounters.complete(temple_id, state): campaign.complete_temple(temple_id)
	else: campaign.mark_changed(true)
