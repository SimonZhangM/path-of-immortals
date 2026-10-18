extends "res://tests/map_shop_tests.gd"

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
	check(map.startup_error.is_empty(),"town initialized")
	if not map.startup_error.is_empty(): quit(1); return
	var dialog: MapShopDialog = map.shop_dialog
	var before: Dictionary = map.loadout.snapshot()
	for event_id: String in map.shops:
		dialog.present(map.event_registry.events[event_id],map.shops[event_id],map.loadout,map.player_status)
		if is_instance_valid(dialog.conversation_view):
			check(dialog.conversation_view.leave_button.get_theme_color("font_hover_color")==Color("fffbea"),"herbal conversation exit shares highlight")
		dialog.set_selling(false)
		await settle()
		check(dialog.leave_button.get_theme_stylebox("hover") is StyleBoxEmpty,"exit retains text-only appearance")
		check(dialog.leave_button.get_theme_color("font_hover_color")==Color("fffbea"),"shop exit subtle highlight")
		check(dialog.balance_row.get_child(1).size_flags_vertical==Control.SIZE_SHRINK_CENTER,"wallet coin vertically centered")
		for index in dialog._visible_products.size():
			var content: Control = dialog.slot_contents[index]
			var price_row: HBoxContainer = content.get_child(content.get_child_count()-1)
			var item_id: String = dialog._visible_products[index].item_id
			check(price_row.get_child(1).text==str(dialog.shop.pricing.buy_unit_price(item_id)),"shelf displays original price")
		if not dialog.apprentice_badge.visible: continue
		check(dialog.apprentice_label.get_theme_font_size("font_size")==18,"badge font reduced by one")
		check(dialog.apprentice_badge.size.is_equal_approx(Vector2(104.5,27.55)),"badge dimensions reduced five percent")
		check(dialog.apprentice_badge.position.is_equal_approx(Vector2(1308.75,226.725)-dialog.FRAME.position),"badge centered shrink and five pixels down")
		check(dialog.apprentice_badge.tooltip_text.begins_with("正在叶伯"),"current apprentice wording")
		dialog.quantity = 10
		dialog.refresh_checkout()
		check(dialog.price_label.text=="5" and dialog.total_label.text=="48","checkout discount unchanged")
		await settle()
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/shop-visual-refinement.png")
	check(map.loadout.snapshot()==before,"visual checks do not alter inventory or money")
	map.queue_free()
	await settle()
	print("SHOP VISUAL REFINEMENT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
