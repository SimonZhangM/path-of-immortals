extends "res://tests/map_shop_tests.gd"

const ALCHEMY := "base.map_event.qingshizhen.alchemy"
const ALCHEMY_POINT := "base.map.qingshizhen.point.n12"
const PILL := "base.map_item.hemostatic_pill"

func open_store(map: Node, point: String) -> void:
	map.travel.current_node_id = point
	map.travel.map_position = map.travel.node_positions[point]
	map.travel.mode = "idle"
	map.travel.node_arrived.emit(point)
	await settle()
	check(not map.event_state.is_active() and not map.shop_dialog.visible,"arrival does not open shop")
	map.content.position = map.map_viewport.size*0.5-map.travel.map_position*map.content.scale
	map._select_destination(map.map_to_screen(map.travel.map_position))
	await settle()
	check(map.shop_dialog.visible and map.travel.paused,"node click opens shop")

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
	check(map.startup_error.is_empty(),"town startup: "+map.startup_error)
	if not map.startup_error.is_empty(): quit(1); return
	check(map.shops.size()==5,"five trading places registered")
	var point = map.find_child("N12",true,false)
	check(point.location_note=="炼丹房" and point.position==Vector2(2804,792),"red-box node is alchemy room")
	check(map.find_child("N14",true,false).location_note=="药材铺","red-box node remains herbalist")
	var fixture: Dictionary = map.loadout.snapshot()
	fixture.spirit_stones = 1000
	check(map.loadout.restore(fixture).is_empty(),"isolated money fixture")
	var headless := DisplayServer.get_name()=="headless"
	if headless: map.inventory_save_path = "res://artifacts/alchemy-%d.json" % Time.get_ticks_usec()
	var shop: MapShop = map.shops[ALCHEMY]
	var herbs: MapShop = map.shops["base.map_event.qingshizhen.herbalist"]
	check(herbs.products().size()==4 and herbs.category_for(map.loadout.records[PILL]).is_empty(),"herbs stocked and pills excluded from herbalist")
	var before: Dictionary = map.loadout.snapshot()
	check(not herbs.sell(map.loadout,PILL,1,"").is_empty() and map.loadout.snapshot()==before,"herbalist rejects direct pill sale without mutation")
	var invalid := shop.definition.duplicate(true)
	invalid.crafting_label = " "
	check(not MapShop.new().configure(invalid,map.loadout).is_empty(),"blank production label rejected")
	for category_count in [0,5]:
		var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MapShop.RULES_PATH))
		rules.profiles[shop.definition.profile].categories.resize(category_count)
		check(not MapShop.new().configure(shop.definition,map.loadout,rules).is_empty(),"category count outside 1-4 rejected")
	await open_store(map,ALCHEMY_POINT)
	var dialog: MapShopDialog = map.shop_dialog
	check(map.event_state.active_id==ALCHEMY,"opens alchemy event")
	check(dialog.title_label.text=="炼丹房" and dialog.leave_button.text=="离开炼丹房","alchemy captions")
	check("|".join(dialog.filters.values().map(func(b):return b.text))=="丹药|丹方","two approved alchemy categories")
	check(dialog.craft_tab.visible and dialog.craft_tab.text=="炼丹","third interaction labeled alchemy")
	check(dialog._visible_products.size()==3 and dialog.selected_id==PILL,"three existing pills transferred")
	check(dialog.backing.texture.atlas.resource_path.ends_with("liandanfang.webp") and dialog.illustration.texture.resource_path.ends_with("liandanfang-boss.webp"),"dedicated artwork")
	for texture: Texture2D in [dialog.backing.texture.atlas,dialog.illustration.texture]: check(texture.get_image().has_mipmaps(),"new art mipmaps")
	if headless:
		var amount := count(map.loadout,PILL)
		var wallet: int = map.loadout.spirit_stones
		await click(dialog.buy_button)
		check(count(map.loadout,PILL)==amount+1 and map.loadout.spirit_stones==wallet-shop.buy_unit_price(PILL),"pill purchase commits")
		await click(dialog.sell_button)
		while not dialog._visible_products.any(func(p):return p.item_id==PILL) and not dialog.next_button.disabled:
			await click(dialog.next_button)
		var slot := dialog._visible_products.find_custom(func(p):return p.item_id==PILL)
		check(slot>=0,"purchased pill can be sold here")
		if slot>=0: await click(dialog.slots[slot])
		await click(dialog.buy_button)
		check(count(map.loadout,PILL)==amount and map.loadout.spirit_stones==wallet-shop.buy_unit_price(PILL)+shop.pricing.sell_unit_price(PILL),"pill sale commits")
		var reloaded: MapLoadoutState = MapLoadoutStore.candidate(map.loadout).state
		check(MapLoadoutStore.load_into(reloaded,map.inventory_save_path).is_empty() and reloaded.snapshot()==map.loadout.snapshot(),"alchemy trades persist after reload")
		await click(dialog.filters.pill_recipe)
		check(dialog._visible_products.is_empty() and dialog.buy_button.disabled,"recipe category empty")
		await click(dialog.craft_tab)
	else:
		await capture("alchemy-buy")
		dialog.set_selling(true)
		await capture("alchemy-sell")
		dialog.set_crafting()
	check(dialog.crafting and dialog.crafting_panel.visible and dialog.crafting_panel.get_child_count()==0,"alchemy page is empty reserved container")
	check(dialog.buy_button.disabled and dialog.trade_controls.all(func(c):return not c.visible),"alchemy page hides and disables trade")
	if headless:
		var snapshot: Dictionary = map.loadout.snapshot()
		dialog.purchase_requested.emit(PILL,1)
		dialog.sale_requested.emit(PILL,1)
		check(map.loadout.snapshot()==snapshot,"alchemy placeholder cannot transact")
		await click(dialog.buy_tab)
		check(not dialog.crafting and dialog.filters.pill.visible,"return from alchemy restores trading")
		await click(dialog.leave_button)
	else:
		await capture("alchemy-empty")
		map._close_shop()
	check(not map.event_state.is_active() and not map.travel.paused,"leave restores travel")
	await open_store(map,"base.map.qingshizhen.point.n14")
	check("|".join(dialog.filters.values().map(func(b):return b.text))=="药材|诱饵" and not dialog.craft_tab.visible,"herbalist has two categories without production tab")
	check(dialog._visible_products.size()==4,"four approved herbs stocked")
	if not headless: await capture("herbalist-two-categories")
	map._close_shop()
	if headless:
		await open_store(map,"base.map.qingshizhen.point.n23")
		check(dialog.craft_tab.visible and dialog.craft_tab.text=="打造" and dialog.filters.size()==4,"blacksmith still says crafting and keeps four categories")
		map._close_shop()
	check(map.loadout.calendar==before.calendar,"no calendar advancement")
	if not headless:
		# Visiting the two fixture nodes legitimately updates the saved map position.
		var after: Dictionary = map.loadout.snapshot()
		before.erase("map_location")
		after.erase("map_location")
		check(after==before,"render does not transact")
	map.queue_free()
	await settle()
	root.get_node("UiButtonAudio").player.stop()
	await create_timer(0.1).timeout
	print("ALCHEMY SHOP: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
