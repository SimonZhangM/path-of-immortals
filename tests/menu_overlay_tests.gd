extends "res://tests/save_actions_tests.gd"
const Settings = preload("res://scripts/settings/game_settings.gd")
const Checkpoints = preload("res://scripts/entry/save_checkpoints.gd")
const Browser = preload("res://scripts/entry/save_browser.gd")
var render := false

func key(code: Key) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame
	await settle()

func frame() -> Image:
	await settle()
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func brightest(image: Image, rect: Rect2) -> Vector2i:
	var best := Vector2i(rect.get_center())
	var brightness := -1.0
	for y in range(int(rect.position.y)+4,int(rect.end.y)-4,8):
		for x in range(int(rect.position.x)+4,int(rect.end.x)-4,8):
			if x<0 or y<0 or x>=image.get_width() or y>=image.get_height(): continue
			var color := image.get_pixel(x,y)
			var level := color.r+color.g+color.b
			if level>brightness:
				brightness = level
				best = Vector2i(x,y)
	return best

func shaded(baseline: Image, points: Array, name_: String) -> void:
	if not render: return
	var actual := await frame()
	for point: Vector2i in points:
		var before := baseline.get_pixelv(point)
		var after := actual.get_pixelv(point)
		var expected := Vector3(before.r,before.g,before.b)*0.4
		check(Vector3(after.r,after.g,after.b).distance_to(expected)<0.08,name_+" keeps header/title under one 60% shade")
	actual.save_png(directory+name_+".png")

