extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS: " if ok else "FAIL: ", label)
func run() -> void:
	for id in ItemCatalog.NAMES: check(ItemIcon.supports(id), "Ícone reconhecível para " + id)
	for id in ResourceRules.RECIPES: check(ItemIcon.supports(id), "Ícone compartilhado para receita " + id)
	for text in ["Água", "Proteção", "Fogueira", "São João", "Amanhece", "Configurações"]:
		var supported := true
		for i in range(text.length()): supported = supported and IslandTheme.BODY.has_char(text.unicode_at(i)) and IslandTheme.TITLE.has_char(text.unicode_at(i))
		check(supported, "Fontes locais têm os caracteres de " + text)
	var menu: Control = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	check(menu.find_children("*", "Camera2D", true, false).is_empty() and menu.find_children("Needs", "Node", true, false).is_empty(), "Cenário do lobby não carrega câmera ou sobrevivência")
	var library := WorldLibrary.new()
	library.configure("fixture-presentation", "res://.tools/presentation-%d" % Time.get_ticks_usec())
	await library.load_index(self)
	menu.set_library(library)
	check(menu.primary.text == "Criar mundo", "Sem mundo jogado, criação fica em destaque")
	var first := await library.create_world("Floresta", self)
	var second := await library.create_world("Refúgio", self)
	await library.touch_world(first, self)
	menu.set_library(library, second)
	check(menu.last_world_id() == first and menu.continue_caption.text == "Floresta", "Continuar usa última partida, não apenas seleção")
	menu.open_page("worlds")
	menu.open_name("rename")
	check(menu.dialog.visible and menu.world_name.text == "Refúgio", "Nome aparece somente em diálogo de renomear")
	menu.world_name.text = "Refúgio da névoa"
	await menu.rename_world()
	check(menu.selected_world == second and library.data.worlds[1].name == "Refúgio da névoa" and not menu.dialog.visible, "Renomear preserva ID e fecha diálogo")
	menu.open_name("create")
	menu.close_name()
	check(library.data.worlds.size() == 2 and menu.dialog_mode == "", "Cancelar não cria mundo")
	check(menu.last_access(Time.get_unix_time_from_system()).contains("hoje") and not menu.last_access(1).contains("UTC"), "Datas usam indicação local")
	menu.queue_free()
	await process_frame
	print("PRESENTATION: %d verificações, %d falhas" % [checks, failures])
	quit(1 if failures else 0)
