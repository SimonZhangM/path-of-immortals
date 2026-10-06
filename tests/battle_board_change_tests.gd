extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(note)
func settle() -> void:
	for i in 8: await process_frame
func click(point: Vector2, button: int) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = button
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
func stored(game: GameManager, item_id: String) -> String:
	for row: Dictionary in game.storage.entries():
		if row.item_id == item_id: return row.instance_id
	return ""
func units(game: GameManager) -> Dictionary:
	var result := {}
	for entry: Dictionary in game.storage.entries() + game.party[0].inventory.get_instances():
		for unit: Dictionary in entry.units: result[unit.id] = unit.duplicate(true)
	return result
func run() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(2560,1440)
	var scene = load("res://scenes/main/main.tscn").instantiate()
	var game: GameManager = scene.get_node("GameManager")
	game.loadout_save_path = ""
	root.add_child(scene)
	game.set_process(false)
	var ui = scene.get_node("MainUI")
	check(game.startup_error.is_empty(), "battle starts")
	var durable := game._durable_snapshot.duplicate(true)
	var all_units := units(game)
	var board: InventoryView = ui.ally_panel.bags[0]
	var big := stored(game,"base.map_item.qinglan_board_6")
	var bag := stored(game,"base.map_item.bag_board")
	game.set_adjustment(true)
	ui.storage_panel.catalog.set_filter("category", "board")
	await settle()
	var card: BattleInventoryItemCard = ui.storage_panel.cards[big]
	check(card.drag_data().kind == "battle_board", "board card is draggable in preparation")
	click(card.get_global_rect().get_center(),MOUSE_BUTTON_RIGHT)
	await settle()
	check(ui.board_change_dialog.visible and game.party[0].board.id == "base.board.bag", "right-click only opens confirmation")
	click(ui.board_change_dialog.cancel_button.get_global_rect().get_center(),MOUSE_BUTTON_LEFT)
	check(not ui.board_change_dialog.visible and game.party[0].board.id == "base.board.bag", "cancel preserves board")
	var data := card.drag_data()
	check(not board._can_drop_data(Vector2(-10,-10),data), "outside rejects board")
	check(not ui.enemy_panel.bags[0]._can_drop_data(ui.enemy_panel.bags[0].size*0.5,data), "enemy rejects board")
	if DisplayServer.get_name() == "headless":
		var source := card.get_global_rect().get_center()
		var destination := board.get_global_transform() * board.visible_art_rect().get_center()
		var move := InputEventMouseMotion.new()
		move.position = source
		move.global_position = source
		Input.parse_input_event(move)
		var down := InputEventMouseButton.new()
		down.position = source
		down.global_position = source
		down.button_index = MOUSE_BUTTON_LEFT
		down.button_mask = MOUSE_BUTTON_MASK_LEFT
		down.pressed = true
		Input.parse_input_event(down)
		await settle()
		check(root.gui_is_dragging(), "native left-click begins board drag")
		move = InputEventMouseMotion.new()
		move.position = destination
		move.global_position = destination
		move.relative = destination-source
		move.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(move)
		await settle()
		var up := InputEventMouseButton.new()
		up.position = destination
		up.global_position = destination
		up.button_index = MOUSE_BUTTON_LEFT
		Input.parse_input_event(up)
		await settle()
	else:
		board._drop_data(board.visible_art_rect().get_center(),data)
		await settle()
	check(ui.board_change_dialog.visible, "drop opens confirmation")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/battle-board-confirm.png")
	click(ui.board_change_dialog.confirm_button.get_global_rect().get_center(),MOUSE_BUTTON_LEFT)
	await settle()
	check(game.party[0].board.id == "base.board.qinglan_6", "confirm equips large board")
	check(board.board_layout == game.party[0].board and board._board_art.texture == board.board_texture, "art and grid follow new board")
	check(not board.can_request_board_change(data), "old drag epoch rejected")
	check(units(game) == all_units, "board switch consumes nothing")
	var sword := stored(game,"base.map_item.qingshi_short_sword")
	var bow := stored(game,"base.map_item.hunting_bow")
	check(game.equip(sword,0,Vector2i.ZERO), "equip retained weapon")
	check(game.equip(bow,0,Vector2i(5,4)), "equip overflow weapon")
	game.start_battle()
	check(not game.change_board(bag), "running battle rejects board command")
	game.simulation.advance(0.7)
	game.pause_battle()
	check(not game.change_board(bag), "paused battle requires adjustment panel")
	game.set_adjustment(true)
	var member := game.party[0]
	member.hp = 24.5
	member.stamina = 22.3
	member.spirit = 13.2
	var runtime: Dictionary = game.simulation.state.item_runtime[sword].duplicate(true)
	var timer: Dictionary = game.simulation.timeline.timers[sword].duplicate(true)
	var time := game.simulation.state.time_usec
	all_units = units(game)
	check(game.change_board(bag), "paused adjustment allows shrink")
	check(member.inventory.get_instance(sword).cell == Vector2i.ZERO, "retained position unchanged")
	check(game.simulation.state.item_runtime[sword] == runtime and game.simulation.timeline.timers[sword] == timer, "retained cooldown and activation count unchanged")
	check(member.inventory.get_instance(bow).is_empty() and not stored(game,"base.map_item.hunting_bow").is_empty(), "overflow returned to storage")
	check(not game.simulation.state.item_runtime.has(bow) and not game.simulation.timeline.timers.has(bow), "overflow no longer scheduled")
	check(units(game) == all_units, "shrink preserves units")
	check(member.hp == 24.5 and member.stamina == 22.3 and member.spirit == 13.2 and game.simulation.state.time_usec == time, "switch does not refill resources or advance time")
	check(game.change_board(big), "grow again in same pause")
	check(game.equip(stored(game,"base.map_item.hunting_bow"),0,Vector2i(5,4)), "re-equip overflow in same pause")
	check(game.simulation.cooling_remaining_usec(bow) == 0, "same-pause return adds no insertion cooldown")
	member.hp = member.maximum("hp")
	check(game.change_board(bag), "switch to bonus board")
	check(member.hp <= member.maximum("hp"), "capacity increase never refills")
	member.hp = member.maximum("hp")
	check(game.change_board(big) and member.hp == member.maximum("hp"), "capacity decrease clamps current health")
	member.cultivation_rank_id = "base.cultivation.mortal"
	check(not game.change_board(big), "realm gate enforced")
	member.cultivation_rank_id = "base.cultivation.spirit_transformation"
	check(not game.change_board("missing"), "unowned board rejected")
	check(game._durable_snapshot == durable and game._durable_loadout.board.id == "base.board.bag", "temporary battle edit preserves saved map board")
	var activated: int = game.simulation.state.item_runtime[sword].activation_count
	game.toggle_pause()
	game.simulation.advance(game.simulation.timeline.remaining(sword) / 1000000.0 + 0.01)
	check(game.simulation.state.item_runtime[sword].activation_count == activated + 1, "retained weapon fires once at original deadline after resume")
	game.pause_battle()
	game.set_adjustment(true)
	await settle()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/battle-board-switched.png")
	game.simulation.state.phase = GameState.Phase.FINISHED
	game.simulation.state.result = "draw"
	check(not game.change_board(bag), "finished battle rejects board change")
	scene.queue_free()
	await settle()
	print("BATTLE BOARD CHANGE: %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)
