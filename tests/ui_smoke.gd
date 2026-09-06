extends SceneTree

var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(2560, 1440)
	var scene: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var manager: GameManager = scene.get_node("GameManager")
	var ui: Control = scene.get_node("MainUI")
	manager.set_process(false)
	var bag: InventoryView = ui.inventory_view
	_check(manager.startup_error.is_empty(), "scene initializes")
	manager._process(10)
	_check(manager.simulation.state.time_usec == 0, "layout stage stays at time zero")
	_key(KEY_SPACE)
	_check(not manager.simulation.clock.paused, "Space in preparation cannot pre-pause battle")
	_check(ProjectSettings.get_setting("display/window/size/viewport_width") == 2560 and ProjectSettings.get_setting("display/window/size/viewport_height") == 1440, "2K design resolution")
	var drag := bag.drag_data_at(bag.cell_center(Vector2i(0, 1)))
	_check(drag["offset"] == Vector2i(0, 1), "drag keeps grab offset from sword lower cell")
	_check(bag._can_drop_data(bag.cell_center(Vector2i(3, 3)), drag), "legal bottom-right sword drop")
	bag._drop_data(bag.cell_center(Vector2i(3, 3)), drag)
	_check(manager.inventory.get_instance(GameManager.SWORD_INSTANCE)["cell"] == Vector2i(3, 2), "sword drop reaches authoritative state")
	var armor_drag := bag.drag_data_at(bag.cell_center(Vector2i(2, 2)))
	bag._drop_data(bag.cell_center(Vector2i(1, 3)), armor_drag)
	_check(manager.inventory.get_instance(GameManager.ARMOR_INSTANCE)["cell"] == Vector2i(0, 2), "armor moves using lower-right grab offset")
	armor_drag = bag.drag_data_at(bag.cell_center(Vector2i(0, 2)))
	_check(not bag._can_drop_data(bag.cell_center(Vector2i(3, 3)), armor_drag), "invalid drag rejected")
	bag._drop_data(bag.cell_center(Vector2i(3, 3)), armor_drag)
	_check(manager.inventory.get_instance(GameManager.ARMOR_INSTANCE)["cell"] == Vector2i(0, 2), "invalid drop returns to original location")
	manager.move_item(GameManager.SWORD_INSTANCE, Vector2i.ZERO)
	manager.move_item(GameManager.ARMOR_INSTANCE, Vector2i(1, 1))
	bag.reset_interaction()
	# Headless Input owns its virtual pointer, so native drag can be exercised without
	# moving the user's OS cursor. A hidden rendered Window reads the real OS pointer.
	if DisplayServer.get_name() == "headless":
		await _native_drag(bag, Vector2i(0, 1), Vector2i(3, 3))
		_check(manager.inventory.get_instance(GameManager.SWORD_INSTANCE)["cell"] == Vector2i(3, 2), "native Godot mouse drag moves sword")
		await _native_drag(bag, Vector2i(2, 2), Vector2i(1, 3))
		_check(manager.inventory.get_instance(GameManager.ARMOR_INSTANCE)["cell"] == Vector2i(0, 2), "native Godot mouse drag moves armor")
		await _native_drag(bag, Vector2i(3, 2), Vector2i(4, 4))
		_check(manager.inventory.get_instance(GameManager.SWORD_INSTANCE)["cell"] == Vector2i(3, 2), "native outside drop preserves sword")
	else:
		manager.move_item(GameManager.SWORD_INSTANCE, Vector2i(3, 2))
		manager.move_item(GameManager.ARMOR_INSTANCE, Vector2i(0, 2))
	_key(KEY_F1)
	_check(manager.simulation.clock.speed_multiplier == 0.5, "F1 maps to half speed")
	_key(KEY_F2)
	_check(manager.simulation.clock.speed_multiplier == 1.0, "F2 maps to normal speed")
	_check(_press(ui, "开始战斗"), "start button exists")
	_check(manager.inventory.locked and manager.simulation.state.phase == GameState.Phase.BATTLE, "start locks layout")
	_check(not manager.move_item(GameManager.SWORD_INSTANCE, Vector2i.ZERO), "cannot move during battle")
	_check(bag.drag_data_at(bag.cell_center(Vector2i(3, 2))).is_empty(), "battle disables drag")
	manager._process(1.0)
	_check(manager.simulation.state.time_usec == 1_000_000, "default 1x is one real second per game second")
	_key(KEY_F1)
	manager._process(2.0)
	_check(manager.simulation.state.time_usec == 2_000_000, "half speed advances one second in two seconds")
	_key(KEY_F3)
	manager._process(0.5)
	ui._refresh()
	_check(manager.simulation.state.enemy_hp == 90 and ui._hp.text == "气血  90 / 100", "F3 double speed attack updates HP")
	_check(ui._log_label.text.contains("造成 10 伤害"), "damage log delivered")
	_key(KEY_SPACE)
	manager._process(10)
	_check(manager.simulation.clock.paused and manager.simulation.state.time_usec == 3_000_000, "Space pauses battle")
	_key(KEY_SPACE, true)
	_check(manager.simulation.clock.paused, "key-repeat does not toggle pause")
	_check(not manager.move_item(GameManager.ARMOR_INSTANCE, Vector2i.ZERO), "pause does not unlock inventory")
	_key(KEY_F1)
	_check(manager.simulation.clock.paused and manager.simulation.clock.speed_multiplier == 0.5, "speed selection preserves pause")
	_key(KEY_SPACE)
	manager._process(2)
	_check(not manager.simulation.clock.paused and manager.simulation.state.time_usec == 4_000_000, "second Space resumes at selected speed")
	manager._process(52)
	ui._refresh()
	_check(manager.simulation.state.is_finished() and ui._status.text.contains("30.00"), "victory displayed at exact time")
	_check(ui._log_label.text.contains("试炼完成"), "defeat event displayed")
	_press(ui, "重新布阵")
	ui._refresh()
	_check(manager.simulation.state.enemy_hp == 100 and manager.simulation.clock.speed_multiplier == 1 and manager.simulation.state.time_usec == 0, "reprepare resets battle and speed")
	_check(not manager.inventory.locked and manager.inventory.get_instance(GameManager.SWORD_INSTANCE)["cell"] == Vector2i(3, 2), "reprepare preserves layout and unlocks")
	_check(not bag._can_drop_data(bag.cell_center(Vector2i.ZERO), armor_drag), "stale drag payload rejected after restart")
	_check(ui._log_label.text.contains("布阵中") and not ui._log_label.text.contains("造成"), "reprepare clears log")
	manager.move_item(GameManager.SWORD_INSTANCE, Vector2i.ZERO)
	manager.move_item(GameManager.ARMOR_INSTANCE, Vector2i(1, 1))
	bag.reset_interaction()
	if DisplayServer.get_name() != "headless":
		for dimensions in [Vector2i(2560, 1440), Vector2i(1280, 720), Vector2i(1280, 800), Vector2i(1720, 720)]:
			root.size = dimensions
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			var path := "res://artifacts/backpack_%dx%d.png" % [dimensions.x, dimensions.y]
			_check(root.get_texture().get_image().save_png(path) == OK, "rendered screenshot " + path)
			_check(ui.get_rect().size.x <= root.get_visible_rect().size.x + 1, "UI fits viewport width")
		root.size = Vector2i(2560, 1440)
		manager.start_battle()
		manager._process(12.5)
		_key(KEY_SPACE)
		ui._refresh()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/backpack_battle_paused.png")
	print("UI RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _key(code: Key, echo_event: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	event.echo = echo_event
	root.push_input(event, true)
	var release := InputEventKey.new()
	release.physical_keycode = code
	release.keycode = code
	root.push_input(release, true)

func _native_drag(bag: InventoryView, from: Vector2i, to: Vector2i) -> void:
	var start := bag.get_global_transform() * bag.cell_center(from)
	var finish := bag.get_global_transform() * bag.cell_center(to)
	_mouse_motion(start)
	_mouse_button(start, true)
	await process_frame
	_mouse_motion(start + Vector2(32, 0), true)
	await process_frame
	_mouse_motion(finish, true)
	await process_frame
	_mouse_button(finish, false)
	await process_frame

func _mouse_motion(point: Vector2, held: bool = false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = Vector2(32, 0)
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	Input.parse_input_event(event)

func _mouse_button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(event)

func _press(node: Node, label: String) -> bool:
	if node is Button and node.text == label and not node.disabled:
		node.pressed.emit()
		return true
	for child in node.get_children():
		if _press(child, label):
			return true
	return false

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + description)
