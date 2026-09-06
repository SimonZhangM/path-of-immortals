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
	_check(manager.party.size() == 3 and manager.enemies.size() == 1, "three allies and one dog")
	_check(ui.enemy_panel.cards[0].stat_values["spirit"].text == "0 / 0", "zero spirit displayed correctly")
	_check(ui.enemy_panel.cards[0].portrait.texture.resource_path == "res://assets/guaiwu.webp", "dog portrait loaded")
	_check(ui.get_node("BattleBackground").texture.resource_path == "res://assets/backgroundtest.png", "supplied background")
	_check(manager.registry.get_item(GameManager.CLAW_ID).icon_path == "res://assets/images/items/dog_claw.svg", "claw artwork configured")
	_check_layout()
	await _capture("formation_front_one")
	for index in 3:
		var card: PartyMemberCard = ui.ally_panel.cards[index]
		var before := card.custom_minimum_size
		if DisplayServer.get_name() == "headless":
			var point := card.get_global_rect().get_center()
			_mouse_motion(point)
			_mouse_button(point, true)
			_mouse_button(point, false)
			await _layout()
		_check(card.custom_minimum_size == before, "clicking character never changes fixed size")
	await _move_all_bags()
	var bag: InventoryView = ui.ally_panel.bags[0]
	var stale := bag.drag_data_at(bag.cell_center(Vector2i.ZERO))
	_check(not ui.ally_panel.bags[1]._can_drop_data(ui.ally_panel.bags[1].cell_center(Vector2i(3, 0)), stale), "cross-character drag rejected")
	_check(manager.set_formation(FormationRules.Kind.FRONT_TWO), "formation switch in preparation")
	await _layout()
	_check_layout()
	_check(not ui.ally_panel.bags[0]._can_drop_data(ui.ally_panel.bags[0].cell_center(Vector2i(3, 0)), stale), "rebuild invalidates stale drag")
	await _capture("formation_front_two")
	manager.set_formation(FormationRules.Kind.FRONT_ONE)
	await _layout()
	manager._process(20)
	_check(manager.simulation.state.time_usec == 0, "preparation time frozen")
	manager.move_item(2, GameManager.sword_instance(2), Vector2i(3, 2))
	_key(KEY_SPACE)
	ui._refresh()
	_check(manager.simulation.state.phase == GameState.Phase.BATTLE and ui._formation.disabled, "space starts and locks formation")
	_check(not manager.set_formation(FormationRules.Kind.FRONT_TWO), "cannot change formation in battle")
	for index in 3:
		_check(ui.ally_panel.bags[index].drag_data_at(ui.ally_panel.bags[index].cell_center(Vector2i.ZERO)).is_empty(), "all allied backpacks locked in battle")
	_key(KEY_F1)
	manager._process(3)
	_check(manager.simulation.state.time_usec == 1_500_000, "half speed")
	_key(KEY_SPACE)
	_key(KEY_SPACE, true)
	_key(KEY_F3)
	manager._process(20)
	_check(manager.simulation.clock.paused and manager.simulation.state.time_usec == 1_500_000, "pause ignores repeat and speed changes do not resume")
	_check(not manager.move_item(1, GameManager.sword_instance(1), Vector2i(3, 0)), "paused battle cannot rearrange ally items")
	_check(ui.ally_panel.bags[1].drag_data_at(ui.ally_panel.bags[1].cell_center(Vector2i.ZERO)).is_empty(), "paused compact bag cannot drag")
	_check(ui.enemy_panel.bags[0].cooldown_progress(GameManager.CLAW_INSTANCE) == 0.5, "enemy cooldown frozen halfway")
	await _capture("formation_paused")
	_key(KEY_SPACE)
	manager._process(0.75)
	ui._refresh()
	await _layout()
	_check(manager.party[0].hp == 95 and manager.enemies[0].hp == 70, "both sides exchange damage at three seconds")
	_check(ui.ally_panel.cards[0].stat_values["hp"].text == "95 / 100" and ui.enemy_panel.cards[0].stat_values["stamina"].text == "95 / 100", "HP and stamina bars reflect simulation")
	_check(ui._log_label.text.contains("野狗") and ui._log_label.text.contains("体力-5"), "combat log includes enemy and stamina cost")
	await _capture("formation_battle_3s")
	_key(KEY_F2)
	manager._process(9)
	ui._refresh()
	await _layout()
	_check(manager.simulation.state.result == "victory" and ui._status.text.contains("12.00"), "victory displayed at exact time")
	_check(manager.party[0].hp == 85 and manager.enemies[0].hp == 0, "default combat resources")
	_check(ui.enemy_panel.cards[0].portrait.modulate.r < 1, "fallen portrait dimmed")
	var old_bag: InventoryView = ui.ally_panel.bags[0]
	manager.restart()
	await _layout()
	_check(manager.party[0].hp == 100 and manager.party[0].stamina == 100 and manager.enemies[0].hp == 100, "reprepare resets both teams")
	_check(manager.can_edit_inventory() and manager.simulation.clock.speed_multiplier == 1 and manager.simulation.state.time_usec == 0, "reprepare unlocks allies and resets clock")
	_check(not is_instance_valid(old_bag), "old inventory view disposed safely")
	_check(ui._log_label.text == "布阵中。", "reprepare resets log")
	_check(manager.party[2].inventory.get_instance(GameManager.sword_instance(2))["cell"] == Vector2i(3, 2), "reprepare preserves custom companion layout")
	manager.move_item(2, GameManager.sword_instance(2), Vector2i.ZERO)
	await _move_all_bags()
	# Roster-size fixtures exercise layout support without introducing party-management gameplay.
	var full_party: Array[PartyMemberState] = manager.party.duplicate()
	for count in [2, 1, 3]:
		manager.party.assign(full_party.slice(0, count))
		manager.restart()
		await _layout()
		_check_layout()
		_check(ui._formation.disabled == (count != 3), "only three-person roster offers two formations")
		await _capture("formation_roster_%d" % count)
	if DisplayServer.get_name() != "headless":
		for dimensions in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(1280, 800), Vector2i(1720, 720)]:
			root.size = dimensions
			await _layout()
			_check_layout()
			await _capture("formation_%dx%d" % [dimensions.x, dimensions.y])
	print("UI RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

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
