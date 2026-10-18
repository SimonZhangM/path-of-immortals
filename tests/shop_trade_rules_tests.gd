extends "res://tests/map_shop_tests.gd"

const CATALOGS := ["qingshizhen_shop","qingshizhen_herbalist","qingshizhen_sect","qingshizhen_blacksmith","qingshizhen_alchemy"]
const LABELS := ["武器|防具|食物|杂货","药材|诱饵","法器|符箓|阵盘|功法","矿石|材料|暗器|器方","丹药|丹方"]

func verify_data(state: MapLoadoutState) -> Array[MapShop]:
	var shops: Array[MapShop] = []
	var ids := {}
	for index in CATALOGS.size():
		var shop := MapShop.new()
		check(shop.load_catalog("res://data/shops/%s.json" % CATALOGS[index],state).is_empty(),"catalog valid "+CATALOGS[index])
		shops.append(shop)
		check("|".join(shop.categories().map(func(row): return row.label))==LABELS[index],"approved ordered tabs")
		check(shop.products().size()==[19,4,3,4,3][index],"approved stock including herbs and ores")
		for row: Dictionary in shop.products():
			check(not ids.has(row.item_id),"sample not duplicated across shops")
			ids[row.item_id] = true
			check(shop.category_for(state.records[row.item_id])==row.category,"stock matches venue scope")
			check(shop.buy_quote(row.item_id).original_unit==shop.pricing.buy_unit_price(row.item_id),"undiscounted stock quote uses approved base price")
			check(shop.pricing.sell_unit_price(row.item_id)>0,"stock has an approved sale quote")
	check(ids.size()==33,"five catalogs contain 33 stock entries")
	for record: Dictionary in state.records.values():
		var venues := shops.filter(func(shop): return not shop.category_for(record).is_empty())
		check(venues.size()==1,"one intended venue for existing item "+record.name)
		var expected: int = {"weapon":0,"armor":0,"plant":1,"pill":4,"artifact":2,"board":2,"mineral":3,"beast":3,"throwable":3}[record.category]
		check(venues[0]==shops[expected],"inventory taxonomy routed without mutation "+record.name)
	var raw := shops[0].definition.duplicate(true)
	raw.products.append(shops[3].products()[0])
	check(not MapShop.new().configure(raw,state).is_empty(),"general rejects blacksmith throwable")
	raw = shops[0].definition.duplicate(true)
	raw.products[0].category = "food"
	check(not MapShop.new().configure(raw,state).is_empty(),"reserved category cannot smuggle a weapon")
	raw = shops[0].definition.duplicate(true)
	raw.products = []
	check(MapShop.new().configure(raw,state).is_empty(),"empty future stock is valid")
	return shops

