extends SceneTree

func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for i in 8: await process_frame
func shot(file: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/" + file + ".png")

func run() -> void:
	create_timer(40).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(2560, 1440)
	var registry := ContentRegistry.new()
	assert(registry.load_base_content())
	var created := MapLoadoutStore.create_state(registry, registry.get_board("base.board.bag"))
	assert(created.error.is_empty())
	var model: MapLoadoutState = created.state
	assert(model.select_board("base.map_item.qinglan_board_4").is_empty())
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/map_inventory.json"))
	var catalog := MapInventoryCatalog.new()
	catalog.configure(config)
	assert(catalog.replace_entries(model.storage_records()).is_empty())
	catalog.set_filter("category", "board")
	var map_ui := MapInventoryScreen.new()
	map_ui.configure(catalog, config, model.board, model)
	root.add_child(map_ui)
	map_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_ui.show()
	await settle()
	for node_name in ["StorageTitleArtwork", "AttributesTitleArtwork"]:
		var art := map_ui.find_child(node_name, true, false) as TextureRect
		assert(art != null and art.texture.atlas.get_image().has_mipmaps())
		assert(art.modulate == Color.WHITE and is_equal_approx(art.size.y, 50))
	var visible := Rect2(MapItemArtwork.TextureMetrics.inspect(load(model.board.texture_path)).visible_rect)
	var center := map_ui.board_art.get_global_transform() * model.board.source_to_view(visible.get_center(), map_ui.board_art.size)
	var expected := map_ui.board_panel.get_global_rect().get_center() + Vector2(2.5 * map_ui.board_art.get_global_transform().x.length(), 0)
	assert(center.is_equal_approx(expected))
	await shot("ui-new-titles-liuxia")
	map_ui.queue_free()
	await settle()
	var scene = load("res://scenes/main/main.tscn").instantiate()
	var game: GameManager = scene.get_node("GameManager")
	game.use_saved_loadout = true
	game.loadout_save_path = ""
	game.enemy_id = "base.enemy.chisong_liaozhu"
	root.add_child(scene)
	game.set_process(false)
	assert(game.startup_error.is_empty())
	var ui = scene.get_node("MainUI")
	await settle()
	assert(ui._time.get_theme_font_size("font_size") == 38)
	for panel in [ui.ally_panel, ui.enemy_panel]:
		assert(is_equal_approx(panel.position.y, -7.5))
	assert(is_equal_approx(ui.ally_panel.cards[0].global_position.y, 211.6666667))
	await shot("ui-battle-groups-up")
	for rank: String in ui.victory_banner.paths:
		ui.victory_banner.present(rank)
		assert(ui.victory_banner.artwork.size.is_equal_approx(ui.size * Vector2(0.66, 0.51)))
	await shot("ui-victory-enlarged")
	ui.victory_banner.reset()
	var records: Array[Dictionary] = []
	for record: Dictionary in model.storage_records():
		if record.category == "board": records.append(record)
	var rewards = ui.victory_rewards
	for count in [1, 2, 3, 5]:
		rewards.present_loot(records.slice(0, count), config.categories)
		await settle()
		var grid: GridContainer = rewards.grid
		var scroll: ScrollContainer = rewards.scroll
		assert(grid.columns == mini(count, 3))
		if count <= 3:
			assert(grid.get_global_rect().get_center().distance_to(scroll.get_global_rect().get_center()) < 2)
			assert(is_equal_approx(grid.get_child(0).size.x, 120))
			if count > 1:
				assert(is_equal_approx(grid.get_child(1).position.x - grid.get_child(0).get_rect().end.x, 16))
		else:
			assert(scroll.get_v_scroll_bar().max_value > scroll.size.y)
			scroll.scroll_vertical = 9999
			await settle()
			assert(grid.get_child(4).get_global_rect().end.y < scroll.get_global_rect().end.y)
		await shot("ui-rewards-%d" % count)
	scene.queue_free()
	await settle()
	await create_timer(0.2).timeout
	print("UI LAYOUT: titles/mipmaps, Liuxia offset, battle groups, timer, six banners, centered loot and scroll passed")
	quit()
