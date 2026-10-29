extends "res://tests/save_actions_tests.gd"
## Focused regression: selecting and restoring an automatic save from the game.
func run() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1920,1080)
	directory = "res://artifacts/auto-save-selection/run-%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	var real_paths := [Slots.AUTO_PATH,"user://manual_save_02.json","user://save_slots.json",Session.INDEX_PATH]
	var before := []
	for path in real_paths: before.append(FileAccess.get_sha256(path))
	var raw := Files.read(Slots.AUTO_PATH)
	Slots.auto_path = directory+"auto.json"
	Session.index_path = directory+"session.json"
	Session.clear_selection()
	var catalog := Catalog.new()
	catalog.index_path = directory+"slots.json"
	catalog.legacy_path = Slots.auto_path
	catalog.manual_directory = directory
	raw.save_info = {"save_kind":"auto","playtime_ms":1234000,"playtime_complete":true}
	Files.write(Slots.auto_path,raw)
	var manual := directory+"manual_save_02.json"
	var copy := raw.duplicate(true)
	copy.save_info.save_kind = "manual"
	Files.write(manual,copy)
	catalog.register(manual)
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
	map._open_system_menu()
	await click(map.system_menu_controller.menu.buttons.saves)
	await settle()
	var browser = controller.browser
	await click(browser.row_buttons[0])
	check(browser.selected_index==0 and not browser.row_buttons[0].disabled,"automatic row selectable by mouse")
	check(browser.back_button.disabled and browser.back_button.modulate.r==0.5,"store disabled and grey for auto")
	check(not browser.load_button.disabled,"automatic save readable")
	var auto_hash := FileAccess.get_sha256(Slots.auto_path)
	await click(browser.back_button)
	check(FileAccess.get_sha256(Slots.auto_path)==auto_hash,"disabled store does not write automatic save")
	check(not Ops.store_manual(catalog,map.loadout,Slots.auto_path,Slots.auto_path).is_empty(),"service still rejects manual overwrite of auto")
	await click(browser.row_buttons[1])
	check(not browser.back_button.disabled and browser.back_button.modulate==Color.WHITE,"manual selection restores store appearance")
	await click(browser.row_buttons[-1])
	check(not browser.back_button.disabled and browser.load_button.disabled,"empty slot remains store-only")
	await click(browser.row_buttons[0])
	await capture("auto-selected-1920")
	# Change only the live value; reloading must restore the earlier on-disk value.
	var saved_stones: int = Files.read(Slots.auto_path).spirit_stones
	map.loadout.spirit_stones = saved_stones+9876
	await click(browser.load_button)
	while is_instance_valid(map) or root.has_node("GameLoadingOverlay"): await process_frame
	await settle()
	var loaded = current_scene
	check(loaded.get("loadout")!=null and loaded.startup_error.is_empty(),"automatic reload reaches actual map")
	check(loaded.loadout.spirit_stones==saved_stones,"reload does not overwrite selected automatic snapshot first")
	check(loaded.inventory_save_path==Slots.working_path(),"resumed game uses isolated live session")
	check(FileAccess.get_sha256(Slots.auto_path)==auto_hash,"reload preserves timed automatic snapshot")
	Meta.stop()
	loaded.deactivate_location()
	loaded.queue_free()
	current_scene = null
	Session.clear_selection()
	await settle()
	for index in real_paths.size():
		check(FileAccess.get_sha256(real_paths[index])==before[index],"real save unchanged: "+real_paths[index])
	print("AUTO_SAVE_SELECTION: %d checks; %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
