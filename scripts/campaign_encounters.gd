class_name CampaignEncounters
extends RefCounted

const ORDER := ["lens", "coil", "core"]
const NAMES := {"lens": "Templo da Névoa", "coil": "Templo das Cinzas", "core": "Templo do Eco"}
const CENTERS := {"lens": Vector2(750, -2048), "coil": Vector2(3072, -2048), "core": Vector2(-2304, 1536.0 * 0.6 / 2.2)}
const WAVES := {
	"lens": [["criatura", "sentinela"], ["acolito", "aranha"]],
	"coil": [["sentinela", "acolito", "aranha"], ["cacador", "acolito", "sentinela"]],
	"core": [["acolito", "sentinela", "aranha"], ["sentinela", "cacador", "acolito"]]}
const FINAL_WAVES := [["criatura", "aranha", "cacador"], ["brutamonte", "uivador", "cacador"]]
const OFFSETS := [Vector2(-150, -100), Vector2(160, -100), Vector2(180, 120)]

static func enemy_ids(id: String) -> Array[String]:
	var result: Array[String] = []
	for wave in range(WAVES[id].size()):
		for slot in range(WAVES[id][wave].size()): result.append("%d-%d" % [wave, slot])
	return result

static func initial_temple() -> Dictionary:
	return {"started": false, "cleared": [], "health": {}, "elapsed": 0.0, "credit": false}

static func valid_temple(id: String, data: Variant) -> bool:
	if not data is Dictionary or not data.get("started") is bool or not data.get("credit") is bool: return false
	if not data.get("cleared") is Array or not data.get("health") is Dictionary: return false
	if not (data.get("elapsed") is int or data.get("elapsed") is float) or not is_finite(float(data.elapsed)) or data.elapsed < 0: return false
	var ids := enemy_ids(id)
	var seen := {}
	for token in data.cleared:
		if token not in ids or seen.has(token): return false
		seen[token] = true
	for token in data.health:
		if token not in ids or token in data.cleared: return false
		var hp: Variant = data.health[token]
		if not (hp is int or hp is float) or hp < 1 or hp > 100 or hp != floorf(hp): return false
	if not data.started and (not data.cleared.is_empty() or not data.health.is_empty()): return false
	# A later wave cannot be completed before the previous one.
	if data.cleared.size() > 0:
		for token in data.cleared:
			if str(token).begins_with("1-"):
				for slot in range(WAVES[id][0].size()):
					if ("0-%d" % slot) not in seen: return false
	return true

static func complete(id: String, data: Dictionary) -> bool:
	return data.credit or data.cleared.size() == enemy_ids(id).size()
