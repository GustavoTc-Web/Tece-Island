class_name SoloCampaign
extends Node
signal changed
signal won
const VERSION := 2
const COMPONENTS := ["lens", "coil", "core"]
const TITLES := {"lens": "Lente do sinal", "coil": "Bobina do sinal", "core": "Núcleo do sinal"}
const LOCATIONS := {"beacon": Vector2(1152, 570), "clue": Vector2(550, 1310), "map": Vector2(1152, -2048), "lens": Vector2(750, -2048), "coil": Vector2(3072, -2048), "core": Vector2(-2339, 1536.0 * 0.6 / 2.2 + 85)}
var discovered := false
var clues := false
var map_found := false
var components: Array[String] = []
var repaired := false
var encounter := "idle"
var attempts := 0
var victory_day := 0
var deaths := 0
var rescue_night := 0
var final_wave := 0
var legacy_migrated := false
var temples := {}
var controllers := {}
var world: Node2D
var boss: ForestCreature
var points := {}
var warned_day := 0
var event_spawn_retry := 0.0
var conversion_notice := false

func _init() -> void:
	for id in COMPONENTS: temples[id] = CampaignEncounters.initial_temple()

static func valid(data: Variant) -> bool:
	if not data is Dictionary: return false
	if data.is_empty(): return true
	# JSON numbers are floats in Godot; Array.has would reject 1.0 against 1.
	if data.get("version") != 1 and data.get("version") != VERSION: return false
	for key in ["discovered", "clues", "repaired"]:
		if not data.get(key) is bool: return false
	if not data.get("components") is Array: return false
	var seen := {}
	for id in data.components:
		if id not in COMPONENTS or seen.has(id): return false
		seen[id] = true
	if data.repaired and seen.size() != 3: return false
	if (data.clues or not seen.is_empty() or data.repaired) and not data.discovered: return false
	var states := ["idle", "active", "retry", "won"]
	if data.version == VERSION: states.append("awaiting_dawn")
	if data.get("encounter") not in states: return false
	if data.encounter in ["active", "retry", "awaiting_dawn", "won"] and not data.repaired: return false
	for key in ["attempts", "victory_day", "deaths"]:
		var value: Variant = data.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) or value < 0 or value != floorf(value): return false
	if data.encounter == "won" and (data.victory_day < 7 or data.attempts < 1): return false
	if data.encounter != "won" and data.victory_day != 0: return false
	if data.version == 1: return true
	if not data.get("map_found") is bool or not data.get("legacy_migrated") is bool or not data.get("temples") is Dictionary or data.temples.size() != 3: return false
	for id in COMPONENTS:
		if not CampaignEncounters.valid_temple(id, data.temples.get(id)): return false
		if data.temples[id].credit and not data.legacy_migrated: return false
		if (id in data.components) != CampaignEncounters.complete(id, data.temples[id]): return false
	if (data.repaired or not seen.is_empty()) and not data.map_found and not data.legacy_migrated: return false
	for key in ["rescue_night", "final_wave"]:
		var value: Variant = data.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) or value < 0 or value != floorf(value): return false
	if data.final_wave > 2: return false
	if data.encounter in ["active", "awaiting_dawn"] and (data.rescue_night < 6 or not data.map_found or data.attempts < 1): return false
	if data.encounter == "awaiting_dawn" and data.final_wave != 2: return false
	if data.encounter == "won" and data.rescue_night > 0 and (data.rescue_night < 6 or data.victory_day <= data.rescue_night or data.final_wave != 2 or not data.map_found): return false
	return true

func capture() -> Dictionary:
	for controller in controllers.values(): controller.capture_health()
	return {"version": VERSION, "discovered": discovered, "clues": clues, "map_found": map_found, "components": components.duplicate(), "repaired": repaired, "encounter": encounter, "attempts": attempts, "victory_day": victory_day, "deaths": deaths, "rescue_night": rescue_night, "final_wave": final_wave, "temples": temples.duplicate(true), "legacy_migrated": legacy_migrated}

