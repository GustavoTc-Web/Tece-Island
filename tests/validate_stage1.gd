extends SceneTree

var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
	else:
		print("PASS: ", label)

func run() -> void:
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await process_frame
	var spawner = world.get_node("EnemySpawner")
	spawner.set_physics_process(false)
	var cycle = world.get_node("DayNight")
	cycle.set_physics_process(false)
	var player = world.get_node("WorldObjects/Player")
	player.position = Vector2(500, 768)
	check(spawner.try_spawn() == null, "Nenhum monstro comum durante o dia")
	cycle.elapsed = cycle.day_duration + 1
	cycle.refresh()
	var common = spawner.try_spawn()
	check(common != null and common.origin == "noturno", "Surgimento noturno com origem explícita")
	var guard = load("res://scenes/forest_creature.tscn").instantiate()
	guard.origin = "guardiao"
	guard.player = player
	guard.position = Vector2(900, 768)
	world.get_node("WorldObjects").add_child(guard)
	check(spawner.alive_count() == 1, "Guardiões não ocupam limite noturno")
	cycle.elapsed = cycle.day_duration + cycle.night_duration - 1
	cycle.refresh()
	spawner._physics_process(0.01)
	check(common.fading and not guard.fading, "Amanhecer remove apenas comuns")
	check(not common.try_attack(), "Monstro em transição não ataca")
	guard.position += Vector2(40, 0)
	guard._physics_process(0.01)
	check(guard.destination == guard.home and not guard.chasing, "Guardião retorna à guarda fora do território")
	var interaction = player.get_node("Interaction")
	guard.position = player.position + Vector2(45, 0)
	guard.set_physics_process(false)
	await physics_frame
	await process_frame
	check(interaction.can_reach(guard) and not guard.try_attack(), "Jogador alcança 45 px, inimigo não")
	guard.position = player.position + Vector2(51, 0)
	await physics_frame
	await process_frame
	check(not interaction.can_reach(guard), "Combate bloqueado acima de 50 px")
	check(interaction.interaction_distance == 80 and guard.attack_range == 30, "Extração 80 preservada e inimigo 30")
	await create_timer(0.7).timeout
	check(not is_instance_valid(common), "Transição breve termina removendo o comum")
	print("ETAPA 1: %d verificações, %d falhas" % [checks, failures])
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
