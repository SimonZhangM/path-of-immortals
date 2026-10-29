extends SceneTree
const Session = preload("res://scripts/entry/game_save_session.gd")
const START = preload("res://scenes/entry/start_menu.tscn")
const DIR := "res://artifacts/start-menu/loading/"
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func hash_file(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
func settle() -> void:
	for i in 6: await process_frame
func click(control: Control) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = control.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)
func run() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0, true)
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1920,1080)
	DirAccess.make_dir_recursive_absolute(DIR)
	var source := Session.resume_path(MapLoadoutStore.DEFAULT_PATH)
	if not FileAccess.file_exists(source): source += ".bak"
	var before_save := hash_file(source)
	var before_index := hash_file(Session.INDEX_PATH)
	var copy := DIR + "copy-%d.json" % Time.get_ticks_usec()
	if not before_save.is_empty():
		var f := FileAccess.open(copy, FileAccess.WRITE)
		f.store_buffer(FileAccess.get_file_as_bytes(source))
		f.close()
	else:
		var registry := ContentRegistry.new()
		check(registry.load_base_content(), "fixture content")
		var created := MapLoadoutStore.create_state(registry, registry.get_board("base.board.bag"))
		check(created.error.is_empty() and MapLoadoutStore.save(created.state, copy).is_empty(), "fixture creation")
	Session.index_path = copy + ".index.json"
	Session.clear_selection()
	preload("res://scripts/entry/start_menu_background_cycle.gd").state_path = copy + ".background.cfg"
	Session.remember(copy)
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(copy))
	var page = START.instantiate()
	page.continue_fallback_path = copy
	root.add_child(page)
	current_scene = page
	while page.entrance.active: await process_frame
	var entry_music: AudioStreamPlayer = page.music
	var entry_position := entry_music.get_playback_position()
	page._request_menu(&"settings")
	page._request_menu(&"load")
	check(entry_music.playing, "settings and load entry keep music")
	page._close_saves()
	await settle()
	page._begin_journey()
	while is_instance_valid(page) or root.has_node("EntrySceneCrossfade"): await process_frame
	check(current_scene.scene_file_path.ends_with("character_preparation.tscn") and is_instance_valid(entry_music)
		and entry_music.playing and entry_music.get_playback_position() > entry_position, "new journey continues same music playback")
	key(KEY_ESCAPE)
	await scene_changed
	page = current_scene
	while page.entrance.active: await process_frame
	check(page.music == entry_music and entry_music.playing, "returning to menu does not restart music")
	root.size = Vector2i(1920,1080)
	await settle()
	await RenderingServer.frame_post_draw
	var menu_background := page.background.texture
	var started := Time.get_ticks_msec()
	click(page.continue_button)
	var overlay = root.get_node_or_null("GameLoadingOverlay")
	check(overlay != null, "loading cover created immediately by real continue click")
	check(overlay.caption.text + overlay.ellipsis.text == "正在进入苍澜界…" and overlay.backdrop != null, "landscape cover and required caption")
	check(overlay.cover_image == menu_background, "loading uses landscape without menu artwork or shade")
	click(page.continue_button)
	key(KEY_ESCAPE)
	check(page._navigating and root.find_children("GameLoadingOverlay", "", false, false).size() == 1, "repeat click and Escape blocked")
	await RenderingServer.frame_post_draw
	var loading_image := root.get_texture().get_image()
	check(overlay.row.get_global_rect().get_center().distance_to(Vector2(root.size)*0.5) < 1.0, "complete caption visually centered")
	var dot_alpha: float = overlay.ellipsis.modulate.a
	var changed := false
	var max_gap := 0.0
	var ticks := 0
	var loading_music_stopped := true
	var premature_map_music := false
	while is_instance_valid(overlay):
		if not overlay._fading:
			loading_music_stopped = loading_music_stopped and (not is_instance_valid(entry_music) or not entry_music.playing)
			premature_map_music = premature_map_music or root.get_node("MapPresentation").music.playing
		changed = changed or absf(overlay.ellipsis.modulate.a-dot_alpha)>0.05
		max_gap = overlay.max_frame_ms
		ticks = overlay.ticks
		await process_frame
	await process_frame
	print("LOADING_MS=", Time.get_ticks_msec()-started, " TICKS=", ticks, " MAX_FRAME_MS=", max_gap)
	loading_image.save_png(DIR + "loading-1920.png")
	check(changed and ticks > 5, "ellipsis animates while loading")
	check(loading_music_stopped and not premature_map_music, "loading stays silent until map reveal")
	check(not is_instance_valid(entry_music) and root.get_node("MapPresentation").music.playing, "map reveal hands audio over to map music")
	var map = current_scene
	print("STARTUP_STAGES=",map.startup_timings)
	check(map != null and map.get("startup_error") == "", "resume reaches valid map")
	if map == null or map.get("loadout") == null: quit(1); return
	check(map.inventory_save_path == copy and not Session.resume_requested, "only isolated selected save is restored")
	check(map.inventory_screen == null and map.technique_screen == null and map.reward_dialog == null, "optional screens remain unbuilt at map entry")
	check(map.loadout.spirit_stones == int(original.get("spirit_stones",0)), "currency restored")
	check(map.process_mode == Node.PROCESS_MODE_INHERIT, "map input reenabled after fade")
	await RenderingServer.frame_post_draw
	var map_image := root.get_texture().get_image()
	map_image.save_png(DIR + "map-ready.png")
	var colors: Dictionary = {}
	for y in range(2,9):
		for x in range(1,10):
			colors[map_image.get_pixel(map_image.get_width()*x/10,map_image.get_height()*y/10).to_html()] = true
	check(colors.size()>20, "revealed map actually renders landscape instead of a uniform blank screen")
	map.set_inventory_open(true)
	await settle()
	check(map.is_inventory_open() and map.technique_screen == null, "first bag open builds only inventory")
	var inventory = map.inventory_screen
	map.set_inventory_open(false)
	map.set_inventory_open(true)
	check(map.inventory_screen == inventory, "bag instance reused")
	var book: String = map.loadout.registry.library.books.keys()[0]
	map._open_book_details(book)
	await settle()
	check(map.is_technique_open() and not map.is_inventory_open() and map.technique_screen.selected_book_id == book, "book detail opens corresponding lazy technique view")
	map.set_technique_open(false)
	# Open a real rest event to exercise the lazy event presentation path.
	for event: Dictionary in map.event_registry.events.values():
		if event.type != "rest": continue
		map.travel.current_node_id = event.point_id
		map.travel.stop_at_current_node()
		check(map._try_start_event(event.point_id,event.get("trigger","click"),true)
			and map.rest_dialog.visible, "rest event opens deferred view")
		map._close_rest()
		break
	check(map.reward_dialog != null and map.shop_dialog != null and map.clinic_dialog != null
		and map.cultivation_progress_dialog != null, "event views created on demand")
	check(map.shop_dialog.purchase_requested.is_connected(map._purchase_shop_item)
		and map.clinic_dialog.treatment_requested.is_connected(map._confirm_clinic_treatment), "event commands remain wired")
	check(hash_file(source) == before_save and hash_file(Session.INDEX_PATH) == before_index, "actual save and index unchanged")
	map.queue_free()
	await settle()
	# Malformed full state may pass the envelope check; it must return safely.
	var broken := DIR + "invalid-full-state.json"
	var f := FileAccess.open(broken,FileAccess.WRITE)
	f.store_string(JSON.stringify({"version":2,"board_id":"unknown.board","placements":[],"owned_units":{}}))
	f.close()
	var broken_hash := hash_file(broken)
	Session.clear_selection()
	Session.index_path = broken + ".index"
	page = START.instantiate()
	page.continue_fallback_path = broken
	root.add_child(page)
	current_scene = page
	while page.entrance.active: await process_frame
	var failed_entry_music: AudioStreamPlayer = page.music
	click(page.continue_button)
	while root.has_node("GameLoadingOverlay"): await process_frame
	await settle()
	check(current_scene.scene_file_path.ends_with("start_menu.tscn") and current_scene.error_label.visible,
		"full restore failure returns to menu and removes overlay")
	check(current_scene.music == failed_entry_music and failed_entry_music.playing, "failed load preserves entry music without restarting")
	check(hash_file(broken) == broken_hash and Session.active_path.is_empty(), "failed restore preserves original file and clears resume selection")
	current_scene.queue_free()
	await settle()
	print("START_MENU_LOADING: %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)