func restore(data: Dictionary) -> bool:
	if not valid(data): return false
	if data.is_empty(): return true
	discovered = data.discovered
	clues = data.clues
	components.assign(data.components)
	repaired = data.repaired
	encounter = "retry" if data.encounter == "active" else data.encounter
	attempts = int(data.attempts)
	victory_day = int(data.victory_day)
	deaths = int(data.deaths)
	if data.version == 1:
		legacy_migrated = true
		map_found = false
		rescue_night = 0
		final_wave = 0
		conversion_notice = true
		for id in COMPONENTS:
			temples[id] = CampaignEncounters.initial_temple()
			# Only components actually recorded in v1 receive explicit legacy credit.
			temples[id].credit = id in components
	else:
		map_found = data.map_found
		temples = data.temples.duplicate(true)
		legacy_migrated = data.legacy_migrated
		rescue_night = int(data.rescue_night)
		final_wave = int(data.final_wave) if encounter != "retry" else 0
	mark_changed()
	return true

func initialize(source: Node2D) -> void:
	world = source
	for id in LOCATIONS:
		var marker := CampaignLandmark.new()
		marker.campaign = self
		marker.kind = id
		marker.position = LOCATIONS[id]
		world.get_node("WorldObjects").add_child(marker)
		points[id] = marker
	for id in COMPONENTS:
		var controller := CampaignTemple.new()
		controller.campaign = self
		controller.temple_id = id
		add_child(controller)
		controllers[id] = controller
	world.get_node("DayNight").clock_changed.connect(_clock)
	world.journal.changed.connect(func():
		if "arrival" in world.journal.discovered and not clues: interact("clue"))
	changed.connect(func():
		world.queue_save()
		for marker in points.values(): marker.queue_redraw())

func mark_changed(immediate: bool = false) -> void:
	changed.emit()
	# Immediate local milestones retain the existing cloud interval/conflict rules.
	if immediate and world != null and not world.loading_progress and world.save_controller != null: world.call_deferred("save_progress", false)

func _clock(day: int, phase: String, remaining: int) -> void:
	if phase == "Anoitecer" and remaining <= 30 and warned_day != day:
		warned_day = day
		world.get_node("HUD").show_message("A noite se aproxima · prepare água, comida e equipamento. " + ("Ataque final: noite 6 ou posterior." if day >= 6 and repaired else "Veja a próxima etapa no Diário."))
	_refresh_hud()

func _refresh_hud() -> void:
	if world != null: world.get_node("HUD").refresh_objective()

func night_requirement(minimum: int) -> String:
	var cycle: DayNightCycle = world.get_node("DayNight")
	if cycle.day_number < minimum: return "Aguarde a noite %d · agora: %s %d." % [minimum, "Noite" if cycle.is_night() else "Dia", cycle.day_number]
	if not cycle.is_night(): return "Aguarde anoitecer · disponível em qualquer noite a partir da %d." % minimum
	return ""

func temple_requirement(id: String) -> String:
	if CampaignEncounters.complete(id, temples[id]): return "Conquista registrada · componente já protegido no Diário."
	if not map_found: return "Falta o mapa da torre · recupere-o na Serra a partir da terceira noite."
	if temples[id].started: return ""
	if id != "lens" and not CampaignEncounters.complete("lens", temples.lens): return "Conquiste primeiro o Templo da Névoa (ALTO)."
	return night_requirement(4 if id == "lens" else 5)

func activation_requirement() -> String:
	if not map_found: return "Falta recuperar o mapa na torre da Serra, na noite 3 ou posterior."
	if components.size() < 3: return "Faltam %d componentes · conclua os templos indicados no Diário." % (3 - components.size())
	if not repaired: return "Falta reparar o sinalizador · disponível a partir do dia 6."
	var requirement := night_requirement(6)
	if not requirement.is_empty(): return requirement
	var cycle: DayNightCycle = world.get_node("DayNight")
	if cycle.remaining_seconds < minf(180, cycle.night_duration * 0.6): return "Pouco tempo de noite · ative na próxima, com pelo menos 3 minutos para o ataque."
	return ""

func collect(id: String) -> bool:
	if id not in COMPONENTS or id in components or not CampaignEncounters.complete(id, temples[id]): return false
	components.append(id)
	discovered = true
	mark_changed(true)
	return true

func complete_temple(id: String) -> void:
	if CampaignEncounters.complete(id, temples[id]) and collect(id): world.get_node("HUD").show_message("%s conquistado · %s protegido no Diário." % [CampaignEncounters.NAMES[id], TITLES[id]])

