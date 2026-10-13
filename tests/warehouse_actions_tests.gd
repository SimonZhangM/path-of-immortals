extends "res://tests/warehouse_inventory_tests.gd"

func run() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(2560,1440)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	var map = load("res://scenes/maps/qingshizhen.tscn").instantiate()
	map.inventory_save_path = ""
	map.defer_map_music = true
	root.add_child(map)
	map.set_process(false)
	await settle()
	check(map.startup_error.is_empty(),"map initialized")
	var ui: MapInventoryScreen = map.inventory_screen
	var state: MapLoadoutState = map.loadout
	ui.set_warehouse(WAREHOUSE)
	ui.show()
	await settle()
	var pane := ui.warehouse_pane
	var actions = ui.warehouse_actions
	var left := pane.storage_panel.get_global_rect()
	var right := ui.storage_panel.get_global_rect()
	var buttons := [actions.withdraw_button,actions.withdraw_all_button,actions.deposit_button,actions.deposit_all_button]
	var rects: Array[Rect2] = []
	for control: TextureButton in buttons:
		rects.append(control.get_global_rect())
		check((control.texture_normal as AtlasTexture).atlas.get_image().has_mipmaps(),"button mipmap")
	check(is_equal_approx(rects[1].position.x-rects[0].end.x,rects[3].position.x-rects[2].end.x),"equal pair spacing")
	check(is_equal_approx(left.end.x-rects[1].end.x,rects[2].position.x-right.position.x+30*ui.stage.scale.x),"deposit group shifted left for calendar")
	check(rects[0].end.y < left.position.y and rects[2].end.y < right.position.y,"buttons above panels")
	check(is_equal_approx(rects[0].size.y,rects[3].size.y),"four matching heights, widths follow source aspect")
	var sign_rect: Rect2 = actions.direction_art.get_global_rect()
	check(is_equal_approx(sign_rect.get_center().y,left.get_center().y),"direction artwork vertically centered")
	check(sign_rect.position.x > left.end.x and sign_rect.end.x < right.position.x,"direction art clears both borders")
	check(absf((sign_rect.position.x-left.end.x)-(right.position.x-sign_rect.end.x)) < 0.1,"direction art horizontally centered")
	var background: TextureRect = pane.find_child("StoragePanelBackground",true,false)
	check(background.texture.resource_path.ends_with("UI-bg-cangku.webp"),"warehouse background")
	check(background.texture.get_image().has_mipmaps(),"background mipmap")
	check((ui.storage_panel.find_child("StoragePanelBackground",true,false).texture as AtlasTexture).atlas.resource_path.ends_with("inv-bg-3.webp"),"bag background unchanged")
	check(actions.withdraw_button.disabled and actions.deposit_button.disabled and actions.withdraw_all_button.disabled,"no selection or empty warehouse disabled")
	if DisplayServer.get_name() == "headless":
		var item := ""
		for record: Dictionary in state.storage_records():
			if record.name == "火砂": item = record.id
		var initial := state.snapshot()
		for index in 4: initial.owned_units["test.warehouse.actions.%d" % index] = item
		check(state.restore(initial).is_empty(),"whole stack fixture")
		ui.catalog.set_filter("search","火砂")
		await settle()
		await click(find_card(ui,item).get_global_rect().get_center())
		check(not actions.deposit_button.disabled and actions.withdraw_button.disabled,"selection enables correct side")
		ui.warehouse_sidebar.set_quantity(5)
		await click(actions.deposit_button.get_global_rect().get_center())
		check(state.warehouse_records(WAREHOUSE).size()==1 and state.warehouse_records(WAREHOUSE)[0].quantity==5,"selected button deposits chosen five units")
		check(actions.deposit_button.disabled,"removed selected card disables button")
		await click(find_card(pane,item).get_global_rect().get_center())
		check(not actions.withdraw_button.disabled and actions.deposit_button.disabled,"warehouse selection enables withdrawal")
		ui.warehouse_sidebar.set_quantity(5)
		await click(actions.withdraw_button.get_global_rect().get_center())
		check(state.warehouse_records(WAREHOUSE).is_empty(),"selected button withdraws full stack")
		var before := state.snapshot()
		check(not Transfer.execute(state,WAREHOUSE,"",false,"res://artifacts/no-such-warehouse-directory/save.json",true).is_empty(),"bulk save failure reported")
		check(state.snapshot()==before,"failed bulk save leaves every stack unchanged")
		# Filter stays on a single item; 'all' still means all loose bag stacks.
		await click(actions.deposit_all_button.get_global_rect().get_center())
		check(state.storage_records().size()==1 and state.storage_records()[0].get("board_layout","")==state.board.id,"bulk deposit keeps only active board")
		check(state.warehouse_records(WAREHOUSE).size()>99,"bulk deposit ignores filter and permits overflow")
		check(state.snapshot().owned_units==before.owned_units and state.layout_snapshot().placements==before.placements,"bulk conserves ownership and equipped layout")
		check(actions.deposit_all_button.disabled,"nothing depositable disables bulk button")
		pane.catalog.set_filter("search","火砂")
		await settle()
		await click(actions.withdraw_all_button.get_global_rect().get_center())
		check(state.warehouse_records(WAREHOUSE).is_empty(),"all withdrawal ignores warehouse filter")
		check(state.snapshot()==before,"bulk round trip restores complete snapshot")
		check(actions.withdraw_all_button.disabled,"empty source disables all withdrawal")
	else:
		for record: Dictionary in state.storage_records().duplicate():
			if record.category != "board": state.transfer_warehouse(WAREHOUSE,record.id,false)
			if state.warehouse_records(WAREHOUSE).size()==8: break
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/warehouse-actions.png")
	ui.set_warehouse()
	await settle()
	check(not actions.visible and ui.board_panel.visible,"ordinary inventory hides warehouse controls")
	map.queue_free()
	await settle()
	print("WAREHOUSE ACTIONS: ",checks," checks, ",failures," failures; isolated state; Render has no mouse")
	quit(1 if failures else 0)
