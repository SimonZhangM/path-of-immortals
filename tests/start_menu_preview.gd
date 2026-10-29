extends SceneTree
## Start-menu-only rendering and navigation; no gameplay save access.
const START := preload("res://scenes/entry/start_menu.tscn")
const DIR := "res://artifacts/start-menu/"
var checks := 0
var failures := 0
var actions: Array[StringName] = []

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	for frame in 6: await process_frame

func click(button: BaseButton) -> void:
	var point := button.get_global_rect().get_center()
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

func run() -> void:
	create_timer(25).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0, true)
	DirAccess.make_dir_recursive_absolute(DIR)
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i.ZERO
	var page = START.instantiate()
	page.BackgroundCycle.state_path = DIR + "preview-background-%d.cfg" % Time.get_ticks_usec()
	# This preview never follows the player's real resume target.
	page.SaveSession.index_path = DIR + "preview-no-session-%d.json" % Time.get_ticks_usec()
	page.continue_fallback_path = ""
	root.add_child(page)
	current_scene = page
	while page.entrance.active: await process_frame
	await settle()
	if OS.get_environment("START_MENU_VISUAL_ONLY") == "1" and OS.get_environment("START_MENU_SHOW_CONTINUE") == "1":
		page.continue_button.show()
	check(page.background.texture.resource_path.ends_with("UI-game-bg1.webp"), "specified landscape")
	check(page.logo.texture.atlas.resource_path.ends_with("UI-game-canglanjie.webp"), "specified logo")
	check(page.version_label.text == "版本 v0.1", "concept interface wording removed")
	check(page.tagline_label.text.replace(" ", "") == "凡尘尽处·仙途始于苍澜", "reference tagline")
	check(page.line_left.texture.resource_path.ends_with("UI-game-line-left.webp")
		and page.line_right.texture.resource_path.ends_with("UI-game-line-rightleft.webp"), "two authored ornament assets")
	check(page.menu_buttons.size() == 4, "four separate menu targets")
	for viewport in [Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		root.size = viewport
		await settle()
		var bounds: Rect2 = page.get_global_rect()
		var controls: Array = [page.logo, page.tagline, page.continue_button, page.primary_button]
		controls.append_array(page.menu_buttons)
		controls.append(page.version_label)
		for control: Control in controls:
			check(bounds.encloses(control.get_global_rect()), "start-menu content fits viewport")
		check(page.logo.get_global_rect().end.y < page.tagline.position.y
			and page.tagline.get_global_rect().end.y < page.continue_button.position.y, "logo, tagline and buttons do not overlap")
		check(page.tagline_label.get_minimum_size().x <= page.tagline_label.size.x, "tagline fits at native font size")
		for index in 3:
			check(page.menu_buttons[index].get_global_rect().end.y < page.menu_buttons[index+1].position.y, "menu hit areas do not overlap")
		check(page.background.size == Vector2(viewport) and page.left_shade.size == Vector2(viewport), "background and shade cover viewport")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(DIR + "start-menu-%d.png" % viewport.x)
	if OS.get_environment("START_MENU_VISUAL_ONLY") == "1":
		print("START_MENU_VISUAL: %d checks; %d failures" % [checks, failures])
		quit(1 if failures else 0)
		return
	page.menu_requested.connect(func(action: StringName): actions.append(action))
	for index in 3:
		await click(page.menu_buttons[index])
		if index == 0:
			await click(page.save_browser.menu_back_button)
			await settle()
	check(actions == [&"load", &"settings", &"credits"], "three independent menu hooks route exactly once")
	check(current_scene == page, "reserved menu actions do not create or load a character")
	await click(page.primary_button)
	while root.has_node("EntrySceneCrossfade"): await process_frame
	check(current_scene.scene_file_path == "res://scenes/entry/character_preparation.tscn"
		and current_scene.current_page == 1, "begin journey opens existing first preparation page")
	check(current_scene.preview_save_path == "user://entry_flow_preview.json", "preparation retains isolated preview path")
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	root.push_input(escape, true)
	await settle()
	check(current_scene.scene_file_path == "res://scenes/entry/start_menu.tscn", "Escape returns to new start page")
	while current_scene.entrance.active: await process_frame
	print("START_MENU: %d checks; %d failures" % [checks, failures])
	if failures:
		quit(1)
		return
	# A real click must terminate this isolated process; the timeout catches a broken exit.
	current_scene.exit_button.pressed.connect(func(): print("EXIT_GAME_CLICKED"))
	await click(current_scene.exit_button)
