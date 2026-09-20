extends SceneTree

const SAVE := "res://artifacts/map-loadout-test.json"
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + message)

func _fresh() -> MapLoadoutState:
	var registry := ContentRegistry.new()
	registry.load_base_content()
	var created := MapLoadoutStore.create_state(registry, registry.get_board("base.board.bag"))
	_check(created.error.is_empty(), "canonical weapons register for both map and battle")
	return created.state

func _clear_test_save() -> void:
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(SAVE + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))

func _model_checks() -> void:
	var state := _fresh()
	var initial := state.snapshot()
	var first: Dictionary = state.storage.get_entry("owned.base.map_item.qingshi_short_sword.0")
	var drag := state.drag_data("storage", first.instance_id)
	_check(not state.can_place(drag, Vector2i(0, 2)) and not state.can_place(drag, Vector2i(3, 0)), "vertical footprint rejects bottom and right overflow")
	_check(state.place(drag, Vector2i.ZERO), "storage unit transferred to board")
	_check(not state.valid_drag(drag) and not state.place(drag, Vector2i(1, 0)), "stale drag cannot duplicate item")
	var second: Dictionary = state.storage.get_entry("owned.base.map_item.hunting_bow.0")
	_check(state.placement_kind(state.drag_data("storage", second.instance_id), Vector2i.ZERO) == "swap" and state.place(state.drag_data("storage", second.instance_id), Vector2i.ZERO), "one overlapping item permits exchange")
	_check(not state.storage.get_entry(first.instance_id).is_empty() and state.inventory.get_instances().size() == 1 and state.storage.entries().size() == 9, "exchange returns displaced item without changing ownership count")
	_check(state.place(state.drag_data("storage", first.instance_id), Vector2i.ZERO), "exchange can be reversed")
	var before := state.snapshot()
	var malformed := before.duplicate(true)
	malformed.placements.append(malformed.placements[0].duplicate(true))
	_check(not state.restore(malformed).is_empty() and state.snapshot() == before, "duplicate persisted unit rejected without modifying live state")
	malformed = before.duplicate(true)
	malformed.placements[0].cell = [0, 2]
	_check(not state.restore(malformed).is_empty() and state.snapshot() == before, "out-of-bounds persisted unit rejected atomically")
	malformed = before.duplicate(true)
	malformed.placements[0].item_id = "unknown.item.id"
	_check(not state.restore(malformed).is_empty(), "unknown item rejected")
	_check(MapLoadoutStore.save(state, SAVE).is_empty(), "snapshot saves")
	var restored := _fresh()
	_check(MapLoadoutStore.load_into(restored, SAVE).is_empty() and restored.snapshot() == before and restored.storage.entries().size() == 9, "fresh model restores same owned item positions and remaining storage")
	_check(state.take_back(state.drag_data("board", first.instance_id)) and state.storage.entries().size() == 10, "return conserves ownership")
	_check(MapLoadoutStore.save(state, SAVE).is_empty(), "empty layout replaces previous equipped save")
	_check(MapLoadoutStore.load_into(restored, SAVE).is_empty() and restored.snapshot() == initial, "empty layout remains empty after restart")
	var file := FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string("{incomplete")
	file.close()
	_check(not MapLoadoutStore.load_into(restored, SAVE).is_empty() and restored.snapshot() == initial, "corrupt save is reported without mutating configuration")
	_clear_test_save()
	_swap_checks()

