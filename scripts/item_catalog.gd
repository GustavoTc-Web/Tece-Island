class_name ItemCatalog
extends RefCounted

const STACKABLE := ["madeira", "pedra", "fibra", "linha", "municao_pistola", "cartucho", "carne_crua", "carne_cozida"]
const NAMES := {"madeira": "Madeira", "pedra": "Pedra", "fibra": "Fibra vegetal", "linha": "Linha", "mochila": "Bolsa nível 1 — +2 espaços", "cama": "Cama simples", "fogueira": "Fogueira", "pistola": "Pistola", "espingarda": "Espingarda calibre 12", "municao_pistola": "Munição de pistola", "cartucho": "Cartuchos", "carne_crua": "Carne crua", "carne_cozida": "Carne cozida", "cantil": "Cantil"}

static func bag_level(item: String) -> int:
	return {"mochila": 1, "mochila_2": 2, "mochila_3": 3, "mochila_4": 4}.get(item, 0)

static func is_consumable(item: String) -> bool:
	return item in ["carne_cozida", "cantil"]

static func title(item: String) -> String:
	return ResourceRules.RECIPES[item].name if ResourceRules.RECIPES.has(item) else NAMES.get(item, item.capitalize())

static func category(item: String) -> String:
	if item in ["pistola", "espingarda"]:
		return item
	return ResourceRules.RECIPES.get(item, {}).get("category", "")

static func is_equippable(item: String) -> bool:
	return category(item) in ["machado", "picareta", "espada", "pistola", "espingarda"]

