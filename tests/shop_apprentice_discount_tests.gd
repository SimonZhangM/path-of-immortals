extends "res://tests/map_shop_tests.gd"

const HERBAL_EVENT := "base.map_event.qingshizhen.herbalist"
const HERBAL_POINT := "base.map.qingshizhen.point.n14"
const HERB := "base.material.zhixuecao"

func prices(map: Node) -> void:
	var shop: MapShop = map.shops[HERBAL_EVENT]
	for row: Dictionary in shop.products():
		var original := shop.pricing.buy_unit_price(row.item_id)
		for quantity in [1,2,3,10,999]:
			var quote := shop.buy_quote(row.item_id,quantity)
			check(quote.original_unit==original and quote.original_total==original*quantity,"original quote preserved")
			check(quote.unit_price==ceili(original*.8) and quote.total==ceili(original*quantity*.8),"separate unit/order rounding "+row.item_id+" x"+str(quantity))
		check(shop.pricing.sell_unit_price(row.item_id)==floori(original/1.5*.5),"discount never changes sale quote")
	check(shop.buy_unit_price(HERB)==5 and shop.buy_quote(HERB,10).total==48,"6 quoted as 5 singly, ten cost 48 not 50")
	check(shop.buy_quote(HERB,2).total==10 and shop.buy_quote(HERB,3).total==15,"fractional order rounds upward")
	check(shop.buy_quote("base.unknown").is_empty() and shop.buy_quote(HERB,0).is_empty() and shop.buy_quote(HERB,1000).is_empty(),"invalid quote rejected")
	var snapshot: Dictionary = map.loadout.snapshot()
	shop.pricing.set_factors(16000,5000)
	check(shop.buy_quote(HERB,10).original_unit==7 and shop.buy_quote(HERB,10).total==56,"discount applies to current full-price quote after factor rounding")
	shop.pricing.set_factors(15000,5000)
	for other: MapShop in map.shops.values():
		if other==shop: continue
		check(not other.definition.has("purchase_discount"),"other shop has no apprentice benefit")
		for product: Dictionary in other.products():
			check(other.buy_quote(product.item_id,10).total==other.pricing.buy_unit_price(product.item_id)*10,"other shop still full price")
	for field in ["factor_bps","label","tooltip","item_ids"]:
		var invalid := shop.definition.duplicate(true)
		invalid.purchase_discount[field] = 10001 if field=="factor_bps" else ([] if field=="item_ids" else "")
		check(not MapShop.new().configure(invalid,map.loadout).is_empty(),"invalid discount rejected "+field)
	var invalid := shop.definition.duplicate(true)
	invalid.purchase_discount.item_ids.append(HERB)
	check(not MapShop.new().configure(invalid,map.loadout).is_empty(),"duplicate eligible ID rejected")
	var unlisted := shop.definition.duplicate(true)
	unlisted.purchase_discount.item_ids.erase(HERB)
	var no_discount := MapShop.new()
	check(no_discount.configure(unlisted,map.loadout).is_empty() and no_discount.buy_quote(HERB,10).total==60,"unlisted items excluded even in same shop")
	var missing := MapShop.new()
	check(missing.configure(shop.definition,map.loadout,null,{"prices":{}}).is_empty() and missing.buy_quote(HERB).is_empty(),"missing price not discounted into free item")
	check(map.loadout.snapshot()==snapshot,"quoting leaves player state untouched")
	var state: MapLoadoutState = MapLoadoutStore.candidate(map.loadout).state
	state.spirit_stones = 47
	snapshot = state.snapshot()
	check(not shop.purchase(state,HERB,10,"").is_empty() and state.snapshot()==snapshot,"47 cannot pay 48; no mutation")
	state.spirit_stones = 48
	snapshot = state.snapshot()
	check(not shop.purchase(state,HERB,10,"res://artifacts/no-apprentice-directory/save.json").is_empty() and state.snapshot()==snapshot,"discounted purchase save failure stays atomic")