func interact(id: String) -> String:
	if id in COMPONENTS:
		var requirement := temple_requirement(id)
		if not requirement.is_empty(): return requirement
		temples[id].started = true
		mark_changed(true)
		return CampaignEncounters.NAMES[id] + " · desafio iniciado. Derrote as duas formações; cada inimigo vencido fica registrado."
	if id == "map":
		if map_found: return "Mapa já registrado · três templos indicados no Diário."
		var requirement := night_requirement(3)
		if not requirement.is_empty(): return requirement
		map_found = true
		discovered = true
		mark_changed(true)
		return "Mapa recuperado · três templos revelados. Prepare armadura, espada, arco, flechas e comida."
	if id == "clue":
		clues = true
		discovered = true
		mark_changed(true)
		return "Diário atualizado · procure o mapa na torre da Serra, na terceira noite ou depois."
	if id != "beacon": return "Objetivo desconhecido."
	if not discovered:
		discovered = true
		mark_changed(true)
		return "Sinalizador quebrado · prepare recursos e procure as pistas na casa a sudoeste."
	if encounter == "won": return "Resgate confirmado · continue explorando ou releia o resumo no Diário."
	if encounter == "awaiting_dawn": return "Guardião derrotado · o resgate será confirmado ao amanhecer."
	if encounter == "active": return "Ataque em andamento · " + ("vença o Guardião, o último confronto." if final_wave == 2 else "derrote os invasores antes do Guardião.")
	if not repaired:
		if not map_found or components.size() < 3: return activation_requirement()
		if world.get_node("DayNight").day_number < 6: return "Três componentes protegidos · reparo disponível a partir do dia 6."
		repaired = true
		mark_changed(true)
		return "Sinalizador reparado · prepare-se e ative na sexta noite ou em outra posterior."
	var requirement := activation_requirement()
	if not requirement.is_empty(): return requirement
	return "O ataque final começou · o Guardião virá por último!" if start_encounter() else "Não foi possível iniciar · libere espaço próximo ao sinalizador."

func start_encounter() -> bool:
	if world == null or encounter in ["active", "awaiting_dawn", "won"] or world.get_node("WorldObjects/Player").dead or not activation_requirement().is_empty(): return false
	encounter = "active"
	final_wave = 0
	rescue_night = world.get_node("DayNight").day_number
	attempts += 1
	event_spawn_retry = 0
	mark_changed(true)
	return true

func final_enemies() -> Array[ForestCreature]:
	var result: Array[ForestCreature] = []
	for node in get_tree().get_nodes_in_group("final_encounter"):
		if world.is_ancestor_of(node) and not node.dead and not node.is_queued_for_deletion(): result.append(node)
	return result

func spawn_enemy(kind: String, preferred: Vector2, enemy_origin: String, center: Vector2, base_access: bool = false) -> ForestCreature:
	var player: CharacterBody2D = world.get_node("WorldObjects/Player")
	var candidates: Array[Vector2] = [preferred]
	if base_access: candidates = [player.position + Vector2(160, 0)]
	var anchor: Vector2 = player.position if base_access else preferred
	for radius in [64, 128, 200, 280]:
		for i in range(12): candidates.append(anchor + Vector2.from_angle(i * TAU / 12) * float(radius))
	var shape := CircleShape2D.new()
	shape.radius = 15
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = 15
	for candidate in candidates:
		if candidate.distance_to(player.position) < 80 or candidate.distance_to(center) > 750 or not WorldTerrain.solid_ground(candidate, Vector2(32, 32)): continue
		if enemy_origin == "templo" and not Rect2(center - Vector2(300, 210), Vector2(600, 420)).has_point(candidate): continue
		query.transform = Transform2D(0, candidate)
		if not player.get_world_2d().direct_space_state.intersect_shape(query).is_empty(): continue
		if base_access:
			var ray := PhysicsRayQueryParameters2D.create(player.position, candidate, 9)
			if not player.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(): continue
		var mob: ForestCreature = preload("res://scenes/forest_creature.tscn").instantiate()
		mob.kind = kind
		mob.origin = enemy_origin
		mob.player = player
		mob.position = candidate
		mob.safe_radius = 0
		mob.territory_radius = 620
		mob.detection_range = 620
		mob.give_up_range = 800
		mob.reinforcement_handler = world.get_node("EnemySpawner").summon_for_howler
		world.get_node("WorldObjects").add_child(mob)
		mob.home = center
		return mob
	return null

