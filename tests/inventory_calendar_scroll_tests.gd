extends SceneTree
var checks := 0
func verify(value: bool, note: String) -> void:
	checks += 1
	assert(value,note)
func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for i in 8: await process_frame
func wheel(point: Vector2, direction: MouseButton) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	await process_frame
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = direction
	event.pressed = true
	event.factor = 1.0
	Input.parse_input_event(event)
	await settle()
func run() -> void:
	create_timer(35).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(2560,1440)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	for map_name in ["qingshihewan","qingshizhen"]:
		var map = load("res://scenes/maps/%s.tscn" % map_name).instantiate()
		map.inventory_save_path = ""
		map.defer_map_music = true
		root.add_child(map)
		map.set_process(false)
		await settle()
		verify(map.startup_error.is_empty(),"map ready")
		verify(not map.calendar_readout.is_visible_in_tree(),"map date hidden")
		var before: Dictionary = map.loadout.snapshot()
		var ui: MapInventoryScreen = map.inventory_screen
		ui.show()
		await settle()
		verify(map.calendar_readout.is_visible_in_tree(),"fullscreen inventory date shown")
		verify(map.calendar_readout.caption.text == WorldCalendar.date_text(map.loadout.calendar).trim_prefix(str(WorldCalendar.rules().world_name)+"·"),"authoritative date without world prefix")
		verify(map.calendar_readout.get_global_rect().end.y <= ui.storage_panel.get_global_rect().position.y,"date above storage panel")
		var well := ui.find_child("StorageItemWell",true,false) as Control
		var column := well.get_parent() as VBoxContainer
		verify(column.get_theme_constant("separation") == 1,"gap reduced another three pixels")
		var toolbar_rect := ui.storage_toolbar.get_global_rect()
		var new_top := well.position.y
		column.add_theme_constant_override("separation",4)
		await settle()
		verify(is_equal_approx(well.position.y-new_top,3),"well moved up exactly three design pixels")
		verify(toolbar_rect == ui.storage_toolbar.get_global_rect(),"toolbar unchanged")
		column.add_theme_constant_override("separation",1)
		await settle()
		var scroll := ui.grid.get_parent() as ScrollContainer
		var pitch: float = scroll.row_pitch()
		verify(pitch > 0,"row-sized wheel step available")
		var last_card := ui.grid.get_child(ui.grid.get_child_count() - 1) as Control
		verify(absf(ui.grid.get_combined_minimum_size().y - last_card.get_rect().end.y) <= 1, "content ends at final card without bottom padding")
		if DisplayServer.get_name() == "headless":
			var card := ui.grid.get_child(0) as Control
			var point := card.get_global_rect().get_center()
			var next_row: Control
			for index in range(0,ui.grid.get_child_count(),5):
				var candidate := ui.grid.get_child(index) as Control
				if candidate.get_global_rect().end.y > scroll.get_global_rect().end.y:
					next_row = candidate
					break
			verify(next_row != null,"offscreen next row exists")
			await wheel(point,MOUSE_BUTTON_WHEEL_DOWN)
			verify(absf(scroll.scroll_vertical-pitch*0.5) <= 1,"one notch half row")
			await wheel(point,MOUSE_BUTTON_WHEEL_DOWN)
			verify(absf(scroll.scroll_vertical-pitch) <= 1,"two notches one row, not double native scrolling")
			verify(next_row.get_global_rect().end.y <= scroll.get_global_rect().end.y,"next row bottom fully visible")
			await wheel(point,MOUSE_BUTTON_WHEEL_UP)
			await wheel(point,MOUSE_BUTTON_WHEEL_UP)
			verify(scroll.scroll_vertical == 0,"two up returns to original position without rounding drift")
			var bar := scroll.get_v_scroll_bar()
			var limit := maxf(0, bar.max_value - bar.page)
			# Near the bottom, keep the regular half-row step without snapping.
			scroll.scroll_vertical = roundi(limit - pitch * 0.5 - 12.0)
			await settle()
			var near_bottom := scroll.scroll_vertical
			await wheel(point, MOUSE_BUTTON_WHEEL_DOWN)
			verify(absf(scroll.scroll_vertical - near_bottom - pitch * 0.5) <= 1, "near-bottom step does not absorb extra space")
			await wheel(point, MOUSE_BUTTON_WHEEL_DOWN)
			verify(absf(scroll.scroll_vertical - limit) <= 1, "scroll reaches actual content end")
			var bottom := scroll.scroll_vertical
			await wheel(point, MOUSE_BUTTON_WHEEL_DOWN)
			verify(scroll.scroll_vertical == bottom, "no extra tiny scroll after final row")
			verify(absf(last_card.get_global_rect().end.y - scroll.get_global_rect().end.y) <= 2, "final card bottom aligns with viewport bottom")
		if DisplayServer.get_name() != "headless" and map_name == "qingshizhen":
			scroll.scroll_vertical = roundi(scroll.get_v_scroll_bar().max_value)
			await settle()
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().get_region(Rect2i(ui.storage_panel.get_global_rect())).save_png("res://artifacts/inventory-bottom-no-padding.png")
		ui.set_warehouse("base.warehouse.qingshizhen.home")
		await settle()
		verify(map.calendar_readout.is_visible_in_tree(),"warehouse date shown")
		if DisplayServer.get_name() != "headless" and map_name == "qingshizhen":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/warehouse-calendar.png")
		ui.hide()
		await settle()
		verify(not map.calendar_readout.is_visible_in_tree(),"return to map hides date")
		verify(map.loadout.snapshot() == before,"no inventory/date mutation")
		map.queue_free()
		await settle()
	print("INVENTORY DATE/SCROLL: ",checks," passed; Render is static, headless wheel only; no real save")
	quit()