func _swap_checks() -> void:
	for victim_size in [Vector2i(1, 2), Vector2i(2, 1)]:
		var state := _fresh()
		var units := state.storage.entries()
		state.registry.get_item(units[0].item_id).grid_size = Vector2i(2, 2)
		state.registry.get_item(units[1].item_id).grid_size = victim_size
		state.registry.get_item(units[2].item_id).grid_size = victim_size
		state.place(state.drag_data("storage", units[1].instance_id), Vector2i.ZERO)
		var data := state.drag_data("storage", units[0].instance_id)
		_check(state.placement_kind(data, Vector2i.ZERO) == "swap", "2x2 over multiple cells of ONE item is exchangeable: %s" % victim_size)
		state.place(state.drag_data("storage", units[2].instance_id), Vector2i(1, 0) if victim_size.x == 1 else Vector2i(0, 1))
		data = state.drag_data("storage", units[0].instance_id)
		var before := state.snapshot()
		var storage_before := state.storage.entries()
		var revision_before := state.revision
		_check(state.placement_kind(data, Vector2i.ZERO) == "invalid" and not state.place(data, Vector2i.ZERO) and state.snapshot() == before and state.storage.entries() == storage_before and state.revision == revision_before, "2x2 across TWO items rejects without mutation: %s" % victim_size)
		_check(not state.can_place(data, Vector2i(2, 1)), "exchange cannot bypass board bounds")
		state.take_back(state.drag_data("board", units[2].instance_id))
		data = state.drag_data("storage", units[0].instance_id)
		_check(state.place(data, Vector2i.ZERO) and state.inventory.occupied_cells() == 4 and state.inventory.get_instance(units[1].instance_id).is_empty() and not state.storage.get_entry(units[1].instance_id).is_empty(), "2x2 exchange consumes one incoming unit and returns whole displaced item")
		_check(not state.valid_drag(data) and not state.place(data, Vector2i.ZERO), "exchange invalidates old drag token")
		var reverse := state.drag_data("storage", units[1].instance_id)
		_check(state.place(reverse, Vector2i.ZERO) and state.inventory.occupied_cells() == 2, "smaller item exchanges with one larger item and clears its leftover cells")
		var board_drag := state.drag_data("board", units[1].instance_id)
		state.inventory.locked = true
		_check(not state.can_place(board_drag, Vector2i.ZERO) and not state.can_place(state.drag_data("storage", units[0].instance_id), Vector2i.ZERO), "locked inventory rejects both moves and swaps")

func _map() -> Control:
	var screen: Control = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	screen.inventory_save_path = SAVE
	root.add_child(screen)
	screen.set_process(false)
	return screen

