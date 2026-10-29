extends "res://tests/save_actions_tests.gd"

func key(code: Key, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	event.echo = echo
	root.push_input(event,true)
	await process_frame
	event = InputEventKey.new()
	event.keycode = code
	root.push_input(event,true)
	await settle()

func run() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(2560,1440)
	directory = "res://artifacts/system-menu/"+OS.get_environment("SYSTEM_MENU_MODE")+"/"
	DirAccess.make_dir_recursive_absolute(directory)
	var real_paths := [Slots.AUTO_PATH,"user://manual_save_02.json","user://save_slots.json",Session.INDEX_PATH]
	var before := []
	for path in real_paths: before.append(FileAccess.get_sha256(path))
	var raw := Files.read(Slots.AUTO_PATH)
	Slots.auto_path = directory+"auto.json"
	Session.index_path = directory+"session.json"
	Session.clear_selection()
	preload("res://scripts/entry/start_menu_background_cycle.gd").state_path = directory+"background.cfg"
	Files.write(Slots.auto_path,raw)
	var catalog := Catalog.new()
	catalog.index_path = directory+"slots.json"
	catalog.legacy_path = Slots.auto_path
	catalog.manual_directory = directory
	var map = load("res://scenes/maps/qingshizhen.tscn").instantiate()
	map.inventory_save_path = Slots.auto_path
	map.defer_map_music = true
	map.defer_optional_views = true
	root.add_child(map)
	current_scene = map
	check(map.startup_error.is_empty(),"isolated map starts")
	var controller = load("res://scripts/map/map_save_browser_controller.gd").new()
	controller.map = map
	controller.catalog_override = catalog
	map.add_child(controller)
	map.save_browser_controller = controller
	await settle()
	if OS.get_environment("SYSTEM_MENU_MODE")=="quit":
		map._open_system_menu()
		map.loadout.spirit_stones = 7654
		print("SYSTEM_MENU_QUIT_REQUESTED")
		await click(map.system_menu_controller.menu.buttons.quit)
		return
	if OS.get_environment("SYSTEM_MENU_MODE")=="render":
		map._open_system_menu()
		await capture("menu-2560")
		check(map.system_menu_controller.menu.canvas.scale.is_equal_approx(Vector2(0.7,0.7)),"2K seventy percent")
		root.size = Vector2i(1920,1080)
		await capture("menu-1920")
		check(map.system_menu_controller.menu.canvas.scale.is_equal_approx(Vector2(0.525,0.525)),"1080 proportional scale")
		Meta.stop()
		map.deactivate_location()
		quit(1 if failures else 0)
		return
	var original_position: Vector2 = map.content.position
	await key(KEY_ESCAPE)
	check(map.is_system_menu_open() and not map.is_save_browser_open(),"Escape opens menu")
	var menu = map.system_menu_controller.menu
	check(menu.canvas.get_global_rect().get_center().is_equal_approx(Vector2(1280,720)),"whole canvas centered")
	check(menu.canvas.scale.is_equal_approx(Vector2(0.7,0.7)),"native 70 percent")
	check(map.status_header.visible and map.map_viewport.position.y>0,"header and original map layout remain beneath modal")
	var location: Vector2 = map.travel.map_position
	map._process(5.0)
	check(map.travel.map_position==location,"menu stops movement")
	await key(KEY_I)
	await key(KEY_M)
	check(not map.is_inventory_open() and not map.is_world_map_open(),"menu blocks map shortcuts")
	await key(KEY_ESCAPE,true)
	check(map.is_system_menu_open(),"held escape cannot reopen or close")
	await key(KEY_ESCAPE)
	check(not map.is_system_menu_open() and map.status_header.visible,"second Escape resumes")
	check(map.content.position.distance_to(original_position)<0.1,"map focus restored")
	await click(map.status_header.settings_button)
	check(map.is_system_menu_open(),"gear opens menu")
	menu = map.system_menu_controller.menu
	check(not menu.buttons.settings.disabled and menu.buttons.help.disabled,"settings enabled and help remains unavailable")
	await click(menu.buttons.saves)
	check(map.is_save_browser_open() and not menu.visible,"save button opens child without double shade")
	check(controller.browser.menu_back==null and controller.browser.cancel_button.text=="取消","child uses bottom cancel instead of upper-left return")
	await key(KEY_ESCAPE)
	check(not map.is_save_browser_open() and menu.visible and map.status_header.visible,"Escape from child retains header and modal pause")
	await click(menu.buttons.saves)
	await click(controller.browser.cancel_button)
	check(menu.visible and not map.is_save_browser_open(),"child back button returns menu")
	await click(menu.buttons.resume)
	check(not map.is_system_menu_open() and map.status_header.visible,"resume button closes menu")
	map.set_world_map_open(true)
	await key(KEY_ESCAPE)
	check(not map.is_world_map_open() and not map.is_system_menu_open(),"existing page Escape only closes page")
	await key(KEY_ESCAPE)
	menu = map.system_menu_controller.menu
	var normal_path: String = map.inventory_save_path
	map.inventory_save_path = directory+"missing/auto.json"
	await click(menu.buttons.main_menu)
	check(current_scene==map and not menu.busy and not menu.message.text.is_empty(),"save failure prevents leaving")
	map.inventory_save_path = normal_path
	map.loadout.spirit_stones = 7654
	await click(menu.buttons.main_menu)
	while is_instance_valid(map): await process_frame
	await settle()
	check(current_scene.scene_file_path=="res://scenes/entry/start_menu.tscn","return reaches real start menu")
	check(Files.read(Slots.auto_path).spirit_stones==7654,"return saves current values")
	check(Session.resume_path("")==Slots.auto_path,"continue target saved")
	check(Meta.active_path.is_empty(),"playtime stops in main menu")
	check(root.get_node("MapPresentation").music_state=="stopped","map music stopped")
	check(current_scene.music!=null,"entry music restored")
	for i in real_paths.size(): check(before[i]==FileAccess.get_sha256(real_paths[i]),"real save unchanged")
	print("SYSTEM_MENU: %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)
