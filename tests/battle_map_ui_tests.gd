extends SceneTree

var failures := 0
var checks := 0
var presentation: Node

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	for i in 8: await process_frame

func shot(label: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/battle-map-" + label + ".png")

func _run() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(2560, 1440)
	presentation = root.get_node("MapPresentation")
	var map = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path = ""
	map.arrival_point_id = "base.map.qingshihewan.point.n14"
	root.add_child(map)
	current_scene = map
	await settle()
	check(map.startup_error.is_empty(), "map ready")
	map.player_status.set_resource("hp", 41)
	map.player_status.set_resource("stamina", 37)
	var snapshot: Dictionary = map.player_status.battle_snapshot()
	check(snapshot.companion_ids.is_empty(), "actual roster starts empty")
	map.travel.request_destination("base.map.qingshihewan.point.n12")
	map.travel.advance(1000)
	check(map.encounter_dialog.visible, "real encounter open")
	map._confirm_encounter()
	while not presentation.transitioning: await process_frame
	var start := Time.get_ticks_msec()
	check(not map.encounter_dialog.visible, "fade uses actual map, not encounter popup")
	await create_timer(0.7).timeout
	check(current_scene == map and presentation._cover.material == null, "uniform full-screen fade rather than directional wipe")
	check(presentation._cover.modulate.a > 0.2 and presentation._cover.modulate.a < 0.8, "fade-out is visibly gradual")
	check(presentation.music_state == "pausing", "map audio fades with first half")
	# Do not synchronously read back/encode a 2K screenshot inside timed fades.
	# That stalls the main thread; capture final layouts after timing assertions.
	while current_scene == map: await process_frame
	var battle := current_scene
	var manager: GameManager = battle.get_node("GameManager")
	var ui = battle.get_node("MainUI")
	print("MIDPOINT SECONDS: ", (Time.get_ticks_msec() - start) / 1000.0)
	check(absf((Time.get_ticks_msec() - start) / 1000.0 - 1.0) < 0.25, "scene swaps at 1s black midpoint")
	check(presentation.music.stream_paused, "map music paused at black")
	check(ui.game_audio.music.playing and ui.game_audio.music.volume_linear < 0.1, "battle music starts at zero gain")
	await create_timer(0.6).timeout
	check(ui.game_audio.music.volume_linear > 0.05 and ui.game_audio.music.volume_linear < 0.5, "battle music fades in while revealing")
	check(manager.simulation.state.time_usec == 0, "no combat time elapses during reveal")
	while presentation.transitioning: await process_frame
	manager.set_process(false)
	print("TRANSITION SECONDS: ", (Time.get_ticks_msec() - start) / 1000.0)
	check(absf((Time.get_ticks_msec() - start) / 1000.0 - 2.0) < 0.3, "total battle transition 2s")
	check(is_equal_approx(ui.game_audio.music.volume_linear, db_to_linear(-6)), "battle music reaches full gain at reveal end")
	check(manager.party[0].definition.id == snapshot.character.id and manager.party[0].definition.portrait == snapshot.character.portrait, "current player identity and portrait passed through")
	check(manager.party[0].hp == 41 and manager.party[0].stamina == 37, "current resources preserved, no fake companion bonuses")
	check(manager.companions.is_empty() and ui.ally_panel.companion_cards.is_empty(), "no dummy companion state or UI")
	var portrait: AtlasTexture = ui.ally_panel.cards[0].portrait.texture
	check(portrait.atlas.resource_path == "res://assets/player-1-1.webp" and portrait.region == Rect2(22,18,448,448), "battle portrait uses actual map crop")
	check(absf(ui.ally_panel.cards[0].get_global_rect().get_center().x - ui.ally_panel.bags[0].get_global_rect().get_center().x) < 2.0, "solo actor status centered over board")
	await shot("solo")
	manager.pause_battle()
	manager.set_adjustment(true)
	await settle()
	var panel: BattleStoragePanel = ui.storage_panel
	check(panel.visible and panel.grid.columns == 6, "replacement opens shared six-column map storage")
	check(panel.storage_panel.find_child("StoragePanelBackground", true, false) != null, "shared storage background")
	check(panel.size.is_equal_approx(Vector2(910,910)), "storage matches map panel dimensions")
	check(panel.catalog.total_count() == manager._durable_loadout.storage_records().size(), "catalog reads live inventory only")
	var card: BattleInventoryItemCard = panel.grid.get_child(0)
	check(card is MapInventoryItemCard and card.background.material.shader.resource_path == "res://scripts/map/map_item_card_background.gdshader", "same map item card renderer")
	await shot("storage")
	panel.catalog.set_filter("search", "青石短剑")
	await settle()
	check(panel.grid.get_child_count() == 1, "map search filters battle inventory")
	card = panel.grid.get_child(0)
	var data := card.drag_data()
	check(data.kind == "storage" and data.epoch == manager.interaction_epoch, "card supplies battle drag protocol")
	var bag: InventoryView = ui.ally_panel.bags[0]
	var point := bag.grid_rect().position + bag.grid_rect().size / 6.0
	check(bag._can_drop_data(point, data), "battle board accepts shared card payload")
	bag._drop_data(point, data)
	var equipped: Array = manager.party[0].inventory.get_instances()
	check(equipped.size() == 1 and manager.simulation.state.item_runtime.has(equipped[0].instance_id), "drop attaches to actual combat simulation")
	var back := {"kind":"inventory", "member_index":0, "instance_id":equipped[0].instance_id, "epoch":manager.interaction_epoch}
	check(panel._can_drop_data(Vector2.ZERO, back), "storage accepts board item return")
	panel._drop_data(Vector2.ZERO, back)
	check(manager.party[0].inventory.get_instances().is_empty(), "return unequips through manager")
	# Native synthetic input runs headless, as in the existing UI suite. Hidden
	# Windows renders are for layout/timing, not OS-cursor-dependent drag tests.
	if DisplayServer.get_name() == "headless":
		await settle()
		card = panel.grid.get_child(0)
		var card_point := card.get_global_rect().get_center()
		var board_point: Vector2 = bag.get_global_transform() * bag.cell_center(Vector2i.ZERO)
		await drag(card_point, board_point)
		check(manager.party[0].inventory.get_instances().size() == 1, "native map-style card drag places into combat board")
		await drag(board_point, panel.search.get_global_rect().get_center())
		check(manager.party[0].inventory.get_instances().is_empty(), "native board drag returns through shared storage child")
		card = panel.grid.get_child(0)
		await drag(card.get_global_rect().get_center(), Vector2(10, 10))
		check(manager.party[0].inventory.get_instances().is_empty() and not root.gui_is_dragging(), "invalid shared card drop cancels without changing inventory")
	panel.catalog.reset_filters()
	# Isolated two-bottle fixture: the default catalog currently grants singles.
	for stored: Dictionary in manager.storage.entries():
		var item := manager.registry.get_item(stored.item_id)
		if item.category == "pill":
			manager.storage.put({"instance_id":"test.pill.extra", "item_id":item.id, "units":[{"id":"test.pill.extra", "uses_left":item.uses_per_unit}]})
			manager.inventory_changed.emit()
			break
	await settle()
	var pill: BattleInventoryItemCard
	for candidate in panel.grid.get_children():
		if candidate.entry.category == "pill" and candidate.quantity_picker != null:
			pill = candidate
			break
	check(pill != null, "quantity control present on map-style pill card")
	if pill != null:
		pill.quantity_picker.value = 2
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_RIGHT
		event.pressed = true
		pill._gui_input(event)
		var instances: Array = manager.party[0].inventory.get_instances()
		check(instances.size() == 1 and instances[0].units.size() == 2, "right-click respects selected battle quantity")
		manager.unequip(0, instances[0].instance_id)
	manager.set_adjustment(false)
	check(not panel._can_drop_data(Vector2.ZERO, back), "closed storage rejects stale edits")
	manager.play_normal()
	manager.request_retreat()
	for second in 10:
		if manager.simulation.state.is_finished(): break
		manager._process(1.0)
	check(manager.simulation.state.result == "defeat" and manager.simulation.state.finish_reason == "retreat", "actual retreat finishes as defeat")
	var offset: float = presentation.music.get_playback_position()
	var result := {"error": "pending"}
	_return_to_map(battle, result)
	while not presentation.transitioning: await process_frame
	start = Time.get_ticks_msec()
	while presentation.transitioning: await process_frame
	var error: String = result.error
	check(error.is_empty() and current_scene.has_method("_try_start_event"), "return transition succeeds")
	check(absf((Time.get_ticks_msec() - start) / 1000.0 - 2.0) < 0.5, "return also 1+1s")
	check(not presentation.music.stream_paused and presentation.music_state == "playing", "map resumes at full gain after return")
	check(presentation.music.get_playback_position() >= offset, "map resumes rather than restarts")
	# A nonempty real roster is also respected; it does not restore both old test allies.
	var game := GameManager.new()
	game.use_saved_loadout = true
	game.loadout_save_path = ""
	game.player_snapshot = snapshot.duplicate(true)
	game.player_snapshot.companion_ids = ["base.character.role_2"]
	root.add_child(game)
	game.set_process(false)
	check(game.startup_error.is_empty() and game.companions.size() == 1 and game.companions[0].definition.id == "base.character.role_2", "only explicitly present teammates are loaded")
	game.queue_free()
	current_scene.queue_free()
	presentation.music.stop()
	await settle()
	print("BATTLE MAP UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _return_to_map(battle: Node, result: Dictionary) -> void:
	result.error = await battle.get_node("MapBattleReturn").return_to_map()

func drag(from: Vector2, to: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = from
	move.global_position = from
	Input.parse_input_event(move)
	var button := InputEventMouseButton.new()
	button.position = from
	button.global_position = from
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = true
	button.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(button)
	await settle()
	move = InputEventMouseMotion.new()
	move.position = to
	move.global_position = to
	move.relative = to - from
	move.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(move)
	await settle()
	if root.gui_is_dragging():
		var live_preview := root.find_child("CenteredItemDragPreview", true, false) as Control
		check(live_preview != null and live_preview.get_global_transform().get_scale().is_equal_approx(Vector2.ONE * (root.size.x / 1920.0)), "native drag preview keeps battle design scale")
	button = InputEventMouseButton.new()
	button.position = to
	button.global_position = to
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = false
	Input.parse_input_event(button)
	await settle()
