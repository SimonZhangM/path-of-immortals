extends SceneTree

func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for i in 8: await process_frame
func shot(path: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/"+path+".png")
func run() -> void:
	create_timer(30).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(2560,1440)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	for map_name in ["qingshihewan","qingshizhen"]:
		var map = load("res://scenes/maps/%s.tscn" % map_name).instantiate()
		map.inventory_save_path = ""
		map.defer_map_music = true
		root.add_child(map)
		map.set_process(false)
		await settle()
		assert(map.startup_error.is_empty())
		assert(not map.calendar_readout.is_visible_in_tree())
		var before: Dictionary = map.loadout.calendar.duplicate(true)
		var ui: MapInventoryScreen = map.inventory_screen
		ui.show()
		await settle()
		assert(map.calendar_readout.is_visible_in_tree())
		var board_font_size: int = ui.board_capacity.display_font_size()
		for used in [9,99,128]:
			ui.storage_capacity.set_capacity(used,99)
			assert(ui.storage_capacity.display_font_size() == board_font_size)
			assert(is_equal_approx(ui.storage_capacity.size.y,ui.board_capacity.size.y))
		await settle()
		if map_name == "qingshihewan":
			await shot("capacity-equal-font")
			ui.hide()
			var event: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_events/qingshihewan_rest_n13.json"))
			map.rest_dialog.present(event,true)
			await settle()
			var imported: Texture2D = map.rest_dialog.illustration.texture
			var original := Image.new()
			assert(original.load_webp_from_buffer(FileAccess.get_file_as_bytes(event.presentation.illustration)) == OK)
			assert(imported.resource_path == event.presentation.illustration)
			assert(imported.get_size() == Vector2(original.get_size()))
			assert(imported.get_image().has_mipmaps())
			assert(map.rest_dialog.illustration.texture_filter == CanvasItem.TEXTURE_FILTER_PARENT_NODE)
			assert(map.rest_dialog.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS)
			await shot("rest-n13-updated")
		assert(map.loadout.calendar == before)
		map.queue_free()
		await settle()
	print("MAP HEADER: both maps hide dates; unchanged calendar; capacity 9/99/128 shares board font size; updated rest picture size/path/mipmap passed. Static only, no mouse or real save.")
	quit()
