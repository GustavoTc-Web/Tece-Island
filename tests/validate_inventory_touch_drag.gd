extends SceneTree
var checks := 0
var failures := 0
var hud: CanvasLayer
var inv: ResourceInventory
var drag: Node
var mobile: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS: " if ok else "FAIL: ",label)
func touch(index: int, point: Vector2, pressed: bool, cancelled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index=index
	event.position=point
	event.pressed=pressed
	event.canceled=cancelled
	Input.parse_input_event(event)
	await process_frame
func motion(index: int, point: Vector2, relative: Vector2 = Vector2.ZERO) -> void:
	var event := InputEventScreenDrag.new()
	event.index=index
	event.position=point
	event.relative=relative
	Input.parse_input_event(event)
	await process_frame
func center(index: int) -> Vector2: return hud.slot_buttons[index].get_global_rect().get_center()
func reset_items() -> void:
	inv.reset()
	for item in [{"item":"fibra","quantity":4},{"item":"madeira","quantity":9},{"item":"linha","quantity":2},{"item":"pedra","quantity":4},{"item":"cantil","quantity":1,"water":2},{"item":"pistola","quantity":1,"loaded":4},{"item":"espada_pedra","quantity":1}]: inv.add_item(item)
	inv.equip_slot(6)
func hold(index: int) -> void:
	await touch(0,center(index),true)
	await create_timer(0.40,true).timeout
func run() -> void:
	mobile=root.get_node("MobileInput")
	root.size=Vector2i(960,540)
	mobile.set_enabled(true)
	var world: Node2D=load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	hud=world.get_node("HUD")
	inv=world.get_node("Inventory")
	var controls: Control=load("res://scripts/mobile_controls.gd").new()
	controls.hud=hud
	controls.player=world.get_node("WorldObjects/Player")
	controls.structures=world.get_node("Structures")
	hud.add_child(controls)
	drag=mobile.inventory_touch_drag
	reset_items()
	hud.mobile_layout(true)
	hud.set_panel("inventory")
	await process_frame
	await process_frame
	var original: Dictionary=inv.network_state().duplicate(true)
	await hold(6)
	check(drag.phase=="dragging" and hud.inventory_drag_active and is_instance_valid(drag.preview),"Hold starts a visible drag while inventory is paused")
	await motion(0,center(0))
	check(drag.target==hud.slot_buttons[0],"Destination slot is recognized and highlighted")
	await touch(0,center(0),false)
	check(inv.slots[0].item=="espada_pedra" and inv.slots[6].item=="fibra" and inv.selected_index==0,"Touch sword 7 to occupied 1 swaps whole stacks and equipped reference")
	check(inv.slots[4].water==2 and inv.slots[5].loaded==4 and inv.slots[5].uid==original.slots[5].uid,"Touch swap preserves unrelated item attributes and weapon identities")
	var selected: Dictionary=inv.network_state().duplicate(true)
	await hold(0)
	await motion(0,Vector2(2,2))
	await touch(0,Vector2(2,2),false)
	check(inv.network_state()==selected and not hud.inventory_drag_active,"Release outside cancels without discarding")
	await hold(0)
	await motion(0,center(1))
	await touch(0,center(1),false,true)
	check(inv.network_state()==selected,"Cancelled OS touch does not move or discard")
	await hold(0)
	mobile.reset()
	await touch(0,center(1),false)
	check(inv.network_state()==selected and not is_instance_valid(drag.preview),"Focus/reset cancels preview and pending release")
	await hold(0)
	hud.set_panel("")
	await touch(0,center(1),false)
	check(inv.network_state()==selected and not hud.inventory_drag_active,"Closing inventory cancels the held drag")
	hud.set_panel("inventory")
	await process_frame
	await hold(0)
	await touch(1,center(1),true)
	await touch(1,center(1),false)
	await touch(0,center(1),false)
	check(inv.network_state()==selected,"Second finger cancels safely without activating another slot/action")
	await touch(0,center(0),true)
	await motion(0,center(0)+Vector2(0,-25),Vector2(0,-25))
	await create_timer(0.40,true).timeout
	check(drag.phase=="scrolling" and not hud.inventory_drag_active,"Motion before hold commits to scroll, never becoming a drag")
	await touch(0,center(0)+Vector2(0,-25),false)
	check(inv.network_state()==selected,"Scrolling cannot swap inventory items")
	hud.get_node("InventoryPanel/Panel/Scroll").scroll_vertical=0
	inv.take_slot(1,9)
	inv.equip_slot(0)
	await process_frame
	var sword: Dictionary=inv.slot_data(0)
	await hold(0)
	await motion(0,center(1))
	await touch(0,center(1),false)
	check(inv.slot_data(0).is_empty() and inv.slot_data(1)==sword and inv.selected_index==1,"Empty target receives the complete stack and equipped selection")
	check(not Input.is_action_pressed("hit") and not Input.is_action_pressed("use_tool") and mobile.overlay.fingers.values().all(func(v): return v == -1),"Touch inventory gestures never generate gameplay attack or joystick input")
	paused=false
	world.queue_free()
	await process_frame
	mobile.set_enabled(false)
	print("INVENTORY TOUCH: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
