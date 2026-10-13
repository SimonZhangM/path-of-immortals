extends SceneTree

func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for i in 8: await process_frame
func run() -> void:
	create_timer(30).timeout.connect(func(): quit(2))
	root.size = Vector2i(2560, 1440)
	var registry := ContentRegistry.new()
	assert(registry.load_base_content())
	var created := MapLoadoutStore.create_state(registry, registry.get_board("base.board.bag"))
	assert(created.error.is_empty())
	var model: MapLoadoutState = created.state
	assert(model.select_board("base.map_item.qinglan_board_5").is_empty())
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/map_inventory.json"))
	var catalog := MapInventoryCatalog.new()
	catalog.configure(config)
	catalog.replace_entries(model.storage_records())
	var ui := MapInventoryScreen.new()
	ui.configure(catalog, config, model.board, model)
	root.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.show()
	await settle()
	var capacity = ui.board_capacity
	var title: Control = ui.board_panel.find_child("BoardTitleArtwork", true, false)
	assert(capacity.texture.atlas.get_image().has_mipmaps())
	assert(capacity.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS)
	assert(capacity.size.y == title.size.y)
	assert(is_equal_approx(capacity.get_global_rect().get_center().y, title.get_global_rect().get_center().y))
	assert(ui.board_panel.get_global_rect().end.x - capacity.get_global_rect().end.x >= 16)
	assert(capacity.USED_COLOR == Color("b18b43") and capacity.TOTAL_COLOR == Color("1f3f3b"))
	assert(capacity.number_font.antialiasing == TextServer.FONT_ANTIALIASING_GRAY)
	assert(capacity.text == "0/30")
	var fixed_center: Vector2 = capacity.number_center()
	for entry: Dictionary in model.storage.entries():
		var item := registry.get_item(entry.item_id)
		if item.grid_size != Vector2i.ONE or item.category not in ["weapon", "armor"]: continue
		var cells := model.inventory.available_cells(item.id)
		if not cells.is_empty(): model.place(model.drag_data("storage", entry.instance_id), cells[0])
		if model.inventory.occupied_cells() == 9: break
	assert(capacity.text == "%d/30" % model.inventory.occupied_cells())
	# Values are also checked independently of which one-cell fixtures are available.
	capacity.set_capacity(9, 30)
	assert(capacity.text == "9/30" and capacity.number_center() == fixed_center)
	await settle()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var screenshot := root.get_texture().get_image()
		screenshot.save_png("res://artifacts/map-board-capacity.png")
		screenshot.get_region(Rect2i(ui.board_panel.global_position, Vector2i(ui.board_panel.get_global_rect().size.x, 130))).save_png("res://artifacts/map-board-capacity-heading.png")
	capacity.set_capacity(30, 30)
	assert(capacity.number_center() == fixed_center)
	assert(model.select_board("base.map_item.bag_board").is_empty())
	await settle()
	assert(capacity.text == "%d/9" % model.inventory.occupied_cells())
	ui.queue_free()
	await settle()
	print("CAPACITY ART: height/center, safe right inset, mipmaps, colors, fixed slash and live board capacity passed")
	quit()
