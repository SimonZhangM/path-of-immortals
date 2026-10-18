extends "res://tests/map_shop_tests.gd"

const SWORD := "base.map_item.qingshi_short_sword"
const KNIFE := "base.map_item.t01_0002"
const HOME := "base.warehouse.qingshizhen.home"

func clone(state: MapLoadoutState) -> MapLoadoutState:
	var copy: MapLoadoutState = MapLoadoutStore.candidate(state).state
	copy.records = copy.records.duplicate(true)
	return copy

func verify_prices(state: MapLoadoutState, shop: MapShop) -> void:
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MapShop.PRICES_PATH)).prices
	var proposal: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/sources/item-base-price-proposal-2026-10-12.json"))
	var revised := {"base.map_item.hemostatic_pill":9,"base.map_item.t01_0078":72,"base.map_item.t01_0094":64}
	for index in range(106,111): revised["base.map_item.t01_%04d" % index] = 10
	for index in 5: revised["base.map_item.t01_%04d" % (111+index)] = [10,14,16,18,18][index]
	check(table.size()==142 and state.records.size()==142,"complete current inventory priced")
	for entry: Dictionary in proposal.entries:
		var id: String = entry.item_id
		var base := int(revised.get(id,entry.base_price))
		check(table.has(id) and int(table[id])==base,"approved baseline and targeted change: "+id)
		check(shop.pricing.buy_unit_price(id)==ceili(base*1.5) and shop.pricing.sell_unit_price(id)==floori(base*.5),"ceil buy / floor sell: "+id)
	check(shop.buy_unit_price(SWORD)==90,"base price supersedes old sample quote")
	check(shop.pricing.buy_unit_price("base.map_item.hemostatic_pill")==14 and shop.pricing.sell_unit_price("base.map_item.hemostatic_pill")==4,"odd price rounding")
	for key in ["weapon","armor"]:
		var rows := shop.products(key)
		var expected := 9 if key=="weapon" else 10
		check(rows.size()==expected,"state-source stock entries "+key)
		check(rows.filter(func(r): return state.records[r.item_id].quality=="下品").size()==6,"six lower-grade "+key)
		check(rows.filter(func(r): return state.records[r.item_id].quality=="凡品").size()==expected-6,"ordinary-grade stock including state sources "+key)
	for row: Dictionary in shop.products(): check(shop.buy_unit_price(row.item_id)>0 and not row.has("preview_buy_price"),"all stock uses approved prices")
	for name in ["qingshizhen_herbalist","qingshizhen_sect","qingshizhen_blacksmith","qingshizhen_alchemy"]:
		var other := MapShop.new()
		check(other.load_catalog("res://data/shops/%s.json" % name,state).is_empty(),"shared pricing catalog "+name)
		for row: Dictionary in other.products(): check(other.buy_unit_price(row.item_id)>0,"other catalog quote ready")

