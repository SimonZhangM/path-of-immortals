extends SceneTree

func _initialize() -> void: run.call_deferred()
func run() -> void:
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
	assert(catalog.replace_entries(model.storage_records()).is_empty())
	catalog.set_filter("category", "board")
	var ui := MapInventoryScreen.new()
	ui.configure(catalog, config, model.board, model)
	root.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.show()
	for i in 8: await process_frame
	var title := ui.board_panel.find_child("BoardTitleArtwork", true, false) as TextureRect
	assert(title.texture.atlas.resource_path == "res://assets/UI-title-zhenpan.webp")
	assert(title.texture.atlas.get_image().has_mipmaps())
	assert(title.modulate == Color.WHITE and title.self_modulate == Color.WHITE)
	assert(title.position == Vector2(-10, -7))
	var storage_title := ui.find_child("StorageTitleArtwork", true, false) as TextureRect
	var attribute_title := ui.find_child("AttributesTitleArtwork", true, false) as TextureRect
	assert(storage_title.position == Vector2(-10, -7))
	assert(attribute_title.position == Vector2(0, -7))
	var gap := ui.find_child("StorageHeadingBottomGap", true, false) as MarginContainer
	assert(gap.get_theme_constant("margin_top") == 6)
	for key in ["armor", "shield"]:
		var icon := ui.find_child("BuffIcon_" + key, true, false) as TextureRect
		assert(icon.texture.resource_path == "res://assets/player-status-%s.webp" % ("armor" if key == "armor" else "sheild"))
		assert(icon.texture.get_image().has_mipmaps())
	assert(ui.find_child("AttributeLabel_shield", true, false).attribute_name == "灵盾")
	assert(ui.find_child("AttributeBottomRule", true, false) != null)
	var tabs := ui.find_child("CollectionTabs", true, false) as Control
	var well := ui.find_child("StorageItemWell", true, false) as Control
	var shifted_tabs := tabs.global_position
	var shifted_well := well.global_position
	var capacity_position := ui.storage_capacity.global_position
	gap.add_theme_constant_override("margin_top", 0)
	for i in 8: await process_frame
	var shift := 6 * ui.storage_toolbar.get_global_transform().y.length()
	assert(is_equal_approx(shifted_tabs.y - tabs.global_position.y, shift))
	assert(is_equal_approx(shifted_well.y - well.global_position.y, shift))
	assert(capacity_position.is_equal_approx(ui.storage_capacity.global_position))
	gap.add_theme_constant_override("margin_top", 6)
	for i in 8: await process_frame
	assert(ui.board_panel.find_child("SectionTitle", true, false) == null)
	assert(ui.board_capacity.text == "0/30")
	assert(is_equal_approx(ui.board_panel.size.y, 910))
	assert(ui.loadout_board.size.is_equal_approx(Vector2(821, 774.833333)))
	assert(title.get_global_rect().position.y > ui.board_panel.get_global_rect().position.y)
	var quick := ui.find_child("QuickFormationTitleArtwork", true, false) as TextureRect
	assert(quick.texture.atlas.resource_path == "res://assets/UI-title-kuaijiezhenxing.webp")
	assert(quick.texture.atlas.get_image().has_mipmaps())
	assert(quick.modulate == Color.WHITE and quick.self_modulate == Color.WHITE)
	assert(is_equal_approx(quick.global_position.x, attribute_title.global_position.x))
	assert(quick.global_position.y > ui.find_child("AttributeBottomRule", true, false).get_global_rect().end.y)
	assert(quick.get_global_rect().end.x < ui.sidebar.get_global_rect().end.x)
	assert(model.select_board("base.map_item.qinglan_board_4").is_empty())
	for i in 8: await process_frame
	var used := Rect2(MapItemArtwork.TextureMetrics.inspect(load(model.board.texture_path)).visible_rect)
	var art_center := ui.board_art.get_global_transform() * model.board.source_to_view(used.get_center(), ui.board_art.size)
	assert(art_center.is_equal_approx(ui.board_panel.get_global_rect().get_center() + ui.board_art.get_global_transform().x * 2.5))
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/map-board-title.png")
	ui.queue_free()
	for i in 8: await process_frame
	print("BOARD/STORAGE: existing layout, quick formation title/mipmaps/placement, Liuxia +2.5 offset passed")
	quit()
