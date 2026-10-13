extends "res://tests/warehouse_inventory_tests.gd"

func visible_categories(ui: MapInventoryScreen) -> Array:
	return ui._categories.keys().filter(func(key): return ui._categories[key].visible)

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
	check(map.startup_error.is_empty(),"map initializes")
	var ui: MapInventoryScreen = map.inventory_screen
	var state: MapLoadoutState = map.loadout
	check(state.restore(state.snapshot()).is_empty(),"normalize fixture like a loaded save")
	var original := state.snapshot()
	ui.set_warehouse(WAREHOUSE)
	ui.show()
	await settle()
	var pane := ui.warehouse_pane
	var categories := visible_categories(ui)
	check(visible_categories(pane)==categories and categories.size()==14,"empty warehouse matches 14 merged categories")
	var empty_height := pane._category_filters.size.y
	ui.catalog.replace_entries([])
	await settle()
	check(visible_categories(ui)==categories and is_equal_approx(ui._category_filters.size.y,empty_height),"empty bag uses same one row")
	ui.catalog.replace_entries(state.storage_records())
	var record: Dictionary = state.storage_records().filter(func(entry): return entry.name=="火砂")[0]
	check(state.transfer_warehouse(WAREHOUSE,record.id,false).is_empty(),"one item fixture")
	await settle()
	check(visible_categories(pane)==categories and is_equal_approx(pane._category_filters.size.y,empty_height),"one item does not change categories or row height")
	for panel: MapInventoryScreen in [ui,pane]:
		for key in ["normal","hover","pressed"]:
			var top: StyleBoxFlat = panel._collections.all.get_theme_stylebox(key)
			var lower: StyleBoxFlat = panel._categories.weapon.get_theme_stylebox(key)
			check(top.bg_color==lower.bg_color and top.border_color==lower.border_color,"collection/category colors match "+key)
		for control in [panel.quality_picker,panel.level_sort]:
			var style: StyleBoxFlat = control.get_theme_stylebox("normal")
			check(style.border_width_left==1 and style.border_color==Color("29424f"),"dropdown outlined")
		check(panel.search_box.position.x < panel.quality_picker.position.x,"search before quality")
		check(panel.storage_capacity.displayed_capacity()==Vector2i(100,100),"display-only capacity fixture")
		check(panel.storage_capacity.font_size_adjustment==-1 and panel.storage_capacity.number_offset==Vector2(-3,0),"capacity font and updated art alignment")
	check(pane.storage_capacity.occupied==1 and ui.storage_capacity.occupied==state.storage_used_slots(),"real counters unaffected")
	check(ui.board_capacity.preview_capacity==Vector2i(99,99),"board occupancy display fixture")
	var actions = ui.warehouse_actions
	var buttons := [actions.withdraw_button,actions.withdraw_all_button,actions.deposit_button,actions.deposit_all_button]
	for button: TextureButton in buttons:
		check(button.stretch_mode==TextureButton.STRETCH_KEEP_ASPECT_CENTERED,"button keeps aspect")
		check(absf(button.size.aspect()-button.texture_normal.get_size().aspect())<0.025,"button bounds fit source aspect")
	var rects: Array[Rect2] = []
	for button: Control in buttons: rects.append(button.get_global_rect())
	check(absf((rects[1].position.x-rects[0].end.x)-(rects[3].position.x-rects[2].end.x))<1.5,"pair gaps remain equal")
	check(absf((pane.storage_panel.get_global_rect().end.x-rects[1].end.x)-(rects[2].position.x-ui.storage_panel.get_global_rect().position.x)-30*ui.stage.scale.x)<1.5,"deposit group clears date banner")
	if DisplayServer.get_name()=="headless":
		for panel: MapInventoryScreen in [ui,pane]:
			var fixtures: Array = []
			for index in 3:
				var sample := record.duplicate(true)
				sample.id = "test.search.%d" % index
				sample.name = "灵草%d" % index
				sample.enhancement_level = index
				fixtures.append(sample)
			check(panel.catalog.replace_entries(fixtures).is_empty(),"level fixture")
			await settle()
			await click(panel.search_box.get_global_rect().get_center())
			var key := InputEventKey.new()
			key.keycode=KEY_I
			key.unicode=105
			key.pressed=true
			Input.parse_input_event(key)
			await settle()
			check(ui.visible and panel.search_box.text=="i" and panel.catalog.search_text=="i","search keyboard I does not close warehouse")
			panel.search_box.text="灵草"
			panel.search_box.text_changed.emit("灵草")
			check(panel.catalog.visible_entries().size()==3,"search matches names")
			# Use the actual OptionButton popup signal to test selection wiring.
			panel.level_sort.get_popup().index_pressed.emit(2)
			await settle()
			check(panel.catalog.enhancement_filter==1 and panel.catalog.visible_entries().size()==1,"level dropdown filters exact enhancement")
			panel.quality_picker.get_popup().index_pressed.emit(1)
			await settle()
			check(panel.catalog.visible_entries().size()==1,"quality combines with level and search")
			panel.catalog.reset_filters()
			await settle()
			check(panel.search_box.text.is_empty() and panel.level_sort.selected==0 and panel.catalog.visible_entries().size()==3,"reset clears new filters")
			panel.catalog.replace_entries(state.warehouse_records(WAREHOUSE) if panel==pane else state.storage_records())
	else:
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/warehouse-filter-one.png")
	check(state.transfer_warehouse(WAREHOUSE,record.id,true).is_empty(),"restore visual fixture")
	await settle()
	check(state.snapshot()==original,"filters and preview never change inventory")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/warehouse-filter-empty.png")
	map.queue_free()
	await settle()
	print("WAREHOUSE FILTER REFINEMENT: ",checks," checks, ",failures," failures; no production save")
	quit(1 if failures else 0)
