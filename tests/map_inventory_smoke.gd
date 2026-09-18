extends SceneTree

var checks := 0
var failures := 0
var screen: Control
const MIPMAPPED_TEST_ICON := "res://assets/weapon-qsdj.webp"

func _initialize() -> void:
	call_deferred("_run")

func _fixtures() -> Array:
	return [
		{"id": "test.a", "name": "回春丹", "category": "pill", "quality": "凡品", "acquired_at": 10, "quantity": 2, "favorite": true, "icon": MIPMAPPED_TEST_ICON},
		{"id": "test.b", "name": "测试灵药", "category": "pill", "quality": "灵品", "acquired_at": 30, "quantity": 1, "common": true, "enhancement_level": 2, "icon": MIPMAPPED_TEST_ICON},
		{"id": "test.c", "name": "测试铁甲", "category": "armor", "quality": "凡品", "acquired_at": 30, "quantity": 1, "enhancement_level": 10, "icon": MIPMAPPED_TEST_ICON},
		{"id": "test.d", "name": "测试草药", "category": "material", "quality": "凡品", "acquired_at": 20, "quantity": 3, "favorite": true, "enhancement_level": 2, "icon": MIPMAPPED_TEST_ICON}
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
	model.set_filter("category", "pill")
	model.set_filter("quality", "凡品")
	model.set_filter("collection", "favorite")
	model.set_filter("search", "  回春  ")
	_check(_ids(model) == ["test.a"], "category quality collection and search intersect")
	model.set_filter("collection", "common")
	_check(model.visible_entries().is_empty(), "incompatible filters produce empty result")
	model.reset_filters()
	_check(model.newest_first and model.quality.is_empty() and model.visible_entries().size() == 4, "reset restores all filters and default order")
	model.set_filter("collection", "material")
	_check(_ids(model) == ["test.d"], "material tab filters materials")
	_check(model.collection_count("favorite") == 2 and model.collection_count("common") == 1, "collection badges reflect independent totals")
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
	_check(panel.grid.get_child_count() == 6 and not panel.empty_state.visible, "three weapons and three armor pieces appear in storage")
	var expected := {"青石短剑": ["斩击", 7, 3.5, 3], "猎弓": ["穿刺", 9, 4.5, 5], "短柄铁锤": ["钝击", 8, 4.0, 4]}
	for card: MapInventoryItemCard in panel.grid.get_children():
		var art := card.canvas.get_node("ItemArtwork") as TextureRect
		var outline := art.get_node_or_null("ItemOutline")
		_check(FileAccess.file_exists(card.entry.icon) and art.texture is AtlasTexture and art.texture.atlas.resource_path == card.entry.icon and art.texture.atlas.get_image().has_mipmaps() and art.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED and art.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "item source exists, has mipmaps, preserves source aspect and uses linear mipmap filtering")
		_check(card.entry.art_outline_px == 1 and outline != null and outline.get_child_count() == 16 and outline.z_index == 0 and (outline.get_child(0) as TextureRect).self_modulate == MapItemArtwork.OUTLINE_COLOR, "all six items use the shared softened one-pixel outline above static backgrounds")
		if card.entry.category == "armor":
			var armor_values: Array = {"粗布甲": [2, 4.0, 3, 7], "旧铁盔": [1, 5.0, 1, 2], "木圆盾": [2, 5.0, 3, 2]}[card.entry.name]
			_check(card.entry.quality == "下品" and card.entry.footprint_columns == 1 and card.entry.footprint_rows == armor_values[0] and card.entry.cooldown == armor_values[1] and card.entry.armor_gain == armor_values[2] and card.entry.armor_capacity == armor_values[3], "armor dimensions and effects match authored values")
			_check(card.entry.has("armor_type") == (card.entry.name == "粗布甲") and card.tooltip_text.contains("护甲上限") and card.tooltip_text.contains("每轮获得"), "only body armor has a type; tooltip contains armor effects")
			continue
		_check(card.entry.enhancement_level == 0 and card.tooltip_text.contains("强化等级：0级"), "authored weapons have zero enhancement level, shown independently of quality")
		var values: Array = expected[card.entry.name]
		_check(card.entry.damage_type == values[0] and int(card.entry.base_damage) == values[1] and is_equal_approx(card.entry.cooldown, values[2]) and int(card.entry.base_stamina_cost) == values[3], "authored weapon values match user table")
		_check(card.frame.resource_path == "res://assets/level-fanpin.webp" and card.entry.quality == "下品" and card.tooltip_text.contains("品质：下品"), "each weapon has lower quality while retaining current frame asset")
		var tags: Array[String] = []
		for tag: Label in card.canvas.get_node("CategoryTags").get_children():
			tags.append(tag.text)
		_check(tags == ["武器", card.entry.subcategory, card.entry.damage_type], "weapon card shows category, weapon kind and damage type as three labels")
		_check(card.footprint_cells.size() == 2 and card.footprint_cells[0].position.x == card.footprint_cells[1].position.x and card.footprint_cells[0].position.y < card.footprint_cells[1].position.y and card.tooltip_text.contains("占格：1列 × 2行"), "one column two rows shown vertically at top right")
		_check(card.tooltip_text.contains("基础伤害") and card.tooltip_text.contains("轮转CD") and card.tooltip_text.contains("基础耗体"), "all weapon attributes available on hover")
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
		_check(is_equal_approx(storage_rect.position.x, board_rect.end.x + 20.0 * panel.stage.scale.x), "storage expands left up to the fixed column gap " + str(dimensions))
		_check(not panel.board_panel.get_global_rect().intersects(panel.formation_panel.get_global_rect()) and not panel.board_panel.get_global_rect().intersects(panel.storage_panel.get_global_rect()), "main regions do not overlap")
		await _capture("map_inventory_%dx%d" % [dimensions.x, dimensions.y])
	root.size = Vector2i(1920, 1080)
	await _settle()
	_check(panel.board_panel.position.x == 0.0 and is_equal_approx(panel.board_panel.global_position.x, 252.0), "bag left edge retains its 1920 design position")
	_check(panel.board_panel.size.is_equal_approx(Vector2(718, 718)) and is_equal_approx(panel.formation_panel.size.x, 718.0), "bag is 718 square and formation follows its width")
	_check(is_equal_approx(panel.storage_panel.global_position.x, 990.0) and is_equal_approx(panel.storage_panel.get_global_rect().end.x, 1896.0), "storage gains the released 62 pixels on its left edge")
	_check(panel.board_capacity_caption.get_theme_font("font") == panel.board_capacity.get_theme_font("font") and panel.board_capacity_caption.get_theme_color("font_color") == Color("c5d0d2"), "capacity caption and value share one font while the Chinese caption stays clearly brighter")
	var first_card: Control = panel.grid.get_child(0)
	var fifth_card: Control = panel.grid.get_child(4)
	var sixth_card: Control = panel.grid.get_child(5)
	_check(is_equal_approx(first_card.global_position.y, fifth_card.global_position.y) and fifth_card.get_global_rect().end.x <= panel.storage_panel.get_global_rect().end.x - 14 * panel.stage.scale.x and sixth_card.global_position.y > first_card.global_position.y, "five cards fit completely inside storage; sixth wraps")
	await _capture("map_inventory_five_columns")
	panel.search.grab_focus()
	_key(KEY_I, false, 105)
	_check(screen.is_inventory_open() and panel.search.text == "i", "typing I in search does not close panel")
	_key(KEY_ESCAPE)
	_check(not screen.is_inventory_open() and header.map_title.visible, "Escape closes even when search focused and restores map plaque")
	screen._process(0.05)
	_check(screen.travel.map_position != position_before and screen.travel.destination_id == destination_before and screen.player.is_playing(), "closing resumes same journey")
	_key(KEY_I)
	panel.catalog.reset_filters()
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
	_click(panel._categories.pill.get_global_rect().get_center())
	await _settle()
	_check(panel.grid.get_child_count() == 2 and panel.catalog.category == "pill", "category button filters actual connected content")
	_click(panel._collections.favorite.get_global_rect().get_center())
	await _settle()
	_check(panel.grid.get_child_count() == 1 and panel.result_count.text == "显示 1 / 4 项", "collection button combines with category and updates count")
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
