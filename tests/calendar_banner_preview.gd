extends "res://tests/item_selection_tooltip_tests.gd"

func run() -> void:
	create_timer(35).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(2560,1440)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	var map = load("res://scenes/maps/qingshizhen.tscn").instantiate()
	map.inventory_save_path = ""
	map.defer_map_music = true
	root.add_child(map)
	map.set_process(false)
	await settle()
	check(map.startup_error.is_empty(),"map ready")
	check(not map.calendar_readout.visible,"travel date remains hidden")
	var before: Dictionary = map.loadout.snapshot()
	var ui: MapInventoryScreen = map.inventory_screen
	var banner: MapCalendarReadout = map.calendar_readout
	ui.show()
	await settle()
	check(banner.caption.text == "青鹿年·正月初一","date shows only year month day")
	check(banner.tooltip_text.contains("第一纪"),"full date tooltip retained")
	check((banner.artwork.texture as AtlasTexture).atlas.get_image().has_mipmaps(),"banner mipmaps enabled")
	var original_size := banner.source_region.size*(390.0*(2560.0/1920.0)/banner.source_region.size.x)
	var original_position := Vector2(roundf(2560-original_size.x-16*(2560.0/1920.0)),roundf(MapStatusHeader.height_for_width(2560)+2560.0/1920.0))
	check(banner.get_global_rect().get_center().distance_to(original_position+original_size*0.5)<0.01,"banner keeps original center")
	check(banner.size.distance_to(original_size*0.9)<0.01,"banner reduced ten percent")
	check(banner.caption.get_theme_font_size("font_size")==23,"date font one design size smaller")
	check("KaiTi" in (banner.caption.get_theme_font("font") as SystemFont).font_names,"date uses KaiTi")
	check(ui.board_capacity.displayed_capacity()==Vector2i(99,99),"board occupancy preview only")
	check(ui.board_capacity.total==9 and ui.board_capacity.occupied==0,"actual empty board occupancy retained")
	check(ui.storage_capacity.number_offset==Vector2(-3,0),"bag digits shifted left three design pixels")
	for mode in ["inventory","warehouse"]:
		if mode == "warehouse": ui.set_warehouse("base.warehouse.qingshizhen.home")
		await settle()
		check(banner.is_visible_in_tree(),"banner visible in "+mode)
		check(banner.get_global_rect().end.y <= ui.storage_panel.get_global_rect().position.y,"banner clears panel headings")
		check(banner.get_global_rect().end.x <= root.size.x,"banner within viewport")
		if mode == "warehouse":
			check(banner.get_global_rect().position.x > ui.warehouse_actions.deposit_all_button.get_global_rect().end.x+6,"banner clears deposit buttons")
			check(ui.warehouse_pane.storage_capacity.number_offset==Vector2(-3,0),"updated warehouse numeric well shifted left three pixels")
		check(banner.caption.get_minimum_size().x <= banner.caption.size.x,"date fits between mountains")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/calendar-banner-%s.png" % mode)
	ui.hide()
	await settle()
	check(not banner.visible,"return to travel hides banner")
	check(map.loadout.snapshot() == before,"inventory and calendar unchanged")
	map.queue_free()
	await settle()
	print("CALENDAR BANNER: ",checks," checks, ",failures," failures; static only")
	quit(1 if failures else 0)
