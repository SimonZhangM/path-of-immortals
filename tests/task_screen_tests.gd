extends "res://tests/save_actions_tests.gd"
const Settings = preload("res://scripts/settings/game_settings.gd")

func key(code: Key, repeated := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	event.echo = repeated
	root.push_input(event,true)
	await settle()

func run() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	directory = "res://artifacts/task-screen/run-%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	Slots.auto_path = directory+"auto.json"
	Session.index_path = directory+"last.json"
	Session.clear_selection()
	root.get_node("SavePlaytime").set_process(false)
	root.get_node("GameSettings").apply_values({"background_pause":false,"background_mute":false})
	root.get_node("GameSettings").set_application_focus(true)
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(2560,1440)
	var map = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path = Slots.working_path()
	map.defer_map_music = true
	map.defer_optional_views = true
	root.add_child(map)
	current_scene = map
	await settle()
	map.set_process(false)
	check(map.startup_error.is_empty(),"isolated map starts")
	var before: Dictionary = map.loadout.snapshot()
	await key(KEY_T)
	check(map.is_task_open(),"T opens task shell")
	check(map.status_header.visible and not map.status_header.map_title.visible and map.calendar_readout.visible,"shell keeps shared header/date and hides travel plaque")
	check(not map.can_save_timed_checkpoint(),"task panel defers timed snapshot")
	var screen: Control = map.task_screen
	check(screen.find_child("ProgressDivider",true,false)==null and screen.task_list != null and screen.detail_header != null and not screen.detail_header.visible,"task list and detail header available; no unselected details or technique divider")
	for resolution: Vector2i in [Vector2i(2560,1440),Vector2i(1920,1080),Vector2i(2560,1080)]:
		root.size = resolution
		await settle()
		var middle: Rect2 = screen.middle_panel.get_global_rect()
		var right: Rect2 = screen.right_panel.get_global_rect()
		var left: Rect2 = screen.left_panel.get_global_rect()
		var stamina: Rect2 = map.status_header.bars.stamina.get_global_rect()
		check(absf(middle.end.x-stamina.get_center().x)<1,"middle right aligns with whole stamina bar midpoint")
		check(absf(right.position.x-middle.end.x-19*screen.stage.scale.x)<1,"right fills leftwards retaining column gap")
		check(absf(right.end.x-(root.size.x-23*screen.stage.scale.x))<1,"right outer edge retained")
		check(is_equal_approx(left.size.y,910*screen.stage.scale.y) and is_equal_approx(left.position.y,right.position.y),"original panel height and top retained")
		for panel: Control in [screen.left_panel,screen.middle_panel,screen.right_panel]:
			var art := panel.get_node_or_null("BackdropLayer/ColumnBackground") as TextureRect
			if panel == screen.left_panel:
				check(art != null and is_equal_approx(art.size.x, panel.size.x) and is_equal_approx(art.position.y + art.size.y, panel.size.y + 30), "left artwork fits width and shifts thirty pixels below bottom alignment")
			elif panel == screen.middle_panel:
				check(art != null and art.texture.resource_path == "res://assets/UI-task-mid-bg.webp", "middle uses requested town background")
			else:
				check(art != null and art.texture.resource_path == "res://assets/UI-task-right-bg.webp", "right uses requested cave background")
		if DisplayServer.get_name()!="headless": await capture("tasks-%dx%d" % [resolution.x,resolution.y])
	var divider_x: float = screen.middle_panel.get_global_rect().end.x
	map.status_header.bars.stamina.value = 1
	await settle()
	check(is_equal_approx(screen.middle_panel.get_global_rect().end.x,divider_x),"stamina changes do not move divider")
	map.status_header.refresh()
	await key(KEY_T,true)
	check(map.is_task_open(),"held shortcut does not toggle repeatedly")
	map.set_inventory_open(true)
	map.set_technique_open(true)
	map.set_world_map_open(true)
	map._open_system_menu()
	map._open_save_browser()
	check(map.is_task_open() and not map.is_inventory_open() and not map.is_technique_open() and not map.is_world_map_open() and not map.is_system_menu_open() and not map.is_save_browser_open(),"other full-screen entrypoints do not overlap tasks")
	var position: Vector2 = map.travel.map_position
	map._process(10)
	check(map.travel.map_position==position,"map stays paused")
	await click(screen.middle_panel)
	check(map.travel.map_position==position and map.is_task_open(),"blank panel does not click through")
	await key(KEY_T)
	check(not map.is_task_open() and map.status_header.map_title.visible,"T returns to travel")
	await click(map.status_header.tasks_button)
	check(map.is_task_open(),"header task button opens")
	await click(map.status_header.tasks_button)
	check(not map.is_task_open(),"header task button closes")
	await key(KEY_T)
	await key(KEY_ESCAPE)
	check(not map.is_task_open() and not map.is_system_menu_open(),"Esc closes only task screen")
	map.event_state.phase = "rest"
	map.event_state.active_id = "test.active"
	map.set_task_open(true)
	check(not map.is_task_open(),"active event blocks task entry")
	map.event_state.phase = ""
	map.event_state.active_id = ""
	var bindings: Dictionary = Settings.values_snapshot().bindings.duplicate(true)
	bindings.map_tasks = KEY_I
	check(not Settings.validate_bindings(bindings).is_empty(),"task key conflicts with map inventory")
	bindings.map_tasks = KEY_Y
	check(root.get_node("GameSettings").apply_values({"bindings":bindings}).is_empty(),"task shortcut remaps")
	await key(KEY_T)
	check(not map.is_task_open(),"old shortcut stops opening")
	await key(KEY_Y)
	check(map.is_task_open() and map.status_header.tasks_button.tooltip_text.contains("Y"),"new shortcut and hint work")
	await key(KEY_ESCAPE)
	bindings.map_tasks = KEY_T
	root.get_node("GameSettings").apply_values({"bindings":bindings})
	var settings = load("res://scripts/settings/settings_panel.gd").new()
	map.add_child(settings)
	settings.select_page("controls")
	for resolution: Vector2i in [Vector2i(2560,1440),Vector2i(1920,1080)]:
		root.size = resolution
		await settle()
		check(settings._key_buttons.size()==9 and settings._key_buttons.map_tasks.text=="T","settings exposes single task key")
		var last: Control = settings._key_buttons.speed_double.get_parent().get_parent()
		check(last.get_rect().end.y<524,"nine bindings fit above toggles")
		if DisplayServer.get_name()!="headless": await capture("bindings-%d" % resolution.x)
	settings.queue_free()
	check(map.loadout.snapshot()==before,"UI and shortcuts do not mutate gameplay state")
	Meta.stop()
	map.deactivate_location()
	map.queue_free()
	await settle()
	print("TASK_SCREEN: %d checks; %d failures" % [checks,failures])
	print("OUTPUT: "+directory)
	quit(1 if failures else 0)
