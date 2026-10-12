class_name ItemCatalog
extends RefCounted

const STACKABLE := ["madeira", "pedra", "fibra", "linha", "flecha", "vidro", "municao_pistola", "cartucho", "carne_crua", "carne_cozida", "carne_peixe", "peixe_cozido"]
const NAMES := {"madeira": "Madeira", "pedra": "Pedra", "fibra": "Fibra vegetal", "linha": "Linha", "vidro": "Vidro", "mochila": "Bolsa nível 1 — +2 espaços", "cama": "Cama simples", "fogueira": "Fogueira", "pistola": "Pistola", "espingarda": "Espingarda calibre 12", "municao_pistola": "Munição de pistola", "cartucho": "Cartuchos", "carne_crua": "Carne crua", "carne_cozida": "Carne cozida", "carne_peixe": "Carne de peixe", "cantil": "Cantil"}

static func bag_level(item: String) -> int:
	return {"mochila": 1, "mochila_2": 2, "mochila_3": 3, "mochila_4": 4}.get(item, 0)

static func quick_title(item: String) -> String:
	if item in ["parede_madeira", "porta_madeira", "vidraca"]: return {"parede_madeira": "Parede", "porta_madeira": "Porta", "vidraca": "Vidraça"}[item]
	if bag_level(item) > 0: return "Bolsa %d" % bag_level(item)
	return {"fibra": "Fibra", "carne_crua": "Carne crua", "carne_cozida": "Carne coz.", "carne_peixe": "Peixe cru", "peixe_cozido": "Peixe coz.", "machado_madeira": "Machado m.", "machado_pedra": "Machado p.", "picareta_madeira": "Picareta m.", "picareta_pedra": "Picareta p.", "espada_madeira": "Espada m.", "espada_pedra": "Espada p.", "cama": "Cama", "espingarda": "Espingarda", "municao_pistola": "Munição", "cartucho": "Cartuchos"}.get(item, title(item))

static func is_consumable(item: String) -> bool:
	return item in ["carne_cozida", "peixe_cozido", "cantil"]

static func title(item: String) -> String:
	return ResourceRules.RECIPES[item].name if ResourceRules.RECIPES.has(item) else NAMES.get(item, item.capitalize())

static func category(item: String) -> String:
	if item in ["pistola", "espingarda"]:
		return item
	return ResourceRules.RECIPES.get(item, {}).get("category", "")

static func is_equippable(item: String) -> bool:
	return category(item) in ["machado", "picareta", "espada", "arco", "pistola", "espingarda"]

