extends "res://tests/map_shop_tests.gd"

func run() -> void:
	create_timer(35).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(2560,1440)
	var map = load("res://scenes/maps/qingshizhen.tscn").instantiate()
	map.inventory_save_path = ""
	map.defer_map_music = true
	root.add_child(map)
	map.set_process(false)
	await settle()
	check(map.startup_error.is_empty(),"town loads")
	var before: Dictionary = map.loadout.snapshot()
	var dialog: MapShopDialog = map.shop_dialog
	var event: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_events/qingshizhen_shop.json"))
	dialog.present(event,map.shops[EVENT],map.loadout)
	dialog.set_category("armor")
	dialog.select_slot(1)
	await settle()
	check(dialog.detail_scroll.vertical_scroll_mode==ScrollContainer.SCROLL_MODE_SHOW_NEVER,"scrollbar hidden with scrolling retained")
	check(not dialog.detail_scroll.get_v_scroll_bar().visible,"long iron armor detail has no visible scrollbar")
	check(dialog.details.size.y>dialog.detail_scroll.size.y,"long effects retained within clipped detail area")
	check(dialog.buy_label.position.y==722-32 and dialog.buy_label.get_rect().get_center().is_equal_approx(dialog.buy_button.get_rect().get_center()),"purchase art and caption retain shifted center")
	check(dialog.buy_label.get_theme_color("font_color")==Color.WHITE,"normal purchase text white")
	check(is_equal_approx(dialog.plus_button.position.x-dialog.minus_button.get_rect().end.x,92*0.8),"quantity gap reduced twenty percent")
	var rails := 0
	for child in dialog.canvas.get_children():
		if child is Line2D and str(child.name).begins_with("QuantityRail"):
			rails += 1
			check(is_equal_approx(child.points[1].x-child.points[0].x,73.6),"quantity top/bottom rails join buttons")
	check(rails==2,"two quantity rails")
	for tab: Button in [dialog.buy_tab,dialog.sell_button]+dialog.filters.values():
		check("SimHei" in (tab.get_theme_font("font") as SystemFont).font_names,"tabs use blackface")
	check(dialog.filters.armor.get_theme_color("font_color")==Color("fff4c9"),"selected tab text brighter")
	for coin: TextureRect in dialog.find_children("ShopCoin","TextureRect",true,false):
		check(is_equal_approx(coin.scale.x*coin.scale.y,0.8),"coin area reduced twenty percent")
	for art: MapItemArtwork in dialog.find_children("*","TextureRect",true,false).filter(func(node): return node is MapItemArtwork):
		var panel := art.get_parent().get_parent() as PanelContainer
		check(is_equal_approx(panel.scale.x*panel.scale.y,0.9),"item thumbnail area reduced ten percent")
		check(art.size.is_equal_approx(art.get_parent().size*0.85),"item body reduced fifteen percent within unchanged thumbnail")
	for record: Dictionary in map.loadout.records.values():
		var slot: String = record.get("subcategory","")
		if not slot.begins_with("护具·"): continue
		var item: ItemData = map.loadout.registry.get_item(record.id)
		check("护"+slot.trim_prefix("护具·") in ItemTooltip.classification_tags(item),"guard classification display renamed")
		check(item.armor_slot==slot,"equipment slot key remains stable")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/shop-visual-iron-armor.png")
		dialog.select_slot(4)
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/shop-visual-guard.png")
	check(map.loadout.snapshot()==before,"no inventory, money or calendar changes")
	map.queue_free()
	await settle()
	print("SHOP VISUAL: ",checks," checks, ",failures," failures; static only, no input")
	quit(1 if failures else 0)