func _run() -> void:
	AudioServer.set_bus_mute(0, true)
	_clear_test_save()
	_model_checks()
	root.size = Vector2i(1920, 1080)
	var screen := _map()
	await _settle()
	screen.set_inventory_open(true)
	await _settle()
	var panel: MapInventoryScreen = screen.inventory_screen
	var board := panel.loadout_board
	var six_card_size: Vector2 = panel.grid.get_child(0).size
	var sword_card: MapInventoryItemCard
	for card in panel.grid.get_children():
		if card.entry.name == "青石短剑":
			sword_card = card
	await _reveal_card(sword_card)
	var start := sword_card.get_global_rect().get_center()
	var finish := _board_center(board, Vector2i.ZERO)
	_mouse(start, MOUSE_BUTTON_LEFT, true)
	await _settle()
	_check(root.gui_is_dragging(), "left press starts full-image native drag immediately")
	_motion(finish, true)
	await _settle()
	var preview := root.find_child("MapItemDragPreview", true, false)
	_check(preview != null, "full item preview exists")
	if preview != null:
		var art: TextureRect = preview.get_child(0)
		_check(art.get_global_rect().get_center().distance_to(finish) < 2 and art.texture is AtlasTexture and art.has_node("ItemGlow"), "whole icon and halo centered on pointer (expected %s, actual %s, mouse %s, window %s)" % [finish, art.get_global_rect().get_center(), root.get_mouse_position(), root.size])
	_check(board._hover_valid and board._hover_dimensions == Vector2i(1, 2), "nearest two vertical cells preview legal placement")
	await _capture("map_loadout_drag_valid")
	_mouse(finish, MOUSE_BUTTON_LEFT, false)
	await _settle()
	_check(screen.loadout.inventory.get_instances().size() == 1 and panel.grid.get_child_count() == 9 and panel.board_capacity.text == "2/9", "actual drag equips one two-cell item and updates occupied capacity")
	_check(panel.grid.get_child(0).size.is_equal_approx(six_card_size), "remaining cards retain the six-column card size")
	if screen.loadout.inventory.get_instances().is_empty():
		quit(1)
		return
	var sword: Dictionary = screen.loadout.inventory.get_instances()[0]
	await _drag(finish, _board_center(board, Vector2i(1, 1)))
	_check(screen.loadout.inventory.get_instance(sword.instance_id).cell == Vector2i(1, 1) and panel.board_capacity.text == "2/9", "board move keeps occupied capacity")
	var blocked_card: MapInventoryItemCard = panel.grid.get_child(0)
	var blocked_size: Vector2i = screen.loadout.registry.get_item(blocked_card.entry.id).grid_size
	var swap_target: Vector2 = board.get_global_transform() * board.layout.footprint_rect(Vector2i(1, 1), blocked_size, board.size).get_center()
	await _reveal_card(blocked_card)
	_mouse(blocked_card.get_global_rect().get_center(), MOUSE_BUTTON_LEFT, true)
	await _settle()
	_motion(swap_target, true)
	await _settle()
	_check(board._hover_valid and board._hover_swap, "single overlapping item previews a light-blue exchange target")
	await _capture("map_loadout_drag_swap")
	_mouse(swap_target, MOUSE_BUTTON_LEFT, false)
	await _settle()
	_check(panel.grid.get_child_count() == 9 and screen.loadout.inventory.get_instance(sword.instance_id).is_empty() and not screen.loadout.storage.get_entry(sword.instance_id).is_empty(), "drop exchanges with the one occupied item and returns sword to storage")
	# The first storage card can now be a1x1 pill; pick its actual footprint.
	var swapped: Dictionary = screen.loadout.inventory.get_instances()[0]
	var swapped_size: Vector2i = screen.loadout.registry.get_item(swapped.item_id).grid_size
	var swapped_center: Vector2 = board.get_global_transform() * board.layout.footprint_rect(swapped.cell, swapped_size, board.size).get_center()
	await _drag(swapped_center, panel.storage_panel.get_global_rect().get_center() + Vector2(0, 250))
	_check(screen.loadout.inventory.get_instances().is_empty() and panel.grid.get_child_count() == 10 and panel.board_capacity.text == "0/9", "dragging to storage returns weapon and clears occupied capacity")
	var random_card: MapInventoryItemCard
	for card: MapInventoryItemCard in panel.grid.get_children():
		if card.entry.name == "猎弓":
			random_card = card
			break
	await _reveal_card(random_card)
	_mouse(random_card.get_global_rect().get_center(), MOUSE_BUTTON_RIGHT, true)
	_mouse(random_card.get_global_rect().get_center(), MOUSE_BUTTON_RIGHT, false)
	await _settle()
	_check(screen.loadout.inventory.get_instances().size() == 1, "storage right click equips in a legal random cell")
	var random_entry: Dictionary = screen.loadout.inventory.get_instances()[0]
	var equipped_bow: MapItemArtwork = board._items[random_entry.instance_id]
	_check(equipped_bow.has_node("ItemOutline") and equipped_bow.get_node("ItemOutline").z_index == 0, "equipped hunting bow keeps its outline above the board background")
	await _capture("map_loadout_bow_outline")
	var random_center := _board_center(board, random_entry.cell)
	_mouse(random_center, MOUSE_BUTTON_RIGHT, true)
	_mouse(random_center, MOUSE_BUTTON_RIGHT, false)
	await _settle()
	_check(screen.loadout.inventory.get_instances().is_empty(), "board right click returns item")
	# Closing while holding an uncommitted drag must cancel it before saving.
	await _reveal_card(panel.grid.get_child(0))
	_mouse(panel.grid.get_child(0).get_global_rect().get_center(), MOUSE_BUTTON_LEFT, true)
	await _settle()
	screen.set_inventory_open(false)
	_mouse(Vector2(800, 800), MOUSE_BUTTON_LEFT, false)
	await _settle()
	_check(not root.gui_is_dragging() and screen.loadout.inventory.get_instances().is_empty(), "closing cancels drag without equipping or losing ownership")
	screen.set_inventory_open(true)
	await _settle()
	await _reveal_card(panel.grid.get_child(0))
	_mouse(panel.grid.get_child(0).get_global_rect().get_center(), MOUSE_BUTTON_LEFT, true)
	await _settle()
	screen.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	_mouse(Vector2(800, 800), MOUSE_BUTTON_LEFT, false)
	await _settle()
	_check(not root.gui_is_dragging() and screen.loadout.inventory.get_instances().is_empty(), "focus loss cancels drag without changing ownership")
	board.scale = Vector2.ONE * 0.75
	var scaled_data: Dictionary = screen.loadout.drag_data("storage", screen.loadout.storage.entries()[0].instance_id)
	var scaled_preview := board.make_preview(scaled_data)
	var preview_item: ItemData = screen.loadout.registry.get_item(screen.loadout.drag_entry(scaled_data).item_id)
	var expected_size := board.layout.footprint_rect(Vector2i.ZERO, preview_item.grid_size, board.size).grow(-9).size * 0.9 * board.get_global_transform().get_scale().abs()
	_check(scaled_preview.get_child(0).size.is_equal_approx(expected_size), "preview inset and footprint scale together with board")
	scaled_preview.free()
	board.scale = Vector2.ONE
	for card in panel.grid.get_children():
		if card.entry.name == "青石短剑":
			sword_card = card
	await _reveal_card(sword_card)
	await _drag(sword_card.get_global_rect().get_center(), _board_center(board, Vector2i(2, 0)))
	for card in panel.grid.get_children():
		if card.entry.name == "粗布甲":
			await _reveal_card(card)
			await _drag(card.get_global_rect().get_center(), _board_center(board, Vector2i.ZERO))
			break
	_check(screen.loadout.inventory.get_instances().size() == 2 and panel.board_capacity.text == "4/9", "armor and weapon capacity counts cells rather than item count")
	await _capture("map_loadout_equipped")
	var saved: Dictionary = screen.loadout.snapshot()
	screen.set_inventory_open(false)
	_check(FileAccess.file_exists(SAVE), "closing interface writes local snapshot")
	screen.queue_free()
	await _settle()
	screen = _map()
	await _settle()
	_check(screen.startup_error.is_empty() and screen.loadout.snapshot() == saved, "new map scene loads last closed layout")
	# Standalone F6 battle has no map underneath; hide the retained save fixture.
	screen.hide()
	var battle: Node = load("res://scenes/main/main.tscn").instantiate()
	battle.get_node("GameManager").loadout_save_path = SAVE
	root.add_child(battle)
	await _settle()
	var game: GameManager = battle.get_node("GameManager")
	game.set_process(false)
	_check(game.startup_error.is_empty() and game.party[0].inventory.get_instances().size() == 2 and game.party[0].inventory.get_instance(sword.instance_id).cell == Vector2i(2, 0), "real battle entry reads exact saved positions without legacy equipment")
	_check(game.storage.entries().size() == 8, "battle storage contains exactly remaining map weapons and armor")
	game.start_battle()
	game._process(3.5)
	_check(is_equal_approx(game.enemies[0].hp, 96.6) and game.party[0].stamina == 52, "saved slash attacks at3.5s for8.4 unarmored damage and3 stamina after board bonuses (actual %.1f/%d)" % [game.enemies[0].hp, game.party[0].stamina])
	_check(game.party[0].hp == 70 and game.party[0].armor == 0, "first dog hit costs full5HP after board and companion bonuses, with no fixed reduction")
	game._process(1.5)
	_check(game.party[0].armor == 5 and game.party[0].maximum("armor") == 7, "saved cloth gains3 at4s and actual ward gains2 at5s")
	await _settle()
	await _capture("armor_battle_runtime")
	_check(MapLoadoutStore.load_into(screen.loadout, SAVE).is_empty() and screen.loadout.snapshot() == saved, "battle does not write temporary changes into map preset")
	battle.queue_free()
	screen.queue_free()
	await _settle()
	# Let the audio mixer release stopped music/hit voices before quitting.
	await create_timer(0.2).timeout
	_clear_test_save()
	print("MAP LOADOUT RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _board_center(board: MapLoadoutBoard, cell: Vector2i) -> Vector2:
	return board.get_global_transform() * board.layout.footprint_rect(cell, Vector2i(1, 2), board.size).get_center()

func _reveal_card(card: Control) -> void:
	(card.get_parent().get_parent() as ScrollContainer).ensure_control_visible(card)
	await _settle()

func _drag(from: Vector2, to: Vector2) -> void:
	_motion(from)
	_mouse(from, MOUSE_BUTTON_LEFT, true)
	await _settle()
	_motion(to, true)
	await _settle()
	_mouse(to, MOUSE_BUTTON_LEFT, false)
	await _settle()

func _mouse(point: Vector2, button: MouseButton, pressed: bool) -> void:
	if DisplayServer.get_name() != "headless":
		root.warp_mouse(point)
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = button
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed and button == MOUSE_BUTTON_LEFT else 0
	Input.parse_input_event(event)

func _motion(point: Vector2, held: bool = false) -> void:
	if DisplayServer.get_name() != "headless":
		root.warp_mouse(point)
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = Vector2(20, 0)
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	Input.parse_input_event(event)

func _settle() -> void:
	for i in 6:
		await process_frame

func _capture(file_name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/" + file_name + ".png")
