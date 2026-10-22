extends "res://tests/item_selection_tooltip_tests.gd"
const Grant = preload("res://tools/grant_test_cultivation_books.gd")
const HOME := "base.warehouse.qingshizhen.home"

func run() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
	root.size = Vector2i(2560, 1440)
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var registry := ContentRegistry.new()
	check(registry.load_base_content(), "registry")
	var made := MapLoadoutStore.create_state(registry, registry.get_board("base.board.bag"))
	check(made.error.is_empty(), "inventory accepts registered books")
	if not made.error.is_empty(): quit(1); return
	var state: MapLoadoutState = made.state
	check(state.restore(state.snapshot()).is_empty(), "normalize initial fixture like a loaded save")
	check(state.storage_records().all(func(row): return row.category != "book"), "opening inventory does not grant books")
	var before := state.snapshot()
	var grant := Grant.prepare(state)
	check(grant.error.is_empty() and grant.added == 35, "explicit grant adds one of each book")
	check(state.restore(grant.snapshot).is_empty(), "book ownership restores")
	var after := state.snapshot()
	for field in before:
		if field not in ["owned_units", "content_grants"]: check(after[field] == before[field], "grant preserves " + field)
	for unit in before.owned_units: check(after.owned_units.get(unit) == before.owned_units[unit], "old unit preserved")
	check(Grant.prepare(state).snapshot == state.snapshot(), "grant is idempotent")
	check(state.storage_capacity_limit() == 999 and state.bag_capacity == 100, "temporary 999 override preserves formal 100")
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/map_inventory.json"))
	var catalog := MapInventoryCatalog.new()
	catalog.configure(config)
	check(catalog.replace_entries(state.storage_records()).is_empty(), "bag records validated")
	check(catalog.collection_names.keys().find("cultivation") == catalog.collection_names.keys().find("equipment") + 1, "cultivation tab directly after equipment")
	check(catalog.collection_count("book") == 35, "primary count 35")
	check("" not in catalog.qualities(), "no blank quality option")
	var identity := registry.get_item("base.cultivation_book.fire_03")
	check(identity == registry.library.book_items[identity.id], "inventory reuses canonical registry identity")
	var invalid: Array = state.storage_records().duplicate(true)
	invalid[0].quality = ""
	if invalid[0].category != "book": check(not catalog.replace_entries(invalid).is_empty(), "ordinary items still require quality")
	var error := MapLoadoutStore.save(state, "res://artifacts/inventory-books-test-save.json")
	check(error.is_empty(), "isolated save")
	var copy: MapLoadoutState = MapLoadoutStore.candidate(state).state
	check(MapLoadoutStore.load_into(copy, "res://artifacts/inventory-books-test-save.json").is_empty() and copy.snapshot() == state.snapshot(), "35 books survive reload without duplication")
	check(state.transfer_warehouse(HOME, identity.id, false).is_empty(), "book can be stored in warehouse")
	check(state.warehouse_records(HOME).any(func(row): return row.id == identity.id and row.identified), "warehouse displays book")
	check(state.transfer_warehouse(HOME, identity.id, true).is_empty(), "book can be withdrawn")
	check(catalog.replace_entries(state.storage_records()).is_empty(), "refresh after transfer")
	var screen := MapInventoryScreen.new()
	screen.configure(catalog, config, state.board, state)
	root.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.show()
	await settle(12)
	var input_check := DisplayServer.get_name() == "headless"
	if input_check: await click(screen._collections.cultivation.get_global_rect().get_center())
	else: catalog.set_filter("collection", "cultivation")
	await settle()
	check(catalog.collection == "cultivation" and catalog.visible_entries().size() == 35, "cultivation tab includes all books")
	check(catalog.subcategories() == ["book", "spell", "metal", "wood", "water", "fire", "earth", "wind", "thunder"], "type and ordered element filters")
	for element: String in catalog.book_elements:
		check(screen._categories[element].visible, "element tag visible")
	check(screen._collections.cultivation.text == "功法 35", "count displayed")
	if not input_check:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/inventory-books-all.png")
	for element: String in catalog.book_elements:
		if input_check: await click(screen._categories[element].get_global_rect().get_center())
		else: catalog.set_filter("category", element)
		await settle()
		check(catalog.visible_entries().size() == 5 and screen.grid.get_child_count() == 5, "five cards for " + element)
		for record: Dictionary in catalog.visible_entries():
			check(record.element == "base.element." + element and record.quantity == 1 and record.identified, "matching identified single book")
		if element == "fire":
			var card: MapInventoryItemCard = screen.grid.get_child(0)
			var host := ItemTooltipHost.for_control(card)
			if input_check: await hover(card.get_global_rect().get_center())
			else: host._show(card, card.entry.id); await settle(12)
			check(is_instance_valid(host.tooltip) and host.tooltip.description == registry.get_item(card.entry.id).combat.description, "bag keeps book tooltip")
			if not input_check:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://artifacts/inventory-books-fire-tooltip.png")
			host.dismiss(false)
			await settle()
	if input_check: await click(screen._categories.thunder.get_global_rect().get_center())
	else: catalog.set_filter("category", "all")
	await settle()
	check(catalog.category == "all" and catalog.visible_entries().size() == 35, "same element click clears subfilter")
	catalog.set_filter("search", "青萝")
	check(catalog.visible_entries().size() == 1, "book title search")
	catalog.set_filter("search", "")
	catalog.set_filter("collection", "equipment")
	await settle()
	check(catalog.visible_entries().all(func(row): return row.category != "book"), "books excluded from equipment")
	check(not screen._categories.metal.visible, "element buttons hidden outside books")
	for viewport_size in [Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		root.size = viewport_size
		await settle(12)
		var tabs: Control = screen.find_child("CollectionTabs", true, false)
		for tab: Button in screen._collections.values():
			check(tabs.get_global_rect().encloses(tab.get_global_rect()), "all collection tabs fit available width")
	check(state.snapshot() == after, "browsing and round-trip transfer preserve ownership and game state")
	screen.queue_free()
	await settle()
	print("INVENTORY BOOKS: %d checks, %d failures; isolated save only" % [checks, failures])
	quit(1 if failures else 0)
