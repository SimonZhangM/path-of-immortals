extends "res://tests/inn_tabs_tests.gd"

func transactions(map: Node) -> void:
	var config: Dictionary = map.event_registry.events[INN_EVENT].lodging
	var state: MapLoadoutState = MapLoadoutStore.candidate(map.loadout).state
	var status := MapPlayerStatus.new()
	check(status.configure(map.loadout.registry,JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/status_header.json"))).is_empty(),"isolated status")
	state.spirit_stones = 200
	for key in status.resources: status.set_resource(key,1)
	var before := state.snapshot()
	var resources := status.resources.duplicate(true)
	var standard: String = config.rooms[0].id
	var premium: String = config.rooms[1].id
	var bad_path := "res://artifacts/no-inn-parent/save.json"
	check(not MapInnLodging.stay(state,status,config,standard,bad_path).error.is_empty(),"failed save refused")
	check(state.snapshot()==before and status.resources==resources,"failed save atomic")
	check(not MapInnLodging.stay(state,status,config,"missing","").error.is_empty(),"unknown room rejected")
	var day := WorldCalendar.current_day(state.calendar)
	var path := "res://artifacts/inn-stay-isolated.json"
	check(MapInnLodging.stay(state,status,config,standard,path).error.is_empty(),"ordinary stay succeeds")
	check(state.spirit_stones==180 and WorldCalendar.current_day(state.calendar)==day+1,"20 stones and one day")
	for key in resources: check(status.resources[key]==status.maxima[key],"full recovery: "+key)
	check(state.cultivation_bonus_percent()==10 and state.cultivation_bonus_days()==10,"ordinary ten full days after waking")
	var reloaded: MapLoadoutState = MapLoadoutStore.candidate(map.loadout).state
	var reload_error := MapLoadoutStore.load_into(reloaded,path)
	check(reload_error.is_empty() and reloaded.lodging_bonus==state.lodging_bonus,"bonus persists on reload: "+reload_error)
	status.award_progression({"cultivation":5,"experience":2})
	check(is_equal_approx(status.cultivation_progress,5.5) and status.experience==2,"battle reward includes fractional bonus; experience unchanged")
	check(MapInnLodging.stay(state,status,config,premium,"").error.is_empty(),"full-health premium stay allowed")
	check(state.spirit_stones==130 and state.cultivation_bonus_percent()==20 and state.cultivation_bonus_days()==15,"premium replaces ordinary, not stacked")
	check(MapInnLodging.stay(state,status,config,standard,"").error.is_empty(),"ordinary replaces premium")
	check(state.cultivation_bonus_percent()==10 and state.cultivation_bonus_days()==10,"downgrade resets strength and expiry")
	check(state.advance_days(9,"test.inn").is_empty() and state.cultivation_bonus_percent()==10 and state.cultivation_bonus_days()==1,"bonus active before boundary")
	check(state.advance_days(1,"test.inn").is_empty() and state.cultivation_bonus_percent()==0 and state.cultivation_bonus_days()==0,"bonus expires at exact day")
	status.cultivation_bonus_percent = state.cultivation_bonus_percent()
	check(status.cultivation_gain(5)==5,"expired reward returns to base")
	state.spirit_stones = 19
	before = state.snapshot()
	check(not MapInnLodging.stay(state,status,config,standard,"").error.is_empty() and state.snapshot()==before,"insufficient currency changes nothing")
	var legacy := state.snapshot()
	legacy.erase("lodging_bonus")
	check(reloaded.restore(legacy).is_empty() and reloaded.cultivation_bonus_percent()==0,"legacy saves default no bonus")
	legacy.lodging_bonus = {"source_id":standard,"percent":10,"start_day":8,"expires_day":7}
	check(not reloaded.restore(legacy).is_empty(),"invalid bonus deadline rejected")

func run() -> void:
	create_timer(55).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(2560,1440)
	var map = load("res://scenes/maps/qingshizhen.tscn").instantiate()
	map.inventory_save_path = ""
	map.defer_map_music = true
	root.add_child(map)
	map.set_process(false)
	await settle()
	check(map.startup_error.is_empty(),"startup: "+map.startup_error)
	if not map.startup_error.is_empty(): quit(1); return
	if DisplayServer.get_name()=="headless": transactions(map)
	map.loadout.spirit_stones = 200
	map.loadout.changed.emit()
	map.travel.current_node_id = INN_POINT
	map.travel.map_position = map.travel.node_positions[INN_POINT]
	map.travel.stop_at_current_node()
	await open_inn(map)
	var dialog: MapInnDialog = map.inn_dialog
	var view := dialog.lodging_content
	check(dialog.title_label.text=="清石客栈" and not dialog.description_label.text.is_empty(),"reference title and description")
	if DisplayServer.get_name()=="headless": await click(dialog.lodging_tab)
	else: dialog.set_mode("lodging")
	await settle()
	for index in 2:
		if DisplayServer.get_name()=="headless": await click(view.room_buttons[index])
		else: view.select_room(map.event_registry.events[INN_EVENT].lodging.rooms[index].id)
		await settle()
		check(view.room_image.get_parent().clip_contents and view.room_image.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_COVERED,"room art clipped and aspect preserved")
		check(view.room_image.texture.get_image().has_mipmaps(),"room art mipmaps")
		check(view.room_title.text==["普通客房","高级客房"][index],"selected room title")
		check(view.fee_label.text==["费用：20灵石","费用：50灵石"][index],"actual fee shown")
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/inn-lodging-%d.png" % index)
	if DisplayServer.get_name()=="headless":
		view._hover(true)
		check(view.confirm_label.get_theme_color("font_color")==Color.BLACK,"hover black text")
		view._hover(false)
		check(view.confirm_label.get_theme_color("font_color")==Color.WHITE,"normal white text")
		map.player_status.set_resource("hp",1)
		var day := WorldCalendar.current_day(map.loadout.calendar)
		await click(view.confirm_button)
		check(map.loadout.spirit_stones==150 and WorldCalendar.current_day(map.loadout.calendar)==day+1,"actual UI buys one premium night")
		check(map.player_status.resources.hp==map.player_status.maxima.hp and map.player_status.cultivation_bonus_percent==20,"UI recovery and reward rate synchronized")
		check(map.inventory_screen.cultivation_bonus_value.text=="+20%","sidebar updates immediately")
		map.loadout.advance_days(15,"test.expiry")
		map.loadout.changed.emit()
		check(map.inventory_screen.cultivation_bonus_value.text=="+0%" and map.player_status.cultivation_bonus_percent==0,"sidebar and award rate expire together")
	else:
		MapInnLodging.stay(map.loadout,map.player_status,map.event_registry.events[INN_EVENT].lodging,view.selected_room,"")
		map._close_inn()
		map.set_inventory_open(true)
		await settle()
		check(map.inventory_screen.cultivation_bonus_value.text=="+20%","render sidebar uses live bonus")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/inn-lodging-sidebar.png")
	map.queue_free()
	await settle()
	root.get_node("UiButtonAudio").player.stop()
	await create_timer(0.1).timeout
	print("INN LODGING: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