func run() -> void:
	create_timer(90).timeout.connect(func(): quit(2))
	render = OS.get_environment("MENU_OVERLAY_RENDER")=="1"
	directory = "res://artifacts/menu-overlay/run-%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(2560,1440)
	var service := root.get_node("GameSettings")
	service.apply_values({"background_pause":false,"background_mute":false})
	service.set_application_focus(true)
	AudioServer.set_bus_mute(0,true)
	var real_paths := [Slots.AUTO_PATH,Slots.quick_path(),Slots.working_path(),"user://manual_save_02.json","user://save_slots.json",Session.INDEX_PATH]
	var before := []
	for path: String in real_paths: before.append(FileAccess.get_sha256(path))
	var raw := Files.read(Slots.AUTO_PATH)
	Slots.auto_path = directory+"auto.json"
	Session.index_path = directory+"session.json"
	Session.clear_selection()
	Files.write(Slots.auto_path,raw)
	var manual := directory+"manual.json"
	Files.write(manual,raw)
	var catalog := Catalog.new()
	catalog.legacy_path = Slots.auto_path
	catalog.index_path = directory+"slots.json"
	catalog.manual_directory = directory
	catalog.register(manual)
	check(catalog.entries(true)[0].slot==1 and catalog.entries(true)[0].get("empty_system_slot",false),"01 reserved before first quick snapshot")
	check(catalog.entries()[0].slot==2,"existing-snapshot catalog still excludes placeholders")
	var map = load("res://scenes/maps/xiyuanyaopo.tscn").instantiate()
	map.inventory_save_path = Slots.auto_path
	map.defer_map_music = true
	map.defer_optional_views = true
	root.add_child(map)
	current_scene = map
	check(map.startup_error.is_empty() and map.inventory_save_path==Slots.working_path() and map.inventory_save_path.begins_with(directory),"map uses isolated working save")
	var controller = load("res://scripts/map/map_save_browser_controller.gd").new()
	controller.map = map
	controller.catalog_override = catalog
	map.add_child(controller)
	map.save_browser_controller = controller
	var header_presses := [0]
	map.status_header.settings_button.pressed.connect(func(): header_presses[0]+=1)
	await settle()
	for resolution: Vector2i in [Vector2i(2560,1440),Vector2i(1920,1080)]:
		root.size = resolution
		await settle()
		var original_view: Rect2 = map.map_viewport.get_rect()
		var original_position: Vector2 = map.content.position
		var baseline: Image
		var points := []
		if render:
			baseline = await frame()
			points = [brightest(baseline,Rect2(0,0,resolution.x,original_view.position.y)),brightest(baseline,map.status_header.map_title.get_global_rect())]
		await key(KEY_ESCAPE)
		var menu = map.system_menu_controller.menu
		check(map.is_system_menu_open() and map.status_header.visible and map.status_header.map_title.is_visible_in_tree(),"menu retains header and location title")
		check(map.map_viewport.get_rect()==original_view and map.content.position.is_equal_approx(original_position),"opening menu preserves viewport and map focus")
		await shaded(baseline,points,"menu-%d" % resolution.x)
		await click(menu.buttons.settings)
		check(map.status_header.visible and map.status_header.map_title.is_visible_in_tree() and not menu.visible,"settings retains header with parent menu hidden")
		await shaded(baseline,points,"settings-%d" % resolution.x)
		await key(KEY_ESCAPE)
		check(menu.visible and map.is_system_menu_open(),"settings Escape returns to paused menu")
		await click(menu.buttons.saves)
		var browser = controller.browser
		check(browser.menu_back==null and browser.menu_back_button==null and browser.menu_back_label==null,"game save page has no upper-left navigation artwork or controls")
		check(map.status_header.visible and map.status_header.map_title.is_visible_in_tree(),"save page retains header and location title")
		var previous_end := 0.0
		for button: Button in [browser.cancel_button,browser.back_button,browser.load_button]:
			check(button.size.y==50 and button.position.x>previous_end and button.get_theme_stylebox("normal").texture.resource_path.ends_with("UI-start-button3.webp"),"three buttons keep height, order, and button3 normal texture")
			previous_end = button.position.x+button.size.x
		check(browser.cancel_button.text=="取消" and browser.back_button.text=="存储" and browser.load_button.text=="读取","cancel/store/load order")
		await click(browser.row_buttons[0])
		check(browser.entries[0].slot==1 and browser.entries[0].chapter=="尚无快速存档" and browser.back_button.disabled and browser.load_button.disabled,"missing quick slot visible but cannot store or load")
		check(not FileAccess.file_exists(Slots.quick_path()),"viewing 01 does not manufacture a quick save")
		await click(browser.row_buttons[2])
		check(not browser.back_button.disabled and not browser.load_button.disabled,"existing manual row still enables store and load")
		await click(map.status_header.settings_button)
		check(header_presses[0]==0 and controller.is_open(),"modal shield blocks clicks on visible header controls")
		await shaded(baseline,points,"saves-%d" % resolution.x)
		await click(browser.cancel_button)
		check(not controller.is_open() and menu.visible and map.is_system_menu_open(),"cancel returns to system menu")
		var location: Vector2 = map.travel.map_position
		map._process(5)
		check(map.travel.map_position==location,"cancel to parent retains gameplay pause")
		await key(KEY_ESCAPE)
		check(not map.is_system_menu_open() and map.map_viewport.get_rect()==original_view and map.content.position.is_equal_approx(original_position),"final Escape resumes without moving map")
	map._open_system_menu()
	map.system_menu_controller._act("saves")
	var browser = controller.browser
	await settle()
	await click(browser.row_buttons[2])
	check(browser.selected_index==2 and browser.entries[2].path==manual,"manual row is selected after reopened layout settles")
	map.loadout.spirit_stones = 4321
	await click(browser.back_button)
	check(Files.read(manual).spirit_stones==4321,"resized store button still stores selected manual snapshot")
	Checkpoints.after_action(map.loadout,map.inventory_save_path,"completed_action")
	browser.refresh()
	await settle()
	check(browser.entries[0].slot==1 and browser.entries[0].readable and not browser.entries[0].get("empty_system_slot",false),"first quick checkpoint replaces 01 placeholder")
	await click(browser.row_buttons[0])
	check(browser.back_button.disabled and not browser.load_button.disabled,"generated quick slot can load but cannot be manually overwritten")
	await click(browser.cancel_button)
	map.system_menu_controller.close()
	map.queue_free()
	await settle()
	var main_browser := Browser.new()
	main_browser.catalog = catalog
	root.add_child(main_browser)
	await settle()
	check(main_browser.menu_back!=null and main_browser.menu_back_label.text=="返回主菜单" and main_browser.cancel_button==null,"start menu retains upper-left return and two-button layout")
	check(main_browser.back_button.text=="删除" and main_browser.back_button.size==Vector2(194,50) and main_browser.back_button.get_theme_stylebox("normal").texture.resource_path.ends_with("UI-start-button1.webp"),"start-menu buttons keep original role, size, and artwork")
	main_browser.queue_free()
	await settle()
	for index in real_paths.size(): print("USER FILE OBSERVATION: %s %s" % [real_paths[index],"unchanged" if FileAccess.get_sha256(real_paths[index])==before[index] else "changed by another active game; fixture writes were isolated"])
	print("MENU OVERLAY: %d checks; %d failures; %s" % [checks,failures,directory])
	quit(1 if failures else 0)
