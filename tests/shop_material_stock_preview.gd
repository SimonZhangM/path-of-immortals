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
	check(map.startup_error.is_empty(),"town startup: "+map.startup_error)
	if not map.startup_error.is_empty(): quit(1); return
	var headless := DisplayServer.get_name()=="headless"
	var fixture: MapLoadoutState = MapLoadoutStore.candidate(map.loadout).state
	fixture.spirit_stones = 1000
	var before: Dictionary = fixture.snapshot()
	var dialog: MapShopDialog = map.shop_dialog
	for key in ["shop","herbalist","sect","blacksmith","alchemy"]:
		var id: String = "base.map_event.qingshizhen."+key
		var event: Dictionary = map.event_registry.events[id]
		var shop: MapShop = map.shops[id]
		dialog.present(event,shop,fixture)
		await settle()
		check(is_equal_approx(dialog.title_label.position.y+dialog.title_label.size.y*0.5+dialog.FRAME.position.y,event.presentation.title_center_y+1),"title follows fixed logo center: "+key)
		check(dialog.backing.texture.region==dialog.FRAME and dialog.title_label.position.x==704-dialog.FRAME.position.x,"background/logo and horizontal title position unchanged")
		check(dialog.title_label.get_theme_font_size("font_size")==52,"title size unchanged")
		if key in ["herbalist","blacksmith"]:
			var category := "herb" if key=="herbalist" else "ore"
			var products := shop.products(category)
			check(products.size()==(4 if key=="herbalist" else 2),"correct material shelf size")
			check(dialog._visible_products.size()==products.size(),"materials shown on first purchase page")
			for product: Dictionary in products:
				var item: String = product.item_id
				check(shop.category_for(fixture.records[item])==category,"material category accepted")
				check(shop.buy_unit_price(item)>0,"existing approved quote available")
				if headless:
					var amount := count(fixture,item)
					var wallet := fixture.spirit_stones
					check(shop.purchase(fixture,item,1,"").is_empty(),"material can actually be purchased: "+item)
					check(count(fixture,item)==amount+1 and fixture.spirit_stones==wallet-shop.buy_unit_price(item),"material purchase balance and stock")
					check(shop.sale_items(fixture,category).any(func(p):return p.item_id==item),"purchased material also eligible for sale")
					check(shop.sell(fixture,item,1,"").is_empty(),"material can actually be sold")
					check(count(fixture,item)==amount and fixture.spirit_stones==wallet-shop.buy_unit_price(item)+shop.pricing.sell_unit_price(item),"material sale balance and stock")
		if not headless:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/shop-material-"+key+".png")
	if not headless: check(fixture.snapshot()==before,"static previews leave state unchanged")
	check(fixture.calendar==before.calendar,"no time spent on trading")
	map.queue_free()
	await settle()
	print("SHOP MATERIAL STOCK: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
