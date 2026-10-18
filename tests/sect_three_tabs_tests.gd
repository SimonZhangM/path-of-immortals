extends "res://tests/map_shop_tests.gd"

func capture(name: String) -> void:
	await settle()
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/sect-three-"+name+".png")

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
	var point := "base.map.qingshizhen.point.n01"
	map.travel.current_node_id = point
	map.travel.mode = "idle"
	check(map._try_start_event(point,"click",true),"N01 opens sect shop")
	var dialog: MapShopDialog = map.shop_dialog
	var talk: MapClinicDialog = dialog.conversation_view
	var before: Dictionary = map.loadout.snapshot()
	var headless := DisplayServer.get_name()=="headless"
	check(dialog.conversing and talk.library.definition.id=="base.npc.xieyunshu" and talk.dialogue_rows.get_child_count()>0,"default Xie conversation")
	check(talk.continue_button.visible and talk.topic_buttons.values().all(func(b):return not b.visible),"welcome hides topics until opened")
	check(talk._presentation.conversation_portrait=="res://assets/ui-portrait-xieyunshu.webp","Xie portrait bound")
	check(talk.backing.texture.atlas.resource_path.ends_with("zongmenpu2.webp"),"conversation background")
	check(not dialog.craft_tab.visible and not talk.canvas.has_node("ShopCraftTab"),"only three modes")
	await capture("conversation")
	if headless: await click(talk.canvas.get_node("ShopBuyTab"))
	else: dialog.set_selling(false)
	check(not dialog.conversing and not dialog.selling and dialog._visible_products.size()==3,"purchase keeps three original artifacts")
	check(dialog.backing.texture.atlas.resource_path.ends_with("tanchuang-qingshizhen-zongmenpu.webp"),"purchase background")
	check(dialog.buy_tab.position.x==828-dialog.FRAME.position.x and dialog.sell_button.position.x==1025-dialog.FRAME.position.x,"second and third slots aligned")
	check(not dialog.balance_row.get_global_rect().intersects(dialog.sell_button.get_global_rect()),"wallet clear of tabs")
	await capture("buy")
	if headless: await click(dialog.sell_button)
	else: dialog.set_selling(true)
	check(dialog.selling and not dialog.conversing,"third tab sale")
	if headless: await click(dialog.conversation_tab)
	else: dialog.set_conversation()
	check(dialog.conversing and talk.visible and not dialog.canvas.visible,"return to conversation")
	check(map.loadout.snapshot()==before,"page changes preserve all player state")
	if headless: await click(talk.leave_button)
	else: map._close_shop()
	check(not dialog.visible and not map.travel.paused,"leave restores map")
	for path in ["tanchuang-qingshizhen-zongmenpu","tanchuang-qingshizhen-zongmenpu2","ui-portrait-xieyunshu"]:
		var texture: Texture2D = load("res://assets/"+path+".webp")
		check(texture.get_image().has_mipmaps(),"mipmaps "+path)
	map.queue_free()
	await settle()
	root.get_node("UiButtonAudio").player.stop()
	await create_timer(0.1).timeout
	print("SECT THREE TABS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
