extends SceneTree

var failures: int = 0
var checks: int = 0
var ui: Control
var manager: GameManager

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var scene: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(scene)
	manager = scene.get_node("GameManager")
	manager.set_process(false)
	ui = scene.get_node("MainUI")
	await _layout()
	_check(manager.startup_error.is_empty(), "startup succeeds")
	_check(manager.party.size() == 3 and manager.enemies.size() == 1, "three allies and single dog")
	_check(not ui.storage_panel.visible and not ui._log_panel.visible, "drawers initially hidden")
	_check(not ui._bag_button.disabled and not manager.can_edit_inventory(), "prebattle adjustment available but bags locked until opened")
	_check_layout()
	_check(absf(ui._status.get_global_rect().get_center().x - ui.size.x / 2) < 1 and ui._status.global_position.y >= ui._time.get_global_rect().end.y, "status below centered timer")
	_check(ui._log_button.get_global_rect().end.y > ui.size.y - 35, "log button at middle bottom")
	await _capture("storage_default")
	ui._bag_button.pressed.emit()
	await _layout()
	_check(ui.storage_panel.visible and manager.can_edit_inventory(), "button opens shared storage")
	_check(ui.storage_panel.cards.size() == 7, "seven content cards visible")
	await _move_all_bags()
	for index in 3:
		var card: PartyMemberCard = ui.ally_panel.cards[index]
		var before := card.custom_minimum_size
		card.clicked.emit(index)
		_check(manager.selected_member_index == index and card.custom_minimum_size == before, "select character changes target without resizing")
	manager.select_member(1)
	var pill_key := "run.storage.base.pill.huichun.0"
	for index in 3:
		var card: StorageItemCard = ui.storage_panel.cards[pill_key]
		if DisplayServer.get_name() == "headless":
			var point := card.get_global_rect().get_center()
			_mouse_motion(point)
			_right_click(point)
		else:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_RIGHT
			event.pressed = true
			card._gui_input(event)
		await _layout()
	var pill_id := manager.party[1].inventory.matching_stack("base.pill.huichun")
	_check(not pill_id.is_empty(), "right click equips selected companion")
	if not pill_id.is_empty():
		_check(manager.party[1].inventory.get_instance(pill_id)["units"].size() == 3, "right clicks stack medicine")
	_check(manager.storage.get_entry(pill_key)["units"].size() == 7, "storage quantity decreases atomically")
	ui.storage_panel.set_category("pill")
	await _layout()
	_check(ui.storage_panel.cards.size() == 3, "medicine category filters content")
	await _capture("storage_medicines")
	ui.storage_panel.set_category("all")
	await _layout()
	var sword_id := "run.storage.base.weapon.qingfeng.0"
	var bag: InventoryView = ui.ally_panel.bags[0]
	var sword_card: StorageItemCard = ui.storage_panel.cards[sword_id]
	var data := sword_card.drag_data()
	_check(bag._can_drop_data(bag.cell_center(Vector2i(3, 0)), data), "storage drag accepts legal grid destination")
	if DisplayServer.get_name() == "headless":
		await _native_between(sword_card.get_global_rect().get_center(), bag.get_global_transform() * bag.cell_center(Vector2i(3, 0)))
	else:
		bag._drop_data(bag.cell_center(Vector2i(3, 0)), data)
	await _layout()
	_check(not manager.party[0].inventory.get_instance(sword_id).is_empty(), "storage drag inserts weapon")
	_check(manager.storage.get_entry(sword_id).is_empty(), "equipped weapon disappears from storage")
	var returning := bag.drag_data_at(bag.cell_center(Vector2i(3, 0)))
	_check(ui.storage_panel._can_drop_data(Vector2.ZERO, returning), "storage accepts returning array item")
	if DisplayServer.get_name() == "headless":
		await _native_between(bag.get_global_transform() * bag.cell_center(Vector2i(3, 0)), ui.storage_panel.global_position + Vector2(300, 20))
	else:
		ui.storage_panel._drop_data(Vector2.ZERO, returning)
	await _layout()
	_check(not manager.storage.get_entry(sword_id).is_empty(), "dragging back returns weapon")
	await _capture("storage_open")
	_key(KEY_SPACE)
	await _layout()
	_check(manager.simulation.state.phase == GameState.Phase.BATTLE and not manager.adjustment_open and not ui.storage_panel.visible, "space starts and closes adjustment")
	_check(ui._bag_button.disabled and not manager.set_adjustment(true), "running battle locks adjustment")
	_check(not bag._can_drop_data(bag.cell_center(Vector2i(3, 0)), data), "stale drag rejected after start")
	manager._process(1)
	_key(KEY_SPACE)
	ui._bag_button.pressed.emit()
	await _layout()
	_check(manager.simulation.clock.paused and manager.can_edit_inventory(), "paused battle permits adjustment")
	_check(manager.equip(sword_id, 0, Vector2i(3, 0)), "paused insertion command")
	_check(manager.simulation.cooling_remaining_usec(sword_id) == 2_000_000, "inserted weapon shows two seconds")
	_check(manager.move_item(2, GameManager.sword_instance(2), Vector2i(3, 0)), "companion rearrangement during pause")
	manager._process(10)
	_check(manager.simulation.state.time_usec == 1_000_000, "paused cooldown frozen")
	await _capture("storage_cooldown_2s")
	_key(KEY_SPACE)
	manager._process(1)
	await _layout()
	_check(manager.simulation.cooling_remaining_usec(sword_id) == 1_000_000, "cooldown displays one second after resume")
	await _capture("storage_cooldown_1s")
	_key(KEY_F3)
	manager._process(0.5)
	_check(manager.simulation.cooling_remaining_usec(sword_id) == 0 and manager.simulation.activation_progress(sword_id) == 0, "rotation starts after insertion cooldown at double speed")
	_key(KEY_F1)
	manager._process(3)
	_check(absf(manager.simulation.activation_progress(sword_id) - 0.5) < 0.001, "rotation follows half-speed simulation")
	ui._log_button.pressed.emit()
	await _layout()
	_check(ui._log_panel.visible and ui._log_label.text.contains("野狗"), "log button reveals battle record")
	await _capture("storage_log")
	ui._log_panel.hide()
	_key(KEY_SPACE)
	ui._bag_button.pressed.emit()
	await _layout()
	if DisplayServer.get_name() != "headless":
		for dimensions in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(1280, 800), Vector2i(1720, 720)]:
			root.size = dimensions
			await _layout()
			_check_layout()
			_check(ui.storage_panel.get_global_rect().end.x <= ui.size.x and ui.storage_panel.get_global_rect().end.y <= ui.size.y, "storage panel within viewport")
			await _capture("storage_%dx%d" % [dimensions.x, dimensions.y])
	# Formation is still a prebattle API, with no combat scene switch.
	manager.set_adjustment(false)
	var full_party: Array[PartyMemberState] = manager.party.duplicate()
	for count in [2, 1, 3]:
		manager.party.assign(full_party.slice(0, count))
		manager.selected_member_index = 0
		manager.restart()
		await _layout()
		_check_layout()
	_check(manager.set_formation(FormationRules.Kind.FRONT_TWO), "future world-map formation API retained")
	await _layout()
	_check_layout()
	print("UI RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _right_click(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_RIGHT
		event.pressed = pressed
		Input.parse_input_event(event)

func _native_between(start: Vector2, finish: Vector2) -> void:
	_mouse_motion(start)
	_mouse_button(start, true)
	await process_frame
	_mouse_motion(start + Vector2(32, 0), true)
	await process_frame
	_mouse_motion(finish, true)
	await process_frame
	_mouse_button(finish, false)
	await _layout()

func _move_all_bags() -> void:
	for index in manager.party.size():
		var bag: InventoryView = ui.ally_panel.bags[index]
		for move in [[Vector2i.ZERO, Vector2i(3, 2), GameManager.sword_instance(index)], [Vector2i(1, 1), Vector2i(0, 2), GameManager.armor_instance(index)]]:
			if DisplayServer.get_name() == "headless":
				await _native_drag(bag, move[0], move[1])
			else:
				var data := bag.drag_data_at(bag.cell_center(move[0]))
				bag._drop_data(bag.cell_center(move[1]), data)
			_check(manager.party[index].inventory.get_instance(move[2])["cell"] == move[1], "own equipment moves directly in bag %d" % index)
		var invalid := bag.drag_data_at(bag.cell_center(Vector2i(0, 2)))
		_check(not bag._can_drop_data(bag.cell_center(Vector2i(3, 3)), invalid), "invalid footprint rejected in each bag")
		manager.move_item(index, GameManager.armor_instance(index), Vector2i(1, 1))
		manager.move_item(index, GameManager.sword_instance(index), Vector2i.ZERO)
		bag.reset_interaction()
	_check(ui.enemy_panel.bags[0].drag_data_at(ui.enemy_panel.bags[0].cell_center(Vector2i(1, 1))).is_empty(), "enemy inventory always read-only")

func _check_layout() -> void:
	_check(absf(ui._time.get_global_rect().get_center().x - ui.size.x / 2) < 1, "timer centered on viewport")
	_check(ui.enemy_panel.get_global_rect().end.x <= ui.size.x + 1, "both teams fit width")
	_check(ui.enemy_panel.bags[0].get_global_rect().end.y <= ui.size.y + 1, "bags fit viewport height")
	for panel in [ui.ally_panel, ui.enemy_panel]:
		_check(panel.cards.size() == panel.members.size() and panel.bags.size() == panel.members.size(), "no empty roster placeholders")
		var hero: Rect2 = panel.bags[0].get_global_rect()
		if panel.members.size() == 1:
			_check(absf(hero.get_center().x - panel.get_global_rect().get_center().x) < 1, "single backpack centered")
			_check(absf(panel.cards[0].get_global_rect().get_center().x - panel.get_global_rect().get_center().x) < 1, "single portrait group centered")
		else:
			_check(hero.size.x > panel.bags[1].size.x and panel.cards[0].custom_minimum_size.x > panel.cards[1].custom_minimum_size.x, "hero always large and companions small")
			var main_on_right: bool = hero.position.x > panel.bags[1].global_position.x
			_check(main_on_right == (manager.formation == FormationRules.Kind.FRONT_ONE or panel.members.size() == 2), "ally front row toward screen center")
			_check((panel.cards[0].global_position.x > panel.cards[1].global_position.x) == main_on_right, "portraits and bags share formation orientation")
			if panel.members.size() == 3:
				_check(absf(panel.bags[1].global_position.y - hero.position.y) < 1 and absf(panel.bags[2].get_global_rect().end.y - hero.end.y) < 1, "rear bags align top and bottom")

func _layout() -> void:
	for frame in 4:
		await process_frame
	ui._refresh()

func _capture(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await _layout()
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png("res://artifacts/%s.png" % name) == OK, "render " + name)

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

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + description)
