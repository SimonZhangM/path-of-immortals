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
	check(map.startup_error.is_empty(),"town ready")
	var before: Dictionary = map.loadout.snapshot()
	var dialog: MapShopDialog = map.shop_dialog
	dialog.present(JSON.parse_string(FileAccess.get_file_as_string("res://data/map_events/qingshizhen_shop.json")),map.shops[EVENT],map.loadout)
	await settle()
	var expected := [Rect2(624,233,192,49),Rect2(828,233,185,49)]
	var tabs := [dialog.buy_tab,dialog.sell_button]
	for index in tabs.size():
		var tab: Button = tabs[index]
		check(tab.position+dialog.FRAME.position==expected[index].position and tab.size==expected[index].size,"mode text centered in new source frame")
		check(tab.alignment==HORIZONTAL_ALIGNMENT_CENTER,"text stays centered")
		check(tab.get_theme_font_size("font_size")==28 and tab.get_theme_font("font").font_names[0]=="SimHei","original blackface font and size retained")
		check(tab.pressed.has_connections(),"existing mode callback retained")
	check(dialog.title_label.position==Vector2(704,107)-dialog.FRAME.position,"shop heading unchanged")
	check(dialog.slot_frames[0].position==dialog.SLOT_ORIGIN-dialog.FRAME.position,"product grid unchanged")
	check(load("res://assets/tanchuang-jiaoyi-qingshizhen-shangpu.webp").get_image().has_mipmaps(),"updated artwork mipmaps")
	for selling in [false,true]:
		# Static display of both modes, no mouse events or transactions.
		dialog.set_selling(selling)
		await settle()
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/shop-mode-frame-%s.png" % ("sell" if selling else "buy"))
	check(map.loadout.snapshot()==before,"money items and date unchanged")
	map.queue_free()
	await settle()
	print("SHOP MODE FRAME: %d checks, %d failures; static only" % [checks,failures])
	quit(1 if failures else 0)