func _advance_final() -> void:
	if not final_enemies().is_empty(): return
	var kinds: Array = CampaignEncounters.FINAL_WAVES[final_wave] if final_wave < 2 else ["guardiao_ilha"]
	for slot in range(kinds.size()):
		var preferred: Vector2 = points.beacon.position + Vector2.from_angle(slot * TAU / kinds.size()) * 210
		var mob := spawn_enemy(kinds[slot], preferred, "campanha", points.beacon.position, base_near(points.beacon.position))
		if mob == null:
			clear_final_enemies()
			world.get_node("HUD").show_message("Invasores aguardam espaço livre perto do sinalizador · afaste-se das paredes da base.")
			return
		mob.add_to_group("final_encounter")
		if final_wave == 2:
			boss = mob
			mob.defeated.connect(finish)
		else: mob.defeated.connect(_final_enemy_defeated)
	world.get_node("HUD").show_message("Guardião da Ilha · último confronto!" if final_wave == 2 else "Ataque final · formação %d/2" % (final_wave + 1))

func _final_enemy_defeated() -> void:
	if encounter == "active" and final_enemies().is_empty():
		final_wave += 1
		event_spawn_retry = 1.5
		mark_changed(true)

func clear_final_enemies() -> void:
	for mob in final_enemies():
		mob.collision_layer = 0
		mob.remove_from_group("enemies")
		mob.queue_free()
	for node in get_tree().get_nodes_in_group("campaign_projectiles"):
		if world.is_ancestor_of(node): node.queue_free()

func interrupt_battle() -> void:
	if encounter != "active": return
	encounter = "retry"
	final_wave = 0
	clear_final_enemies()
	mark_changed(true)

func finish() -> void:
	if encounter != "active" or final_wave != 2 or not is_instance_valid(boss) or not boss.dead: return
	encounter = "awaiting_dawn"
	for node in get_tree().get_nodes_in_group("campaign_projectiles"):
		if world.is_ancestor_of(node): node.queue_free()
	mark_changed(true)
	world.get_node("HUD").show_message("Guardião derrotado · aguarde o amanhecer para confirmar o resgate.")

func _physics_process(delta: float) -> void:
	if world == null: return
	if conversion_notice and not world.loading_progress:
		conversion_notice = false
		world.get_node("HUD").show_message("Piloto atualizado · conquistas anteriores preservadas (%d/3 componentes). Confira a conversão e o novo roteiro no Diário." % components.size())
	var cycle: DayNightCycle = world.get_node("DayNight")
	if encounter == "awaiting_dawn" and cycle.day_number > rescue_night and not cycle.is_night():
		encounter = "won"
		victory_day = cycle.day_number
		mark_changed(true)
		won.emit()
	if encounter != "active": return
	var player: CharacterBody2D = world.get_node("WorldObjects/Player")
	if player.dead or player.position.distance_to(points.beacon.position) > 900 or not cycle.is_night():
		interrupt_battle()
		world.get_node("HUD").show_message("Ataque interrompido · conquistas e reparo preservados. Reative em outra noite, a partir da sexta.")
		return
	event_spawn_retry = maxf(0, event_spawn_retry - delta)
	if event_spawn_retry == 0:
		event_spawn_retry = 0.5
		_advance_final()

func objective() -> String:
	if encounter == "won": return "Resgate concluído · explore"
	if encounter == "awaiting_dawn": return "Aguarde amanhecer · resgate"
	if encounter == "active": return "Guardião · último confronto" if final_wave == 2 else "Ataque · invasores %d/2" % (final_wave + 1)
	var day: int = world.get_node("DayNight").day_number if world != null else 1
	if not discovered: return "Recursos · investigue o sinal"
	if not map_found:
		if day < 3: return "Prepare · mapa na noite 3"
		return "Mapa · aguarde anoitecer" if world != null and not world.get_node("DayNight").is_night() else "Mapa · torre da Serra"
	for id in COMPONENTS:
		if not CampaignEncounters.complete(id, temples[id]):
			var minimum := 4 if id == "lens" else 5
			var number := COMPONENTS.find(id) + 1
			if not temples[id].started and not night_requirement(minimum).is_empty(): return "Templo %d · noite %d+" % [number, minimum]
			return "Templo %d · %d/%d vencidos" % [number, temples[id].cleared.size(), CampaignEncounters.enemy_ids(id).size()]
	if not repaired: return "3/3 · repare no dia 6" if day < 6 else "3/3 · repare o sinal"
	if world != null and not activation_requirement().is_empty():
		return "Pronto · próxima noite" if world.get_node("DayNight").is_night() and day >= 6 else "Pronto · aguarde noite 6+"
	return "Pronto · inicie o ataque"

func base_near(point: Vector2) -> bool:
	for node in world.get_node("WorldObjects").get_children():
		if node is PlacedStructure and node.position.distance_to(point) < 230: return true
	return false

