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
	var dialog: MapShopDialog = map.shop_dialog
	dialog.present(JSON.parse_string(FileAccess.get_file_as_string("res://data/map_events/qingshizhen_shop.json")),map.shops[EVENT],map.loadout)
	for category in ["weapon","armor","misc"]:
		dialog.set_category(category)
		await settle()
		var bodies := 0
		for art in dialog.find_children("*","TextureRect",true,false):
			if not art is MapItemArtwork: continue
			bodies += 1
			var area: Control = art.get_parent()
			var panel: PanelContainer = area.get_parent()
			check(art.size.is_equal_approx(area.size*0.85),"body width/height eighty-five percent: "+category)
			check(art.get_rect().get_center().is_equal_approx(area.size*0.5),"body remains centered")
			check(is_equal_approx(panel.scale.x*panel.scale.y,0.9),"quality frame scale unchanged")
			var background: TextureRect = panel.find_child("QualityBackground",true,false)
			check(background.size==panel.size,"quality background remains full size")
		check(bodies==9,"eight products and selected detail use same body scale")
		if category=="weapon" and DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/shop-item-body-85.png")
	var sample: Dictionary = map.loadout.records[dialog.selected_id]
	var regular := MapItemThumbnail.create(map,sample,58,76)
	await settle()
	check(regular.get_child(-1) is MapItemArtwork,"default warehouse thumbnail retains original hierarchy")
	check(regular.get_child(-1).scale==Vector2.ONE,"default thumbnail not scaled")
	check(map.loadout.snapshot()==before,"inventory money and date unchanged")
	map.queue_free()
	await settle()
	print("SHOP BODY: %d checks, %d failures; static only" % [checks,failures])
	quit(1 if failures else 0)
