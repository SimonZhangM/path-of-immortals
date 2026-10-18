extends "res://tests/map_shop_tests.gd"

func capture(name: String) -> void:
	await settle()
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/forge-four-"+name+".png")

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
	var point := "base.map.qingshizhen.point.n23"
	map.travel.current_node_id = point
	map.travel.mode = "idle"
	check(map._try_start_event(point,"click",true),"N23 opens")
	var dialog: MapShopDialog = map.shop_dialog
	var talk: MapClinicDialog = dialog.conversation_view
	var before: Dictionary = map.loadout.snapshot()
	var headless := DisplayServer.get_name()=="headless"
	check(dialog.conversing and talk.library.definition.id=="base.npc.hantieshan" and talk.dialogue_rows.get_child_count()>0,"default Han conversation")
	check(talk.continue_button.visible and talk.topic_buttons.values().all(func(b):return not b.visible),"welcome waits before topic cards")
	check(talk.library.definition.portrait=="res://assets/ui-portrait-hantieshan.webp","Han dedicated portrait")
	check(talk.backing.texture.atlas.resource_path.ends_with("tiejiangpu2.webp"),"conversation background")
	check(talk.canvas.get_node("ShopCraftTab").text=="打造","fourth tab says forge")
	await capture("conversation")
	if headless: await click(talk.canvas.get_node("ShopBuyTab"))
	else: dialog.set_selling(false)
	check(not dialog.conversing and not dialog.selling and dialog._visible_products.size()==2,"purchase keeps two ores")
	check(dialog.backing.texture.atlas.resource_path.ends_with("tanchuang-qingshizhen-tiejiangpu.webp"),"purchase background")
	check("|".join(dialog.filters.values().map(func(b):return b.text))=="矿石|材料|暗器|器方","categories unchanged")
	check(not dialog.balance_row.get_global_rect().intersects(dialog.craft_tab.get_global_rect()),"wallet avoids fourth tab")
	await capture("buy")
	if headless: await click(dialog.sell_button)
	else: dialog.set_selling(true)
	check(dialog.selling and not dialog.conversing,"third tab sale")
	if headless: await click(dialog.craft_tab)
	else: dialog.set_crafting()
	check(dialog.crafting and dialog.crafting_panel.get_child_count()==0 and dialog.trade_controls.all(func(c):return not c.visible),"forge placeholder hides trading")
	check(dialog.backing.texture.atlas.resource_path.ends_with("tiejiangpu2.webp"),"forge second background")
	await capture("crafting")
	if headless: await click(dialog.conversation_tab)
	else: dialog.set_conversation()
	if headless: await click(talk.canvas.get_node("ShopCraftTab"))
	else: dialog.set_crafting()
	check(dialog.crafting and not dialog.conversing,"conversation to forge works repeatedly")
	check(map.loadout.snapshot()==before,"page changes never alter state")
	if headless: await click(dialog.leave_button)
	else: map._close_shop()
	check(not dialog.visible and not map.travel.paused,"leave restores map")
	var alchemy := "base.map_event.qingshizhen.alchemy"
	dialog.present(map.event_registry.events[alchemy],map.shops[alchemy],map.loadout,map.player_status)
	talk = dialog.conversation_view
	check(talk.library.definition.portrait=="res://assets/ui-portrait-luhuaizhen.webp" and not talk.library.definition.has("portrait_region"),"Lu dedicated portrait without scene crop")
	var bubble := DialogueBubble.new()
	bubble.configure("npc",["你好，辰宇。"],talk.library,map.player_status,"张辰宇")
	talk.dialogue_rows.add_child(bubble)
	check(bubble.portrait.texture.resource_path.ends_with("ui-portrait-luhuaizhen.webp"),"actual bubble uses Lu image")
	await capture("lu-portrait")
	for path in ["tanchuang-qingshizhen-tiejiangpu","tanchuang-qingshizhen-tiejiangpu2","ui-portrait-hantieshan","ui-portrait-luhuaizhen"]:
		var texture: Texture2D = load("res://assets/"+path+".webp")
		check(texture.get_image().has_mipmaps(),"mipmaps "+path)
	map.queue_free()
	await settle()
	root.get_node("UiButtonAudio").player.stop()
	await create_timer(0.1).timeout
	print("BLACKSMITH FOUR TABS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
