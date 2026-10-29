extends SceneTree
const Catalog = preload("res://scripts/entry/save_catalog.gd")
const Files = preload("res://scripts/entry/save_file.gd")
const Metadata = preload("res://scripts/entry/save_metadata.gd")
const Session = preload("res://scripts/entry/game_save_session.gd")
const START = preload("res://scenes/entry/start_menu.tscn")
const Browser = preload("res://scripts/entry/save_browser.gd")
var checks := 0
var failures := 0
var directory := "res://artifacts/save-browser/run-%d/" % Time.get_ticks_usec()
var catalog := Catalog.new()
var fixture: Dictionary
var paths: Array[String] = []

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func settle() -> void:
	for index in 5: await process_frame
func click(control: Control) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = control.get_global_rect().get_center()
	motion.global_position = motion.position
	root.push_input(motion,true)
	await process_frame
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = control.get_global_rect().get_center()
		event.global_position = event.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame
func wheel(control: Control, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = control.get_global_rect().get_center()
	event.button_index = MOUSE_BUTTON_WHEEL_DOWN if down else MOUSE_BUTTON_WHEEL_UP
	event.pressed = true
	root.push_input(event,true)
	event.pressed = false
	root.push_input(event,true)
func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event,true)
func digest(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
func capture(name_: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/save-browser/"+name_+".png")

func run() -> void:
	create_timer(110).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1920,1080)
	DirAccess.make_dir_recursive_absolute(directory)
	var guarded: Dictionary = {}
	for path in [MapLoadoutStore.DEFAULT_PATH,MapLoadoutStore.DEFAULT_PATH+".bak",Session.INDEX_PATH,Session.INDEX_PATH+".bak","user://save_slots.json"]:
		guarded[path] = digest(path)
	# Read the actual character only as a fixture; every write/load uses a new project file.
	fixture = Files.read(MapLoadoutStore.DEFAULT_PATH)
	if fixture.is_empty():
		var registry := ContentRegistry.new()
		check(registry.load_base_content(),"fixture registry")
		fixture = MapLoadoutStore.create_state(registry,registry.get_board("base.board.bag")).state.snapshot()
	for index in 7:
		var path := directory+"slot-%02d.json" % (index+1)
		var raw := fixture.duplicate(true)
		if index==0: raw.erase("save_info")
		if index>0:
			raw.narrative.identity = {"surname":"沈","given_name":"知远" if index%2 else "映棠"}
			raw.save_info = {"version":1,"chapter_id":"prologue","saved_at_unix":1793077200+index*60,
				"timezone_bias":480,"playtime_ms":3600000*index,"playtime_complete":true}
		check(Files.write(path,raw)==OK,"write isolated fixture")
		paths.append(path)
	catalog.index_path = directory+"slots.json"
	catalog.legacy_path = paths[0]
	Session.index_path = directory+"last.json"
	preload("res://scripts/entry/start_menu_background_cycle.gd").state_path = directory+"background.cfg"
	Session.clear_selection()
	check(catalog.entries().size()==1 and catalog.entries()[0].slot==1,"legacy character is sole first slot; no directory scan")
	var first := catalog.entries()[0]
	check(first.name==DialogueJournal.full_name(fixture.narrative),"actual identity from narrative")
	check(first.rank=="结丹一层" and first.location=="青石镇","current fixture realm/location")
	check(first.picture.ends_with("map-worldmap-qingshizhen.webp"),"location picture from map id")
	check(first.calendar=="青鹿年·春" and first.chapter=="序章 山外有仙","chapter and actual calendar")
	check(first.duration=="未记录" and first.saved_at!="未记录","old duration unknown; real modified time fallback")
	check(Catalog.duration_text(360001000)=="100:00:01","duration does not wrap at 24 hours")
	check(Catalog.timestamp_text(0,480)=="未记录","unknown date not fabricated")
	for path in paths.slice(1): check(catalog.register(path)==OK,"explicit slot registration")
	check(catalog.register(paths[1])==OK and catalog.entries().size()==7,"registration deduplicates")
	check(catalog.entries()[1].duration=="01:00:00","recorded duration")
	check(not Session.has_save(Session.PREVIEW_PATH),"creation preview not a game save")
	var bad_path := directory+"bad.json"
	Files.write(bad_path,{"version":2})
	check(not catalog.describe(bad_path,8).readable,"invalid envelope disabled")
	var backup_path := directory+"recovered.json"
	Files.write(backup_path+".bak",fixture)
	catalog.last_path = backup_path
	check(catalog.entries().size()==8 and catalog.entries()[7].readable,"missing main uses one recovery entry")
	catalog.last_path = ""
	# Metadata remains presentation-only and never writes an old gameplay snapshot.
	var timing_path := directory+"timing.json"
	Files.write(timing_path,fixture)
	Metadata.start(timing_path)
	Metadata.started_ms -= 1500
	var start_ticks := Metadata.started_ms
	Metadata.start(timing_path)
	check(Metadata.started_ms==start_ticks,"same character/map transitions do not restart clock")
	var changed := Files.read(timing_path)
	changed.spirit_stones = 12345
	Files.write(timing_path,changed)
	check(Metadata.flush()==OK,"playtime flush succeeds")
	var stamped := Files.read(timing_path)
	check(stamped.spirit_stones==12345 and stamped.calendar==fixture.calendar,"flush preserves newest gameplay and game days")
	check(stamped.save_info.playtime_ms>=1500 and not stamped.save_info.playtime_complete,"old history remains explicitly incomplete")
	Metadata.stop()
	var stopped := digest(timing_path)
	check(Metadata.flush()==OK and stopped==digest(timing_path),"no active character means no timer write")
	var fresh := Metadata.stamp(fixture,directory+"new.json")
	check(fresh.save_info.playtime_ms==0 and fresh.save_info.playtime_complete,"new save starts at true zero")
	# A real open/return/select/scroll/load flow; main music must remain the same player.
	var page = START.instantiate()
	page.continue_fallback_path = paths[0]
	page.save_catalog_override = catalog
	root.add_child(page)
	current_scene = page
	while page.entrance.active: await process_frame
	var music: AudioStreamPlayer = page.music
	var background: Texture2D = page.background.texture
	await click(page.menu_buttons[0])
	await settle()
	check(is_instance_valid(page.save_browser),"load menu opens actual browser")
	if not is_instance_valid(page.save_browser): quit(1); return
	var browser = page.save_browser
	check(browser.row_buttons.size()==7 and browser.selected_index==0,"seven actual slots, first selected")
	await click(browser.row_buttons[1])
	check(browser.selected_index==1 and browser.detail_values[0].text=="沈知远","row click refreshes real details")
	await capture("seven-1920")
	for index in 8: wheel(browser.list,true)
	await settle()
	check(browser.list.scroll_vertical>0,"native wheel scrolls seven slots")
	check(browser.list.get_global_rect().encloses(browser.row_buttons[6].get_global_rect()),"last row fully reachable")
	await click(browser.row_buttons[6])
	check(browser.selected_index==6,"last row can be selected after scrolling")
	await capture("seven-last-1920")
	await click(browser.menu_back_button)
	await settle()
	check(page.save_browser==null and page.music==music and music.playing and page.background.texture==background,"return retains cover and music")
	# Static first-slot views at both target resolutions, no fake empty rows.
	var single := Catalog.new()
	single.index_path = directory+"unused-index.json"
	single.legacy_path = paths[0]
	page.save_catalog_override = single
	await click(page.menu_buttons[0])
	await settle()
	browser = page.save_browser
	for resolution in [Vector2i(1920,1080),Vector2i(2560,1440)]:
		root.size = resolution
		await settle()
		check(browser.row_buttons.size()==1,"single slot hides unused rows")
		check(browser.load_button.get_global_rect().end.y<root.size.y,"buttons fit viewport")
		check(browser.back_button.position==Vector2(1119,812) and browser.load_button.position==Vector2(1351,812),"button source anchors retained")
		await capture("one-%d" % resolution.x)
	key(KEY_ESCAPE)
	await settle()
	check(page.save_browser==null,"Escape returns to same start menu")
	root.size = Vector2i(1920,1080)
	page.save_catalog_override = catalog
	await click(page.menu_buttons[0])
	await settle()
	browser = page.save_browser
	await click(browser.row_buttons[1])
	await click(browser.load_button)
	while is_instance_valid(page) and not root.has_node("GameLoadingOverlay"): await process_frame
	var overlay = root.get_node_or_null("GameLoadingOverlay")
	check(overlay!=null and not music.playing,"read action stops entry music at loading cover")
	while root.has_node("GameLoadingOverlay"): await process_frame
	await settle()
	var map = current_scene
	check(map != null and map.get("loadout") != null and map.startup_error.is_empty(),"full map restore succeeds")
	if map == null or map.get("loadout") == null: quit(1); return
	check(map.inventory_save_path==paths[1] and Session.resume_path("")==paths[1],"selected save becomes continue target")
	check(Metadata.active_path==paths[1],"online clock starts after reveal")
	check(DialogueJournal.full_name(map.loadout.narrative)=="沈知远","selected character actually restored")
	check(map.loadout.spirit_stones==int(fixture.spirit_stones),"saved currency restored")
	check(MapLoadoutStore.save(map.loadout,paths[1]).is_empty(),"gameplay save with metadata succeeds")
	check(Files.read(paths[1]).save_info.playtime_ms>=3600000,"gameplay save preserves cumulative time")
	await capture("loaded-isolated-map")
	map.queue_free()
	await settle()
	Metadata.stop()
	# Menu with no saves and a disappearing selected file.
	var empty := Catalog.new()
	empty.legacy_path = ""
	empty.index_path = directory+"empty.json"
	browser = Browser.new()
	browser.catalog = empty
	root.add_child(browser)
	await settle()
	check(browser.row_buttons.is_empty() and browser.load_button.disabled,"no saves shows no slots and disables read")
	browser.queue_free()
	await settle()
	# A structurally recognized but invalid full state must not be rewritten.
	Files.write(bad_path,{"version":2,"board_id":"unknown.board","placements":[],"owned_units":{}})
	var bad_before := digest(bad_path)
	empty.legacy_path = bad_path
	page = START.instantiate()
	page.continue_fallback_path = bad_path
	page.save_catalog_override = empty
	root.add_child(page)
	current_scene = page
	while page.entrance.active: await process_frame
	await click(page.menu_buttons[0])
	await settle()
	await click(page.save_browser.load_button)
	while is_instance_valid(page) and not root.has_node("GameLoadingOverlay"): await process_frame
	while root.has_node("GameLoadingOverlay"): await process_frame
	await settle()
	check(current_scene.scene_file_path.ends_with("start_menu.tscn") and current_scene.error_label.visible,"invalid full state returns with error")
	check(digest(bad_path)==bad_before and Metadata.active_path.is_empty(),"failed restore changes neither file nor active timer")
	for path in guarded: check(guarded[path]==digest(path),"actual save/index untouched: "+path)
	current_scene.queue_free()
	await settle()
	print("SAVE_BROWSER: %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)
