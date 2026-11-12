extends "res://tests/save_actions_tests.gd"
const Settings = preload("res://scripts/settings/game_settings.gd")

func key(code: Key, repeated := false, pressed := true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = repeated
	root.push_input(event,true)
	await settle()

func make_map(path: String) -> Control:
	Session.clear_selection()
	var map = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path = path
	map.defer_map_music = true
	map.defer_optional_views = true
	root.add_child(map)
	current_scene = map
	await settle()
	map.set_process(false)
	return map

func run() -> void:
	create_timer(58).timeout.connect(func(): quit(2))
	directory = "res://artifacts/breakthrough-primary-20261104/run-%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	Slots.auto_path = directory+"auto.json"
	Session.index_path = directory+"last.json"
	root.get_node("SavePlaytime").set_process(false)
	root.get_node("GameSettings").apply_values({"background_pause":false,"background_mute":false})
	root.get_node("GameSettings").set_application_focus(true)
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(2560,1440)
	var map: Control = await make_map(directory+"keyboard.json")
	check(map.startup_error.is_empty(),"isolated map starts")
	var before: Dictionary = map.loadout.snapshot()
	map.set_breakthrough_open(true)
	await settle()
	var screen: Control = map.breakthrough_screen
	var flow: RefCounted = map.breakthrough_session
	var primary: TextureRect = screen.primary_art
	check(primary.texture.resource_path.ends_with("UI-tupo-button-kaishitupo.webp"),"ready page uses authored start image")
	check(screen.board_art.visible and screen.board_art.texture.resource_path==map.loadout.board.texture_path,"actual player board is visible")
	check(screen.board_view.state==map.loadout and screen.board_reference.get_meta("board_id")==map.loadout.board.id,"board is bound to authoritative player loadout")
	check(screen.character_art.texture.resource_path.ends_with("UI-tupo-male.webp") and screen.character_art.get_rect()==Rect2(1081,825,401,401),"male character uses calibrated square source canvas")
	for art: TextureRect in [primary,screen.board_art,screen.character_art]:
		check(art.texture.get_image().has_mipmaps(),"separate artwork has mipmaps")
	var initial_rect := primary.get_global_rect()
	if DisplayServer.get_name()!="headless": await capture("ready-2560")
	await key(KEY_SPACE)
	primary = screen.primary_art
	check(flow.started and flow.phase=="running" and primary.texture.resource_path.ends_with("UI-tupo-button-biguanyunzhuan.webp"),"first Space starts and swaps to running artwork")
	check(primary.get_global_rect()==initial_rect and primary.texture.get_size()==Vector2(1084,362),"swapped artwork preserves size and exact center")
	map._process(1.25)
	check(flow.elapsed_usec==1250000,"started clock advances")
	await key(KEY_SPACE,true)
	await key(KEY_SPACE,false,false)
	check(flow.phase=="running","held and released Space do not repeat commands")
	await key(KEY_SPACE)
	check(flow.phase=="paused" and primary.texture.resource_path.ends_with("biguanyunzhuan.webp") and screen.pause_art.texture.resource_path.ends_with("jixu.webp"),"second Space pauses without reverting primary artwork")
	var stopped: int = flow.elapsed_usec
	map._process(3.0)
	check(flow.elapsed_usec==stopped,"paused clock remains fixed")
	await key(KEY_SPACE)
	check(flow.phase=="running" and screen.change_button.disabled,"third Space resumes and locks adjustment")
	if DisplayServer.get_name()!="headless": await capture("running-2560")
	await click(screen.pause_button)
	check(flow.phase=="paused" and primary.get_global_rect()==initial_rect,"pause click shares session without shifting main artwork")
	var bindings: Dictionary = Settings.value("bindings")
	var original: Dictionary = bindings.duplicate(true)
	bindings.map_tasks = KEY_SPACE
	check(root.get_node("GameSettings").apply_values({"bindings":bindings}).is_empty(),"test remaps another full-screen shortcut onto Space")
	await key(KEY_SPACE)
	check(flow.phase=="running" and map.is_breakthrough_open() and not map.is_task_open(),"breakthrough Space command takes priority in its own page")
	root.get_node("GameSettings").apply_values({"bindings":original})
	await key(KEY_SPACE)
	var field := LineEdit.new()
	screen.add_child(field)
	field.grab_focus()
	await key(KEY_SPACE)
	check(flow.phase=="paused","text editing retains Space input")
	field.release_focus()
	field.queue_free()
	await settle()
	for resolution: Vector2i in [Vector2i(2560,1440),Vector2i(1920,1080)]:
		root.size = resolution
		await settle()
		var factor: float = screen.stage.scale.x
		check(primary.get_global_rect().get_center().distance_to(Vector2(1283,1331)*factor)<0.1,"primary images share the center shifted left by three pixels")
		check(absf(primary.size.x/primary.size.y-1084.0/362.0)<0.001,"primary source aspect is preserved")
		check((screen.rotation_reference.get_global_transform()*screen.rotation_reference.pivot_offset).distance_to(Vector2(1147.5,1324)*factor)<0.1 and screen.rotation_reference.visible,"rotating image pivot matches recorded yellow ring")
		if DisplayServer.get_name()!="headless" and resolution.x==1920: await capture("paused-1920")
	await key(KEY_T)
	await key(KEY_SPACE)
	check(flow.phase=="paused" and not map.is_breakthrough_open(),"hidden page does not consume Space for breakthrough")
	await key(KEY_T)
	check(primary.texture.resource_path.ends_with("biguanyunzhuan.webp"),"primary remains running artwork after closing and reopening")
	check(map.loadout.snapshot()==before,"input and new images do not mutate growth, quest or inventory")
	Meta.stop()
	map.deactivate_location()
	map.queue_free()
	await settle()
	map = await make_map(directory+"mouse.json")
	map.set_breakthrough_open(true)
	await settle()
	screen = map.breakthrough_screen
	await click(screen.start_button)
	check(map.breakthrough_session.started and screen.primary_art.texture.resource_path.ends_with("biguanyunzhuan.webp"),"actual start click swaps authored image")
	await click(screen.pause_button)
	check(map.breakthrough_session.phase=="paused" and screen.primary_art.texture.resource_path.ends_with("biguanyunzhuan.webp"),"pause click keeps running main image")
	await click(screen.pause_button)
	check(map.breakthrough_session.phase=="running" and screen.primary_art.texture.resource_path.ends_with("biguanyunzhuan.webp"),"resume click keeps running main image")
	Meta.stop()
	map.deactivate_location()
	map.queue_free()
	await settle()
	print("BREAKTHROUGH_PRIMARY: %d checks; %d failures" % [checks,failures])
	print("OUTPUT: "+directory)
	quit(1 if failures else 0)
