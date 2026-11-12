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
	return [map.is_inventory_open(),map.is_technique_open(),map.is_task_open(),map.is_breakthrough_open(),map.is_world_map_open()]

func run() -> void:
	create_timer(58).timeout.connect(func(): quit(2))
	directory = "res://artifacts/breakthrough-screen-20261104/run-%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	Slots.auto_path = directory+"auto.json"
	Session.index_path = directory+"last.json"
	Session.clear_selection()
	root.get_node("SavePlaytime").set_process(false)
	var service := root.get_node("GameSettings")
	service.apply_values({"background_pause":false,"background_mute":false})
	service.set_application_focus(true)
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
	check(map.breakthrough_screen==null,"breakthrough view loads on demand")
	var before: Dictionary = map.loadout.snapshot()
	await key(KEY_T)
	check(map.is_breakthrough_open() and not map.is_task_open(),"T opens breakthrough")
	check(map.status_header.visible and map.status_header.z_index>map.breakthrough_screen.z_index and not map.status_header.map_title.visible,"shared header overlays breakthrough without the map plaque")
	check(not map.can_save_timed_checkpoint(),"breakthrough defers timed checkpoint")
	var position: Vector2 = map.travel.map_position
	map._process(10)
	check(map.travel.map_position==position and map.loadout.snapshot()==before,"breakthrough pauses travel and cultivation")
	await key(KEY_T,true)
	check(map.is_breakthrough_open(),"held T does not toggle")
	map.set_task_open(true)
	map.set_inventory_open(true)
	map.set_technique_open(true)
	map.set_world_map_open(true)
	map._open_system_menu()
	map._open_save_browser()
	check(active(map).count(true)==1 and map.is_breakthrough_open() and not map.is_system_menu_open() and not map.is_save_browser_open(),"other direct entrypoints respect breakthrough boundary")
	await key(KEY_T)
	check(active(map).count(true)==0 and map.status_header.map_title.visible,"T returns to travel")
	await key(KEY_R)
	check(map.is_task_open(),"R opens tasks")
	await key(KEY_R)
	check(not map.is_task_open(),"R closes tasks")
	var keys := [KEY_I,KEY_G,KEY_R,KEY_T,KEY_M]
	for source in keys.size():
		await key(keys[source])
		check(active(map)[source],"source page opens")
		for target in keys.size():
			if target==source: continue
			await key(keys[target])
			check(active(map)[target] and active(map).count(true)==1,"exclusive keyboard switch %d -> %d" % [source,target])
			await key(keys[source])
		await key(KEY_ESCAPE)
		check(active(map).count(true)==0 and not map.is_system_menu_open(),"Esc returns from page")
	map.event_state.phase = "rest"
	map.event_state.active_id = "test.active"
	await key(KEY_T)
	check(not map.is_breakthrough_open(),"active event blocks breakthrough")
	map.event_state.phase = ""
	map.event_state.active_id = ""
	map._open_system_menu()
	await key(KEY_T)
	check(map.is_system_menu_open() and not map.is_breakthrough_open(),"system menu retains modal input")
	map.system_menu_controller.close()
	await settle()
	await key(KEY_I)
	var field := LineEdit.new()
	map.inventory_screen.add_child(field)
	field.grab_focus()
	await key(KEY_T)
	check(map.is_inventory_open() and not map.is_breakthrough_open(),"text editing protects T")
	field.release_focus()
	field.queue_free()
	await key(KEY_ESCAPE)
	var bindings: Dictionary = Settings.value("bindings")
	bindings.map_breakthrough = KEY_R
	check(not Settings.validate_bindings(bindings).is_empty(),"breakthrough and task keys cannot conflict")
	bindings.map_breakthrough = KEY_Y
	check(service.apply_values({"bindings":bindings}).is_empty(),"breakthrough shortcut remaps")
	await key(KEY_T)
	check(not map.is_breakthrough_open(),"old breakthrough binding is inactive")
	await key(KEY_Y)
	check(map.is_breakthrough_open(),"remapped breakthrough key opens")
	await key(KEY_R)
	check(map.is_task_open(),"remapped breakthrough participates in switching")
	await key(KEY_Y)
	await key(KEY_Y)
	check(active(map).count(true)==0,"remapped key closes breakthrough")
	bindings.map_breakthrough = KEY_T
	service.apply_values({"bindings":bindings})
	await key(KEY_T)
	var art: TextureRect = map.breakthrough_screen.background_art
	for resolution: Vector2i in [Vector2i(2560,1440),Vector2i(1920,1080)]:
		root.size = resolution
		await settle()
		check(art.get_global_rect()==map.get_global_rect(),"background fills the complete viewport")
		check(art.texture.resource_path=="res://assets/UI-tupo-bg.webp" and art.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_COVERED,"requested image uses proportional cover")
		check(art.texture.get_image().has_mipmaps() and art.self_modulate==Color.WHITE,"background keeps full authored color with mipmaps")
		if DisplayServer.get_name()!="headless": await capture("breakthrough-%d" % resolution.x)
	await key(KEY_ESCAPE)
	var settings = load("res://scripts/settings/settings_panel.gd").new()
	map.add_child(settings)
	settings.select_page("controls")
	for resolution: Vector2i in [Vector2i(2560,1440),Vector2i(1920,1080)]:
		root.size = resolution
		await settle()
		check(settings._key_buttons.size()==11 and settings._key_buttons.map_tasks.text=="R" and settings._key_buttons.map_breakthrough.text=="T","settings shows R tasks and T breakthrough")
		var previous_end := 0.0
		for button: Button in settings._key_buttons.values():
			var row: Control = button.get_parent().get_parent()
			check(row.position.y>=previous_end and row.get_rect().end.y<524,"bindings fit without overlapping rows or toggles")
			previous_end = row.get_rect().end.y
		if DisplayServer.get_name()!="headless" and resolution.x==2560: await capture("bindings-2560")
	settings.queue_free()
	check(map.loadout.snapshot()==before,"viewing and shortcuts preserve gameplay state")
	Meta.stop()
	map.deactivate_location()
	map.queue_free()
	await settle()
	print("BREAKTHROUGH_SCREEN: %d checks; %d failures" % [checks,failures])
	print("OUTPUT: "+directory)
	quit(1 if failures else 0)
