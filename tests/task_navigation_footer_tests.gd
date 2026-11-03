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

func active(map: Node) -> Array:
	return [map.is_inventory_open(),map.is_technique_open(),map.is_task_open(),map.is_world_map_open()]

func run() -> void:
	create_timer(58).timeout.connect(func(): quit(2))
	directory = "res://artifacts/task-navigation/run-%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	Slots.auto_path = directory+"auto.json"
	Session.index_path = directory+"last.json"
	Session.clear_selection()
	root.get_node("SavePlaytime").set_process(false)
	root.get_node("GameSettings").apply_values({"background_pause":false,"background_mute":false})
	root.get_node("GameSettings").set_application_focus(true)
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1920,1080)
	var map = load("res://scenes/maps/qingshizhen.tscn").instantiate()
	map.inventory_save_path = Slots.working_path()
	map.defer_map_music = true
	map.defer_optional_views = true
	root.add_child(map)
	current_scene = map
	await settle()
	map.set_process(false)
	check(map.startup_error.is_empty(),"isolated map starts")
	var before: Dictionary = map.loadout.snapshot()
	var keys := [KEY_I,KEY_G,KEY_T,KEY_M]
	# Every ordered pair, using actual input dispatch rather than direct page calls.
	for source in 4:
		await key(keys[source])
		check(active(map)[source],"source opened")
		for target in 4:
			if target==source: continue
			await key(keys[target])
			check(active(map)[target] and active(map).count(true)==1,"switch %d -> %d without overlap" % [source,target])
			check(map.status_header.map_title.visible==(target==3),"world map keeps plaque under its shade; full panels hide it")
			await key(keys[source])
		await key(KEY_ESCAPE)
		check(active(map).count(true)==0 and not map.is_system_menu_open(),"Esc returns to travel")
	await key(KEY_I)
	var input := LineEdit.new()
	map.inventory_screen.add_child(input)
	input.size = Vector2(160,32)
	input.grab_focus()
	await key(KEY_T)
	check(map.is_inventory_open() and not map.is_task_open(),"typing T does not switch from a text field")
	input.release_focus()
	input.queue_free()
	await key(KEY_T)
	await key(KEY_G,true)
	check(map.is_task_open(),"key repeat does not switch pages")
	# Closing the task page restores the suspended cultivation parent, if any.
	map._ensure_event_views()
	map._cultivation_adjusting = true
	map.cultivation_session = MapCultivationSession.new()
	await key(KEY_ESCAPE)
	check(not map.is_task_open() and map.cultivation_progress_dialog.visible and not map._cultivation_adjusting,"task close returns to cultivation adjustment parent")
	map.cultivation_progress_dialog.hide()
	await key(KEY_T)
	var bindings: Dictionary = Settings.values_snapshot().bindings.duplicate(true)
	bindings.map_tasks = KEY_Y
	root.get_node("GameSettings").apply_values({"bindings":bindings})
	await key(KEY_I)
	await key(KEY_T)
	check(map.is_inventory_open(),"old remapped task shortcut inactive")
	await key(KEY_Y)
	check(map.is_task_open(),"remapped task key participates in cross-page switching")
	bindings.map_tasks = KEY_T
	root.get_node("GameSettings").apply_values({"bindings":bindings})
	map.task_screen.task_list.select_task(QuestState.ID)
	await settle()
	var body = map.task_screen.detail_body
	check(body.location_body.get_node("LocationName").text=="青石镇·药材铺","location separator has no surrounding spaces")
	for resolution in [Vector2i(1920,1080),Vector2i(2560,1440)]:
		root.size = resolution
		await settle()
		var top: float = maxf(body.frames.people.get_global_rect().end.y,body.frames.rewards.get_global_rect().end.y)
		var bottom: float = map.task_screen.right_panel.get_global_rect().end.y
		for button: TextureButton in body.footer_buttons:
			check(absf(button.get_global_rect().get_center().y-(top+bottom)*0.5)<1,"button center bisects lower frame and column bottom")
			check(map.task_screen.right_panel.get_global_rect().encloses(button.get_global_rect()),"button remains inside column")
			check(button.texture_normal.resource_path.ends_with("UI-gongfa-right-blackbtn.webp") and button.texture_hover.resource_path.ends_with("UI-gongfa-right-goldbtn.webp"),"authored normal/hover textures")
		var motion := InputEventMouseMotion.new()
		motion.position = Vector2(10,10)
		root.push_input(motion,true)
		await capture("footer-normal-%d" % resolution.x)
	# Only the two new hover/click behaviors are checked, no unrelated mouse chains.
	for button: TextureButton in body.footer_buttons:
		var motion := InputEventMouseMotion.new()
		motion.position = button.get_global_rect().get_center()
		root.push_input(motion,true)
		await settle()
		check(button.is_hovered() and button.get_draw_mode()==BaseButton.DRAW_HOVER,"native hover uses highlighted state")
		await capture("footer-hover-"+button.name)
		# Tracking/navigation click behavior is covered by task_tracker_tests.gd.
	await key(KEY_ESCAPE)
	map._open_system_menu()
	await key(KEY_T)
	check(map.is_system_menu_open() and not map.is_task_open(),"system menu retains its modal input boundary")
	map.system_menu_controller.close()
	Meta.stop()
	map.deactivate_location()
	map.queue_free()
	await settle()
	print("TASK_NAVIGATION_FOOTER: %d checks; %d failures" % [checks,failures])
	print("OUTPUT: "+directory)
	quit(1 if failures else 0)
