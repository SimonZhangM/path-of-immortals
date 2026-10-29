extends "res://tests/save_actions_tests.gd"
const Settings = preload("res://scripts/settings/game_settings.gd")
var render := false

func press_key(code: int) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame
	await settle()

func run() -> void:
	create_timer(90).timeout.connect(func(): quit(2))
	render = OS.get_environment("SYSTEM_SETTINGS_RENDER")=="1"
	directory = "res://artifacts/system-settings/"+("render/" if render else "logic/")
	DirAccess.make_dir_recursive_absolute(directory)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(2560,1440)
	var service := root.get_node("GameSettings")
	var safe := Settings.values_snapshot()
	safe.background_pause = false
	safe.background_mute = false
	check(service.apply_values(safe).is_empty(),"test session settings apply")
	service.set_application_focus(true)
	AudioServer.set_bus_mute(0,true)
	var real_paths := [Slots.AUTO_PATH,Slots.quick_path(),Slots.working_path(),"user://manual_save_02.json","user://save_slots.json",Session.INDEX_PATH]
	var before := []
	for path: String in real_paths: before.append(FileAccess.get_sha256(path))
	var raw := Files.read(Slots.AUTO_PATH)
	Slots.auto_path = directory+"auto.json"
	Session.index_path = directory+"session.json"
	Session.clear_selection()
	preload("res://scripts/entry/start_menu_background_cycle.gd").state_path = directory+"background.cfg"
	Files.write(Slots.working_path(),raw)
	var map = load("res://scenes/maps/qingshizhen.tscn").instantiate()
	map.inventory_save_path = Slots.working_path()
	map.defer_map_music = true
	map.defer_optional_views = true
	root.add_child(map)
	current_scene = map
	check(map.startup_error.is_empty(),"isolated map loaded")
	await settle()
	await click(map.status_header.settings_button)
	check(map.is_system_menu_open(),"gear opens system menu")
	await click(map.system_menu_controller.menu.buttons.settings)
	var panel = map.system_menu_controller.settings
	check(is_instance_valid(panel),"settings menu opens shared five-page view")
	if not is_instance_valid(panel): quit(1); return
	if render:
		# Render the approved switch defaults in the editable draft while the
		# isolated automation session itself keeps background pausing disabled.
		panel.draft.background_pause = true
		panel.draft.background_mute = true
		panel._refresh_values()
	check(not map.system_menu_controller.menu.visible and map.status_header.visible,"settings retains header beneath modal and hides parent menu")
	var prior_position: Vector2 = map.travel.map_position
	map._process(10)
	check(map.travel.map_position==prior_position,"settings pauses travel")
	var center: Vector2 = panel.canvas.get_global_rect().get_center()
	check(center.is_equal_approx(Vector2(root.size)*0.5),"settings canvas centered on viewport")
	check(panel.pages.size()==5 and panel.widgets.size()==16 and panel._key_buttons.size()==9,"five pages and seventeen settings including nine-action key mapping")
	check(panel.reset_button.get_theme_stylebox("normal").texture.resource_path.ends_with("UI-start-button3.webp"),"default button uses requested button3")
	check(panel.reset_button.get_theme_stylebox("hover").texture.resource_path.ends_with("UI-start-button2.webp"),"hover uses requested button2")
	for resolution in [Vector2i(2560,1440),Vector2i(1920,1080)]:
		root.size = resolution
		await settle()
		var row_start: Vector2
		var heading_start: Vector2
		for page: String in ["game","controls","display","audio","other"]:
			await click(panel.tabs[page])
			check(panel.current_page==page and panel.pages[page].visible,"tab input selects "+page)
			if page=="game":
				row_start = panel.first_rows[page].global_position
				heading_start = panel.heading_origins[page].global_position
			check(panel.first_rows[page].global_position.is_equal_approx(row_start),"first setting row shares x/y "+page)
			check(panel.heading_origins[page].global_position.is_equal_approx(heading_start),"heading shares x/y "+page)
			check(panel.canvas.get_global_rect().get_center().is_equal_approx(Vector2(resolution)*0.5),"center remains fixed "+page)
			if render: await capture("%s-%d" % [page,resolution.x])
		check(panel.reset_button.disabled,"read-only page reset disabled")
	if not render:
		panel.select_page("game")
		await settle()
		await click(panel.widgets.auto_save)
		check(not panel.draft.auto_save and panel.widgets.auto_save_minutes.disabled,"auto off disables interval in draft")
		check(Settings.value("auto_save",false),"draft does not change live autosave")
		await press_key(KEY_ESCAPE)
		check(not is_instance_valid(map.system_menu_controller.settings) and map.system_menu_controller.menu.visible,"Escape cancels child and returns parent")
		check(map.is_system_menu_open() and map.status_header.visible,"cancel retains header and does not resume underlying map")
		await click(map.system_menu_controller.menu.buttons.settings)
		panel = map.system_menu_controller.settings
		panel.select_page("audio")
		await settle()
		panel.widgets.volume_music.value = 33
		check(is_equal_approx(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("Music")),0.33),"volume preview reaches music bus")
		check(is_equal_approx(float(Settings.value("volume_music")),1.0),"audio preview does not commit")
		await click(panel.cancel_button)
		check(is_equal_approx(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("Music")),1.0),"cancel restores preview volume")
		await click(map.system_menu_controller.menu.buttons.settings)
		panel = map.system_menu_controller.settings
		panel.select_page("controls")
		await settle()
		await click(panel._key_buttons.battle_pause)
		await press_key(KEY_I)
		check(panel.capture_action=="battle_pause" and not panel.message.text.is_empty(),"capture rejects battle key overlapping battle inventory action")
		await press_key(KEY_ESCAPE)
		check(is_instance_valid(panel) and panel.capture_action.is_empty(),"Escape cancels capture without closing settings")
		await click(panel._key_buttons.map_inventory)
		await press_key(KEY_G)
		check(not panel.capture_action.is_empty() and not panel.message.text.is_empty(),"same context key conflict remains in capture")
		await press_key(KEY_K)
		check(panel.capture_action.is_empty() and panel.draft.bindings.map_inventory==KEY_K,"single replacement key captured")
		check(InputMap.action_get_events("map_inventory")[0].physical_keycode==KEY_I,"unapplied binding stays live default")
		await click(panel.apply_button)
		check(InputMap.action_get_events("map_inventory")[0].physical_keycode==KEY_K,"apply updates actual InputMap")
		check(map.system_menu_controller.menu.visible,"apply returns system menu")
		await click(map.system_menu_controller.menu.buttons.settings)
		panel = map.system_menu_controller.settings
		panel.select_page("controls")
		await click(panel.reset_button)
		check(panel.draft.bindings.map_inventory==KEY_I,"reset this page restores key defaults in draft")
		await click(panel.apply_button)
	else:
		await click(panel.cancel_button)
	# Compare against the actual save browser's fitted canvas, not a copy of its formula.
	var catalog := Catalog.new()
	catalog.index_path = directory+"slots.json"
	catalog.legacy_path = Slots.auto_path
	catalog.manual_directory = directory
	var saves = load("res://scripts/map/map_save_browser_controller.gd").new()
	saves.map = map
	saves.catalog_override = catalog
	map.add_child(saves)
	map.save_browser_controller = saves
	await click(map.system_menu_controller.menu.buttons.saves)
	await settle()
	check(saves.browser.canvas.get_global_rect().get_center().is_equal_approx(Vector2(root.size)*0.5),"settings and UI-start-saveload share actual center")
	await press_key(KEY_ESCAPE)
	await click(map.system_menu_controller.menu.buttons.resume)
	check(not map.is_system_menu_open() and map.status_header.visible,"resume restores game header")
	map.deactivate_location()
	Meta.stop()
	map.queue_free()
	await settle()
	var entry = load("res://scenes/entry/start_menu.tscn").instantiate()
	root.add_child(entry)
	current_scene = entry
	while entry.entrance.active: await process_frame
	entry._request_menu(&"settings")
	await settle()
	check(is_instance_valid(entry.settings_panel) and not entry.primary_button.visible,"start menu opens same settings view")
	await press_key(KEY_ESCAPE)
	check(not is_instance_valid(entry.settings_panel) and entry.primary_button.visible,"start settings returns to start menu")
	entry.queue_free()
	await settle()
	for i in real_paths.size(): check(before[i]==FileAccess.get_sha256(real_paths[i]),"real save unchanged "+str(i))
	print("SYSTEM_SETTINGS: %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)
