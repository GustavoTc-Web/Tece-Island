class_name PlacedStructure
extends StaticBody2D

@export_enum("cama", "fogueira", "bau", "parede_madeira", "porta_madeira", "vidraca") var kind: String = "cama"
var system: Node2D
var highlighted := false
var animation_time := 0.0
var light: PointLight2D
var storage: ResourceInventory
var door_open := false
var structure_id := ""
var chest_name := "Baú"
const PIECES := ["parede_madeira", "porta_madeira", "vidraca"]

func _ready() -> void:
	if structure_id.is_empty(): structure_id = "%d-%d" % [Time.get_ticks_usec(), randi()]
	if kind in PIECES:
		var shape := RectangleShape2D.new()
		shape.size = Vector2(64, 16)
		$CollisionShape2D.shape = shape
		if kind != "porta_madeira": remove_from_group("interactables")
		if kind == "vidraca": collision_layer = 8 # Opaque to bodies/projectiles, transparent to vision.
	if kind == "bau":
		storage = ResourceInventory.new()
		storage.capacity = 12
		add_child(storage)
		storage.changed.connect(func(_a, _b): progress_changed())
	if kind == "fogueira":
		add_to_group("campfires")
		var gradient := Gradient.new()
		gradient.set_color(0, Color.WHITE)
		gradient.set_color(1, Color(1, 1, 1, 0))
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.width = 256
		texture.height = 256
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(0.5, 1)
		light = PointLight2D.new()
		light.texture = texture
		light.texture_scale = 2.0
		light.color = Color(1, 0.78, 0.42)
		light.energy = 0.9
		add_child(light)

func prompt() -> String:
	if kind == "porta_madeira": return "E — Fechar porta" if door_open else "E — Abrir porta"
	if kind == "bau": return "E — Abrir " + chest_name
	if kind == "cama": return "E — Cama · " + (system.bed_status(self) if system != null else "Definir reaparecimento")
	return "E — Preparar carne na fogueira"

func set_highlighted(value: bool) -> void:
	highlighted = value
	queue_redraw()

func interact(_inventory: ResourceInventory) -> String:
	if kind == "porta_madeira":
		if door_open and not can_close(): return "Porta ocupada: saia da passagem antes de fechar"
		set_open(not door_open)
		return "Porta aberta" if door_open else "Porta fechada"
	if kind == "bau":
		system.hud.open_chest(self)
		return "Baú — selecione um item e use Guardar / Retirar"
	if kind == "cama": return system.use_bed(self)
	_inventory.cooking_available = system.near_fire(system.player.global_position)
	system.hud.open_cooking()
	return "Receita: 1 carne crua + 1 madeira → 1 carne cozida"

func set_open(value: bool) -> void:
	door_open = value
	collision_layer = 0 if value else 1
	$CollisionShape2D.set_deferred("disabled", value)
	queue_redraw()
	progress_changed()

func can_close() -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(63.5, 15.5)
	query.shape = shape
	query.transform = global_transform
	query.collision_mask = 6
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query).is_empty()

func rename_chest(value: String) -> bool:
	value = value.strip_edges()
	if kind != "bau" or value.is_empty() or value.length() > 24: return false
	chest_name = value
	progress_changed()
	return true

func dismantle_error() -> String:
	if is_queued_for_deletion() or not is_instance_valid(system): return "Estrutura indisponível"
	if kind == "bau":
		for slot in storage.slots:
			if not slot.is_empty(): return "Baú cheio: retire todos os itens antes de desmontar"
	if not ResourceRules.RECIPES.has(kind): return "Estrutura não desmontável"
	return ""

func dismantle(inventory: ResourceInventory) -> String:
	var error := dismantle_error()
	if error != "": return error
	if system.player.global_position.distance_to(global_position) > 90: return "Aproxime-se da estrutura para desmontar."
	if system.respawn_bed == self: system.respawn_bed = null
	for material in ResourceRules.ingredients(kind):
		var refund := floori(float(ResourceRules.ingredients(kind)[material]) * 0.5)
		var remaining := refund - inventory.add_resource(material, refund)
		if remaining > 0:
			var drop: ResourceDrop = preload("res://scenes/resource_drop.tscn").instantiate()
			drop.resource = material
			drop.quantity = remaining
			drop.position = system.player.global_position
			system.container.add_child(drop)
	remove_from_group("structures")
	remove_from_group("interactables")
	collision_layer = 0
	queue_free()
	progress_changed()
	return "Estrutura desmontada: metade dos materiais devolvida; excedentes no chão."

func progress_changed() -> void:
	if is_instance_valid(system) and system.get_parent().has_method("queue_save"): system.get_parent().queue_save()

func _process(delta: float) -> void:
	if kind == "fogueira":
		animation_time += delta
		light.energy = 0.9 + sin(animation_time * 8) * 0.07
		queue_redraw()

func _draw() -> void:
	if kind in PIECES:
		if kind == "vidraca":
			draw_rect(Rect2(-32, -8, 64, 16), Color(0.5, 0.8, 0.88, 0.4))
			draw_rect(Rect2(-32, -8, 64, 16), Color("a78351"), false, 3)
			draw_line(Vector2(0, -8), Vector2(0, 8), Color("a78351"), 3)
		elif kind == "porta_madeira" and door_open:
			draw_line(Vector2(-32, 0), Vector2(-32, -62), Color("a57c4d"), 12)
			draw_circle(Vector2(-32, -52), 3, Color("ddcb83"))
		else:
			draw_rect(Rect2(-32, -8, 64, 16), Color("967047"))
			for x in range(-30, 31, 8): draw_line(Vector2(x, -7), Vector2(x, 7), Color("654c32"), 1)
			if kind == "porta_madeira": draw_circle(Vector2(22, 0), 3, Color("ddcb83"))
	elif kind == "bau":
		draw_rect(Rect2(-26, -18, 52, 36), Color("a08048"))
		draw_rect(Rect2(-26, -18, 52, 12), Color("c2a35c"))
		draw_rect(Rect2(-4, -6, 8, 12), Color("e1d180"))
	elif kind == "cama":
		draw_rect(Rect2(-26, -18, 52, 36), Color("6b4931"))
		draw_rect(Rect2(-22, -14, 44, 28), Color("c7b580"))
		draw_rect(Rect2(-20, -12, 12, 24), Color("eee2bd"))
	else:
		IslandArt.fire(self, animation_time)
	if highlighted:
		draw_arc(Vector2.ZERO, 34, 0, TAU, 32, Color("f2d786"), 2)
