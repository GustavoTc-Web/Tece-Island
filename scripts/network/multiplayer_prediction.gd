extends RefCounted
# Visual movement only. Rewards, inventory, tools and actions remain server-only.
# Geometry and speed are the exact manifest used by the authoritative Room.
var data: Dictionary
var cells := {}
var depleted := {}
var position := Vector2.ZERO
var correction := Vector2.ZERO
var pending := []
var enabled := true
var corrections := 0
var correction_size := 0.0
var limited := false

func configure(world: Dictionary) -> void:
	data = world
	cells.clear()
	var radius: float = data.player_radius
	for collider in data.colliders:
		var half := Vector2.ONE * float(collider.radius) if collider.type == "circle" else Vector2(collider.size[0], collider.size[1]) / 2
		half += Vector2.ONE * radius
		var center := Vector2(collider.x, collider.y)
		for x in range(floori((center.x - half.x) / 128), floori((center.x + half.x) / 128) + 1):
			for y in range(floori((center.y - half.y) / 128), floori((center.y + half.y) / 128) + 1):
				var key := Vector2i(x, y)
				if not cells.has(key): cells[key] = []
				cells[key].append(collider)

func contains(point: Vector2) -> bool:
	for region in data.regions:
		var rect := Rect2(region.rect[0], region.rect[1], region.rect[2], region.rect[3])
		if rect.has_point(point): return true
	return false

func is_free(point: Vector2) -> bool:
	var radius: float = data.player_radius
	var interior := false
	for region in data.regions:
		if Rect2(region.rect[0], region.rect[1], region.rect[2], region.rect[3]).grow(-radius - 0.001).has_point(point):
			interior = true
			break
	if not interior:
		for offset in [Vector2.ZERO, Vector2(radius, 0), Vector2(-radius, 0), Vector2(0, radius), Vector2(0, -radius)]:
			if not contains(point + offset): return false
	for c in cells.get(Vector2i(floori(point.x / 128), floori(point.y / 128)), []):
		if depleted.has(c.owner): continue
		if c.type == "circle":
			if point.distance_to(Vector2(c.x, c.y)) < float(c.radius) + radius: return false
		else:
			var dx: float = maxf(0, absf(point.x - float(c.x)) - float(c.size[0]) / 2)
			var dy: float = maxf(0, absf(point.y - float(c.y)) - float(c.size[1]) / 2)
			if dx * dx + dy * dy < radius * radius: return false
	return true

func water(point: Vector2) -> bool:
	for pond in data.ponds:
		if Rect2(pond[0], pond[1], pond[2], pond[3]).has_point(point): return true
	for region in data.regions:
		var rect := Rect2(region.rect[0], region.rect[1], region.rect[2], region.rect[3])
		if not rect.has_point(point): continue
		if region.kind != "Aquático": return false
		var local := point - rect.position
		if local.x < 14 or local.y < 14 or local.x > rect.size.x - 14 or local.y > rect.size.y - 14 or absf(local.x - rect.size.x / 2) < 46 or absf(local.y - rect.size.y / 2) < 46: return false
		for fraction in [Vector2(0.25, 0.25), Vector2(0.75, 0.75), Vector2(0.25, 0.75)]:
			if local.distance_to(rect.size * fraction) <= 112: return false
		return true
	return false

func move_at(point: Vector2, direction: Vector2, delta: float) -> Vector2:
	var dt := clampf(delta, 0, 0.1)
	var speed: float = float(data.speed) * (float(data.swim_speed) if water(point) else 1.0)
	var steps := maxi(1, ceili(speed * dt / 3))
	var change := direction.limit_length(1) * speed * dt / steps
	for i in steps:
		var next := point + Vector2(change.x, 0)
		if is_free(next): point.x = next.x
		next = point + Vector2(0, change.y)
		if is_free(next): point.y = next.y
	return point

func reset(point: Vector2) -> void:
	position = point
	correction = Vector2.ZERO
	pending.clear()
	limited = false

func advance(direction: Vector2, delta: float, sequence: int) -> Vector2:
	var dt := minf(delta, 0.05)
	var age := 0.0
	for input in pending: age += float(input.dt)
	limited = age > 1.0
	if not limited:
		position = move_at(position, direction, dt)
		if not pending.is_empty() and pending[-1].seq == sequence and pending[-1].direction == direction:
			pending[-1].dt += dt
		else: pending.append({"seq":sequence,"direction":direction,"dt":dt})
	correction *= exp(-18 * delta)
	var visual := position + correction
	return visual if is_free(visual) else position

func reconcile(point: Vector2, acknowledged: int) -> void:
	var old_visual := position + correction
	var remaining := []
	for input in pending:
		if int(input.seq) > acknowledged: remaining.append(input)
	pending = remaining
	var replayed := point
	for input in pending: replayed = move_at(replayed, input.direction, input.dt)
	correction_size = position.distance_to(replayed)
	if correction_size > 0.5: corrections += 1
	position = replayed
	correction = old_visual - position if correction_size < 64 else Vector2.ZERO