func verify_prices(state: MapLoadoutState, shop: MapShop) -> void:
	var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MapShop.RULES_PATH))
	var id: String = shop.products()[0].item_id
	var priced := MapShop.new()
	check(priced.configure(shop.definition,state,rules,{"prices":{id:101}}).is_empty(),"isolated base table accepted")
	check(priced.buy_unit_price(id)==152 and priced.pricing.sell_unit_price(id)==50,"101 base: buy ceil 151.5 sell floor 50.5")
	check(priced.pricing.set_factors(12500,6500).is_empty(),"future effective-factor entry")
	check(priced.buy_unit_price(id)==127 and priced.pricing.sell_unit_price(id)==65,"same base with modified buy/sell factors")
	for factor in [0,-1,1000001]:
		check(not priced.pricing.set_factors(factor,5000).is_empty(),"invalid factor refused")
		check(priced.buy_unit_price(id)==127,"invalid factor does not corrupt quote")
	var before := state.snapshot()
	state.spirit_stones = 10000
	var units := count(state,id)
	check(priced.purchase(state,id,3,"").is_empty(),"purchase uses authoritative factor")
	check(state.spirit_stones==9619 and count(state,id)==units+3,"rounded unit price multiplied by quantity")
	check(state.restore(before).is_empty(),"restore isolated fixture")
	var missing := shop.definition.duplicate(true)
	missing.products[0].erase("preview_buy_price")
	var unpriced := MapShop.new()
	check(unpriced.configure(missing,state,rules,{"prices":{}}).is_empty(),"unpriced catalog allowed")
	check(unpriced.buy_unit_price(id)==-1 and not unpriced.purchase(state,id,1,"").is_empty(),"missing price cannot be purchased as free")
	check(state.snapshot()==before,"missing price leaves state intact")
	var bad_rules := rules.duplicate(true)
	bad_rules.pricing.buy_factor_bps = 15000.5
	check(not MapShop.new().configure(shop.definition,state,bad_rules).is_empty(),"fractional basis point rejected")
	bad_rules = rules.duplicate(true)
	bad_rules.profiles[shop.definition.profile].categories[0].id = "all"
	check(not MapShop.new().configure(shop.definition,state,bad_rules).is_empty(),"all category disallowed")
	check(not MapShop.new().configure(shop.definition,state,rules,{"prices":{"base.unknown":100}}).is_empty(),"unknown base-price item rejected")
	check(not MapShop.new().configure(shop.definition,state,rules,{"prices":{id:-1}}).is_empty(),"negative base price rejected")
	check(priced.configure(shop.definition,state,rules,{"prices":{id:100}}).is_empty(),"whole base table")
	check(priced.buy_unit_price(id)==150 and priced.pricing.sell_unit_price(id)==50,"100 base: exact 150/50")

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
	var map_before: Dictionary = map.loadout.snapshot()
	var fixture: MapLoadoutState = MapLoadoutStore.candidate(map.loadout).state
	var before := fixture.snapshot()
	var shops := verify_data(fixture)
	var dialog: MapShopDialog = map.shop_dialog
	var event: Dictionary = map.event_registry.events[EVENT]
	# Other shops reuse the general art only in this isolated UI fixture.
	# They are not bound to map nodes without their own approved presentation.
	for index in shops.size():
		dialog.present(event,shops[index],fixture)
		check("|".join(dialog.filters.values().map(func(button): return button.text))==LABELS[index],"dialog uses configured labels")
		check(not dialog.filters.has("all") and dialog.category==shops[index].categories()[0].id,"first category default without all")
		check(not dialog.sell_button.disabled,"sale page available")
	dialog.present(event,shops[0],fixture)
	await settle()
	if DisplayServer.get_name()=="headless":
		verify_prices(fixture,shops[0])
		transactions(map)
		for key in ["armor","food","grocery","weapon"]:
			await click(dialog.filters[key])
			check(dialog.category==key,"new native category click "+key)
			if key in ["food","grocery"]:
				check(dialog.selected_id.is_empty() and dialog.details.get_child_count()==0 and dialog.buy_button.disabled and dialog.empty_label.visible,"empty category clears checkout and shows hint")
		var id := dialog.selected_id
		check(shops[0].pricing.set_factors(12000,5000).is_empty(),"effective buy factor changes from 150 to 120 percent")
		await settle()
		check(dialog.price_label.text=="72" and dialog.total_label.text=="72","base 60 at 120% becomes 72; UI refreshes")
		fixture.spirit_stones = 1000
		check(shops[0].purchase(fixture,id,1,"").is_empty() and fixture.spirit_stones==928,"checkout quote equals actual debit")
		check(fixture.restore(before).is_empty(),"isolated purchase cleanup")
	else:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/shop-final-categories.png")
		dialog.set_category("food")
		await settle()
		check(dialog.empty_label.visible and dialog.buy_button.disabled,"empty static preview")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/shop-empty-category.png")
	check(fixture.snapshot()==before and map.loadout.snapshot()==map_before,"no persistent wallet, inventory, bag taxonomy or calendar changes")
	map.queue_free()
	await settle()
	print("SHOP TRADE RULES: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
