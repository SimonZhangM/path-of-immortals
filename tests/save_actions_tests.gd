extends SceneTree
const Files = preload("res://scripts/entry/save_file.gd")
const Catalog = preload("res://scripts/entry/save_catalog.gd")
const Ops = preload("res://scripts/entry/save_operations.gd")
const Slots = preload("res://scripts/entry/save_slot_policy.gd")
const Session = preload("res://scripts/entry/game_save_session.gd")
const Meta = preload("res://scripts/entry/save_metadata.gd")
var checks := 0
var failures := 0
var directory := "res://artifacts/save-actions/run-%d/" % Time.get_ticks_usec()
func _initialize() -> void: run.call_deferred()
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(text)
func settle() -> void:
	for i in 5: await process_frame
func click(control: Control) -> void:
	var position := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	root.push_input(motion,true)
	await process_frame
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame
func capture(name_: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory+name_+".png")
func run() -> void:
	create_timer(90).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1920,1080)
	DirAccess.make_dir_recursive_absolute(directory)
	var real_paths := [Slots.AUTO_PATH,"user://manual_save_02.json","user://save_slots.json",Session.INDEX_PATH]
	var before := []
	for path in real_paths: before.append(FileAccess.get_sha256(path))
	var raw := Files.read(Slots.AUTO_PATH)
	Slots.auto_path = directory+"auto.json"
	Session.index_path = directory+"session.json"
	Session.clear_selection()
	preload("res://scripts/entry/start_menu_background_cycle.gd").state_path = directory+"background.cfg"
	var catalog := Catalog.new()
	catalog.index_path = directory+"slots.json"
	catalog.legacy_path = Slots.auto_path
	catalog.manual_directory = directory
	raw.save_info = {"save_kind":"auto","playtime_ms":1234000,"playtime_complete":true}
	Files.write(Slots.auto_path,raw)
	var manual := directory+"manual_save_02.json"
	var copy := raw.duplicate(true)
	copy.save_info.save_kind = "manual"
	copy.spirit_stones = 4321
	Files.write(manual,copy)
	check(catalog.register(manual)==OK,"register isolated manual")
	# Real settings-button input opens the game mode on an isolated live map.
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
	await click(map.status_header.settings_button)
	await settle()
	check(map.is_system_menu_open(),"gear opens system menu")
	await click(map.system_menu_controller.menu.buttons.saves)
	if not map.is_save_browser_open(): quit(1); return
	var browser = controller.browser
	check(browser.back_button.text=="存储" and browser.load_button.text=="读取","game mode action labels")
	check(browser.back_button.get_theme_font_size("font_size")==24 and browser.load_button.get_theme_font_size("font_size")==24,"both action fonts reduced two points")
	check(not browser.row_buttons[0].disabled and browser.selected_index==1,"auto row selectable and manual selected initially")
	check(not map.status_header.visible,"game header hidden behind browser return navigation")
	await click(browser.row_buttons[0])
	check(browser.selected_index==0 and browser.back_button.disabled and not browser.load_button.disabled,"auto can be read but not manually overwritten")
	await click(browser.row_buttons[1])
	var snapshot = map.loadout.snapshot().duplicate(true)
	map._process(20.0)
	check(map.loadout.snapshot()==snapshot,"modal does not advance gameplay")
	var key := InputEventKey.new()
	key.keycode = KEY_M
	key.pressed = true
	root.push_input(key,true)
	check(not map.is_world_map_open(),"modal blocks world-map shortcut")
	var auto_hash := FileAccess.get_sha256(Slots.auto_path)
	check(not Ops.store_manual(catalog,map.loadout,Slots.auto_path,Slots.auto_path).is_empty(),"backend rejects manual overwrite of automatic slot")
	check(FileAccess.get_sha256(Slots.auto_path)==auto_hash,"auto protected")
	map.loadout.spirit_stones = 5678
	await click(browser.back_button)
	check(Files.read(manual).spirit_stones==5678 and Files.read(manual).save_info.save_kind=="manual","explicit manual overwrite stores live state")
	check(Files.read(manual).save_info.playtime_ms>=1234000,"manual snapshot records current accumulated playtime")
	check(map.inventory_save_path==Slots.auto_path and FileAccess.get_sha256(Slots.auto_path)==auto_hash,"manual saving does not change automatic target or file")
	var fresh_index: int = browser.entries.size()-1
	var fresh_path: String = browser.entries[fresh_index].path
	await click(browser.row_buttons[fresh_index])
	check(browser.load_button.disabled and not browser.back_button.disabled,"empty slot stores but cannot load")
	await click(browser.back_button)
	check(Session.has_save(fresh_path) and Files.read(fresh_path).save_info.save_kind=="manual","empty slot creates registered manual snapshot")
	check(catalog.entries().size()==3,"new manual listed")
	await capture("game-1920")
	root.size = Vector2i(2560,1440)
	await capture("game-2560")
	root.size = Vector2i(1920,1080)
	await settle()
	await click(browser.menu_back_button)
	check(not map.is_save_browser_open() and map.is_system_menu_open(),"top return closes to system menu")
	await click(map.system_menu_controller.menu.buttons.resume)
	await click(map.status_header.settings_button)
	await click(map.system_menu_controller.menu.buttons.saves)
	browser = controller.browser
	await settle()
	await click(browser.row_buttons[1])
	# Persist a different outgoing value: loading must restore the selected manual value.
	map.loadout.spirit_stones = 9999
	var manual_hash := FileAccess.get_sha256(manual)
	await click(browser.load_button)
	while is_instance_valid(map) or root.has_node("GameLoadingOverlay"): await process_frame
	await settle()
	var loaded = current_scene
	check(loaded.get("loadout")!=null and loaded.startup_error.is_empty(),"game-mode reading reaches actual restored map")
	check(loaded.loadout.spirit_stones==5678 and loaded.inventory_save_path==Slots.auto_path,"selected manual restored into automatic slot")
	check(FileAccess.get_sha256(manual)==manual_hash,"loading does not modify manual snapshot")
	Meta.stop()
	loaded.deactivate_location()
	loaded.queue_free()
	current_scene = null
	Session.clear_selection()
	await settle()
	# Menu deletion operates on the selected snapshot including its recovery backup.
	var page = load("res://scenes/entry/start_menu.tscn").instantiate()
	page.continue_fallback_path = Slots.auto_path
	page.save_catalog_override = catalog
	root.add_child(page)
	current_scene = page
	while page.entrance.active: await process_frame
	page._open_saves()
	browser = page.save_browser
	check(browser.back_button.text=="删除" and browser.load_button.text=="读取","menu mode labels")
	check(browser.menu_back_label.text=="返回主菜单","menu return label")
	await capture("menu-1920")
	root.size = Vector2i(2560,1440)
	await capture("menu-2560")
	root.size = Vector2i(1920,1080)
	await settle()
	Files.write(manual,Files.read(manual))
	check(FileAccess.file_exists(manual+".bak"),"deletion fixture has recovery backup")
	await click(browser.row_buttons[1])
	await click(browser.back_button)
	check(not FileAccess.file_exists(manual) and not FileAccess.file_exists(manual+".bak") and not Session.has_save(manual),"delete removes main and backup with no resurrection")
	check(catalog.entries().size()==2 and catalog.entries()[1].slot==3,"other slot identity survives deletion")
	check(not Ops.delete_slot(catalog,directory+"unregistered.json").is_empty(),"unknown files cannot be deleted")
	Session.remember(Slots.auto_path)
	await click(browser.row_buttons[0])
	await click(browser.back_button)
	check(not Session.has_save(Slots.auto_path) and Session.resume_path(Slots.auto_path).is_empty(),"deleting latest auto disables continue")
	await click(browser.menu_back_button)
	check(not page.continue_button.visible,"menu reflects deleted continue target")
	page.queue_free()
	await settle()
	# Failed writes must not mutate a live state or unrelated snapshots.
	var registered_hash := FileAccess.get_sha256(fresh_path)
	var bad_catalog := Catalog.new()
	bad_catalog.legacy_path = Slots.auto_path
	bad_catalog.index_path = directory+"missing-parent/slots.json"
	bad_catalog.manual_directory = directory
	var registry := ContentRegistry.new()
	registry.load_base_content()
	var state: MapLoadoutState = MapLoadoutStore.create_state(registry,registry.get_board("base.board.bag")).state
	var candidate: String = bad_catalog.next_manual_slot().path
	check(not Ops.store_manual(bad_catalog,state,Slots.auto_path,candidate).is_empty(),"index failure reports failure")
	check(not FileAccess.file_exists(candidate) and FileAccess.get_sha256(fresh_path)==registered_hash,"failed registration leaves no new file or unrelated mutation")
	for i in real_paths.size(): check(before[i]==FileAccess.get_sha256(real_paths[i]),"real user file unchanged")
	print("SAVE_ACTIONS: %d checks; %d failures; %s" % [checks,failures,directory])
	quit(1 if failures else 0)
