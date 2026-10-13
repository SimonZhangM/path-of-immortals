extends SceneTree

func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for i in 8: await process_frame

func run() -> void:
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(2560, 1440)
	var registry := ContentRegistry.new()
	assert(registry.load_base_content())
	var created := MapLoadoutStore.create_state(registry, registry.get_board("base.board.bag"))
	assert(created.error.is_empty())
	var model: MapLoadoutState = created.state
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/map_inventory.json"))
	var catalog := MapInventoryCatalog.new()
	catalog.configure(config)
	assert(catalog.replace_entries(model.storage_records()).is_empty())
	catalog.set_filter("category", "board")
	var ui := MapInventoryScreen.new()
	ui.configure(catalog, config, model.board, model)
	root.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.show()
	await settle()
	assert(is_equal_approx(ui.board_panel.size.y, 910.0))
	assert(is_equal_approx(ui.board_panel.get_global_rect().end.y, ui.storage_panel.get_global_rect().end.y))
	for panel in [ui.board_panel, ui.storage_panel, ui.sidebar]:
		var border := panel.find_child(str(panel.name) + "Border", true, false) as ColorRect
		assert(border.material.get_shader_parameter("line_width") == 2.0)
	var ids := ["base.map_item.bag_board"]
	for i in range(1, 7): ids.append("base.map_item.qinglan_board_%d" % i)
	var factors := [0.8, 0.8, 0.9, 0.9, 1.0, 1.0, 1.0]
	for i in ids.size():
		assert(model.select_board(ids[i]).is_empty())
		await settle()
		var art := ui.loadout_board
		var slot := art.get_parent() as Control
		var previous := slot.size - Vector2(0, ui.board_panel.size.y - MapInventoryScreen.MIDDLE_WIDTH)
		assert(art.size.is_equal_approx(previous * factors[i]))
		var visible := Rect2(MapItemArtwork.TextureMetrics.inspect(art._board_art.texture).visible_rect)
		var center := art.get_global_transform() * model.board.source_to_view(visible.get_center(), art.size)
		var x_offset := float(config.get("board_display_x_offsets", {}).get(model.board.id, 0.0))
		assert(center.is_equal_approx(ui.board_panel.get_global_rect().get_center() + art.get_global_transform().x * x_offset))
		assert(art._board_art.get_rect().is_equal_approx(model.board.art_rect(art.size)))
		print("MAP BOARD ", model.board.id, " scale=", factors[i], " size=", art.size)
		if i in [0, 3, 5] and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/map-board-size-%d.png" % i)
	for card in ui.grid.get_children():
		var expected := MapItemQuality.color(card.entry.quality)
		if card.entry.get("board_level") == "结丹": expected = Color("b65cde")
		if card.entry.get("board_level") == "元婴": expected = Color("ed8b28")
		assert(card.background.material.get_shader_parameter("line_color").is_equal_approx(expected))
		assert(card.frame.resource_path == MapItemQuality.background_path(card.entry.quality))
	ui.queue_free()
	await settle()
	print("MAP BOARD SIZE: panel alignment, seven scales, artwork mapping and card colors passed")
	quit()
