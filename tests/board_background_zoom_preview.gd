extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(2560,1440)
	var registry := ContentRegistry.new()
	assert(registry.load_base_content())
	var created := MapLoadoutStore.create_state(registry,registry.get_board("base.board.bag"))
	assert(created.error.is_empty())
	var model: MapLoadoutState = created.state
	assert(model.select_board("base.map_item.qinglan_board_5").is_empty())
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/map_inventory.json"))
	var catalog := MapInventoryCatalog.new()
	catalog.configure(config)
	catalog.replace_entries(model.storage_records())
	catalog.set_filter("category","board")
	var ui := MapInventoryScreen.new()
	ui.configure(catalog,config,model.board,model)
	root.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.show()
	for i in 8: await process_frame
	var background: TextureRect = ui.find_child("BoardPanelBackground",true,false)
	var atlas := background.texture as AtlasTexture
	var base_size := ui.board_panel.size + Vector2(11,5)
	var line_uv := (638.0-atlas.region.position.x)/atlas.region.size.x
	var line_before := -13.0 + base_size.x * line_uv
	var line_after := background.position.x + background.size.x * line_uv
	assert(is_equal_approx(line_after,line_before-0.5), "source line moves only 0.5px left despite zoom")
	assert(background.size.is_equal_approx(base_size*1.05), "background width and height +5 percent")
	assert(is_equal_approx(background.position.y+background.size.y*0.5,base_size.y*0.5), "vertical center retained")
	assert(model.board.display_scale == 1.0, "foreground board unchanged")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/board-background-line-zoom.png")
	ui.queue_free()
	for i in 8: await process_frame
	print("BOARD BACKGROUND: line -0.5px; size x1.05; vertical center and foreground preserved")
	quit()
