extends SceneTree

const SAVE := "res://artifacts/item-variants-test.json"
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _clear_save() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(SAVE + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))

func _run() -> void:
	_clear_save()
	var records: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/inventory_items.json"))
	var by_id := {}
	for record: Dictionary in records:
		by_id[record.id] = record
	_check(records.size() == 10 and by_id.size() == 10, "six original items and four support items")
	for base: Dictionary in records.slice(0, 6):
		for suffix in ["a", "b", "c"]:
			_check(not by_id.has(base.id + "_" + suffix), "retired variant removed: " + base.name + suffix)
	var registry := ContentRegistry.new()
	registry.load_base_content()
	var state: MapLoadoutState = MapLoadoutStore.create_state(registry, registry.get_board("base.board.bag")).state
	_check(state != null and state.storage.entries().size() == 10, "live storage contains ten independent items")
	var original_id := "owned.base.map_item.qingshi_short_sword.0"
	var new_id := "owned.base.map_item.warm_jade.0"
	var retired := {"instance_id": "owned.base.map_item.qingshi_short_sword_a.0", "item_id": "base.map_item.qingshi_short_sword_a", "cell": [1, 0]}
	var old_save := {"version": 1, "board_id": "base.board.bag", "placements": [{"instance_id": original_id, "item_id": "base.map_item.qingshi_short_sword", "cell": [0, 0]}, retired]}
	old_save.formations = [{"id": "old-layout", "name": "旧阵型", "icon": state.formation_icons[0], "layout": {"placements": old_save.placements.duplicate(true)}}]
	_check(state.restore(old_save).is_empty() and state.inventory.get_instance(original_id).cell == Vector2i.ZERO and state.storage.entries().size() == 9, "legacy save preserves original and drops retired equipped variant")
	_check(state.apply_formation("old-layout").is_empty() and state.inventory.item_at(Vector2i(1, 0)).is_empty(), "retired formation placement remains empty")
	_check(state.place(state.drag_data("storage", new_id), Vector2i(1, 0)) and state.inventory.get_instances().size() == 2 and state.storage.entries().size() == 8, "new artifact equips alongside original")
	_check(registry.get_item("base.map_item.warm_jade").effects == by_id["base.map_item.warm_jade"].effects, "battle uses canonical effects")
	state.save_formation("辅助记录", state.formation_icons[0])
	_check(MapLoadoutStore.save(state, SAVE).is_empty(), "new items persist through existing store")
	var reload_registry := ContentRegistry.new()
	reload_registry.load_base_content()
	var restored: MapLoadoutState = MapLoadoutStore.create_state(reload_registry, reload_registry.get_board("base.board.bag")).state
	_check(MapLoadoutStore.load_into(restored, SAVE).is_empty() and restored.snapshot() == state.snapshot(), "new item IDs and formation positions survive reload")
	root.size = Vector2i(1920, 1080)
	var map = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path = ""
	root.add_child(map)
	map.set_inventory_open(true)
	for i in 8:
		await process_frame
	var panel: MapInventoryScreen = map.inventory_screen
	_check(panel.grid.get_child_count() == 10 and panel._collections.all.text == "全部 10", "actual UI shows ten owned cards and count")
	_check(panel.body.position.x == 23 and panel.body.size.x == 1874 and panel.body.get_theme_constant("separation") == 19 and panel.storage_panel.size == Vector2(910, 910), "storage panel is square910x910 after reducing both outer margins and both column gaps1px")
	var storage_background := panel.storage_panel.get_node("StorageBackgroundLayer/StoragePanelBackground") as TextureRect
	var storage_texture := storage_background.texture as AtlasTexture
	var storage_style := panel.storage_panel.get_theme_stylebox("panel") as StyleBoxFlat
	var storage_item_well := panel.storage_panel.find_child("StorageItemWell", true, false) as PanelContainer
	var storage_item_well_style := storage_item_well.get_theme_stylebox("panel") as StyleBoxFlat
	var storage_toolbar_margin := panel.storage_panel.find_child("StorageToolbarMargin", true, false) as MarginContainer
	_check(storage_texture.atlas.resource_path == "res://assets/inv-bg-3.webp" and storage_texture.region == panel.STORAGE_BACKGROUND_REGION, "storage panel uses the authored inv-bg-3 painted region")
	var expected_storage_background_size := panel.storage_panel.size * panel.STORAGE_BACKGROUND_SCALE
	var expected_storage_background_position := (panel.storage_panel.size - expected_storage_background_size) * 0.5 + Vector2(panel.STORAGE_BACKGROUND_X_SHIFT, panel.STORAGE_BACKGROUND_Y_SHIFT)
	_check(storage_background.position.is_equal_approx(expected_storage_background_position) and storage_background.size.is_equal_approx(expected_storage_background_size) and is_equal_approx(storage_background.self_modulate.a, 0.5) and storage_background.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "storage background applies the cumulative1.0404 scale then shifts right2px and down2px at fifty-percent opacity")
	var storage_border := panel.storage_panel.find_child("StoragePanelBorder", true, false) as ColorRect
	var sidebar_border := panel.sidebar.find_child("InformationPanelBorder", true, false) as ColorRect
	var sidebar_style := panel.sidebar.get_theme_stylebox("panel") as StyleBoxFlat
	var storage_border_material := storage_border.material as ShaderMaterial
	var sidebar_border_material := sidebar_border.material as ShaderMaterial
	_check(storage_border != null and storage_style.border_width_left == 0 and storage_style.corner_radius_top_left == int(panel.BOARD_PANEL_RADIUS), "storage panel uses the board panel radius and restores its shader border")
	_check(storage_border_material.get_shader_parameter("line_width") == sidebar_border_material.get_shader_parameter("line_width") and storage_border_material.get_shader_parameter("line_color") == panel.STORAGE_BORDER_COLOR, "storage border keeps the sidebar line width and uses the requested806d48 color")
	_check(panel.search.custom_minimum_size.x == panel.STORAGE_SEARCH_WIDTH and storage_item_well_style.bg_color.a == 0.0, "storage search is narrower and the item display well is transparent")
	var board_title_icon := panel.board_panel.find_child("SectionTitleIcon", true, false) as TextureRect
	var storage_title_icon := panel.storage_panel.find_child("SectionTitleIcon", true, false) as TextureRect
	var board_icon_visual_left := board_title_icon.global_position.x - panel.board_panel.global_position.x
	var storage_icon_visual_left := storage_title_icon.global_position.x - panel.storage_panel.global_position.x - panel.STORAGE_TITLE_ICON_X_OFFSET
	_check(is_equal_approx(board_icon_visual_left, panel.STORAGE_CONTENT_INSET) and is_equal_approx(storage_icon_visual_left, board_icon_visual_left), "storage title artwork has the same visual left inset as the board title artwork")
	_check(storage_toolbar_margin.get_theme_constant("margin_left") == panel.STORAGE_CONTENT_INSET and storage_toolbar_margin.get_theme_constant("margin_right") == panel.STORAGE_CONTENT_INSET and storage_item_well_style.content_margin_left == panel.STORAGE_CONTENT_INSET and storage_item_well_style.content_margin_right == panel.STORAGE_CONTENT_INSET, "storage rows and cards use equal left and right panel insets matching the title artwork")
	var collection_tabs := panel.storage_panel.find_child("CollectionTabs", true, false) as HBoxContainer
	var category_filters := panel.storage_panel.find_child("CategoryFilters", true, false) as HFlowContainer
	_check(collection_tabs.get_child_count() == panel._collections.size() and collection_tabs.get_theme_constant("separation") == 8 and category_filters.get_child_count() == panel._categories.size() and category_filters.get_theme_constant("h_separation") == 5, "collection and category rows restore their compact pre-justified layout")
	var formation_background := panel.formation_panel.get_node("FormationBackgroundLayer/FormationPanelBackground") as TextureRect
	var formation_texture := formation_background.texture as AtlasTexture
	var formation_style := panel.formation_panel.get_theme_stylebox("panel") as StyleBoxFlat
	var expected_formation_region_size: Vector2 = panel.FORMATION_BACKGROUND_REGION.size / panel.FORMATION_BACKGROUND_CONTENT_SCALE
	expected_formation_region_size.x /= panel.FORMATION_BACKGROUND_HORIZONTAL_SCALE
	var expected_formation_region := Rect2(panel.FORMATION_BACKGROUND_REGION.get_center() - expected_formation_region_size * 0.5, expected_formation_region_size)
	_check(formation_texture.atlas.resource_path == "res://assets/inv-bg-1.webp" and formation_texture.region.is_equal_approx(expected_formation_region), "formation panel enlarges the authored inv-bg-1 painted region1% about its center")
	_check(formation_background.position == Vector2(-1, 0) and formation_background.size == panel.formation_panel.size + Vector2(1, 0) and is_equal_approx(formation_background.self_modulate.a, 0.5) and formation_background.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "formation background extends only its left edge1px at fifty-percent opacity")
	_check(is_equal_approx(panel.FORMATION_BACKGROUND_HORIZONTAL_SCALE, 714.0 / 718.0), "formation artwork compresses horizontally by2px per side while retaining its full height")
	_check(panel.formation_panel.find_child("FormationPanelBorder", true, false) == null and formation_style.border_width_left == 0, "formation panel removes its procedural gold border")
	_check(formation_style.corner_radius_top_left == int(panel.BOARD_PANEL_RADIUS), "formation panel radius matches the board panel radius")
	var board_background := panel.board_panel.get_node("BoardBackdropLayer/BoardPanelBackground") as TextureRect
	var board_style := panel.board_panel.get_theme_stylebox("panel") as StyleBoxFlat
	_check(sidebar_style.bg_color.a == 0.0 and board_style.bg_color.a == 0.0 and formation_style.bg_color.a == 0.0 and storage_style.bg_color.a == 0.0, "all four main panels remove their opaque dark backing fills")
	_check(is_equal_approx(panel.BOARD_PANEL_RADIUS, 13.0) and board_style.corner_radius_top_left == 13, "board panel uses the requested13px rounded corners")
	_check(is_equal_approx(panel.BOARD_BACKGROUND_CONTENT_SCALE, 0.970299) and is_equal_approx(board_background.self_modulate.a, 0.5), "board background restores its previous content scale and fifty-percent opacity")
	_check(board_background.position == Vector2(-7, 0) and board_background.size == panel.board_panel.size + Vector2(11, 5), "board background restores its previous geometry")
	var formation_card := panel.custom_formation_card
	var formation_icon_slot := formation_card.find_child("FormationIconSlot", true, false) as Control
	var icon_offset := formation_icon_slot.get_global_rect().position - formation_card.get_global_rect().position
	_check(formation_card.size == panel.FORMATION_CARD_SIZE and formation_icon_slot.size == panel.FORMATION_ICON_SIZE and icon_offset.is_equal_approx(Vector2(7, 7)), "formation icon has equal7px left/right/top spacing inside its card")
	_check(formation_card.get_theme_stylebox("normal") is StyleBoxEmpty and formation_card.get_theme_stylebox("hover") is StyleBoxEmpty and formation_card.get_theme_stylebox("pressed") is StyleBoxEmpty, "formation cards have no button border or interior fill in every visible state")
	_check(panel.formation_name_input.get_theme_font_size("font_size") == 17 and panel.formation_replace_layout.get_theme_font_size("font_size") == 17, "formation name placeholder matches the layout-option font size")
	var unchecked_icon := panel.formation_replace_layout.get_theme_icon("unchecked")
	var checked_icon := panel.formation_replace_layout.get_theme_icon("checked")
	_check(unchecked_icon != null and checked_icon != null and unchecked_icon.get_size() == checked_icon.get_size() and unchecked_icon.get_image().get_data() != checked_icon.get_image().get_data(), "unchecked layout option retains its square while only the check mark changes")
	var first: Control = panel.grid.get_child(0)
	var second: Control = panel.grid.get_child(1)
	var seventh: Control = panel.grid.get_child(6)
	var last: Control = panel.grid.get_child(9)
	_check(panel.grid.columns == 6 and last.size.is_equal_approx(first.size) and is_equal_approx(last.position.y, first.size.y + panel.STORAGE_CARD_ROW_GAP), "ten cards occupy two fixed-size rows of six")
	_check(is_equal_approx(second.position.x - first.get_rect().end.x, panel.STORAGE_CARD_GAP) and is_equal_approx(seventh.position.y - first.get_rect().end.y, panel.STORAGE_CARD_ROW_GAP), "card row layout gap compensates for the frame artwork's top inset")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/inventory_10_items.png")
		var scroll := panel.grid.get_parent() as ScrollContainer
		scroll.scroll_vertical = 10000
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/inventory_10_items_bottom.png")
		panel._open_formation_dialog()
		for i in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/formation_layout_checked.png")
		panel.formation_replace_layout.button_pressed = false
		for i in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/formation_layout_unchecked.png")
	map.queue_free()
	for i in 3:
		await process_frame
	_clear_save()
	print("ITEM VARIANTS RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