func verify_sales(map: Node, shop: MapShop) -> void:
	var state := clone(map.loadout)
	var next := state.snapshot()
	next.placements = []
	for index in 5: next.owned_units["sale-test.%d" % index] = SWORD
	next.placements = [{"instance_id":"sale-test.0","item_id":SWORD,"cell":[0,0],"unit_ids":["sale-test.0"]}]
	next.warehouses = {HOME:{"sale-test.1":SWORD}}
	check(state.restore(next).is_empty(),"fixture includes same item on board, at home and in bag")
	var before := state.snapshot()
	for qty in [0,-1,1000,count(state,SWORD)+1]:
		check(not shop.sell(state,SWORD,qty,"").is_empty(),"invalid/over-owned quantity rejected")
	for id in ["base.unknown","base.map_item.warm_jade"]:
		check(not shop.sell(state,id,1,"").is_empty(),"unknown / out of scope rejected")
	check(state.snapshot()==before,"rejection never changes money or ownership")
	state.inventory.locked = true
	check(not shop.sell(state,SWORD,1,"").is_empty(),"locked state rejected")
	state.inventory.locked = false
	for flag in ["favorite","key_item","quest_item"]:
		state.records[SWORD][flag] = true
		check(not shop.sell(state,SWORD,1,"").is_empty(),"protected command rejected: "+flag)
		check(not shop.sale_items(state).any(func(r): return r.item_id==SWORD),"protected item absent from UI")
		state.records[SWORD][flag] = false
	check(not shop.sell(state,SWORD,2,"res://artifacts/no-shop-directory/sale.json").is_empty(),"save failure propagated")
	check(state.snapshot()==before,"save failure atomic")
	var missing := MapShop.new()
	check(missing.configure(shop.definition,state,null,{"prices":{}}).is_empty(),"missing-price fixture")
	check(not missing.sell(state,SWORD,1,"").is_empty() and state.snapshot()==before,"no free sale of unpriced item")
	state.spirit_stones = 1000000000
	check(not shop.sell(state,SWORD,1,"").is_empty() and state.spirit_stones==1000000000,"wallet overflow prevented")
	check(state.restore(before).is_empty(),"restore wallet fixture")
	var path := "res://artifacts/shop-sale-%d.json" % Time.get_ticks_usec()
	var amount := count(state,SWORD)
	var wallet := state.spirit_stones
	check(shop.sell(state,SWORD,2,path).is_empty(),"sale commits")
	check(count(state,SWORD)==amount-2 and state.spirit_stones==wallet+60,"exact count removed / base-half credit")
	check(state.snapshot().placements==before.placements and state.warehouses==before.warehouses,"equipped and warehouse copies preserved")
	check(state.calendar==before.calendar and state.granted_rewards==before.get("granted_rewards",{}),"sale preserves date and reward receipts")
	var loaded := clone(map.loadout)
	check(MapLoadoutStore.load_into(loaded,path).is_empty() and loaded.snapshot()==state.snapshot(),"sale persists once across reload")
	check(shop.sell(state,SWORD,count(state,SWORD),path).is_empty(),"sell remaining carried copies")
	var sold_out := state.snapshot()
	check(not shop.sell(state,SWORD,1,path).is_empty() and state.snapshot()==sold_out,"stale repeat cannot sell equipped or stored copies")
	check(shop.product(KNIFE).is_empty() and count(state,KNIFE)>0,"non-stock weapon fixture")
	check(shop.sell(state,KNIFE,1,"").is_empty(),"accepts unstocked item in correct category")
	var priced := MapShop.new()
	check(priced.configure(shop.definition,state,null,{"prices":{SWORD:101}}).is_empty(),"isolated factor fixture")
	check(priced.pricing.set_factors(12500,6500).is_empty(),"effective factor hook")
	next = state.snapshot()
	next.owned_units["sale-factor.0"] = SWORD
	check(state.restore(next).is_empty(),"factor sale unit")
	wallet = state.spirit_stones
	check(priced.sell(state,SWORD,1,"").is_empty() and state.spirit_stones==wallet+65,"sale uses current factor with floor rounding")

