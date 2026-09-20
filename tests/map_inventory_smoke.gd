extends SceneTree

var checks := 0
var failures := 0
var screen: Control
const MIPMAPPED_TEST_ICON := "res://assets/weapon-qsdj.webp"

func _initialize() -> void:
	call_deferred("_run")

func _fixtures() -> Array:
	return [
		{"id": "test.a", "name": "回春丹", "category": "pill", "quality": "凡品", "acquired_at": 10, "quantity": 2, "favorite": true, "recipe": true, "icon": MIPMAPPED_TEST_ICON},
		{"id": "test.b", "name": "测试灵药", "category": "pill", "quality": "灵品", "acquired_at": 30, "quantity": 1, "common": true, "enhancement_level": 2, "icon": MIPMAPPED_TEST_ICON},
		{"id": "test.c", "name": "测试铁甲", "category": "armor", "quality": "凡品", "acquired_at": 30, "quantity": 1, "enhancement_level": 10, "icon": MIPMAPPED_TEST_ICON},
		{"id": "test.d", "name": "测试草药", "category": "plant", "quality": "凡品", "acquired_at": 20, "quantity": 3, "favorite": true, "enhancement_level": 2, "icon": MIPMAPPED_TEST_ICON}
	]

func _ids(model: MapInventoryCatalog) -> Array:
	return model.visible_entries().map(func(entry: Dictionary): return entry.id)

