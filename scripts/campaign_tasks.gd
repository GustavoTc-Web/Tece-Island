class_name CampaignTasks
extends RefCounted
signal changed
const VERSION := 1
const CRAFT_IDS := ["machado_madeira", "picareta_madeira", "espada_pedra", "machado_pedra", "picareta_pedra", "fogueira", "mochila", "armadura_pedra", "arco", "cantil"]
const STAGES := [
	{"title": "Dia 1 · Kit inicial", "day": 1, "tasks": ["axe", "pick", "sword", "fire"]},
	{"title": "Dia 2 · Preparação", "day": 2, "tasks": ["stone_tools", "bag", "armor", "food2", "water2"]},
	{"title": "Dia 3 · Expedição", "day": 3, "tasks": ["bow", "arrows8", "food3", "water3", "map"]},
	{"title": "Dia 4 · Templo alto", "day": 4, "tasks": ["wear", "weapon", "food3", "water3", "lens"]},
	{"title": "Dia 5 · Dois extremos", "day": 5, "tasks": ["wear", "food6", "water3", "arrows16", "coil", "core"]},
	{"title": "Dia 6 · Preparação final", "day": 6, "tasks": ["repair", "wear", "weapon", "food6", "water3", "arrows16"]},
	{"title": "Noite 6+ · Ataque final", "day": 6, "tasks": ["activate", "waves", "guardian"]},
	{"title": "Amanhecer · Resgate", "day": 7, "tasks": ["rescue"]}]
const LABELS := {"axe":"Obter machado de madeira ou melhor", "pick":"Obter picareta de madeira ou melhor", "sword":"Fabricar espada de pedra", "fire":"Fabricar 1 fogueira", "stone_tools":"Fabricar machado e picareta de pedra", "bag":"Fabricar bolsa nível 1", "armor":"Fabricar armadura de pedra", "bow":"Fabricar 1 arco", "wear":"Equipar armadura de pedra", "weapon":"Levar espada de pedra ou arco", "food2":"Levar 2 refeições cozidas", "food3":"Levar 3 refeições cozidas", "food6":"Levar 6 refeições cozidas", "water2":"Levar cantil com 2 doses", "water3":"Levar cantil com 3 doses", "arrows8":"Levar 8 flechas", "arrows16":"Levar 16 flechas", "map":"Recuperar mapa na torre da Serra", "lens":"Conquistar Névoa · ALTO", "coil":"Conquistar Cinzas · EXTREMO", "core":"Conquistar Eco · EXTREMO", "repair":"Reparar o sinalizador", "activate":"Ativar o sinalizador", "waves":"Vencer as 2 formações de invasores", "guardian":"Derrotar o Guardião da Ilha", "rescue":"Confirmar resgate ao amanhecer"}
var world: Node2D
var crafted: Array[String] = []
var inferred: Array[String] = []
var collapsed := false
var last_signature := ""

func capture() -> Dictionary:
	return {"version": VERSION, "crafted": crafted.duplicate(), "inferred": inferred.duplicate(), "collapsed": collapsed}

static func valid(data: Variant) -> bool:
	if not data is Dictionary: return false
	if data.is_empty(): return true
	if data.get("version") != VERSION or not data.get("collapsed") is bool: return false
	if not data.get("crafted") is Array or not data.get("inferred") is Array: return false
	var seen := {}
	for id in data.crafted:
		if id not in CRAFT_IDS or seen.has(id): return false
		seen[id] = true
	var evidence := {}
	for id in data.inferred:
		if id not in seen or evidence.has(id): return false
		evidence[id] = true
	return true

func restore(data: Dictionary) -> bool:
	if not valid(data): return false
	crafted.assign(data.get("crafted", []))
	inferred.assign(data.get("inferred", []))
	collapsed = data.get("collapsed", false)
	return true

func record_crafted(id: String, from_save: bool = false) -> void:
	if ItemCatalog.bag_level(id) > 0: id = "mochila"
	if id not in CRAFT_IDS: return
	var modified := false
	if id not in crafted:
		crafted.append(id)
		if from_save: inferred.append(id)
		modified = true
	elif not from_save and id in inferred:
		inferred.erase(id)
		modified = true
	if modified: changed.emit()

func initialize(source: Node2D) -> void:
	world = source
	world.get_node("Inventory").changed.connect(refresh_live)
	world.campaign.changed.connect(refresh_live)
	world.get_node("DayNight").clock_changed.connect(func(_day, _phase, _remaining): refresh_live())

