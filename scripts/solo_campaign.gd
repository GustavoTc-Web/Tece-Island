class_name SoloCampaign
extends Node
signal changed
signal won

# Additive schema: the existing save, inventory and sync envelope keep their IDs.
const VERSION := 1
const COMPONENTS := ["lens", "coil", "core"]
const TITLES := {"lens": "Lente da torre", "coil": "Bobina das ruínas", "core": "Núcleo do castelo"}
const LOCATIONS := {"beacon": Vector2(1152, 570), "clue": Vector2(550, 1310), "lens": Vector2(1152, -2048), "coil": Vector2(3072, -2048), "core": Vector2(2800, 520)}
var discovered := false
var clues := false
var components: Array[String] = []
var repaired := false
var encounter := "idle"
var attempts := 0
var victory_day := 0
var deaths := 0
var world: Node2D
var boss: ForestCreature
var points := {}
var warned_day := 0

static func valid(data: Variant) -> bool:
	if not data is Dictionary: return false
	if data.is_empty(): return true
	if data.get("version") != VERSION: return false
	for key in ["discovered", "clues", "repaired"]:
		if not data.get(key) is bool: return false
	if not data.get("components") is Array: return false
	var seen := {}
	for id in data.components:
		if id not in COMPONENTS or seen.has(id): return false
		seen[id] = true
	if data.repaired and seen.size() != 3: return false
	if (data.clues or not seen.is_empty() or data.repaired) and not data.discovered: return false
	if data.get("encounter") not in ["idle", "active", "retry", "won"]: return false
	if data.encounter in ["active", "retry", "won"] and not data.repaired: return false
	for key in ["attempts", "victory_day", "deaths"]:
		var value: Variant = data.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) or value < 0 or value != floorf(value): return false
	if data.encounter == "won" and data.victory_day < 7: return false
	if data.encounter == "won" and data.attempts < 1: return false
	if data.encounter != "won" and data.victory_day != 0: return false
	return true

func capture() -> Dictionary:
	return {"version": VERSION, "discovered": discovered, "clues": clues, "components": components.duplicate(), "repaired": repaired, "encounter": encounter, "attempts": attempts, "victory_day": victory_day, "deaths": deaths}

func restore(data: Dictionary) -> bool:
	if not valid(data): return false
	if data.is_empty(): return true
	discovered = data.discovered
	clues = data.clues
	components.assign(data.components)
	repaired = data.repaired
	# An interrupted battle always restarts explicitly, at full boss health.
	encounter = "retry" if data.encounter == "active" else data.encounter
	attempts = int(data.attempts)
	victory_day = int(data.victory_day)
	deaths = int(data.deaths)
	changed.emit()
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
	world.get_node("DayNight").clock_changed.connect(_clock)
	world.journal.changed.connect(func():
		if "arrival" in world.journal.discovered and not clues: interact("clue"))
	changed.connect(func():
		world.queue_save()
		for marker in points.values(): marker.queue_redraw())

func _clock(day: int, phase: String, remaining: int) -> void:
	if phase == "Anoitecer" and remaining <= 30 and warned_day != day:
		warned_day = day
		world.get_node("HUD").show_message("A noite se aproxima! Prepare luz, água e equipamento." + (" O sinalizador pode ser ativado hoje." if day >= 7 and repaired else ""))
	_refresh_hud()

func _refresh_hud() -> void:
	if world != null: world.get_node("HUD").refresh_objective()

func collect(id: String) -> bool:
	if id not in COMPONENTS or id in components: return false
	components.append(id)
	discovered = true
	changed.emit()
	return true

func interact(id: String) -> String:
	if id in COMPONENTS:
		return "Componente protegido no diário: " + TITLES[id] if collect(id) else "Componente já recuperado."
	if id == "clue":
		clues = true
		discovered = true
		changed.emit()
		return "Diário atualizado: torre ao norte do Pântano, ruínas ao norte dos Campos e castelo no Pântano."
	if not discovered:
		discovered = true
		changed.emit()
		return "Sinalizador quebrado. A casa abandonada a sudoeste guarda as pistas. Consulte o Diário."
	if not repaired:
		if components.size() < 3: return "Faltam %d componentes. Os encontrados estão protegidos no Diário." % (3 - components.size())
		repaired = true
		changed.emit()
		return "Sinalizador reparado. Prepare-se: ative a partir da sétima noite."
	if encounter == "won": return "Resgate confirmado. A ilha continua disponível para explorar."
	if encounter == "active": return "O Guardião está aqui. Vença-o ou recue para tentar novamente."
	var cycle: DayNightCycle = world.get_node("DayNight")
	if cycle.day_number < 7 or not cycle.is_night(): return "Ative durante qualquer noite a partir do dia 7. O mundo não tem prazo de expiração."
	return "O sinal chamou o Guardião da Ilha!" if start_encounter() else "Libere a clareira ao redor do sinalizador para o confronto."

