extends "res://tests/validate_integration.gd"

func run() -> void:
	root.size = Vector2i(960, 540)
	var world := make_world({"loot_chance": 0.0, "guardian_chance": 0.0, "external_weapon_chance": 0.0})
	var player: CharacterBody2D = world.get_node("WorldObjects/Player")
	var inv: ResourceInventory = world.get_node("Inventory")
	var interaction: Node = player.get_node("Interaction")
	var building := Node2D.new()
	world.get_node("WorldObjects").add_child(building)
	var chest: Node2D = load("res://scenes/loot_container.tscn").instantiate()
	chest.position = player.position + Vector2(0, 12)
	chest.contents = {"madeira": 5}
	building.add_child(chest)
	await step()
	interaction.collect_nearest()
	check(chest.released and inv.wood == 0, "Abrir baú gera loot no chão, sem coleta automática")
	interaction.collect_nearest()
	check(inv.wood == 5, "Segunda interação coleta loot, sem ser interceptada pelo baú vazio")
	inv.reset()
	inv.add_resource("madeira", 104)
	var drop := load("res://scenes/resource_drop.tscn").instantiate() as ResourceDrop
	drop.resource = "madeira"
	drop.quantity = 5
	drop.position = player.position + Vector2(20, 0)
	world.get_node("WorldObjects").add_child(drop)
	interaction.cursor_screen = Vector2(-9999, -9999)
	check(interaction.collect_nearest() == 1 and inv.wood == 105 and drop.quantity == 4, "Coleta parcial usa capacidade real sem depender do mouse")
	check(interaction.collect_nearest() == 0 and inv.wood == 105 and drop.quantity == 4, "Inventário cheio mantém drop e quantidade")
	inv.remove_item("madeira", 2)
	check(interaction.collect_nearest() == 2 and drop.quantity == 2, "Liberar espaço permite nova coleta parcial sem duplicar")
	drop.position = player.position + Vector2(interaction.pickup_distance + 1, 0)
	check(interaction.collect_nearest() == 0 and drop.quantity == 2, "Toque não amplia alcance de coleta")
	var ui := Control.new()
	root.add_child(ui)
	var behind := Button.new()
	behind.size = Vector2(100, 60)
	ui.add_child(behind)
	var notice := Button.new()
	notice.size = behind.size
	notice.disabled = true
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(notice)
	check(root.get_node("MobileInput").button_at(ui, Vector2(20, 20)) == behind, "Aviso desabilitado e mouse_filter Ignore não intercepta botão de toque")
	ui.queue_free()
	world.queue_free()
	await step()
	print("CONTROLS: ", checks, " verificações, ", failures, " falhas")
	quit(1 if failures else 0)
