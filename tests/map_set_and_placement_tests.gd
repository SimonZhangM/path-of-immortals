extends SceneTree

func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for i in 6: await process_frame
func move_mouse(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	motion.relative = Vector2(20, 0)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(motion)
func stored(model: MapLoadoutState, item: String) -> String:
	for entry: Dictionary in model.storage.entries():
		if entry.item_id == item: return entry.instance_id
	return ""

func run() -> void:
	create_timer(25).timeout.connect(func(): quit(2))
	root.size = Vector2i(2560, 1440)
	var registry := ContentRegistry.new()
	if not registry.load_base_content():
		push_error(str(registry.errors))
		quit(1)
		return
	var created := MapLoadoutStore.create_state(registry, registry.get_board("base.board.bag"))
	assert(created.error.is_empty())
	var model: MapLoadoutState = created.state
	assert(model.select_board("base.map_item.qinglan_board_4").is_empty())
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/map_inventory.json"))
	var catalog := MapInventoryCatalog.new()
	catalog.configure(config)
	assert(catalog.replace_entries(model.storage_records()).is_empty())
	var ui := MapInventoryScreen.new()
	ui.configure(catalog, config, model.board, model)
	root.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.show()
	await settle()
	var body := stored(model, "base.map_item.coarse_cloth_armor")
	var arm := stored(model, "base.map_item.t01_0014")
	var leg := stored(model, "base.map_item.t01_0015")
	assert(model.place(model.drag_data("storage", body), Vector2i.ZERO))
	assert(model.place(model.drag_data("storage", arm), Vector2i(1, 0)))
	assert(model.place(model.drag_data("storage", leg), Vector2i(1, 1)))
	assert(model.buff_bonus_totals().armor == 13 and ui.buff_bonus_values.armor.text == "+13")
	assert(model.place(model.drag_data("board", leg), Vector2i(1, 2)))
	assert(model.buff_bonus_totals().armor == 10 and ui.buff_bonus_values.armor.text == "+10")
	assert(model.place(model.drag_data("board", leg), Vector2i(1, 1)))
	assert(ui.buff_bonus_values.armor.text == "+13")
	assert(model.take_back(model.drag_data("board", arm)))
	assert(ui.buff_bonus_values.armor.text == "+9")
	assert(model.place(model.drag_data("storage", arm), Vector2i(1, 0)))
	assert(ui.buff_bonus_values.armor.text == "+13")
	await settle()
	var board: MapLoadoutBoard = ui.loadout_board
	assert(board._placement_overlay.z_index > board._board_art.z_index)
	assert(board._placement_overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	var hammer := stored(model, "base.map_item.short_iron_hammer")
	var data := model.drag_data("storage", hammer)
	var dimensions := registry.get_item("base.map_item.short_iron_hammer").grid_size
	var cell := Vector2i(2, 2)
	var point := board.get_global_transform_with_canvas() * board.layout.footprint_rect(cell, dimensions, board.size).get_center()
	var sample := Vector2i(board.get_global_transform_with_canvas() * (board.layout.footprint_rect(cell, Vector2i.ONE, board.size).position + Vector2(10, 10)))
	var baseline := Color.BLACK
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		baseline = root.get_texture().get_image().get_pixelv(sample)
	board.force_drag(data, board.make_preview(data))
	move_mouse(point)
	await settle()
	if DisplayServer.get_name() != "headless":
		assert(board._can_drop_data(board.get_global_transform_with_canvas().affine_inverse() * point, data))
	assert(root.gui_is_dragging() and board._hover_valid and board._hover_cell == cell and board._hover_dimensions == dimensions)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var capture := root.get_texture().get_image()
		var color := capture.get_pixelv(sample)
		assert(absf(color.r - baseline.r) + absf(color.g - baseline.g) + absf(color.b - baseline.b) > .03)
		capture.save_png("res://artifacts/map-placement-overlay.png")
	board._drop_data(board.get_global_transform_with_canvas().affine_inverse() * point, data)
	root.gui_cancel_drag()
	await settle()
	assert(not root.gui_is_dragging() and model.inventory.item_at(cell) == hammer)
	assert(board._hover_dimensions == Vector2i.ZERO)
	board._begin_drag(model.drag_data("board", hammer))
	cell = Vector2i(3, 2)
	point = board.get_global_transform_with_canvas() * board.layout.footprint_rect(cell, dimensions, board.size).get_center()
	move_mouse(point)
	await settle()
	if DisplayServer.get_name() != "headless":
		assert(board._can_drop_data(board.get_global_transform_with_canvas().affine_inverse() * point, model.drag_data("board", hammer)))
	assert(board._hover_valid and board._hover_dimensions == dimensions)
	board._drop_data(board.get_global_transform_with_canvas().affine_inverse() * point, model.drag_data("board", hammer))
	root.gui_cancel_drag()
	await settle()
	assert(model.inventory.item_at(cell) == hammer and board._hover_dimensions == Vector2i.ZERO)
	ui.queue_free()
	await settle()
	print("PASS: map set total13, broken10, removed9, restored13; storage and board drags show visible footprint above board and clear after drop")
	quit()