func interaction_sales(map: Node, dialog: MapShopDialog) -> void:
	var snapshot: Dictionary = map.loadout.snapshot()
	var buy_rect := dialog.buy_button.get_rect()
	await click(dialog.sell_button)
	check(dialog.selling and dialog.buy_label.text=="出售" and not dialog.buy_button.disabled,"actual sell tab/button")
	check("|".join(dialog.filters.values().map(func(b): return b.text))=="武器|防具|食物|杂货","categories unchanged")
	check(dialog._visible_products.size()==8 and not dialog.next_button.disabled,"eight-item sale pagination")
	check(dialog.buy_button.texture_normal.atlas.resource_path.ends_with("cangku1.webp") and dialog.buy_button.texture_hover.atlas.resource_path.ends_with("cangku2.webp"),"sale art pair")
	var motion := InputEventMouseMotion.new()
	motion.position = dialog.buy_button.get_global_rect().get_center()
	root.push_input(motion,true)
	await settle()
	check(dialog.buy_label.get_theme_color("font_color")==Color.BLACK,"sale hover black caption")
	await click(dialog.next_button)
	check(dialog.page==1,"sale next page")
	await click(dialog.previous_button)
	await click(dialog.slots[1])
	var id := dialog.selected_id
	var amount := count(map.loadout,id)
	var wallet: int = map.loadout.spirit_stones
	var shop: MapShop = map.shops[EVENT]
	var price := shop.pricing.sell_unit_price(id)
	check(dialog.details.get_node("AvailableQuantity").text=="可售数量：%d" % amount,"actual detail quantity")
	check(dialog.price_label.text==str(price),"actual sell price")
	dialog.change_quantity(10000)
	check(dialog.quantity==mini(amount,999) and dialog.plus_button.disabled,"owned quantity cap")
	var sold := dialog.quantity
	await click(dialog.buy_button)
	check(count(map.loadout,id)==amount-sold and map.loadout.spirit_stones==wallet+price*sold,"native sell callback changes money and units")
	check(dialog.message.text.contains("已出售") and map.player_status.spirit_stones==map.loadout.spirit_stones,"receipt and status header sync")
	check(dialog.selected_id.is_empty() and dialog.buy_button.disabled,"sold-out selection cleared, no automatic next-item sale")
	var after: Dictionary = map.loadout.snapshot()
	await click(dialog.buy_button)
	dialog.buy_button.pressed.emit()
	check(map.loadout.snapshot()==after,"extra click on sold-out checkout harmless")
	await click(dialog.buy_tab)
	check(not dialog.selling and dialog.buy_button.get_rect().is_equal_approx(buy_rect),"purchase mode geometry restored")
	var funded: Dictionary = map.loadout.snapshot()
	funded.spirit_stones = 10000
	check(map.loadout.restore(funded).is_empty(),"isolated purchase funds")
	await click(dialog.slots[4])
	id = dialog.selected_id
	amount = count(map.loadout,id)
	price = shop.buy_unit_price(id)
	await click(dialog.buy_button)
	check(count(map.loadout,id)==amount+1 and map.loadout.spirit_stones==10000-price,"newly priced stock can be purchased")
	for category in ["food","grocery"]:
		await click(dialog.filters[category])
		check(dialog.selected_id.is_empty() and dialog.details.get_child_count()==0 and dialog.buy_button.disabled,"empty buy category")
		await click(dialog.sell_button)
		check(dialog._visible_products.is_empty() and dialog.buy_button.disabled,"empty sell category")
		await click(dialog.buy_tab)
	await click(dialog.filters.armor)
	await click(dialog.sell_button)
	check(dialog.category=="armor" and dialog._visible_products.all(func(r): return r.category=="armor"),"sell category retained")
	check(map.loadout.restore(snapshot).is_empty(),"restore isolated native-input fixture")
	await settle()

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
	check(map.loadout.restore(map.loadout.snapshot()).is_empty(),"normalize isolated state")
	var before: Dictionary = map.loadout.snapshot()
	var shop: MapShop = map.shops[EVENT]
	verify_prices(map.loadout,shop)
	map.travel.current_node_id = POINT
	map.travel.map_position = map.travel.node_positions[POINT]
	map.travel.mode = "idle"
	check(map._try_start_event(POINT,"click",true),"map shop entry opens")
	await settle()
	var dialog: MapShopDialog = map.shop_dialog
	if DisplayServer.get_name()=="headless":
		verify_sales(map,shop)
		transactions(map)
		await interaction_sales(map,dialog)
	else:
		dialog.set_selling(true)
		await settle()
		check(not dialog.buy_button.disabled and dialog.price_label.text!="待定","priced sale checkout")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/shop-sale-enabled.png")
		dialog.set_selling(false)
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/shop-priced-stock.png")
	check(map.loadout.snapshot()==before,"player save untouched / fixture restored")
	map.queue_free()
	await settle()
	print("SHOP TRANSACTIONS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
