extends "res://tests/map_shop_tests.gd"

func capture(label: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/"+label+".png")

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
	check(map.startup_error.is_empty(),"four town shops load: "+map.startup_error)
	if not map.startup_error.is_empty(): quit(1); return
	check(map.shops.size()==5,"all five trading entrances registered")
	var n01 = map.find_child("N01",true,false)
	var n05 = map.find_child("N05",true,false)
	check(n01.location_note=="宗门商铺" and n01.position==Vector2(1323,148),"sect at blue-box node without relocation")
	check(n05.location_note=="修炼所" and n05.position==Vector2(1057,405),"training at red-box node without relocation")
	check(n01.get_node("Sign/LocationIcon").texture.atlas.resource_path.ends_with("map-xianmenshangpu.webp"),"sect sign moved with function")
	check(n05.get_node("Sign/LocationIcon").texture.atlas.resource_path.ends_with("map-xiuliansuo.webp"),"training sign moved with function")
	check(not map.event_registry.events.values().any(func(e): return e.point_id==n05.point_id),"training retains reserved node without shop event")
	var fixture: Dictionary = map.loadout.snapshot()
	fixture.spirit_stones = 1000
	fixture.owned_units["shop.test.herb"] = "base.material.zhixuecao"
	check(map.loadout.restore(fixture).is_empty(),"isolated trade fixture")
	var headless := DisplayServer.get_name()=="headless"
	if headless: map.inventory_save_path = "res://artifacts/herbalist-sect-%d.json" % Time.get_ticks_usec()
	var dialog: MapShopDialog = map.shop_dialog
	for row in [
		["herbalist","n14","药材铺","药材|诱饵","yaocaipu","herb",["bait"]],
		["sect","n01","宗门商铺","法器|符箓|阵盘|功法","zongmenshangpu","artifact",["talisman","manual"]]
	]:
		var event_id: String = "base.map_event.qingshizhen."+row[0]
		var point: String = "base.map.qingshizhen.point."+row[1]
		var shop: MapShop = map.shops[event_id]
		map.travel.current_node_id = point
		map.travel.map_position = map.travel.node_positions[point]
		map.travel.mode = "idle"
		map.travel.node_arrived.emit(point)
		await settle()
		check(not map.event_state.is_active() and not dialog.visible,"arrival does not open "+row[0])
		map.content.position = map.map_viewport.size*0.5-map.travel.map_position*map.content.scale
		map._select_destination(map.map_to_screen(map.travel.map_position))
		await settle()
		check(map.event_state.active_id==event_id and dialog.visible and map.travel.paused,"location selection opens "+row[0])
		check(dialog.title_label.text==row[2] and not dialog.craft_tab.visible,"correct title and two trade modes")
		check("|".join(dialog.filters.values().map(func(b):return b.text))==row[3],"approved categories")
		check(dialog.backing.texture.atlas.resource_path.ends_with(row[4]+".webp") and dialog.illustration.texture.resource_path.ends_with(row[4]+"-boss.webp"),"dedicated shop artwork")
		for texture: Texture2D in [dialog.backing.texture.atlas,dialog.illustration.texture]:
			check(texture.get_image().has_mipmaps(),"artwork mipmaps")
		dialog.set_category(row[5])
		await settle()
		if row[0]=="herbalist":
			check(dialog._visible_products.size()==4,"four herbs stocked after pill transfer")
			dialog.set_selling(true)
			check(dialog._visible_products.any(func(p):return p.item_id=="base.material.zhixuecao"),"herbalist still buys herbs")
			if not headless: await capture("herbalist-sell")
			map._close_shop()
			continue
		check(dialog._visible_products.size()==3,"existing stock retained")
		if headless:
			var item: String = dialog.selected_id
			var amount := count(map.loadout,item)
			var wallet: int = map.loadout.spirit_stones
			var calendar: Dictionary = map.loadout.calendar.duplicate(true)
			await click(dialog.buy_button)
			check(count(map.loadout,item)==amount+1 and map.loadout.spirit_stones==wallet-shop.buy_unit_price(item),"actual purchase in "+row[0])
			await click(dialog.sell_button)
			while not dialog._visible_products.any(func(p):return p.item_id==item) and not dialog.next_button.disabled:
				await click(dialog.next_button)
			var slot := dialog._visible_products.find_custom(func(p):return p.item_id==item)
			check(slot>=0,"purchased item is available to sell")
			if slot>=0: await click(dialog.slots[slot])
			await settle()
			await click(dialog.buy_button)
			check(count(map.loadout,item)==amount and map.loadout.spirit_stones==wallet-shop.buy_unit_price(item)+shop.pricing.sell_unit_price(item),"actual sale in "+row[0])
			var reloaded: MapLoadoutState = MapLoadoutStore.candidate(map.loadout).state
			check(MapLoadoutStore.load_into(reloaded,map.inventory_save_path).is_empty() and reloaded.snapshot()==map.loadout.snapshot(),"trade persists after reload")
			check(map.loadout.calendar==calendar,"trading costs no days")
			if row[0]=="herbalist":
				await click(dialog.filters.herb)
				check(dialog._visible_products.any(func(p):return p.item_id=="base.material.zhixuecao"),"herbs accepted despite empty purchase shelf")
			for category in row[6]:
				await click(dialog.filters[category])
				check(dialog._visible_products.is_empty() and dialog.buy_button.disabled,"reserved category empty: "+category)
		else:
			var before: Dictionary = map.loadout.snapshot()
			await capture(row[0]+"-buy")
			dialog.set_selling(true)
			if row[0]=="herbalist": dialog.set_category("herb")
			await capture(row[0]+"-sell")
			check(map.loadout.snapshot()==before,"static previews do not transact")
		if headless: await click(dialog.leave_button)
		else: map._close_shop()
		check(not dialog.visible and not map.event_state.is_active() and not map.travel.paused,"close restores travel")
	if not headless:
		map.content.position = map.map_viewport.size*0.5-Vector2(1350,430)*map.content.scale
		await capture("town-sect-training-swap")
	map.queue_free()
	await settle()
	root.get_node("UiButtonAudio").player.stop()
	await create_timer(0.1).timeout
	print("HERBALIST / SECT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
