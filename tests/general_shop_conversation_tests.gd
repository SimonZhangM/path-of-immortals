extends "res://tests/map_shop_tests.gd"

func capture(name: String) -> void:
	await settle()
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/"+name+".png")

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
	check(map.startup_error.is_empty(),"town loads with updated shop art")
	if not map.startup_error.is_empty(): quit(1); return
	map.travel.current_node_id = POINT
	map.travel.mode = "idle"
	map.loadout.spirit_stones = 1000
	check(map._try_start_event(POINT,"click",true),"N16 opens shop")
	var shop: MapShopDialog = map.shop_dialog
	var talk: MapClinicDialog = shop.conversation_view
	check(talk!=null and shop.conversing and not shop.canvas.visible,"default conversation uses one visible canvas")
	check(talk.library!=null and talk.library.definition.id=="base.npc.qianwanshun" and talk.dialogue_rows.get_child_count()>0 and talk.continue_button.visible,"authored merchant welcome loaded")
	for button: Button in talk.topic_buttons.values(): check(not button.visible,"topics hidden during welcome")
	check(talk.backing.texture.atlas.resource_path.ends_with("tanchuang-qingshizhen-shangpu2.webp"),"conversation uses new second art")
	check(shop.backing.texture.atlas.resource_path.ends_with("tanchuang-qingshizhen-shangpu.webp"),"trade uses new first art")
	for path in ["res://assets/tanchuang-qingshizhen-shangpu.webp.import","res://assets/tanchuang-qingshizhen-shangpu2.webp.import"]:
		var config := ConfigFile.new()
		check(config.load(path)==OK and config.get_value("params","mipmaps/generate",false),"new art has mipmaps")
	var before: Dictionary = map.loadout.snapshot()
	await capture("general-shop-conversation")
	if DisplayServer.get_name()=="headless": await click(talk.canvas.get_node("ShopBuyTab"))
	else: shop.set_selling(false)
	check(not shop.conversing and not shop.selling and shop.canvas.visible and not talk.visible,"second tab opens buying")
	check(shop.buy_tab.position.x==828-shop.FRAME.position.x and shop.sell_button.position.x==1025-shop.FRAME.position.x,"buy and sell aligned to second and third slots")
	check(shop._visible_products.size()==9,"original weapons plus lightning bow")
	await capture("general-shop-buy")
	if DisplayServer.get_name()=="headless":
		var item: String = shop.selected_id
		var amount := count(map.loadout,item)
		var price := shop.shop.buy_unit_price(item)
		await click(shop.buy_button)
		check(count(map.loadout,item)==amount+1 and map.loadout.spirit_stones==1000-price,"purchase still works from second tab")
		await click(shop.sell_button)
		var index: int = shop._visible_products.find_custom(func(row): return row.item_id==item)
		while index<0 and not shop.next_button.disabled:
			shop.change_page(1)
			await settle()
			index = shop._visible_products.find_custom(func(row): return row.item_id==item)
		check(index>=0,"purchased item available to sell")
		if index>=0: await click(shop.slots[index])
		await click(shop.buy_button)
		check(count(map.loadout,item)==amount and map.loadout.spirit_stones==1000-price+shop.shop.pricing.sell_unit_price(item),"sale still works from third tab")
	else: shop.set_selling(true)
	check(shop.selling and not shop.conversing,"third tab opens sale")
	if DisplayServer.get_name()=="headless": await click(shop.conversation_tab)
	else: shop.set_conversation()
	check(shop.conversing and talk.visible and talk.library!=null,"can return to merchant conversation")
	check(map.loadout.narrative==before.narrative,"trading tabs do not advance dialogue")
	if DisplayServer.get_name()=="headless":
		await click(talk.leave_button)
		check(not shop.visible and not map.travel.paused,"leave resumes map")
	else: check(map.loadout.snapshot()==before,"render mode never trades or saves")
	map.queue_free()
	await settle()
	root.get_node("UiButtonAudio").player.stop()
	await create_timer(0.1).timeout
	print("GENERAL SHOP CONVERSATION: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