func run() -> void:
	create_timer(40).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(2560,1440)
	var map = load("res://scenes/maps/qingshizhen.tscn").instantiate()
	map.inventory_save_path = ""
	map.defer_map_music = true
	root.add_child(map)
	map.set_process(false)
	await settle()
	check(map.startup_error.is_empty(),"town loaded")
	if not map.startup_error.is_empty(): quit(1); return
	if DisplayServer.get_name()=="headless": prices(map)
	map.travel.current_node_id = HERBAL_POINT
	map.travel.mode = "idle"
	map.loadout.spirit_stones = 48
	check(map._try_start_event(HERBAL_POINT,"click",true),"actual herbalist entry")
	var dialog: MapShopDialog = map.shop_dialog
	dialog.set_selling(false)
	dialog.quantity = 10
	dialog.refresh_checkout()
	await settle()
	check(dialog.price_label.text=="5" and dialog.total_label.text=="48","UI uses single 5, order 48")
	check(dialog.price_label.get_meta("original_price_label").text=="6" and dialog.total_label.get_meta("original_price_label").text=="60","struck originals 6 and 60")
	for label: Label in [dialog.price_label,dialog.total_label]:
		var old: Label = label.get_meta("original_price_label")
		check(old.visible and old.get_node("PriceStrike").visible,"original strikethrough visible")
		check(label.get_theme_color("font_color")==dialog.apprentice_label.get_theme_color("font_color"),"discount price matches badge green")
		check(label.get_parent().get_combined_minimum_size().x<=145,"original and current price fit checkout")
	check(dialog.apprentice_badge.visible and dialog.apprentice_label.text=="学徒待遇","herbalist benefit badge")
	check(dialog.apprentice_badge.get_theme_stylebox("panel","TooltipPanel")==map.calendar_readout.get_theme_stylebox("panel","TooltipPanel"),"simple tooltip matches existing style")
	check(dialog.apprentice_badge.tooltip_text.contains("八折") and dialog.apprentice_label.mouse_filter==Control.MOUSE_FILTER_IGNORE,"authored benefit explanation")
	check(dialog.balance_label.text=="48" and dialog.balance_row.get_child(1).get_child(0).texture.atlas.resource_path.ends_with("tanchuang-jiaoyi-coin.webp"),"balance coin immediately before numeric value")
	check(not dialog.balance_row.get_global_rect().intersects(dialog.sell_button.get_global_rect()),"wallet clear of third tab")
	check(dialog.apprentice_badge.get_global_rect().end.y<dialog.balance_row.get_global_rect().position.y,"benefit above wallet")
	var before: Dictionary = map.loadout.snapshot()
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/shop-apprentice-ten.png")
	else:
		var move := InputEventMouseMotion.new()
		move.position = dialog.apprentice_badge.get_global_rect().get_center()
		root.push_input(move,true)
		await settle()
		check(root.gui_get_hovered_control()==dialog.apprentice_badge,"new badge can be hovered")
		var amount := count(map.loadout,HERB)
		var save_path := "res://artifacts/shop-apprentice-%d.json" % Time.get_ticks_usec()
		map.inventory_save_path = save_path
		await click(dialog.buy_button)
		check(count(map.loadout,HERB)==amount+10 and map.loadout.spirit_stones==0,"actual map click buys ten for 48")
		check(JSON.parse_string(FileAccess.get_file_as_string(save_path)).spirit_stones==0,"discounted payment saved")
		check(dialog.balance_label.text=="0","wallet refreshes after purchase")
		await click(dialog.buy_button)
		check(count(map.loadout,HERB)==amount+10 and map.loadout.spirit_stones==0,"insufficient repeat cannot buy again")
	dialog.set_selling(true)
	await settle()
	check(not dialog.price_label.get_meta("original_price_label").visible and not dialog.total_label.get_meta("original_price_label").visible,"sale clears discount originals")
	for event_id: String in map.shops:
		if event_id==HERBAL_EVENT: continue
		dialog.present(map.event_registry.events[event_id],map.shops[event_id],map.loadout,map.player_status)
		await settle()
		check(not dialog.apprentice_badge.visible,"benefit never leaks to another shop")
		check(not dialog.price_label.get_meta("original_price_label").visible,"ordinary quote clears strikethrough")
		var wallet_y := 194 if dialog.conversation_tab.visible and dialog.craft_tab.visible else 260
		check(dialog.balance_row.get_rect()==Rect2(Vector2(1224,wallet_y)-dialog.FRAME.position,Vector2(192,28)),"wallet uses upper position only for four-tab shop")
		check(not dialog.balance_row.get_global_rect().intersects((dialog.craft_tab if dialog.craft_tab.visible else dialog.sell_button).get_global_rect()),"wallet avoids mode tabs")
		if DisplayServer.get_name()!="headless" and event_id==EVENT:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/shop-wallet-aligned.png")
	if DisplayServer.get_name()!="headless": check(map.loadout.snapshot()==before,"static views leave money/inventory unchanged")
	map.queue_free()
	await settle()
	print("SHOP APPRENTICE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
