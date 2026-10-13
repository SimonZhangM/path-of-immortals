extends SceneTree

func _initialize() -> void: run.call_deferred()

func run() -> void:
	root.size = Vector2i(2560, 1440)
	for level in range(1, 8):
		var path := "res://assets/levelbq-%d.webp" % level
		var source := Image.load_from_file(ProjectSettings.globalize_path(path))
		var partial := 0
		var opaque := 0
		for y in source.get_height():
			for x in source.get_width():
				var alpha := source.get_pixel(x, y).a
				if alpha > 0 and alpha < 1: partial += 1
				elif alpha == 1: opaque += 1
		var texture: Texture2D = load(path)
		var imported := texture.get_image()
		print("SOURCE %d size=%s partial_alpha=%d opaque=%d used=%s imported_mips=%d" % [level, source.get_size(), partial, opaque, source.get_used_rect(), imported.get_mipmap_count()])
	print("nearest_mipmap_filter=", ProjectSettings.get_setting("rendering/textures/default_filters/use_nearest_mipmap_filter"))
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
	for i in 8: await process_frame
	for card: MapInventoryItemCard in ui.grid.get_children():
		var badge := card.quality_badge
		print("CARD %s card_size=%s badge_global=%s screen_transform=%s filter=%d mipmaps=%s" % [card.entry.name, card.size, badge.get_global_rect(), badge.get_screen_transform(), badge.texture_filter, badge.texture.atlas.get_image().has_mipmaps()])
	ui.queue_free()
	await process_frame
	if DisplayServer.get_name() != "headless":
		var stage := ColorRect.new()
		stage.color = Color("10232d")
		stage.size = Vector2(2560, 1440)
		root.add_child(stage)
		for index in 2:
			var source: Texture2D = load("res://assets/levelbq-%d.webp" % (index + 1))
			var label := Label.new()
			label.text = "下品：原图及相同小尺寸" if index == 0 else "凡品：原图及相同小尺寸"
			label.position = Vector2(180 + index * 560, 45)
			stage.add_child(label)
			for small in 2:
				var view := TextureRect.new()
				var atlas := AtlasTexture.new()
				atlas.atlas = source
				atlas.region = source.get_image().get_used_rect()
				view.texture = atlas
				view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
				view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				view.position = Vector2(180 + index * 560, 100 if small == 0 else 560)
				view.size = atlas.get_size() if small == 0 else Vector2(38.8463, 38.8463 / atlas.get_size().aspect())
				stage.add_child(view)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/quality-badge-source-comparison.png")
		stage.queue_free()
		await process_frame
	quit()
