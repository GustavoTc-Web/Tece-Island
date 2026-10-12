extends Node2D

const MAP_SIZE := Vector2(6912, 1536)
const TREE := preload("res://scenes/obstacles/tree.tscn")
const ROCK := preload("res://scenes/obstacles/rock.tscn")
const DROP := preload("res://scenes/resource_drop.tscn")
const BUSH := preload("res://scenes/obstacles/bush.tscn")
var persistence_enabled := false
var progress_path := "user://solo-progress.json"
var progress_store: WorldProgress
var save_clock := 0.0
var terrain: WorldTerrain
var world_seed := 0
var ruins: Node
var current_biome := ""
var minimap: IslandMinimap
var activity_clock := 0.0
var last_region := ""
var initial_progress := {}
var region_wells := {}
var journal: IslandJournal


func _ready() -> void:
	if world_seed == 0: world_seed = int($Exploration.random_seed) if $Exploration.random_seed > 0 else randi_range(1, 2147480000)
	if persistence_enabled:
		var store := SaveStore.new()
		store.path = progress_path
		var preview := store.read()
		initial_progress = preview
		world_seed = int(preview.get("world_seed", world_seed))
	terrain = WorldTerrain.new()
	terrain.name = "Terrain"
	add_child(terrain)
	move_child(terrain, 0)
	$Borders.collision_layer = 0
	$Borders.queue_free()
	terrain.build_boundaries()
	$WorldObjects/Player.terrain_enabled = true
	$WorldObjects/Player.collision_mask |= 8
	var camera: Camera2D = $WorldObjects/Player/Camera2D
	camera.limit_left = int(WorldTerrain.BOUNDS.position.x)
	camera.limit_top = int(WorldTerrain.BOUNDS.position.y)
	camera.limit_right = int(WorldTerrain.BOUNDS.end.x)
	camera.limit_bottom = int(WorldTerrain.BOUNDS.end.y)
	# O mundo conecta os componentes; o inventário não depende da interface.
	$Inventory.changed.connect($HUD.update_counts)
	$WorldObjects/Player/Interaction.target_changed.connect($HUD.show_target)
	$WorldObjects/Player/Interaction.message_requested.connect($HUD.show_message)
	$WorldObjects/Player/Interaction.pickup_changed.connect($HUD.show_pickup)
	$WorldObjects/Player/Interaction.inventory = $Inventory
	$Inventory.equipment_changed.connect($WorldObjects/Player.show_equipment)
	$WorldObjects/Player.show_equipment($Inventory.equipped_tool())
	$HUD.panel_toggled.connect(_on_panel_toggled)
	$HUD.initialize($Inventory)
	minimap = IslandMinimap.new()
	minimap.player = $WorldObjects/Player
	$HUD.add_child(minimap)
	$HUD.update_counts($Inventory.wood, $Inventory.stone)
	$WorldObjects/Player.health_changed.connect($HUD.update_health)
	$WorldObjects/Player.died.connect(_on_player_died)
	$HUD.respawn_requested.connect(respawn_player)
	$HUD.update_health($WorldObjects/Player.health, $WorldObjects/Player.max_health)
	$DayNight.clock_changed.connect($HUD.update_clock)
	$HUD.update_time($DayNight.day_number, $DayNight.phase)
	$HUD.update_clock($DayNight.day_number, $DayNight.phase, $DayNight.remaining_seconds)
	$EnemySpawner.player = $WorldObjects/Player
	$EnemySpawner.cycle = $DayNight
	$EnemySpawner.container = $WorldObjects
	$Structures.player = $WorldObjects/Player
	$Structures.inventory = $Inventory
	$Structures.hud = $HUD
	$Structures.cycle = $DayNight
	$Structures.container = $WorldObjects
	$HUD.placement_requested.connect($Structures.start_placement)
	$HUD.discard_requested.connect(_discard)
	$HUD.use_requested.connect(_use_item)
	$WorldObjects/Player/Interaction.use_requested.connect(_use_item)
	$WorldObjects/Player/Needs.changed.connect($HUD.update_needs)
	$WorldObjects/Player/Needs.alert.connect($HUD.show_message)
	$HUD.update_needs($WorldObjects/Player/Needs.hunger, $WorldObjects/Player/Needs.thirst)
	$WorldObjects/Player/Interaction.discard_requested.connect(_discard)
	$Structures.map_size = MAP_SIZE
	$Weapons.player = $WorldObjects/Player
	$Weapons.inventory = $Inventory
	$Weapons.container = $WorldObjects
	$Weapons.message_requested.connect($HUD.show_message)
	$WorldObjects/Player/Interaction.weapons = $Weapons
	# Coordenadas fixas: o mapa é sempre igual e os caminhos ficam desimpedidos.
	var trees := [
		Vector2(180, 210), Vector2(320, 290), Vector2(490, 180),
		Vector2(670, 330), Vector2(850, 220), Vector2(1000, 390),
		Vector2(1320, 250), Vector2(1490, 370), Vector2(1650, 200),
		Vector2(1850, 310), Vector2(2040, 210), Vector2(2180, 420),
		Vector2(210, 520), Vector2(400, 610), Vector2(570, 480),
		Vector2(760, 600), Vector2(910, 530), Vector2(1400, 530),
		Vector2(1590, 590), Vector2(1790, 490), Vector2(2010, 610),
		Vector2(200, 1000), Vector2(390, 920), Vector2(590, 1100),
		Vector2(760, 970), Vector2(920, 1090), Vector2(1390, 1050),
		Vector2(1580, 940), Vector2(1790, 1120), Vector2(2000, 980),
		Vector2(2180, 1110), Vector2(180, 1330), Vector2(370, 1220),
		Vector2(570, 1390), Vector2(740, 1290), Vector2(990, 1380),
		Vector2(1320, 1350), Vector2(1520, 1230), Vector2(1700, 1390),
		Vector2(1900, 1300), Vector2(2110, 1390)
	]
	for point in trees:
		add_obstacle(TREE, point)
	# Uma linha de árvores perto do perímetro ajuda a mostrar o limite da floresta.
	for x in range(80, 2304, 150):
		if absf(x - 1152) < 100: continue
		add_obstacle(TREE, Vector2(x, 105))
		add_obstacle(TREE, Vector2(x, 1490))
	for y in range(260, 1400, 160):
		if absf(y - 768) < 100: continue
		add_obstacle(TREE, Vector2(65, y))
		add_obstacle(TREE, Vector2(2240, y))
	for point in [
		Vector2(460, 390), Vector2(840, 420), Vector2(1460, 180),
		Vector2(1930, 450), Vector2(350, 1100), Vector2(810, 1200),
		Vector2(1450, 1190), Vector2(1920, 1190), Vector2(2090, 890)
	]:
		add_obstacle(ROCK, point)
	for point in [Vector2(1050, 640), Vector2(1250, 640), Vector2(1050, 890), Vector2(1250, 890), Vector2(650, 700), Vector2(1660, 850), Vector2(1100, 450), Vector2(1200, 1120)]:
		add_obstacle(BUSH, point)
	$Biomes.initialize(self)
	terrain.initialize_resources(self)
	$Exploration.player = $WorldObjects/Player
	$Exploration.random_seed = world_seed
	$Exploration.container = $WorldObjects
	$Exploration.initialize()
	$Animals.initialize($WorldObjects/Player, $WorldObjects)
	ruins = preload("res://scripts/ruins_system.gd").new()
	ruins.name = "Ruins"
	add_child(ruins)
	ruins.initialize(self, world_seed)
	journal = IslandJournal.new()
	add_child(journal)
	journal.initialize(self)
	$HUD.initialize_journal(journal)
	var previous_wells: Dictionary = initial_progress.get("region_wells", {}) if initial_progress.get("region_wells", {}) is Dictionary else {}
	if NaturalWells.valid_metadata(previous_wells):
		region_wells = NaturalWells.generate(world_seed, previous_wells, initial_progress.get("structures", []) if initial_progress.get("structures", []) is Array else [])
		NaturalWells.spawn(self, region_wells)
	if persistence_enabled:
		progress_store = WorldProgress.new()
		progress_store.world = self
		progress_store.store.path = progress_path
		progress_store.load_progress()
		# Persist the fixed layout after loading; any older/draft format has a backup.
		if initial_progress.get("wells_policy", "") != "fixed": save_progress()