func _check_catalog() -> void:
	var model := MapInventoryCatalog.new()
	model.configure(JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/map_inventory.json")))
	_check(model.total_count() == 0, "new map storage has no battle fixture items")
	_check(model.replace_entries(_fixtures()).is_empty(), "valid content accepted")
	_check(_ids(model) == ["test.b", "test.c", "test.d", "test.a"], "time descending with stable tie ordering")
	model.set_newest_first(false)
	_check(_ids(model) == ["test.a", "test.d", "test.b", "test.c"], "time ascending with stable tie ordering")
	model.set_newest_first(true)
	model.set_level_descending(true)
	_check(_ids(model) == ["test.c", "test.b", "test.d", "test.a"], "level descending compares numbers, with acquisition tie break and missing level zero")
	model.set_level_descending(false)
	_check(_ids(model) == ["test.a", "test.b", "test.d", "test.c"], "level ascending retains acquisition tie break")
	model.set_filter("collection", "consumable")
	model.set_filter("category", "pill")
	model.set_filter("quality", "凡品")
	model.set_filter("collection", "favorite")
	model.set_filter("search", "  回春  ")
	_check(_ids(model) == ["test.a"], "category quality collection and search intersect")
	model.set_filter("collection", "equipment")
	_check(model.visible_entries().is_empty(), "incompatible filters produce empty result")
	model.reset_filters()
	_check(model.newest_first and model.quality.is_empty() and model.visible_entries().size() == 4, "reset restores all filters and default order")
	model.set_filter("collection", "material")
	_check(_ids(model) == ["test.d"], "material tab filters materials")
	model.set_filter("collection", "blueprint")
	_check(_ids(model).is_empty(), "legacy recipe tag does not classify a pill as a blueprint")
	model.set_filter("collection", "material")
	_check(model.collection_count("favorite") == 2 and model.collection_count("equipment") == 1, "collection badges reflect independent totals")
	var copies := model.visible_entries()
	copies[0].name = "changed"
	_check(model.visible_entries()[0].name == "测试草药", "results cannot mutate catalog")
	for invalid in [[_fixtures()[0], _fixtures()[0]], [{"id": "bad"}]]:
		_check(not model.replace_entries(invalid).is_empty() and model.total_count() == 4, "invalid data leaves previous catalog intact")
	var invalid_time := _fixtures()
	invalid_time[0].acquired_at = -1
	_check(not model.replace_entries(invalid_time).is_empty(), "acquisition sequence must be nonnegative")
	var invalid_count := _fixtures()
	invalid_count[0].quantity = 0
	_check(not model.replace_entries(invalid_count).is_empty(), "zero-count entries rejected")
	for invalid_level: Variant in [-1, 0.5, "2"]:
		var invalid_entries := _fixtures()
		invalid_entries[0].enhancement_level = invalid_level
		_check(not model.replace_entries(invalid_entries).is_empty() and model.total_count() == 4, "invalid enhancement level rejected without replacing contents")
	var invalid_outline := _fixtures()
	invalid_outline[0].art_outline_px = 0
	_check(not model.replace_entries(invalid_outline).is_empty() and model.total_count() == 4, "artwork outline must be a positive integer")
	var missing_mipmap := _fixtures()
	missing_mipmap[0].icon = "res://assets/level-fanpin.webp"
	_check(not model.replace_entries(missing_mipmap).is_empty() and model.total_count() == 4, "future item artwork without mipmaps is rejected")
	model.reset_filters()
	model.set_filter("category", "not_a_category")
	_check(model.category == "all", "unknown filter rejected")
	model.set_filter("quality", "灵品")
	model.replace_entries([])
	_check(model.quality.is_empty(), "removed quality selection resets safely")

func _run() -> void:
	_check_catalog()
	root.size = Vector2i(1920, 1080)
	MapEventState.session_completed.clear()
	screen = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	screen.inventory_save_path = ""
	root.add_child(screen)
	await _settle()
	screen.set_process(false)
	_check(screen.startup_error.is_empty() and not screen.is_inventory_open(), "map opens normally with inventory hidden")
	var panel: MapInventoryScreen = screen.inventory_screen
	var header: MapStatusHeader = screen.status_header
	var header_rect := header.get_global_rect()
	var state_before: Dictionary = screen.player_status.resources.duplicate()
	# Use the stable point ID from the scene, independent of display/node naming.
	screen.travel.request_destination(screen.content.get_node("Points/N37").point_id)
	_key(KEY_I)
	await _settle()
	_check(screen.is_inventory_open() and panel.is_visible_in_tree(), "I opens map inventory through actual keyboard input")
	_check(header.is_visible_in_tree() and header.z_index > panel.z_index and header.get_global_rect() == header_rect, "same Head stays visible at same position")
	_check(not header.map_title.visible, "map location plaque hidden in inventory")
	_check(panel.board_art.texture.resource_path == "res://assets/zhenpan-bag.webp", "map displays new bag board")
	_check(panel.grid.get_child_count() == 10 and not panel.empty_state.visible, "six original items and four support items appear in storage")
	var expected := {"青石短剑": ["斩击", 7, 3.5, 3], "猎弓": ["穿刺", 9, 4.5, 5], "短柄铁锤": ["钝击", 8, 4.0, 4]}
	for card: MapInventoryItemCard in panel.grid.get_children():
		var base_name := String(card.entry.name).trim_suffix('a').trim_suffix('b').trim_suffix('c')
		var art := card.canvas.get_node("ItemArtwork") as TextureRect
		var outline := art.get_node_or_null("ItemOutline")
		_check(FileAccess.file_exists(card.entry.icon) and art.texture is AtlasTexture and art.texture.atlas.resource_path == card.entry.icon and art.texture.atlas.get_image().has_mipmaps() and art.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED and art.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "item source exists, has mipmaps, preserves source aspect and uses linear mipmap filtering")
		_check(card.entry.art_outline_px == 1 and outline != null and outline.get_child_count() == 16 and outline.z_index == 0 and (outline.get_child(0) as TextureRect).self_modulate == MapItemArtwork.OUTLINE_COLOR, "all items use the shared softened one-pixel outline above static backgrounds")
		if card.entry.category == "armor":
			var armor_values: Array = {"粗布甲": [2, 4.0, 3, 7], "旧铁盔": [1, 5.0, 1, 2], "木圆盾": [2, 5.0, 3, 2]}[base_name]
			_check(card.entry.quality == "下品" and card.entry.footprint_columns == 1 and card.entry.footprint_rows == armor_values[0] and card.entry.cooldown == armor_values[1] and card.entry.armor_gain == armor_values[2] and card.entry.armor_capacity == armor_values[3], "armor dimensions and effects match authored values")
			_check(card.entry.has("armor_type") == (base_name == "粗布甲") and ItemTooltip.effect_text(panel.loadout.registry.get_item(card.entry.id)).contains("护甲上限"), "only body armor has a type; tooltip contains armor effects")
			continue
		if card.entry.category != "weapon":
			continue
		_check(card.entry.enhancement_level == 0, "authored weapons have zero enhancement level")
		var values: Array = expected[base_name]
		_check(card.entry.damage_type == values[0] and int(card.entry.base_damage) == values[1] and is_equal_approx(card.entry.cooldown, values[2]) and int(card.entry.base_stamina_cost) == values[3], "authored weapon values match user table")
		_check(card.frame.resource_path == "res://assets/level-fanpin.webp" and card.entry.quality == "下品", "each weapon has lower quality while retaining current frame asset")
		var tags: Array[String] = []
		for tag: Label in card.canvas.get_node("CategoryTags").get_children():
			tags.append(tag.text)
		_check(tags == ["武器", card.entry.subcategory, card.entry.damage_type], "weapon card shows category, weapon kind and damage type as three labels")
		_check(card.footprint_cells.size() == 2 and card.footprint_cells[0].position.x == card.footprint_cells[1].position.x and card.footprint_cells[0].position.y < card.footprint_cells[1].position.y, "one column two rows shown vertically at top right")
		var description := ItemTooltip.effect_text(panel.loadout.registry.get_item(card.entry.id))
		_check(description.contains("伤害") and description.contains("冷却") and description.contains("耗费"), "all weapon attributes available on hover")
	var position_before: Vector2 = screen.travel.map_position
	var camera_before: Vector2 = screen.content.position
	var zoom_before: float = screen.zoom_factor
	var destination_before: String = screen.travel.destination_id
	screen._process(10.0)
	_check(screen.travel.map_position == position_before and not screen.player.is_playing(), "opening pauses movement and sprite playback")
	_mouse(MOUSE_BUTTON_LEFT, true, Vector2(700, 700))
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(900, 730)
	motion.relative = Vector2(200, 30)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion, true)
	_mouse(MOUSE_BUTTON_LEFT, false, motion.position)
	_mouse(MOUSE_BUTTON_WHEEL_UP, true, Vector2(900, 700))
	_check(screen.content.position == camera_before and screen.zoom_factor == zoom_before and screen.travel.destination_id == destination_before, "inventory clicks drags and wheel do not leak to map")
	_key(KEY_I, true)
	_check(screen.is_inventory_open(), "key repeat never toggles repeatedly")
	var original_art_button_offset := (panel.return_button.global_position - panel.sidebar_art.global_position) / panel.stage.scale
	for dimensions in [Vector2i(1920, 1080), Vector2i(1280, 800), Vector2i(1280, 720), Vector2i(2560, 1080)]:
		root.size = dimensions
		await _settle()
		var bounds := Rect2(Vector2.ZERO, screen.size)
		var art_button_offset := (panel.return_button.global_position - panel.sidebar_art.global_position) / panel.stage.scale
		_check(art_button_offset.is_equal_approx(original_art_button_offset), "background and return button retain scaled relative position " + str(dimensions))
		for region in [panel.sidebar, panel.board_panel, panel.formation_panel, panel.storage_panel]:
			_check(bounds.encloses(region.get_global_rect()), "panel inside viewport " + str(dimensions))
		var board_rect := panel.board_panel.get_global_rect()
		var formation_rect := panel.formation_panel.get_global_rect()
		var storage_rect := panel.storage_panel.get_global_rect()
		_check(is_equal_approx(board_rect.size.x, board_rect.size.y), "bag outer panel remains square " + str(dimensions))
		_check(is_equal_approx(board_rect.position.x, formation_rect.position.x) and is_equal_approx(board_rect.size.x, formation_rect.size.x), "array and formation share column and width")
		_check(is_equal_approx(storage_rect.position.x, board_rect.end.x + panel.BODY_COLUMN_GAP * panel.stage.scale.x), "storage expands left up to the fixed column gap " + str(dimensions))
		_check(not panel.board_panel.get_global_rect().intersects(panel.formation_panel.get_global_rect()) and not panel.board_panel.get_global_rect().intersects(panel.storage_panel.get_global_rect()), "main regions do not overlap")
		await _capture("map_inventory_%dx%d" % [dimensions.x, dimensions.y])
	root.size = Vector2i(1920, 1080)
	await _settle()
	_check(panel.board_panel.position.x == 0.0 and is_equal_approx(panel.board_panel.global_position.x, 250.0), "bag left edge follows the current 1920 design position")
	_check(panel.board_panel.size.is_equal_approx(Vector2(718, 718)) and is_equal_approx(panel.formation_panel.size.x, 718.0), "bag is 718 square and formation follows its width")
	_check(is_equal_approx(panel.storage_panel.global_position.x, 987.0) and is_equal_approx(panel.storage_panel.get_global_rect().end.x, 1897.0), "storage is a910px square within the current side margins")
	var board_background := panel.board_panel.get_node("BoardBackdropLayer/BoardPanelBackground") as TextureRect
	var board_background_atlas := board_background.texture as AtlasTexture
	var expected_board_inset := Vector2.ONE * panel.BOARD_BACKGROUND_BORDER_INSET
	var expected_base_region_size := board_background_atlas.atlas.get_size() - expected_board_inset * 2.0
	var expected_top_reference_size := expected_base_region_size / panel.BOARD_BACKGROUND_TOP_REFERENCE_SCALE
	var expected_scaled_region_size := expected_base_region_size / panel.BOARD_BACKGROUND_CONTENT_SCALE
	var expected_board_region := Rect2(
		Vector2(
			(board_background_atlas.atlas.get_size().x - expected_scaled_region_size.x) * 0.5,
			(board_background_atlas.atlas.get_size().y - expected_top_reference_size.y) * 0.5
		),
		expected_scaled_region_size
	)
	var board_panel_style := panel.board_panel.get_theme_stylebox("panel") as StyleBoxFlat
	_check(board_background_atlas.atlas.resource_path == "res://assets/inv-bg-2.webp" and board_background_atlas.region == expected_board_region, "board panel uses the requested cumulative content scale while preserving the previous top sample")
	_check(board_background.position == Vector2(-7, 0) and board_background.size == panel.board_panel.size + Vector2(11, panel.BOARD_BACKGROUND_BOTTOM_EXTENSION), "board background restores the previous shifted and extended geometry")
	_check(is_equal_approx(board_background.self_modulate.a, 0.5), "board background restores fifty-percent opacity")
	_check(panel.board_panel.find_child("BoardPanelBorder", true, false) == null and board_panel_style.border_width_left == 0 and board_panel_style.corner_radius_top_left == int(panel.BOARD_PANEL_RADIUS), "board panel removes the procedural gold rim and uses the reduced corner radius")
	_check(panel.board_capacity_caption.get_theme_font("font") == panel.board_capacity.get_theme_font("font") and panel.board_capacity_caption.get_theme_color("font_color") == Color("c5d0d2"), "capacity caption and value share one font while the Chinese caption stays clearly brighter")
	var heading_specs := [
		[panel.sidebar, "属性加成", "res://assets/title-zpsxjc.webp"],
		[panel.board_panel, "阵盘", "res://assets/title-zhenpan.webp"],
		[panel.storage_panel, "储物袋", "res://assets/title-chuwudai.webp"],
	]
	for spec: Array in heading_specs:
		var heading_row := (spec[0] as Control).find_child("SectionHeading", true, false) as HBoxContainer
		var heading_icon := heading_row.find_child("SectionTitleIcon", true, false) as TextureRect
		var heading_title := heading_row.get_node("SectionTitle") as Label
		_check(heading_title.text == spec[1] and heading_title.get_theme_font_size("font_size") == 26 and heading_icon.custom_minimum_size == Vector2(26, 26), "%s heading uses a same-size title icon" % spec[1])
		_check(heading_icon.texture.resource_path == spec[2] and heading_icon.texture.get_image().has_mipmaps() and heading_icon.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "%s heading uses its mipmapped authored icon" % spec[1])
	var motto_found := false
	for sidebar_label: Label in panel.sidebar.find_children("*", "Label", true, false):
		if sidebar_label.text == "天地灵物，纳于一盘":
			motto_found = true
	_check(panel.bag_caption.text == "属性加成" and motto_found, "sidebar copy reads 属性加成 and 天地灵物，纳于一盘")
	_check(panel.board_bonus_values.hp.text == "+5" and panel.board_bonus_values.stamina.text == "+5" and panel.board_bonus_values.spirit.text == "+0", "sidebar reads all three bonuses from equipped board including zero")
	var hp_row := panel.board_bonus_values.hp.get_parent().get_parent() as HBoxContainer
	var hp_icon := hp_row.find_child("BoardBonusIcon_hp", true, false) as TextureRect
	var hp_caption := hp_row.find_child("AttributeCaption", true, false) as Label
	_check(hp_icon != null and hp_caption.text == "气血" and is_equal_approx(panel.board_bonus_values.hp.global_position.x, panel.board_bonus_values.spirit.global_position.x), "sidebar shows existing resource icons and labels with an aligned bonus column")
	var bonus_icon_paths := ["res://assets/player-status-health.webp", "res://assets/player-status-stamina.webp", "res://assets/player-status-spirit.webp"]
	var bonus_rows := (panel.sidebar.find_child("BoardResourceBonuses", true, false) as VBoxContainer).get_children()
	var shared_icon_canvas: Vector2 = (load(bonus_icon_paths[0]) as Texture2D).get_size()
	for index in bonus_icon_paths.size():
		var bonus_icon := bonus_rows[index].find_child("BoardBonusIcon_" + ["hp", "stamina", "spirit"][index], true, false) as TextureRect
		var uses_shared_canvas := false
		if index == 0 and bonus_icon.texture is AtlasTexture:
			var health_atlas := bonus_icon.texture as AtlasTexture
			var expected_size := shared_icon_canvas / panel.BOARD_HEALTH_ICON_SCALE
			uses_shared_canvas = health_atlas.atlas.resource_path == bonus_icon_paths[index] and health_atlas.region.size.is_equal_approx(expected_size) and health_atlas.region.position.is_equal_approx((shared_icon_canvas - expected_size) * 0.5)
		else:
			uses_shared_canvas = bonus_icon.texture.resource_path == bonus_icon_paths[index] and not bonus_icon.texture is AtlasTexture and bonus_icon.texture.get_size() == shared_icon_canvas
		_check(uses_shared_canvas and bonus_icon.custom_minimum_size == Vector2(27, 27), "board resource icon %d keeps the shared authored canvas with only the centered heart optical scale" % index)
	_check(panel._collections.keys() == ["all", "favorite", "equipment", "consumable", "material", "blueprint", "key", "misc"] and panel._collections.all.text == "全部 10", "primary categories follow the requested order")
	_check(panel._categories.has("artifact") and panel._categories.has("board") and panel._categories.has("bait") and panel._categories.plant.text == "草木", "subcategories cover the authored taxonomy")
	var collection_selected := panel._collections.all.get_theme_stylebox("pressed") as StyleBoxFlat
	var category_selected := panel._categories.weapon.get_theme_stylebox("pressed") as StyleBoxFlat
	var category_normal := panel._categories.weapon.get_theme_stylebox("normal") as StyleBoxFlat
	_check(collection_selected.border_width_left == 2 and collection_selected.border_color == panel.COLLECTION_SELECTED_BORDER and collection_selected.shadow_size >= 4 and panel._collections.all.get_theme_color("font_pressed_color") == Color("ffe49a"), "selected collection uses the gold bordered glow treatment")
	_check(category_selected.border_width_left == 2 and category_selected.border_color == panel.CATEGORY_SELECTED_BORDER and category_selected.shadow_size >= 4 and category_normal.border_width_left == 1, "selected category uses the blue glow while idle categories retain fine frames")
	var first_card: Control = panel.grid.get_child(0)
	var second_card: Control = panel.grid.get_child(1)
	var sixth_card: Control = panel.grid.get_child(5)
	var panel_rect: Rect2 = panel.storage_panel.get_global_rect()
	var card_gap: float = panel.STORAGE_CARD_GAP * panel.stage.scale.x
	var card_inset: float = panel.STORAGE_CARD_INSET * panel.stage.scale.x
	_check(panel.grid.columns == 6 and is_equal_approx(first_card.global_position.y, sixth_card.global_position.y) and is_equal_approx(first_card.global_position.x - panel_rect.position.x, card_inset) and is_equal_approx(panel_rect.end.x - sixth_card.get_global_rect().end.x, card_inset) and is_equal_approx(second_card.global_position.x - first_card.get_global_rect().end.x, card_gap), "six cards share a row with equal visible gaps, accounting for the authored background frame")
	await _capture("map_inventory_six_columns")
	var add_formation_name := panel.custom_formation_card.find_child("FormationName", true, false) as Label
	var formation_panel_rect := panel.formation_panel.get_global_rect()
	var add_card_rect := panel.custom_formation_card.get_global_rect()
	_check(panel.find_child("FormationTitle", true, false) == null and panel.formation_cards.get_child_count() == 1, "formation panel removes the separate formation title and starts with one record action")
	_check(is_equal_approx(add_card_rect.position.y - formation_panel_rect.position.y, formation_panel_rect.end.y - add_card_rect.end.y), "formation record card is vertically centered with equal top and bottom spacing")
	_check(add_formation_name.text == "阵型记录" and add_formation_name.get_theme_font_size("font_size") == 15 and add_formation_name.get_theme_color("font_color") == Color("f9f8c8"), "formation record action uses the bag heading color and the smaller name size")
	var record_icon := panel.custom_formation_card.find_child("FormationRecordIcon", true, false) as TextureRect
	var record_mark := panel.custom_formation_card.find_child("FormationAddMark", true, false) as Label
	_check(record_icon.texture.resource_path == "res://assets/title-zhenxing.webp" and record_icon.custom_minimum_size == panel.FORMATION_ICON_SIZE and record_icon.texture.get_image().has_mipmaps(), "formation record action uses the title-zhenxing icon in the fixed artwork slot")
	_check(record_mark.text == "+" and record_mark.get_theme_font_size("font_size") == 22 and record_mark.get_theme_font("font") is FontVariation and (record_mark.get_theme_font("font") as FontVariation).variation_embolden > 0, "formation record action shows a bold plus above its second-line caption")
	for formation_card: Button in panel.formation_cards.get_children():
		_check(is_equal_approx(formation_card.size.x / formation_card.size.y, 2.0 / 3.0), "each formation card keeps a two-to-three aspect ratio")
		var icon_slot := formation_card.find_child("FormationIconSlot", true, false) as Control
		_check(icon_slot != null and is_equal_approx(icon_slot.size.x, icon_slot.size.y), "formation icon holder is square without an added frame")
		var formation_name := formation_card.find_child("FormationName", true, false) as Label
		_check(formation_name.get_theme_font_size("font_size") == 15 and formation_name.get_theme_constant("line_spacing") == -6 and formation_name.autowrap_mode == TextServer.AUTOWRAP_ARBITRARY and formation_name.max_lines_visible == 2 and formation_name.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS, "formation names use two tighter lines and ellipsize overflow on the second line")
	var formation_hover := InputEventMouseMotion.new()
	formation_hover.position = panel.custom_formation_card.get_global_rect().get_center()
	root.push_input(formation_hover, true)
	await _settle()
	var hovered_formation_control := root.gui_get_hovered_control()
	_check(hovered_formation_control == panel.custom_formation_card or panel.custom_formation_card.is_ancestor_of(hovered_formation_control), "custom formation card owns pointer hit testing (hovered=%s card=%s rect=%s)" % [hovered_formation_control, panel.custom_formation_card, panel.custom_formation_card.get_global_rect()])
	_click(panel.custom_formation_card.get_global_rect().get_center())
	await _settle()
	_check(panel.is_formation_dialog_open() and panel.formation_icon_buttons.size() == 6 and panel.formation_create_button.disabled, "add formation opens a six-icon dialog with create disabled until named (visible=%s icons=%d create_disabled=%s card_disabled=%s)" % [panel.is_formation_dialog_open(), panel.formation_icon_buttons.size(), panel.formation_create_button.disabled, panel.custom_formation_card.disabled])
	for choice: Button in panel.formation_icon_buttons:
		var choice_slot := choice.find_child("FormationChoiceIconSlot", true, false) as Control
		var choice_icon := choice.find_child("FormationChoiceIcon", true, false) as TextureRect
		_check(choice_slot != null and is_equal_approx(choice_slot.size.x, choice_slot.size.y) and choice_icon.texture.get_image().has_mipmaps(), "dialog formation icon holder is square, borderless and mipmapped")
	await _capture("formation_create_dialog")
	var dialog_panel := panel.formation_dialog.find_child("FormationDialogPanel", true, false) as Control
	var dialog_actions := dialog_panel.find_child("FormationDialogActions", true, false) as Control
	var choice_buttons := panel.formation_icon_buttons
	_check(is_equal_approx(dialog_panel.size.x, panel.FORMATION_DIALOG_WIDTH) and choice_buttons[0].position.y == choice_buttons[2].position.y and choice_buttons[0].get_parent() == choice_buttons[2].get_parent() and choice_buttons[3].get_parent() == choice_buttons[5].get_parent() and choice_buttons[3].global_position.y > choice_buttons[0].global_position.y, "narrower formation dialog lays out two complete rows of three choices")
	_check(panel.config.formation_icons.map(func(option): return option.name) == ["攻击", "防御", "平衡", "修炼", "炼丹", "炼器"] and choice_buttons[5].find_child("FormationChoiceIcon", true, false).texture.resource_path == "res://assets/zhen-lianqi.webp", "formation labels include the炼器 option with its authored icon")
	_check(panel.formation_replace_layout.visible and panel.formation_replace_layout.button_pressed and panel.formation_replace_layout.text == "按当前阵盘的道具和格位保存" and not panel.formation_message.visible, "new formation uses a checked current-board layout option instead of the old note")
	_check(dialog_actions.get_child(0) == panel.formation_create_button and dialog_actions.get_child(1) == panel.formation_cancel_button, "new and cancel buttons use the requested left-to-right order")
	_check(is_equal_approx(dialog_panel.get_global_rect().end.y - dialog_actions.get_global_rect().end.y, 22.0 * panel.stage.scale.y), "formation dialog height follows its content without the oversized empty footer")
	panel.formation_name_input.text = "临时阵型"
	panel.formation_name_input.text_changed.emit(panel.formation_name_input.text)
	var cancel_hover := InputEventMouseMotion.new()
	cancel_hover.position = panel.formation_cancel_button.get_global_rect().get_center()
	root.push_input(cancel_hover, true)
	await _settle()
	var hovered_cancel := root.gui_get_hovered_control()
	_check(hovered_cancel == panel.formation_cancel_button or panel.formation_cancel_button.is_ancestor_of(hovered_cancel), "formation cancel button owns pointer hit testing (hovered=%s)" % hovered_cancel)
	_click(panel.formation_cancel_button.get_global_rect().get_center())
	await _settle()
	_check(not panel.is_formation_dialog_open() and (panel.custom_formation_card.find_child("FormationName", true, false) as Label).text == "阵型记录", "cancel closes dialog without changing the formation record action")
	_click(panel.custom_formation_card.get_global_rect().get_center())
	await _settle()
	_check(panel.is_formation_dialog_open(), "custom slot can reopen the formation dialog after cancel")
	_key(KEY_ESCAPE)
	await _settle()
	_check(screen.is_inventory_open() and not panel.is_formation_dialog_open(), "Escape closes only the formation dialog")
	_click(panel.custom_formation_card.get_global_rect().get_center())
	await _settle()
	_click(panel.formation_icon_buttons[1].get_global_rect().get_center())
	panel.formation_name_input.text = "玄甲阵"
	panel.formation_name_input.text_changed.emit(panel.formation_name_input.text)
	_check(not panel.formation_create_button.disabled, "selecting an icon and entering a name enables create")
	_click(panel.formation_create_button.get_global_rect().get_center())
	await _settle()
	var saved_card = panel.formation_cards.get_child(0)
	var custom_icon := saved_card.find_child("FormationIcon", true, false) as TextureRect
	_check(not panel.is_formation_dialog_open() and not panel.custom_formation_card.disabled and panel.formation_cards.get_child_count() == 2 and (saved_card.find_child("FormationName", true, false) as Label).text == "玄甲阵" and custom_icon.texture.resource_path == "res://assets/zhen-fangyu.webp" and screen.loadout.formations.size() == 1, "create saves a layout card and retains the add action")
	await _capture("formation_custom_created")
	var saved_name := saved_card.find_child("FormationName", true, false) as Label
	var saved_icon_position := custom_icon.global_position
	saved_name.text = "天地玄黄宇宙洪荒日月盈昃"
	await _settle()
	_check(saved_name.get_line_count() >= 2 and saved_name.get_visible_line_count() == 2, "long formation names stop after two visible lines before ellipsis (lines=%d visible=%d size=%s)" % [saved_name.get_line_count(), saved_name.get_visible_line_count(), saved_name.size])
	_check(custom_icon.global_position.is_equal_approx(saved_icon_position), "formation artwork stays fixed when its name changes from one line to two")
	await _capture("formation_name_two_lines")
	saved_name.text = "玄甲阵"
	await _settle()
	saved_card.set_process(false)
	saved_card._reset_edit_hover()
	root.grab_focus()
	await _settle()
	var saved_hover := InputEventMouseMotion.new()
	saved_hover.position = saved_card.get_global_rect().get_center()
	if DisplayServer.get_name() != "headless":
		root.warp_mouse(saved_hover.position)
	root.push_input(saved_hover, true)
	await _settle()
	saved_card.set_process(false)
	_check(saved_card.hover_active and saved_card.hover_seconds < 0.25, "edit countdown starts immediately when the pointer enters the formation card")
	saved_card.hover_seconds = 0.0
	saved_card._process(2.9)
	_check(not saved_card.edit_button.visible, "edit button remains hidden before three seconds")
	saved_card._process(0.11)
	_check(saved_card.edit_button.visible, "three-second hover reveals the edit menu (hovered=%s, focus=%s, elapsed=%s, rect=%s)" % [root.gui_get_hovered_control(), root.has_focus(), saved_card.hover_seconds, saved_card.get_global_rect()])
	await _capture("formation_hover_edit")
	var before_edit: Dictionary = screen.loadout.layout_snapshot()
	var edit_hover := InputEventMouseMotion.new()
	edit_hover.position = saved_card.edit_button.get_global_rect().get_center()
	if DisplayServer.get_name() != "headless":
		root.warp_mouse(edit_hover.position)
	root.push_input(edit_hover, true)
	await _settle()
	_check((saved_card.edit_button.visible if DisplayServer.get_name() == "headless" else root.gui_get_hovered_control() == saved_card.edit_button), "edit button receives pointer without activating the card (hovered=%s rect=%s)" % [root.gui_get_hovered_control(), saved_card.edit_button.get_global_rect()])
	_click(saved_card.edit_button.get_global_rect().get_center())
	await _settle()
	_check(panel.is_formation_dialog_open() and panel.formation_name_input.text == "玄甲阵" and not panel.formation_replace_layout.button_pressed and screen.loadout.layout_snapshot() == before_edit, "edit menu opens populated metadata without applying a layout (open=%s name=%s id=%s same_layout=%s)" % [panel.is_formation_dialog_open(), panel.formation_name_input.text, panel._editing_formation_id, screen.loadout.layout_snapshot() == before_edit])
	await _capture("formation_edit_dialog")
	_click(panel.formation_icon_buttons[2].get_global_rect().get_center())
	panel.formation_name_input.text = "平衡阵"
	panel.formation_name_input.text_changed.emit("平衡阵")
	_click(panel.formation_create_button.get_global_rect().get_center())
	await _settle()
	_check(screen.loadout.formations[0].name == "平衡阵" and screen.loadout.formations[0].icon == "res://assets/zhen-pingheng.webp" and screen.loadout.formations[0].layout == {"placements": before_edit.placements}, "editing icon and name preserves the saved layout")
	panel.search.grab_focus()
	_key(KEY_I, false, 105)
	_check(screen.is_inventory_open() and panel.search.text == "i", "typing I in search does not close panel")
	_key(KEY_ESCAPE)
	_check(not screen.is_inventory_open() and header.map_title.visible, "Escape closes even when search focused and restores map plaque")
	screen._process(0.05)
	_check(screen.travel.map_position != position_before and screen.travel.destination_id == destination_before and screen.player.is_playing(), "closing resumes same journey")
	_key(KEY_I)
	panel.catalog.reset_filters()
	await _fixed_card_size_checks(panel)
	panel.catalog.replace_entries(_fixtures())
	await _settle()
	_click(panel.level_sort.get_global_rect().get_center())
	await _settle()
	_check(_ids(panel.catalog) == ["test.c", "test.b", "test.d", "test.a"] and panel.level_sort.button_pressed and not panel.order_picker.button_pressed, "level button selects descending enhancement sort")
	_click(panel.level_sort.get_global_rect().get_center())
	await _settle()
	_check(_ids(panel.catalog) == ["test.a", "test.b", "test.d", "test.c"], "second level click switches ascending")
	_click(panel.order_picker.get_global_rect().get_center())
	await _settle()
	_check(_ids(panel.catalog) == ["test.b", "test.c", "test.d", "test.a"] and panel.order_picker.button_pressed and not panel.level_sort.button_pressed, "acquisition button restores time as primary sorting")
	_click(panel.order_picker.get_global_rect().get_center())
	await _settle()
	_check(_ids(panel.catalog) == ["test.a", "test.d", "test.b", "test.c"], "second acquisition click switches oldest first")
	_click(panel._collections.consumable.get_global_rect().get_center())
	await _settle()
	_click(panel._categories.pill.get_global_rect().get_center())
	await _settle()
	_check(panel.grid.get_child_count() == 2 and panel.catalog.category == "pill", "category button filters actual connected content")
	_click(panel._collections.favorite.get_global_rect().get_center())
	await _settle()
	_check(panel.grid.get_child_count() == 2 and panel.catalog.category == "all" and panel.catalog.collection == "favorite", "switching primary clears the old secondary filter")
	panel.catalog.set_filter("search", "无匹配")
	await _settle()
	_check(panel.empty_state.visible and panel.empty_title.text == "没有符合条件的物品", "empty filtered result has clear feedback")
	panel.catalog.replace_entries([])
	panel.catalog.reset_filters()
	_click(panel.return_button.get_global_rect().get_center())
	_check(not screen.is_inventory_open(), "return button closes interface")
	_check(screen.player_status.resources == state_before, "opening and filters never change player resources")
	_key(KEY_I)
	_key(KEY_I)
	_check(not screen.is_inventory_open(), "I toggles closed outside text editing")
	screen.travel.advance(1000)
	screen.player.present(screen.travel)
	var point: Node2D = screen.content.get_node("Points/N37")
	screen._select_destination(screen.map_to_screen(point.position))
	_check(screen.event_state.is_active(), "existing bridge event still opens")
	_key(KEY_I)
	_check(not screen.is_inventory_open() and screen.event_state.line_index == 0, "I cannot replace active dialogue or advance it")
	screen.queue_free()
	await process_frame
	MapEventState.session_completed.clear()
	print("MAP INVENTORY RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _fixed_card_size_checks(panel: MapInventoryScreen) -> void:
	await _settle()
	var original := panel.loadout.storage_records()
	var expected: Vector2 = panel.grid.get_child(0).size
	for count in [5, 4, 3, 2, 1, 0, 7, 30, 6]:
		var records: Array = []
		for index in count:
			var record: Dictionary = original[index % original.size()].duplicate(true)
			record.id = "test.fixed_card.%d" % index
			record.acquired_at = index
			records.append(record)
		panel.catalog.replace_entries(records)
		await _settle()
		var stable: bool = panel.grid.get_child_count() == count
		for index in count:
			var card: Control = panel.grid.get_child(index)
			stable = stable and card.size.is_equal_approx(expected) and is_equal_approx(card.position.x, (index % 6) * (expected.x + panel.STORAGE_CARD_GAP))
		_check(stable, "card size and six fixed column positions remain stable with %d visible items (expected=%s actual=%s)" % [count, expected, panel.grid.get_child(0).size if count > 0 else Vector2.ZERO])
		if count == 30:
			var scroll := panel.grid.get_parent() as ScrollContainer
			var point := scroll.get_global_rect().get_center()
			var motion := InputEventMouseMotion.new()
			motion.position = point
			root.push_input(motion, true)
			_mouse(MOUSE_BUTTON_WHEEL_DOWN, true, point)
			_mouse(MOUSE_BUTTON_WHEEL_DOWN, false, point)
			await _settle()
			_check(scroll.scroll_vertical > 0 and panel.grid.get_child(0).size.is_equal_approx(expected), "overflow wheel scrolling works without changing card size")
	panel.catalog.replace_entries(original)
	await _settle()

func _settle() -> void:
	for i in 5:
		await process_frame

func _capture(file_name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png("res://artifacts/" + file_name + ".png") == OK, "save inventory screenshot")

func _key(code: Key, echo: bool = false, unicode_value: int = 0) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.unicode = unicode_value
	event.pressed = true
	event.echo = echo
	root.push_input(event, true)
	event.pressed = false
	root.push_input(event, true)

func _click(point: Vector2) -> void:
	_mouse(MOUSE_BUTTON_LEFT, true, point)
	_mouse(MOUSE_BUTTON_LEFT, false, point)

func _mouse(button: MouseButton, pressed: bool, point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = point
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed and button == MOUSE_BUTTON_LEFT else 0
	root.push_input(event, true)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