func refresh_live(_a: Variant = null, _b: Variant = null) -> void:
	if not is_instance_valid(world): return
	# Current conditions are derived, never added to a cumulative counter.
	var snapshot := [automatic_stage()]
	for stage in range(STAGES.size()): snapshot.append(rows(stage))
	var signature := JSON.stringify(snapshot)
	if signature != last_signature:
		last_signature = signature
		changed.emit()

func ever(id: String) -> bool:
	if id == "machado_madeira": return id in crafted or "machado_pedra" in crafted
	if id == "picareta_madeira": return id in crafted or "picareta_pedra" in crafted
	return id in crafted

func automatic_stage() -> int:
	if not is_instance_valid(world): return 0
	var c: SoloCampaign = world.campaign
	if c.encounter in ["won", "awaiting_dawn"]: return 7
	if c.encounter == "active": return 6
	var cycle: DayNightCycle = world.get_node("DayNight")
	var day := cycle.day_number
	if day > 3 and not c.map_found: return 2
	if day > 4 and not CampaignEncounters.complete("lens", c.temples.lens): return 3
	if day > 5 and (not CampaignEncounters.complete("coil", c.temples.coil) or not CampaignEncounters.complete("core", c.temples.core)): return 4
	if day >= 6:
		if c.repaired and cycle.is_night(): return 6
		return 5
	return clampi(day - 1, 0, 4)

