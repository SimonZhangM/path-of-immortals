extends SceneTree

var checks := 0
var failures := 0
const GROUPS := {
	"equipment": ["weapon", "armor", "artifact", "board", "talisman"],
	"consumable": ["pill", "throwable", "bait", "food"],
	"material": ["plant", "beast", "mineral", "exotic"],
	"blueprint": ["pill_recipe", "artifact_recipe", "talisman_recipe", "bait_recipe"],
}
const PRIMARY := ["all", "favorite", "equipment", "consumable", "material", "blueprint", "key", "misc"]

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _settle() -> void:
	for i in 6:
		await process_frame

func _click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		root.push_input(event, true)

func _capture(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/" + name + ".png")

func _test_model(config: Dictionary) -> void:
	var catalog := MapInventoryCatalog.new()
	catalog.configure(config)
	_check(catalog.collection_names.keys() == PRIMARY, "eight primary categories in exact order")
	_check(config.categories.throwable == "掷具" and not config.categories.has("board_recipe"), "throwables use 掷具 and 阵图 is removed")
	var records: Array = []
	for key: String in config.categories:
		if key == "all":
			continue
		records.append({"id": "test.category." + key, "name": config.categories[key], "category": key, "quality": "下品", "acquired_at": records.size(), "quantity": 1, "favorite": key in ["weapon", "pill", "plant", "pill_recipe", "key", "misc"], "icon": "res://assets/weapon-qsdj.webp"})
	_check(catalog.replace_entries(records).is_empty(), "all19 leaf categories accept future records")
	_check(catalog.total_count() == 19 and catalog.visible_entries().size() == 19, "all includes every leaf")
	for group: String in GROUPS:
		catalog.set_filter("collection", group)
		_check(catalog.subcategories() == GROUPS[group], "exact secondary order for " + group)
		_check(catalog.visible_entries().size() == GROUPS[group].size() and catalog.collection_count(group) == GROUPS[group].size(), "parent aggregates only its children")
		for leaf: String in GROUPS[group]:
			catalog.set_filter("category", leaf)
			_check(catalog.visible_entries().size() == 1 and catalog.visible_entries()[0].category == leaf, "leaf filters correctly: " + leaf)
			catalog.set_filter("search", "no-match")
			_check(catalog.visible_entries().is_empty(), "search intersects the leaf")
			catalog.set_filter("search", "")
		catalog.set_filter("collection", group)
		_check(catalog.category == "all" and catalog.visible_entries().size() == GROUPS[group].size(), "reselecting parent resets leaf")
	catalog.set_filter("collection", "all")
	_check(catalog.subcategories().size() == 17, "all shows every grouped secondary")
	catalog.set_filter("category", "weapon")
	_check(catalog.visible_entries().size() == 1, "all supports secondary filtering")
	for group in ["favorite", "key", "misc"]:
		catalog.set_filter("collection", group)
		_check(catalog.subcategories().is_empty() and catalog.category == "all", "flat primary has no stale secondary: " + group)
		var expected: int = 19 if group == "all" else (6 if group == "favorite" else 1)
		_check(catalog.visible_entries().size() == expected, "flat primary filters correctly: " + group)
		catalog.set_filter("category", "weapon")
		_check(catalog.category == "all", "hidden secondary cannot become active")
	catalog.set_filter("collection", "common")
	_check(catalog.collection == "misc", "removed primary is rejected")
	catalog.set_filter("search", "武器")
	catalog.set_filter("quality", "下品")
	catalog.set_level_descending(false)
	catalog.reset_filters()
	_check(catalog.collection == "all" and catalog.category == "all" and catalog.search_text.is_empty() and catalog.quality.is_empty() and catalog.sort_key == "acquired_at", "reset clears hierarchy and independent filters")
	var invalid := records.duplicate(true)
	invalid[0].category = "missing"
	_check(not catalog.replace_entries(invalid).is_empty() and catalog.total_count() == 19, "unknown leaf rejected atomically")

func _run() -> void:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/map_inventory.json"))
	_test_model(config)
	root.size = Vector2i(1920, 1080)
	var map = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path = ""
	root.add_child(map)
	map.set_inventory_open(true)
	await _settle()
	var panel: MapInventoryScreen = map.inventory_screen
	var saved_layout: Dictionary = panel.loadout.snapshot()
	var card_size: Vector2 = panel.grid.get_child(0).size
	_check(panel._collections.keys() == PRIMARY and panel.grid.get_child_count() == 10, "live ten items and eight primary buttons")
	_check(panel.catalog.collection_count("equipment") == 7 and panel.catalog.collection_count("consumable") == 3, "live items are7 equipment and3 consumables")
	_check(panel._collections.all.text == "全部 10" and panel._category_filters.visible, "all default has total badge and all secondaries")
	for button: Button in panel._categories.values():
		_check(button.is_visible_in_tree(), "all shows every secondary button")
	var previous_right := 0.0
	for button: Button in panel._collections.values():
		var rect := button.get_global_rect()
		_check(rect.position.x >= previous_right and rect.end.x <= panel.storage_toolbar.get_global_rect().end.x + 1, "eight buttons fit in one row without overlap")
		previous_right = rect.end.x
	await _capture("inventory_categories_all")
	_click(panel._collections.equipment)
	await _settle()
	_check(panel.catalog.collection == "equipment" and panel.grid.get_child_count() == 7 and panel._category_filters.visible, "actual primary click opens equipment children")
	for key in panel._categories:
		_check(panel._categories[key].is_visible_in_tree() == (key in GROUPS.equipment), "only equipment children visible")
	await _capture("inventory_categories_equipment")
	_click(panel._categories.weapon)
	await _settle()
	_check(panel.catalog.category == "weapon" and panel.grid.get_child_count() == 3 and panel._categories.weapon.button_pressed, "actual weapon click filters3 weapons")
	_check(panel.grid.get_child(0).size.is_equal_approx(card_size), "filtering preserves six-column card size")
	_click(panel._categories.weapon)
	await _settle()
	_check(panel.catalog.category == "all" and panel.grid.get_child_count() == 7 and not panel._categories.weapon.button_pressed, "click selected child again returns full parent")
	_click(panel._categories.armor)
	await _settle()
	_click(panel._collections.consumable)
	await _settle()
	_check(panel.catalog.category == "all" and panel.grid.get_child_count() == 3 and panel._categories.pill.visible and not panel._categories.armor.visible, "changing parent discards previous armor filter")
	_click(panel._categories.pill)
	await _settle()
	_check(panel.catalog.category == "pill" and panel.grid.get_child_count() == 3, "consumables include all three medicines")
	await _capture("inventory_categories_consumable")
	for group in ["material", "blueprint", "key", "misc", "favorite"]:
		_click(panel._collections[group])
		await _settle()
		_check(panel.catalog.collection == group and panel.empty_state.visible and panel.catalog.category == "all", "empty future or favorite group works: " + group)
		_check(panel._category_filters.visible == GROUPS.has(group), "second row presence follows hierarchy: " + group)
		if group == "blueprint":
			await _capture("inventory_categories_blueprint")
	panel.catalog.reset_filters()
	await _settle()
	_check(panel.grid.get_child_count() == 10 and panel.loadout.snapshot() == saved_layout, "category interaction never mutates ownership or saved layouts")
	map.queue_free()
	await _settle()
	print("INVENTORY CATEGORIES: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
