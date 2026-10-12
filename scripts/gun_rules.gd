class_name GunRules
extends RefCounted

# Valores iniciais de teste: alcance em pixels, cadência/recarga em segundos.
const WEAPONS := {
	"arco": {"damage": 12, "range": 550.0, "speed": 450.0, "spread": 0.0, "interval": 1.0, "pellets": 1, "magazine": 0, "reload": 0.0, "ammo": "flecha"},
	"pistola": {"damage": 18, "range": 550.0, "speed": 900.0, "spread": 0.02, "interval": 0.45, "pellets": 1, "magazine": 8, "reload": 1.2, "ammo": "municao_pistola"},
	"espingarda": {"damage": 10, "range": 260.0, "speed": 750.0, "spread": 0.28, "interval": 1.2, "pellets": 6, "magazine": 2, "reload": 1.8, "ammo": "cartucho"},
}
