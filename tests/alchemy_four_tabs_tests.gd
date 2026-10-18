extends "res://tests/map_shop_tests.gd"

const ALCHEMY_POINT := "base.map.qingshizhen.point.n12"

func capture(name: String) -> void:
	await settle()
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/alchemy-four-"+name+".png")

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
	map.travel.current_node_id = ALCHEMY_POINT
	map.travel.mode = "idle"
	map.loadout.spirit_stones = 1000
	check(map._try_start_event(ALCHEMY_POINT,"click",true),"N12 opens alchemy")
	var dialog: MapShopDialog = map.shop_dialog
	var talk: MapClinicDialog = dialog.conversation_view
	var before: Dictionary = map.loadout.snapshot()
	var headless := DisplayServer.get_name()=="headless"
	check(dialog.conversing and talk.library!=null and talk.library.definition.id=="base.npc.luhuaizhen" and talk.dialogue_rows.get_child_count()>0,"default Lu Huaizhen conversation")
	check(talk.backing.texture.atlas.resource_path.ends_with("tanchuang-qingshizhen-liandanfang2.webp"),"conversation second background")
	check(talk.canvas.get_node("ShopCraftTab").text=="炼丹","fourth conversation tab")
	check(talk.continue_button.visible and talk.topic_buttons.values().all(func(b):return not b.visible),"welcome before three topics")
	for name in ["liandanfang","liandanfang2"]:
		var texture: Texture2D = load("res://assets/tanchuang-qingshizhen-"+name+".webp")
		check(texture.get_image().has_mipmaps(),"mipmaps "+name)
	await capture("conversation")
	if headless: await click(talk.canvas.get_node("ShopCraftTab"))
	else: dialog.set_crafting()
	check(dialog.crafting and not dialog.conversing and not talk.visible and dialog.canvas.visible,"conversation to crafting")
	check(dialog.backing.texture.atlas.resource_path.ends_with("liandanfang2.webp"),"crafting second background")
	check(dialog.crafting_panel.visible and dialog.crafting_panel.get_child_count()==0 and dialog.trade_controls.all(func(c):return not c.visible),"empty alchemy hides trade")
	check(dialog.craft_tab.position.x==1227-dialog.FRAME.position.x,"fourth frame alignment")
	check(not dialog.balance_row.get_global_rect().intersects(dialog.craft_tab.get_global_rect()),"wallet avoids fourth tab")
	await capture("crafting")
	if headless: await click(dialog.buy_tab)
	else: dialog.set_selling(false)
	check(not dialog.crafting and not dialog.conversing and not dialog.selling,"crafting to purchase")
	check(dialog.backing.texture.atlas.resource_path.ends_with("tanchuang-qingshizhen-liandanfang.webp"),"buy restores first background")
	check(dialog._visible_products.size()==3 and dialog.filters.size()==2,"existing pills and filters preserved")
	await capture("buy")
	if headless:
		var item: String = dialog.selected_id
		var amount := count(map.loadout,item)
		var cost := dialog.shop.buy_unit_price(item)
		await click(dialog.buy_button)
		check(count(map.loadout,item)==amount+1 and map.loadout.spirit_stones==1000-cost,"purchase works")
		await click(dialog.sell_button)
		var index: int = dialog._visible_products.find_custom(func(row): return row.item_id==item)
		while index<0 and not dialog.next_button.disabled:
			dialog.change_page(1)
			await settle()
			index = dialog._visible_products.find_custom(func(row): return row.item_id==item)
		check(index>=0,"purchased pill sellable")
		if index>=0: await click(dialog.slots[index])
		await click(dialog.buy_button)
		check(count(map.loadout,item)==amount and map.loadout.spirit_stones==1000-cost+dialog.shop.pricing.sell_unit_price(item),"sale works")
	else: dialog.set_selling(true)
	check(dialog.selling and not dialog.crafting,"third tab sale")
	if headless: await click(dialog.conversation_tab)
	else: dialog.set_conversation()
	if headless: await click(talk.canvas.get_node("ShopCraftTab"))
	else: dialog.set_crafting()
	check(dialog.crafting and not dialog.conversing,"repeat conversation/crafting switch not stuck")
	check(DialogueJournal.normalized(map.loadout.narrative)==DialogueJournal.normalized(before.narrative) and WorldCalendar.normalized(map.loadout.calendar)==WorldCalendar.normalized(before.calendar),"no dialogue progress or time cost (allow save normalization)")
	if not headless: check(map.loadout.snapshot()==before,"preview never transacts")
	if headless:
		await click(dialog.leave_button)
		check(not dialog.visible and not map.travel.paused,"leave crafting restores map")
	# A three-page shop restores the lower wallet after leaving four-page alchemy.
	var event_id := "base.map_event.qingshizhen.sect"
	dialog.present(map.event_registry.events[event_id],map.shops[event_id],map.loadout,map.player_status)
	check(dialog.conversation_tab.visible and not dialog.craft_tab.visible and dialog.buy_tab.position.x==828-dialog.FRAME.position.x,"three-page shop layout restored")
	check(dialog.balance_row.position.y==260-dialog.FRAME.position.y,"other shop wallet restored")
	map.queue_free()
	await settle()
	root.get_node("UiButtonAudio").player.stop()
	await create_timer(0.1).timeout
	print("ALCHEMY FOUR TABS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