func rows(stage: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in STAGES[stage].tasks: result.append(task(id))
	return result

func task(id: String) -> Dictionary:
	var result := {"id": id, "title": LABELS[id], "value": 0, "target": 1, "done": false, "mode": "conquista", "requirement": "", "hint": ""}
	if not is_instance_valid(world): return result
	var inv: ResourceInventory = world.get_node("Inventory")
	var c: SoloCampaign = world.campaign
	var craft_id: String = {"axe":"machado_madeira", "pick":"picareta_madeira", "sword":"espada_pedra", "fire":"fogueira", "bag":"mochila", "armor":"armadura_pedra", "bow":"arco"}.get(id, "")
	if not craft_id.is_empty():
		result.value = int(ever(craft_id))
		result.hint = recipe_hint(craft_id)
		if not result.value:
			result.requirement = inv.craft_error(craft_id)
			if result.requirement == "Materiais insuficientes": result.requirement = "Faltam " + missing_ingredients(inv, craft_id)
			# Making a fire is always possible before cooking is available.
		var from_save := craft_id in inferred or (craft_id == "machado_madeira" and "machado_pedra" in inferred) or (craft_id == "picareta_madeira" and "picareta_pedra" in inferred)
		if from_save: result.hint = "Reconhecido no save anterior · " + result.hint
	elif id == "stone_tools":
		result.target = 2
		result.value = int(ever("machado_pedra")) + int(ever("picareta_pedra"))
		var next_tool := "machado_pedra" if not ever("machado_pedra") else "picareta_pedra"
		result.hint = recipe_hint(next_tool)
		if result.value == 2 and ("machado_pedra" in inferred or "picareta_pedra" in inferred): result.hint = "Reconhecido no save anterior · ferramentas registradas."
		if result.value < 2 and not inv.can_craft(next_tool): result.requirement = "Faltam " + missing_ingredients(inv, next_tool)
	elif id.begins_with("food"):
		result.mode = "agora"
		result.target = int(id.trim_prefix("food"))
		result.value = inv.count_item("carne_cozida") + inv.count_item("peixe_cozido")
		result.hint = "Carne ou peixe cozido; use uma fogueira acesa."
	elif id.begins_with("water"):
		result.mode = "agora"
		result.target = int(id.trim_prefix("water"))
		for slot in inv.slots:
			if slot.get("item") == "cantil": result.value = maxi(result.value, int(slot.get("water", 0)))
		result.hint = "Encha um cantil em um poço. " + recipe_hint("cantil")
	elif id.begins_with("arrows"):
		result.mode = "agora"
		result.target = int(id.trim_prefix("arrows"))
		result.value = inv.count_item("flecha")
		result.hint = "Cada fabricação: 4 flechas por 2 madeiras + 1 pedra."
	elif id == "wear":
		result.mode = "agora"
		result.value = int(inv.armor.get("item") == "armadura_pedra")
		if not result.value and inv.count_item("armadura_pedra") == 0: result.requirement = "Falta armadura na bolsa · fabrique outra ou recupere a guardada."
		result.hint = "Inventário → selecione a armadura → equipar."
	elif id == "weapon":
		result.mode = "agora"
		result.value = int(inv.count_item("espada_pedra") > 0 or inv.count_item("arco") > 0)
		result.hint = "Tenha a arma na bolsa; armas de fogo são opcionais."
	elif id == "map":
		result.value = int(c.map_found or c.encounter == "won")
		result.requirement = c.night_requirement(3)
		result.hint = "Siga o ícone e a seta da torre: ao norte, pelo Pântano até a Serra (1152, -2048). Contorne as construções. Mapa no chão · E ou Interagir · qualquer noite 3+. Não precisa subir."
	elif id in SoloCampaign.COMPONENTS:
		result.value = int(CampaignEncounters.complete(id, c.temples[id]))
		result.requirement = c.temple_requirement(id)
		var point: Vector2 = SoloCampaign.LOCATIONS[id]
		result.hint = "(%d, %d) · %d/%d inimigos vencidos." % [point.x, point.y, c.temples[id].cleared.size(), CampaignEncounters.enemy_ids(id).size()]
		if c.temples[id].credit: result.hint = "Crédito legado · componente anterior preservado."
	elif id == "repair":
		result.value = int(c.repaired)
		if not c.map_found: result.requirement = "Falta recuperar o mapa na torre da Serra."
		elif c.components.size() < 3: result.requirement = "Faltam %d componentes · conquiste os templos pendentes." % (3 - c.components.size())
		elif world.get_node("DayNight").day_number < 6: result.requirement = "Aguarde o dia 6."
		result.hint = "Interaja com o sinalizador (1152, 570)."
	elif id == "activate":
		result.mode = "tentativa atual"
		result.value = int(c.encounter in ["active", "awaiting_dawn", "won"])
		result.requirement = c.activation_requirement()
		result.hint = "Reative após uma tentativa interrompida."
	elif id == "waves":
		result.mode = "tentativa atual"
		result.target = 2
		result.value = 2 if c.encounter in ["awaiting_dawn", "won"] else (c.final_wave if c.encounter == "active" else 0)
		result.requirement = "Ative o sinalizador." if c.encounter not in ["active", "awaiting_dawn", "won"] else ""
		result.hint = "Derrote também os reforços do Uivador."
	elif id == "guardian":
		result.value = int(c.encounter in ["awaiting_dawn", "won"])
		result.requirement = "Vença as duas formações primeiro." if c.final_wave < 2 else ""
		result.hint = "O Guardião é o último confronto."
	elif id == "rescue":
		result.value = int(c.encounter == "won")
		result.requirement = "Derrote o Guardião antes de aguardar o amanhecer." if c.encounter not in ["awaiting_dawn", "won"] else "Aguarde amanhecer."
		result.hint = "O relógio sozinho não concede vitória."
	result.done = result.value >= result.target
	if result.done: result.requirement = ""
	return result

static func recipe_hint(id: String) -> String:
	var parts: Array[String] = []
	for item in ResourceRules.ingredients(id): parts.append("%d %s" % [ResourceRules.ingredients(id)[item], ItemCatalog.title(item).to_lower()])
	return " + ".join(parts)

static func missing_ingredients(inv: ResourceInventory, id: String) -> String:
	var parts: Array[String] = []
	for item in ResourceRules.ingredients(id):
		var missing: int = ResourceRules.ingredients(id)[item] - inv.count_item(item)
		if missing > 0: parts.append("%d %s" % [missing, ItemCatalog.title(item).to_lower()])
	return ", ".join(parts) if not parts.is_empty() else "espaço na bolsa."

func journal_text() -> String:
	var lines: Array[String] = ["PLANO DA JORNADA", "[x] Conquista: fica registrada. Agora: depende da bolsa/equipamento atual. As metas de preparo orientam; não bloqueiam a campanha. Etapas atrasadas continuam abaixo."]
	for stage in range(STAGES.size()):
		var entries := rows(stage)
		var done := entries.filter(func(row): return row.done).size()
		var section: Array[String] = ["%s · %d/%d" % [STAGES[stage].title, done, entries.size()]]
		for row in entries:
			section.append("%s %s · %d/%d (%s)" % ["[x]" if row.done else "[ ]", row.title, mini(row.value, row.target), row.target, row.mode])
			if not row.done: section.append(row.requirement if not row.requirement.is_empty() else row.hint)
			if row.id == "map" and not row.done and not row.requirement.is_empty(): section.append(row.hint)
			elif row.hint.begins_with("Reconhecido no save anterior"): section.append("Reconhecido no save anterior.")
			elif row.hint.begins_with("Crédito legado"): section.append(row.hint)
		lines.append("\n".join(section))
	return "\n\n".join(lines)
