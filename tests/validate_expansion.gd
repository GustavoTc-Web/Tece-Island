extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1
	print("PASS: " if value else "FAIL: ", label)
func step(frames: int = 3) -> void:
	for i in range(frames): await physics_frame
func run() -> void:
	root.size = Vector2i(960, 540)
	var regions := WorldTerrain.regions()
	check(regions.size() == 16, "Quatro regiões preservadas mais doze novas")
	var kinds := {}
	var ids := {}
	for region in regions:
		kinds[region.kind] = int(kinds.get(region.kind, 0)) + 1
		ids[region.id] = true
	check(kinds.Floresta == 3 and kinds["Pântano"] == 3 and kinds.Campos == 3 and kinds.Deserto == 3 and kinds["Aquático"] == 2 and kinds["Ruínas Escuras"] == 2, "Duas novas regiões de cada tipo existente e duas de cada tipo novo")
	check(ids.size() == 16, "IDs de regiões únicos para persistência")
	var overlap := false
	for a in regions:
		for b in regions:
			if a.id != b.id and a.rect.intersects(b.rect): overlap = true
	check(not overlap, "Regiões não se sobrepõem")
	var reachable := {"forest": true}
	for pass_index in range(16):
		for a in regions:
			if not reachable.has(a.id): continue
			for b in regions:
				if a.id == b.id: continue
				if a.rect.grow(1).intersects(b.rect) and (a.rect.position.x == b.rect.end.x or a.rect.end.x == b.rect.position.x or a.rect.position.y == b.rect.end.y or a.rect.end.y == b.rect.position.y): reachable[b.id] = true
	check(reachable.size() == 16, "Todas as regiões conectadas à floresta original")
	var world: Node2D = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await step()
	var player: CharacterBody2D = world.get_node("WorldObjects/Player")
	player.set_physics_process(false)
	var camera: Camera2D = player.get_node("Camera2D")
	check(camera.limit_left == -3072 and camera.limit_top == -1536 and camera.limit_right == 6912 and camera.limit_bottom == 3072, "Câmera cobre norte, sul e oeste sem deslocar leste")
	check(world.terrain.get_child_count() < 40, "Bordas físicas agrupadas após expansão")
	var invalid_resources := 0
	var new_resources := 0
	for resource in get_nodes_in_group("harvest_resources"):
		if not WorldTerrain.solid_ground(resource.position): invalid_resources += 1
		if WorldTerrain.region_at(resource.position).get("id", "") not in ["forest", "swamp", "fields", "desert"]: new_resources += 1
	check(invalid_resources == 0 and new_resources >= 64, "Recursos novos em solo válido")
	var minimap: IslandMinimap = world.minimap
	minimap.reveal()
	check(minimap.explored.size() > 0 and minimap.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Minimapa revela entorno sem interceptar comandos")
	var rect := minimap.get_global_rect()
	check(rect.position.x >= 700 and rect.position.y > 68 and rect.end.y < 396, "Minimapa evita saída e controles de toque")
	var explored := minimap.explored.size()
	player.position = Vector2(1152, 2304)
	await step()
	minimap.reveal()
	check(minimap.explored.size() > explored, "Exploração cresce ao visitar região nova")
	var sleeping := 0
	var dormant_animals := 0
	for node in world.get_node("WorldObjects").get_children():
		if node is ForestCreature and not node.is_physics_processing(): sleeping += 1
		if node is NeutralAnimal and node.kind in ["coelho", "vaca"] and node.global_position.distance_to(player.global_position) > 2200:
			if not node.is_physics_processing() and not node.is_queued_for_deletion(): dormant_animals += 1
	check(sleeping >= 4, "Guardiões distantes têm IA desativada")
	check(dormant_animals > 0, "Animais terrestres antigos permanecem no mundo, inativos quando distantes")
	player.position = Vector2(-2304, 768)
	await step()
	var awake := 0
	for guard in world.ruins.guardians:
		if guard.is_physics_processing(): awake += 1
	check(awake > 0, "Guardiões reativam perto do jogador")
	var progress := WorldProgress.new()
	progress.world = world
	var state := progress.capture()
	check(state.generated_regions.size() == 16 and state.explored == minimap.explored, "Save conserva regiões e exploração do minimapa")
	world.queue_free()
	await process_frame
	print("%d verificações, %d falhas" % [checks, failures])
	quit(1 if failures else 0)
