class_name ResourceRules
extends RefCounted

# Ajuste aqui custos, recompensas, número de golpes e intervalo em segundos.
const RECIPES := {
	"cantil": {"name": "Cantil", "category": "agua", "material": "", "wood": 2, "stone": 0, "fiber": 2},
	"carne_cozida": {"name": "Carne cozida", "category": "comida", "material": "", "wood": 1, "stone": 0, "fiber": 0, "meat": 1},
	"peixe_cozido": {"name": "Peixe cozido", "category": "comida", "material": "", "wood": 1, "stone": 0, "fish_meat": 1, "cooking": true},
	"mochila": {"name": "Bolsa nível 1 — +2 espaços", "category": "mochila", "material": "", "wood": 4, "stone": 0, "fiber": 12},
	"mochila_2": {"name": "Bolsa nível 2 — +4 espaços", "category": "mochila", "material": "", "wood": 12, "stone": 0, "thread": 4, "previous_bag": "mochila"},
	"mochila_3": {"name": "Bolsa nível 3 — +6 espaços", "category": "mochila", "material": "", "wood": 20, "stone": 0, "thread": 8, "previous_bag": "mochila_2"},
	"mochila_4": {"name": "Bolsa nível 4 — +8 espaços", "category": "mochila", "material": "", "wood": 30, "stone": 0, "thread": 12, "previous_bag": "mochila_3"},
	"cama": {"name": "Cama simples", "category": "estrutura", "material": "", "wood": 8, "stone": 0, "fiber": 6},
	"fogueira": {"name": "Fogueira", "category": "estrutura", "material": "", "wood": 4, "stone": 5, "fiber": 0},
	"bau": {"name": "Baú de madeira", "category": "estrutura", "material": "", "wood": 20, "stone": 8},
	"parede_madeira": {"name": "Parede de madeira", "category": "estrutura", "material": "", "wood": 4, "stone": 0},
	"porta_madeira": {"name": "Porta de madeira", "category": "estrutura", "material": "", "wood": 6, "stone": 0},
	"vidraca": {"name": "Vidraça com moldura", "category": "estrutura", "material": "", "wood": 4, "stone": 0, "glass": 2},
	"arco": {"name": "Arco", "category": "arco", "material": "madeira", "wood": 8, "stone": 0, "thread": 3},
	"flecha": {"name": "Flechas", "category": "flechas", "material": "", "wood": 2, "stone": 1, "quantity": 4},
	"machado_madeira": {"name": "Machado de madeira", "category": "machado", "material": "madeira", "wood": 3, "stone": 0},
	"picareta_madeira": {"name": "Picareta de madeira", "category": "picareta", "material": "madeira", "wood": 3, "stone": 0},
	"espada_madeira": {"name": "Espada de madeira", "category": "espada", "material": "madeira", "wood": 2, "stone": 0},
	"machado_pedra": {"name": "Machado de pedra", "category": "machado", "material": "pedra", "wood": 2, "stone": 3},
	"picareta_pedra": {"name": "Picareta de pedra", "category": "picareta", "material": "pedra", "wood": 2, "stone": 3},
	"espada_pedra": {"name": "Espada de pedra", "category": "espada", "material": "pedra", "wood": 1, "stone": 2},
}
const EXTRACTION := {
	"fibra": {"reward": 4, "hits": {"maos": 2}},
	"madeira": {"reward": 5, "hits": {"maos": 6, "machado_madeira": 3, "machado_pedra": 2}},
	"pedra": {"reward": 4, "hits": {"picareta_madeira": 6, "picareta_pedra": 3}},
}
# 0.5: +20% uma única vez sobre 1,00 / 0,45 / 0,30 da versão 0.4.
const INTERVAL := {"maos": 1.20, "madeira": 0.54, "pedra": 0.36}
const COMBAT_DAMAGE := {"maos": 5, "espada_madeira": 10, "espada_pedra": 15}


static func combat_damage(tool: String) -> int:
	return COMBAT_DAMAGE.get(tool, 5)


static func crafting_group(id: String) -> String:
	var recipe: Dictionary = RECIPES.get(id, {})
	if recipe.get("cooking", id == "carne_cozida"): return "Fogueira"
	if recipe.get("category", "") in ["machado", "picareta", "espada", "arco", "flechas"]: return "Ferramentas"
	if recipe.get("category", "") == "comida": return "Alimentos"
	return "Recursos"


static func ingredients(id: String) -> Dictionary:
	var recipe: Dictionary = RECIPES.get(id, {})
	var result := {}
	for pair in [["wood", "madeira"], ["stone", "pedra"], ["fiber", "fibra"], ["meat", "carne_crua"], ["thread", "linha"], ["glass", "vidro"], ["fish_meat", "carne_peixe"]]:
		if int(recipe.get(pair[0], 0)) > 0: result[pair[1]] = int(recipe[pair[0]])
	if recipe.has("previous_bag"): result[recipe.previous_bag] = 1
	return result


static func hit_interval(tool: String) -> float:
	if tool == "maos":
		return INTERVAL.maos
	return INTERVAL.get(RECIPES.get(tool, {}).get("material", ""), INTERVAL.maos)


static func guidance(resource: String) -> String:
	if resource == "madeira":
		return "Use as mãos ou um machado na árvore."
	return "Equipe uma picareta para extrair pedra."
