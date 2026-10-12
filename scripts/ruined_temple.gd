class_name RuinedTemple
extends AbandonedBuilding
var chests: Array[Node2D] = []

func _ready() -> void:
	footprint = Vector2(700, 480)
	wall(Vector2(0, -240), Vector2(700, 18))
	wall(Vector2(-350, 0), Vector2(18, 480))
	wall(Vector2(350, 0), Vector2(18, 480))
	wall(Vector2(-205, 240), Vector2(290, 18))
	wall(Vector2(205, 240), Vector2(290, 18))
	# Four rooms open onto the central crossing; entry gap is 120 px.
	for side in [-1, 1]:
		wall(Vector2(0, side * 150), Vector2(14, 180))
		wall(Vector2(side * 205, 0), Vector2(290, 14))

func populate_temple(random: RandomNumberGenerator, budget: int) -> void:
	if initialized: return
	initialized = true
	var count := random.randi_range(3, 5)
	var positions := [Vector2(-210, -120), Vector2(210, -120), Vector2(-210, 120), Vector2(210, 120), Vector2(110, 45)]
	for i in range(count):
		var chest: Node2D = CONTAINER.instantiate()
		chest.position = positions[i]
		add_child(chest)
		chests.append(chest)
	# A single budget is divided across all chests; adding a chest adds no loot.
	var choices := ["madeira", "pedra", "fibra", "linha", "flecha", "vidro"]
	for i in range(budget):
		var chest := chests[i % count]
		var item: String = choices[random.randi_range(0, choices.size() - 1)]
		chest.contents[item] = int(chest.contents.get(item, 0)) + 1

func _draw() -> void:
	draw_rect(Rect2(-350, -240, 700, 480), Color("626069"))
	for x in range(-330, 331, 42):
		for y in range(-220, 221, 42):
			draw_rect(Rect2(x, y, 38, 38), Color("6b6972") if posmod(x + y, 3) == 0 else Color("56555e"), false, 2)
	for x in [-350, 350]:
		draw_rect(Rect2(x - 9, -240, 18, 480), Color("8c8190"))
		draw_rect(Rect2(x - 25, -260, 50, 42), Color("9b8a9c"))
	draw_rect(Rect2(-350, -240, 700, 18), Color("8c8190"))
	for side in [-1, 1]:
		draw_rect(Rect2(side * 205 - 145, 231, 290, 18), Color("8c8190"))
		draw_rect(Rect2(-7, side * 150 - 90, 14, 180), Color("827688"))
		draw_rect(Rect2(side * 205 - 145, -7, 290, 14), Color("827688"))
	draw_string(ThemeDB.fallback_font, Vector2(-345, -276), "Templo em ruínas", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("d6c4ba"))
