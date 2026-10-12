extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1
	print("PASS: " if value else "FAIL: ", label)
func run() -> void:
	var inv := ResourceInventory.new()
	root.add_child(inv)
	check(inv.capacity == 7, "Sete espaços básicos")
	inv.add_resource("madeira", 4)
	inv.add_resource("fibra", 12)
	check(inv.craft("mochila") and inv.capacity == 9, "Receita nível 1 preservada")
	inv.add_item({"item": "pistola", "quantity": 1, "loaded": 5})
	inv.add_item({"item": "cantil", "quantity": 1, "water": 2})
	var gun := inv.slot_data(0)
	check(inv.craft_error("mochila_3").contains("Equipe"), "Não pode pular nível")
	for upgrade in [["mochila_2", 12, 4, 11], ["mochila_3", 20, 8, 13], ["mochila_4", 30, 12, 15]]:
		inv.add_resource("madeira", upgrade[1])
		inv.add_resource("linha", upgrade[2])
		var before := inv.network_state()
		check(not inv.craft("mochila"), "Não acumula outra bolsa nível 1")
		check(before == inv.network_state(), "Receita rejeitada preserva tudo")
		check(inv.craft(upgrade[0]) and inv.capacity == upgrade[3], "Melhoria substitui bolsa: " + upgrade[0])
		check(inv.wood == 0 and inv.count_item("linha") == 0 and inv.count_item(upgrade[0]) == 0, "Custos exatos; bolsa equipada sem duplicação")
		check(inv.slot_data(0) == gun and inv.slot_data(1).water == 2, "Arma e cantil preservados")
	var saved := inv.network_state()
	var loaded := ResourceInventory.new()
	root.add_child(loaded)
	check(loaded.restore_state(saved) and loaded.capacity == 15 and loaded.slots == inv.slots and loaded.backpack == inv.backpack, "Carregar preserva bolsa, inventário e propriedades")
	inv.add_resource("pedra", 1)
	inv.swap_slots(2, 14)
	var full := inv.network_state()
	check(not inv.remove_backpack() and full == inv.network_state(), "Espaço extra ocupado bloqueia retirada sem perda")
	inv.swap_slots(14, 2)
	check(inv.remove_backpack() and inv.capacity == 7 and inv.count_item("mochila_4") == 1, "Retirada com espaços livres conserva bolsa")
	var index := -1
	for i in range(inv.capacity):
		if inv.slot_data(i).get("item", "") == "mochila_4": index = i
	check(inv.equip_backpack(index) and inv.capacity == 15, "Equipar nível 4 devolve oito espaços")
	inv.add_resource("mochila_2", 1)
	check(inv.capacity == 15, "Bolsa guardada não soma capacidade")
	var old := {"slots": [{"item": "cantil", "quantity": 1, "water": 3}], "backpack": {"item": "mochila", "quantity": 1}, "selected": 0}
	check(loaded.restore_state(old) and loaded.capacity == 9 and loaded.slot_data(0).water == 3, "Estado anterior de bolsa nível 1 continua válido")
	var bad := old.duplicate(true)
	bad.backpack.item = "desconhecida"
	var snapshot := loaded.network_state()
	check(not loaded.restore_state(bad) and loaded.network_state() == snapshot, "Estado inválido rejeitado sem substituir progresso")
	inv.queue_free()
	loaded.queue_free()
	await process_frame
	print("%d verificações, %d falhas" % [checks, failures])
	quit(1 if failures else 0)