func start_encounter() -> bool:
	if not repaired or encounter in ["active", "won"]: return false
	var player: CharacterBody2D = world.get_node("WorldObjects/Player")
	var cycle: DayNightCycle = world.get_node("DayNight")
	if player.dead or cycle.day_number < 7 or not cycle.is_night(): return false
	var center: Vector2 = points.beacon.position
	var spawn := Vector2.INF
	var shape := CircleShape2D.new()
	shape.radius = 24
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = 15
	for radius in [210, 320, 440]:
		for i in range(24):
			var candidate: Vector2 = center + Vector2.from_angle(i * TAU / 24) * float(radius)
			if not WorldTerrain.solid_ground(candidate, Vector2(48, 48)): continue
			query.transform = Transform2D(0, candidate)
			if player.get_world_2d().direct_space_state.intersect_shape(query).is_empty():
				spawn = candidate
				break
		if spawn.is_finite(): break
	if not spawn.is_finite(): return false
	boss = preload("res://scenes/forest_creature.tscn").instantiate()
	boss.kind = "guardiao_ilha"
	boss.origin = "campanha"
	boss.player = player
	boss.position = spawn
	boss.safe_radius = 0
	world.get_node("WorldObjects").add_child(boss)
	boss.defeated.connect(finish)
	encounter = "active"
	attempts += 1
	changed.emit()
	return true

func interrupt_battle() -> void:
	if encounter != "active": return
	encounter = "retry"
	if is_instance_valid(boss):
		boss.collision_layer = 0
		boss.remove_from_group("enemies")
		boss.queue_free()
	for node in get_tree().get_nodes_in_group("campaign_projectiles"): node.queue_free()
	changed.emit()

func finish() -> void:
	if encounter != "active": return
	encounter = "won"
	victory_day = world.get_node("DayNight").day_number
	for node in get_tree().get_nodes_in_group("campaign_projectiles"): node.queue_free()
	changed.emit()
	won.emit()

func _physics_process(_delta: float) -> void:
	if world == null or encounter != "active": return
	var player: CharacterBody2D = world.get_node("WorldObjects/Player")
	if player.dead or player.position.distance_to(points.beacon.position) > 900 or not world.get_node("DayNight").is_night():
		interrupt_battle()
		world.get_node("HUD").show_message("Confronto interrompido. Componentes preservados: reative em outra noite.")

func objective() -> String:
	if encounter == "won": return "Resgate concluído · Explore a ilha"
	if encounter == "active": return "Vença o Guardião da Ilha"
	if not discovered: return "Investigue o sinal · perto do início"
	if not clues and components.is_empty(): return "Pistas · casa a sudoeste do início"
	if components.size() < 3: return "Resgate · componentes %d/3" % components.size()
	if not repaired: return "Repare o sinalizador · início"
	return "Ative o sinal · noite 7 ou posterior"

# Old player bases are never moved or deleted. A nearby journal interaction
# recovers access through those old walls; new construction reserves the markers.
func blocked_by_base(id: String) -> bool:
	if world == null or not points.has(id): return false
	var point: Vector2 = points[id].global_position
	if world.get_node("WorldObjects/Player").global_position.distance_to(point) > 400: return false
	for node in world.get_node("WorldObjects").get_children():
		if node is PlacedStructure and node.position.distance_to(point) < 200: return true
	return false

func journal_text() -> String:
	var lines: Array[String] = ["RESGATE · " + objective(), "Sinalizador: próximo ao início (1152, 570). Interaja com E / botão de coleta.", "Pistas: casa abandonada a sudoeste (550, 1310)."]
	if clues or not components.is_empty():
		for id in COMPONENTS:
			lines.append(("[x] " if id in components else "[ ] ") + TITLES[id] + " · " + {"lens": "Serra Nebulosa, torre ao norte do Pântano (1152, -2048)", "coil": "Floresta Queimada, ruínas ao norte dos Campos (3072, -2048)", "core": "castelo abandonado no Pântano (2800, 520)"}[id])
	lines.append("Ritmo sugerido: dia 1 recursos e sinal; 2 pistas; 3 serra; 4 floresta queimada; 5 castelo; 6 reparo e suprimentos; 7 confronto. Você pode explorar e coletar antes.")
	lines.append("Os componentes não ocupam bolsa e não podem ser descartados. Ative em qualquer noite do dia 7 em diante. Derrota, amanhecer, fuga ou saída permitem reiniciar o chefe, com vida cheia, preservando o mundo.")
	lines.append("Leve espada, armadura fabricada, arco, flechas e suprimentos. A linha dourada anuncia a investida; o leque azul anuncia três projéteis. Esquive lateralmente.")
	return "\n\n".join(lines)
