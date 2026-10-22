extends "res://tests/item_selection_tooltip_tests.gd"
const Grant = preload("res://tools/grant_test_cultivation_books.gd")
const BOOK := "base.cultivation_book.wood_04"
const HOME := "base.warehouse.qingshizhen.home"

func press_details(card: MapInventoryItemCard) -> void:
	var host := ItemTooltipHost.for_control(card)
	host._show(card, card.entry.id)
	await settle(12)
	check(is_instance_valid(host.tooltip) and host.tooltip.details_button != null, "details button in live tooltip")
	if not is_instance_valid(host.tooltip): return
	await click(host.tooltip.details_button.get_global_rect().get_center())
	await settle(12)
	check(not is_instance_valid(host.tooltip), "details click closes tooltip")

func run() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
	root.size = Vector2i(1920,1080)
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	AudioServer.set_bus_mute(0,true)
	var before := FileAccess.get_file_as_bytes(MapLoadoutStore.DEFAULT_PATH)
	var map = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path = ""
	map.defer_map_music = true
	root.add_child(map)
	await settle()
	check(map.startup_error.is_empty(), "map starts")
	check(map.loadout.restore(Grant.prepare(map.loadout).snapshot).is_empty(), "memory book fixture")
	map.set_inventory_open(true)
	map.inventory_screen.catalog.set_filter("collection","book")
	map.inventory_screen.catalog.set_filter("search","万木")
	await settle(12)
	await press_details(map.inventory_screen.grid.get_child(0))
	check(map.is_technique_open() and not map.is_inventory_open(), "bag switches to technique page")
	check(map.technique_screen.selected_book_id == BOOK and map.technique_screen.selected_element_id == "base.element.wood", "exact book and element selected")
	check(map.technique_screen.book_cards.filter(func(card): return card.book_id == BOOK)[0].button_pressed, "target book highlighted")
	map.set_technique_open(false)
	check(map.loadout.transfer_warehouse(HOME, BOOK, false).is_empty(), "store book for warehouse route")
	map.set_inventory_open(true)
	map.inventory_screen.set_warehouse(HOME)
	map.inventory_screen.warehouse_pane.catalog.set_filter("collection","book")
	await settle(12)
	await press_details(map.inventory_screen.warehouse_pane.grid.get_child(0))
	check(map.is_technique_open() and not map.is_inventory_open(), "warehouse route switches without reopening rest")
	check(map.technique_screen.selected_book_id == BOOK, "warehouse same-book selection still reveals it")
	var player_data: Dictionary = map.player_status.battle_snapshot()
	map.queue_free()
	await settle()
	var battle = load("res://scenes/main/main.tscn").instantiate()
	var manager: GameManager = battle.get_node("GameManager")
	manager.use_saved_loadout = true
	manager.loadout_save_path = ""
	manager.player_snapshot = player_data
	root.add_child(battle)
	manager.set_process(false)
	check(manager.startup_error.is_empty(), "battle starts")
	check(manager._durable_loadout.restore(Grant.prepare(manager._durable_loadout).snapshot).is_empty(), "battle memory books")
	manager.storage = manager._durable_loadout.storage
	manager.start_battle()
	manager.pause_battle()
	manager.set_adjustment(true)
	manager.inventory_changed.emit()
	var ui = battle.get_node("MainUI")
	ui.storage_panel.catalog.set_filter("collection","book")
	ui.storage_panel.catalog.set_filter("search","万木")
	await settle(12)
	await press_details(ui.storage_panel.grid.get_child(0))
	check(is_instance_valid(ui._book_details) and ui._book_details.selected_book_id == BOOK, "battle opens matching technique page")
	check(manager.simulation.clock.paused, "reading details pauses running combat")
	if is_instance_valid(ui._book_details): await click(ui._book_details.return_button.get_global_rect().get_center())
	check(not is_instance_valid(ui._book_details) and manager.simulation.clock.paused and manager.adjustment_open, "return preserves prior pause and bag")
	battle.queue_free()
	await settle()
	check(FileAccess.get_file_as_bytes(MapLoadoutStore.DEFAULT_PATH)==before, "real save unchanged")
	print("TECHNIQUE DETAILS: %d checks, %d failures; targeted button mouse input only" % [checks,failures])
	quit(1 if failures else 0)
