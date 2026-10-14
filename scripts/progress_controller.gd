class_name ProgressController
extends Node
var world: Node2D
var dirty := true
var saving := false
var revision := 0
var debounce := 1.5
var periodic := 0.0
var last_write := -10000
var last_ok := true

func _ready() -> void: process_mode = Node.PROCESS_MODE_ALWAYS
func changed(_a: Variant = null, _b: Variant = null) -> void:
	if world.loading_progress: return
	dirty = true
	revision += 1
	debounce = 1.5
func _process(delta: float) -> void:
	periodic += delta
	debounce = maxf(0, debounce - delta)
	if periodic >= 30:
		periodic = 0
		changed()
	if dirty and debounce == 0 and not saving and Time.get_ticks_msec() - last_write >= 3000:
		flush()
func flush(force: bool = false) -> bool:
	while saving: await get_tree().process_frame
	if not dirty and not force: return last_ok
	saving = true
	var captured_revision := revision
	world.get_node("HUD").show_save_state("Salvando…", false)
	await get_tree().process_frame
	last_ok = await world.progress_store.save()
	last_write = Time.get_ticks_msec()
	if last_ok:
		dirty = revision != captured_revision
		world.get_node("HUD").show_save_state("Salvo neste aparelho", false)
	else:
		# Keep the snapshot dirty, but retry only on user request or a later change.
		dirty = true
		debounce = 30
		world.get_node("HUD").show_save_state("Falha ao salvar · Tentar novamente", true)
	saving = false
	if last_ok and world.account_store != null and world.world_library != null:
		get_tree().root.get_node("WorldSync").local_saved(world.account_store, world.world_library, world.last_local_snapshot, force)
	return last_ok