func save_progress() -> bool:
	return progress_store.save() if progress_store != null else true

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST] and is_node_ready():
		save_progress()

func _discard(index: int, whole: bool) -> void:
	if not DropRules.discard($Inventory, index, whole, $WorldObjects/Player, $WorldObjects, MAP_SIZE):
		$HUD.show_message("Descarte bloqueado: libere espaço ao retirar a bolsa ou procure terreno livre.")

func _use_item(index: int) -> void:
	$HUD.show_message($WorldObjects/Player/Needs.use_slot($Inventory, index))

func _physics_process(_delta: float) -> void:
	var dark: bool = WorldTerrain.is_dark($WorldObjects/Player.global_position)
	if $DayNight.local_darkness != dark:
		$DayNight.local_darkness = dark
		$DayNight.refresh()
	var biome: String = WorldTerrain.region_at($WorldObjects/Player.global_position).get("kind", "")
	var region_id: String = WorldTerrain.region_at($WorldObjects/Player.global_position).get("id", "")
	activity_clock += _delta
	if activity_clock >= 0.5 or last_region != region_id:
		activity_clock = 0
		update_activity()
		if last_region != region_id:
			$Animals.ensure_local_animals()
		last_region = region_id
	if biome != current_biome:
		current_biome = biome
		$HUD.show_message(biome + (" · escuridão permanente; dormir bloqueado" if dark else ""))
	if persistence_enabled:
		save_clock += _delta
		if save_clock >= 30:
			save_clock = 0
			save_progress()
	var available: bool = $Structures.near_fire($WorldObjects/Player.global_position)
	if $Inventory.cooking_available != available:
		$Inventory.cooking_available = available
		$Inventory.changed.emit($Inventory.wood, $Inventory.stone)