func blocked_by_base(id: String) -> bool:
	return world != null and points.has(id) and world.get_node("WorldObjects/Player").position.distance_to(points[id].position) <= 400 and base_near(points[id].position)

func local_darkness(point: Vector2) -> bool:
	for center in CampaignEncounters.CENTERS.values():
		if Rect2(center - Vector2(300, 210), Vector2(600, 420)).has_point(point): return true
	return false

func journal_text() -> String:
	var lines: Array[String] = ["RESGATE · " + objective(), "Componentes protegidos: %d/3 · sinalizador %s. Nada ocupa a bolsa." % [components.size(), "reparado" if repaired else "quebrado"], "Sinalizador: (1152, 570). Mapa: torre da Serra (1152, -2048), a partir da terceira noite."]
	if not map_found and encounter != "won": lines.append("Como chegar ao mapa: siga o ícone da torre no minimapa. Fora do alcance, a seta na borda e o rumo indicam a direção. Partindo do sinalizador, vá ao norte pela trilha central do Pântano até a Serra Nebulosa. O mapa está no chão, na base aberta da torre; não precisa subir. Aproxime-se do pergaminho e aperte E ou toque em Interagir durante qualquer noite a partir da terceira. De dia, aguarde anoitecer; o objetivo não expira. Se uma construção antiga bloquear o acesso, aproxime-se e use Acessar mapa pela base neste Diário.")
	if legacy_migrated: lines.append("Conversão do piloto .1: componentes e reparo anteriores preservados. Cada componente registrado credita seu desafio, sem inventar conquista de combate nem outro item. Vitórias antigas continuam concluídas. Recupere o novo mapa se a campanha ainda estiver aberta.")
	if legacy_migrated:
		var credits: Array[String] = []
		for id in components:
			if temples[id].credit: credits.append(TITLES[id])
		lines.append("Crédito legado: " + (", ".join(credits) if not credits.is_empty() else "nenhum componente registrado no piloto anterior."))
	if map_found:
		for id in COMPONENTS:
			var state: Dictionary = temples[id]
			var point: Vector2 = LOCATIONS[id]
			var status := "Crédito legado · componente anterior" if state.credit else ("Conquistado" if CampaignEncounters.complete(id, state) else "%d/%d inimigos vencidos" % [state.cleared.size(), CampaignEncounters.enemy_ids(id).size()])
			lines.append("%s · %s · (%d, %d)\n%s · componente %s" % [CampaignEncounters.NAMES[id], "ALTO / noite 4+" if id == "lens" else "EXTREMO / noite 5+", point.x, point.y, status, "obtido" if id in components else "pendente"])
	lines.append("Dias/noites 1–2: recursos, ferramentas, espada, comida, água e armadura. Noite 1: roxos; 2: esqueletos e aranhas; 3: mapa e Caçador; 4: templo alto; 5: dois extremos; dia 6: reparo; noite 6: ataque final; amanhecer 7: resgate, se o Guardião caiu.")
	lines.append("Templos: inicie na noite indicada ou posterior. Depois de iniciado, o desafio pode continuar de dia na construção. Inimigos, dano e conquistas ficam ao sair; Sentinelas e Acólitos não aparecem no mundo aberto. Dentro dos templos, as formações substituem os surgimentos comuns; guardiões das construções continuam. Os ataques têm aviso e respeitam obstáculos.")
	lines.append("Prepare armadura de pedra (20 pedras + 4 linhas), espada (1 madeira + 2 pedras), arco (8 madeiras + 3 linhas), flechas (2 madeiras + 1 pedra por 4) e comida cozida. Priorize equipamento antes da bolsa opcional. Pistola e doze são alternativas; loot comum preservado.")
	lines.append("Ataque final: mapa, três componentes, sinal reparado e noite 6+, com pelo menos 3 minutos de noite. Duas formações precedem o Guardião. Brutamonte e Uivador entram na sexta noite; atacar o Uivador interrompe seu chamado. Após vencer o Guardião, aguarde amanhecer. O relógio sozinho nunca dá vitória.")
	lines.append("Atrasos não expiram a campanha. Derrota, fuga ou saída durante o ataque exigem nova ativação; invasores e chefe reiniciam, mas templos, componentes e reparo ficam. Guardião já vencido mantém o resgate pendente após reabrir. Vitória salva não repete a tela automaticamente.")
	return "\n\n".join(lines)
