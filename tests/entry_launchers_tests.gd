extends SceneTree

const DIR := "res://artifacts/entry-launcher-tests/"
const ENTRY := preload("res://scripts/entry/entry_preview.gd")
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	for frame in 6: await process_frame

func click(button: BaseButton) -> void:
	var position := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	await settle()

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(DIR+name+".png")

func run() -> void:
	create_timer(50).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0, true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var fingerprint: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR+"save-before.json"))
	var actual := ProjectSettings.globalize_path(MapLoadoutStore.DEFAULT_PATH).replace("\\", "/")
	check(actual == str(fingerprint.source).replace("\\", "/"), "renamed project resolves to original user save directory")
	var before := FileAccess.get_sha256(actual)
	check(ProjectSettings.get_setting("application/config/name") == "苍澜界", "Chinese project name")
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/maps/session_start.tscn", "project Run remains direct game")
	var preview_before := FileAccess.get_sha256(ENTRY.PREVIEW_SAVE) if FileAccess.file_exists(ENTRY.PREVIEW_SAVE) else ""
	var page = load(ENTRY.START_SCENE).instantiate()
	root.add_child(page)
	current_scene = page
	await settle()
	check(page.screen == 0 and root.title == "苍澜界 · 测试开始界面", "standalone start scene")
	check(page.preview_save_path == ENTRY.PREVIEW_SAVE, "F6 defaults to preview save")
	check(page.preview_save_path != MapLoadoutStore.DEFAULT_PATH, "preview save isolated")
	check(root.get_visible_rect().encloses(page.primary_button.get_global_rect()), "start controls fit viewport")
	await capture("start")
	await click(page.primary_button)
	page = current_scene
	check(page != null and page.screen == 1, "mouse opens preparation scene")
	if page == null or page.screen != 1: quit(1); return
	check(root.title == "苍澜界 · 测试踏入仙途", "preparation window title")
	check(page.preview_save_path == ENTRY.PREVIEW_SAVE, "preparation shares isolated preview profile")
	check(root.get_visible_rect().encloses(page.primary_button.get_global_rect()), "preparation controls fit viewport")
	await capture("preparation")
	var requested: Array[int] = []
	page.continue_requested.connect(func(next: int): requested.append(next))
	await click(page.primary_button)
	check(requested == [2] and current_scene == page and page.current_page == 2, "continue opens the second introduction page")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape, true)
	await settle()
	check(current_scene.screen == 0, "Escape returns to start scene")
	current_scene.queue_free()
	await settle()
	# Also boot preparation directly, as F6 and its launcher do.
	page = load(ENTRY.PREPARATION_SCENE).instantiate()
	root.add_child(page)
	current_scene = page
	await settle()
	check(page.screen == 1 and page.preview_save_path == ENTRY.PREVIEW_SAVE, "standalone preparation requires no previous menu")
	page.queue_free()
	await settle()
	var preview_after := FileAccess.get_sha256(ENTRY.PREVIEW_SAVE) if FileAccess.file_exists(ENTRY.PREVIEW_SAVE) else ""
	check(preview_after == preview_before, "scaffolds do not create or modify a character save")
	# Exercise the existing direct entry with an explicit copied save only.
	var copy_error := DirAccess.copy_absolute(actual, ProjectSettings.globalize_path(DIR+"direct.json"))
	check(copy_error == OK, "copy current save for direct-entry check")
	if copy_error != OK: quit(1); return
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR+"direct.json"))
	var direct = load("res://scenes/maps/session_start.tscn").instantiate()
	direct.inventory_save_path = DIR+"direct.json"
	direct.defer_map_music = true
	root.add_child(direct)
	await settle()
	var map := current_scene
	check(map != null and map.get("startup_error") == "", "direct entry restores copied save")
	if map == null or map.get("startup_error") != "": quit(1); return
	map.set_process(false)
	check(map.inventory_save_path == DIR+"direct.json", "direct entry forwards save path")
	check(map.definition.id == expected.map_location.map_id and map.travel.current_node_id == expected.map_location.point_id, "direct entry retains map and node")
	check(map.loadout.growth.realm == int(expected.growth.realm) and map.loadout.growth.layer == int(expected.growth.layer), "direct entry retains cultivation")
	map.queue_free()
	await settle()
	check(FileAccess.get_sha256(actual) == before, "actual gameplay save unchanged")
	print("ENTRY LAUNCHERS: %d checks; %d failures" % [checks, failures])
	quit(1 if failures else 0)