func update_activity() -> void:
	for node in $WorldObjects.get_children():
		if node.is_queued_for_deletion() or not (node is ForestCreature or node is NeutralAnimal or node is HarvestResource or node is PlacedStructure): continue
		var distance: float = node.global_position.distance_to($WorldObjects/Player.global_position)
		if node is ForestCreature and node.fading:
			node.set_process(true)
			continue
		if node is ForestCreature and node.origin == "noturno" and distance > 1800:
			node.remove_from_group("enemies")
			node.queue_free()
			continue
		if node is NeutralAnimal and node.kind == "garca_azul" and distance > 2200:
			node.remove_from_group("animals")
			node.queue_free()
			continue
		var active := distance <= 1600
		if bool(node.get_meta("activity_active", true)) == active: continue
		node.set_meta("activity_active", active)
		node.visible = active
		node.set_process(active)
		if node is ForestCreature or node is NeutralAnimal:
			node.set_physics_process(active)
			if not node.has_meta("activity_layer"): node.set_meta("activity_layer", node.collision_layer)
			node.collision_layer = int(node.get_meta("activity_layer")) if active else 0


func _on_panel_toggled(open: bool) -> void:
	if open and $Structures.active:
		$Structures.cancel()
	var stopped: bool = open or $WorldObjects/Player.dead
	$WorldObjects/Player.controls_blocked = stopped
	$WorldObjects/Player/Interaction.set_blocked(stopped)
	# HUD usa Always; o restante herda a pausa e congela relógios e física.
	get_tree().paused = stopped


func _on_player_died() -> void:
	$Structures.cancel()
	$HUD.set_panel("")
	$HUD.show_death(true)
	_on_panel_toggled(false)


func respawn_player() -> void:
	$WorldObjects/Player.respawn($Structures.respawn_point($EnemySpawner.safe_center))
	$WorldObjects/Player/Interaction.cooldown = 0.0
	$HUD.show_death(false)
	_on_panel_toggled(false)


func add_obstacle(scene: PackedScene, point: Vector2) -> void:
	var obstacle := scene.instantiate() as HarvestResource
	obstacle.position = point
	obstacle.depleted.connect(_spawn_drop)
	$WorldObjects.add_child(obstacle)


func _spawn_drop(resource: String, amount: int) -> void:
	var drop := DROP.instantiate() as ResourceDrop
	drop.resource = resource
	drop.quantity = amount
	# O ponto do jogador já é transitável, tem alcance e linha de visão validados.
	# Evita largar a recompensa dentro de um tronco vizinho ou além das bordas.
	drop.position = $WorldObjects/Player.position
	$WorldObjects.add_child(drop)
	$HUD.show_message("%d %s no chão — E para recolher" % [amount, resource])


func _draw() -> void:
	draw_rect(WorldTerrain.BOUNDS.grow(1000), Color("182b29"))
	draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), Color("567c46"))
	# Semente local fixa: detalhes visuais não mudam entre execuções.
	var random := RandomNumberGenerator.new()
	random.seed = 71
	for i in range(1800):
		var point := Vector2(random.randf_range(32, 2272), random.randf_range(32, 1504))
		var shade := Color("628750") if i % 2 == 0 else Color("4b713f")
		draw_line(point, point + Vector2(-2, -5), shade, 1.0)
		draw_line(point + Vector2(2, 0), point + Vector2(4, -4), shade, 1.0)
	# Caminhos largos em cruz conectam os quatro setores e a clareira inicial.
	var trail := Color("7e8b55")
	draw_line(Vector2(32, 768), Vector2(2272, 768), trail, 104.0)
	draw_line(Vector2(1152, 32), Vector2(1152, 1504), trail, 104.0)
	draw_circle(Vector2(1152, 768), 155.0, trail)
	draw_arc(Vector2(1152, 768), 140.0, 0.0, TAU, 64, Color("89955d"), 2.0)
