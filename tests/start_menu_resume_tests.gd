extends SceneTree
const Session = preload("res://scripts/entry/game_save_session.gd")
const START = preload("res://scenes/entry/start_menu.tscn")
var dir := "res://artifacts/start-menu/resume-%d/" % Time.get_ticks_usec()
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func settle() -> void:
	for frame in 8: await process_frame
func hash_if_exists(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
func write_json(path: String, value: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value))
	file.close()
func click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	await settle()
	while root.has_node("EntrySceneCrossfade"): await process_frame
	while root.has_node("GameLoadingOverlay"): await process_frame
func menu(fallback: String) -> Control:
	if is_instance_valid(current_scene):
		current_scene.queue_free()
		await settle()
	var page = START.instantiate()
	page.continue_fallback_path = fallback
	root.add_child(page)
	current_scene = page
	while page.entrance.active: await process_frame
	await settle()
	return page
func capture(page: Control, label: String) -> void:
	for viewport in [Vector2i(1920,1080), Vector2i(2560,1440)]:
		root.size = viewport
		await settle()
		var factor: float = viewport.x / 2560.0
		check(is_equal_approx(page.continue_button.size.x, 621 * factor)
			and is_equal_approx(page.primary_button.size.x, 621 * factor), "both primary buttons shrink ten percent")
		check(is_equal_approx(page.primary_button.position.y - page.continue_button.get_global_rect().end.y, 17.0175 * factor), "primary gap halved")
		check(is_equal_approx(page.logo.position.y,75 * factor) and is_equal_approx(page.tagline.position.y,517 * factor), "latest title group positioning")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/start-menu/resume-%s-%d.png" % [label,viewport.x])

func run() -> void:
	create_timer(50).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0, true)
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1920,1080)
	DirAccess.make_dir_recursive_absolute(dir)
	var protected_paths := [MapLoadoutStore.DEFAULT_PATH, Session.INDEX_PATH, Session.PREVIEW_PATH]
	var fingerprints := {}
	for path: String in protected_paths: fingerprints[path] = hash_if_exists(path)
	Session.index_path = dir + "last.json"
	Session.clear_selection()
	var page = await menu("")
	check(not page.continue_button.visible, "first launch hides Continue")
	await capture(page,"first")
	await click(page.continue_button)
	check(current_scene == page and Session.active_path.is_empty(), "hidden Continue cannot launch a new game save")
	var registry := ContentRegistry.new()
	check(registry.load_base_content(), "content loads for independent fixtures")
	var created := MapLoadoutStore.create_state(registry,registry.get_board("base.board.bag"))
	check(created.error.is_empty(), "fixture state configured")
	if not created.error.is_empty(): quit(1); return
	var model: MapLoadoutState = created.state
	var a := dir + "a.json"
	var b := dir + "b.json"
	model.spirit_stones = 101
	check(MapLoadoutStore.save(model,a).is_empty(), "write isolated save A")
	model.spirit_stones = 202
	check(MapLoadoutStore.save(model,b).is_empty(), "write isolated save B")
	check(Session.resume_path(a) == a and not FileAccess.file_exists(Session.index_path), "legacy save recognized read-only without bookmark")
	check(Session.remember(b) == OK and Session.remember(a) == OK, "last-used bookmark updates B then A")
	model.spirit_stones = 999
	MapLoadoutStore.save(model,b)
	check(Session.resume_path(b) == a, "newer writes to another save cannot change last played character")
	model.spirit_stones = 333
	MapLoadoutStore.save(model,a)
	page = await menu(b)
	check(page.continue_button.visible, "returning player sees Continue")
	await capture(page,"returning")
	await click(page.continue_button)
	await settle()
	var map = current_scene
	check(map != null and map.get("startup_error") == "", "Continue successfully starts existing map")
	if map == null or map.get("loadout") == null:
		quit(1)
		return
	map.set_process(false)
	check(map.inventory_save_path == a, "explicit resume target wins over preview command-line path")
	check(map.loadout.spirit_stones == 333, "latest contents of last used save are loaded")
	check(Session.resume_path(b) == a and not Session.resume_requested, "successful session remains remembered")
	# A later ordinary map load records B even without pressing Continue.
	map.queue_free()
	await settle()
	Session.clear_selection()
	# Select B for this isolated process because this run deliberately has a preview CLI argument.
	Session.active_path = b
	var direct = load("res://scenes/maps/session_start.tscn").instantiate()
	direct.inventory_save_path = b
	direct.defer_map_music = true
	root.add_child(direct)
	current_scene = direct
	await settle()
	check(current_scene.get("startup_error") == "" and Session.resume_path(a) == b, "successfully using another save updates resume bookmark")
	Session.clear_selection()
	page = await menu(a)
	var bookmark := hash_if_exists(Session.index_path)
	await click(page.primary_button)
	check(current_scene.scene_file_path == "res://scenes/entry/character_preparation.tscn"
		and current_scene.current_page == 1, "Begin Journey enters preparation page one")
	var preparation = current_scene
	for target in [2,3,4]:
		if target == 4:
			preparation.creation_draft.set_manual_name("杨辰")
			preparation.identity_form.name_input.text = "杨辰"
			preparation.identity_form._select_gender(0)
		await click(preparation.primary_button)
		while preparation.page_transition.active: await process_frame
		await settle()
		check(preparation.current_page == target, "preparation proceeds through page %d" % target)
	await click(preparation.root_panel.random_button)
	while preparation.root_selection_spin.active: await process_frame
	check(preparation.creation_draft.full_name == "杨辰"
		and not preparation.creation_draft.root_selection.is_empty(), "four-page name and root flow works")
	check(Session.active_path.is_empty() and hash_if_exists(Session.index_path) == bookmark, "new journey leaves previous save and resume bookmark intact")
	# Missing or damaged last-used target must not silently fall back to A.
	write_json(Session.index_path, {"version":1,"path":dir+"missing.json"})
	page = await menu(a)
	check(not page.continue_button.visible and Session.resume_path(a).is_empty(), "missing last-used save does not pick an alternative")
	write_json(dir+"broken.json", {"version":2})
	write_json(Session.index_path, {"version":1,"path":dir+"broken.json"})
	check(Session.resume_path(a).is_empty(), "malformed last-used save does not fall back")
	Session.remember(a)
	page = await menu(b)
	# It may disappear between displaying the button and clicking it.
	DirAccess.rename_absolute(a,dir+"a-away.json")
	if FileAccess.file_exists(a+".bak"): DirAccess.rename_absolute(a+".bak",dir+"a-away.bak")
	await click(page.continue_button)
	check(current_scene == page and not page.continue_button.visible and page.error_label.visible, "missing-at-click save stays on menu without creating replacement")
	check(not FileAccess.file_exists(a), "missing save is not recreated")
	Session.resume_requested = true
	var vanished := dir + "vanished-during-load.json"
	check(not MapLoadoutStore.load_into(model,vanished).is_empty()
		and not FileAccess.file_exists(vanished), "store also refuses to create a missing resume target")
	Session.clear_selection()
	Session.index_path = Session.INDEX_PATH
	check(Session.remember(b) == OK and hash_if_exists(Session.INDEX_PATH) == fingerprints[Session.INDEX_PATH], "project fixture sessions cannot update real resume bookmark")
	for path: String in protected_paths:
		check(hash_if_exists(path) == fingerprints[path], "actual player save, preview save and bookmark untouched")
	Session.clear_selection()
	print("START_MENU_RESUME: %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)
