extends "res://tests/map_shop_tests.gd"

func run() -> void:
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(2560,1440)
	var map = load("res://scenes/maps/qingshizhen.tscn").instantiate()
	map.inventory_save_path = ""
	map.defer_map_music = true
	root.add_child(map)
	map.set_process(false)
	await settle()
	check(map.startup_error.is_empty(),"map ready")
	if not map.startup_error.is_empty(): quit(1); return
	var before: Dictionary = map.loadout.snapshot()
	var ui: MapInventoryScreen = map.inventory_screen
	ui.show()
	map.status_header.map_title.hide()
	await settle()
	for capacity in [ui.board_capacity,ui.storage_capacity]:
		check(capacity.number_offset==Vector2(-3,0),"digits and slash shifted left three design pixels")
		var geometry: Rect2 = capacity.get_global_rect()
		var original_center: Vector2 = capacity.number_center()
		var font_size: int = capacity.display_font_size()
		capacity.number_offset = Vector2.ZERO
		check(capacity.get_global_rect()==geometry and capacity.number_center()==original_center,"artwork and numeric source area unchanged")
		check(capacity.display_font_size()==font_size,"font unchanged")
		capacity.number_offset = Vector2(-3,0)
		capacity.queue_redraw()
	check(ui.board_capacity.displayed_capacity()==Vector2i(99,99),"board preview unchanged")
	check(ui.storage_capacity.displayed_capacity()==Vector2i(100,100),"bag preview unchanged")
	if DisplayServer.get_name()!="headless":
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/inventory-capacity-left3.png")
	ui.set_warehouse("base.warehouse.qingshizhen.home")
	await settle()
	check(ui.warehouse_pane.storage_capacity.number_offset==Vector2(-3,0),"warehouse inventory digits now also shifted left three design pixels")
	check(ui.storage_capacity.number_offset==Vector2(-3,0),"shared carry bag keeps offset in warehouse")
	check(ui.warehouse_pane.storage_capacity.displayed_capacity()==Vector2i(100,100),"warehouse preview unchanged")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/warehouse-capacity-left3.png")
	check(map.loadout.snapshot()==before,"inventory and occupancy untouched")
	map.queue_free()
	await settle()
	print("CAPACITY LEFT: %d checks, %d failures; static only" % [checks,failures])
	quit(1 if failures else 0)
