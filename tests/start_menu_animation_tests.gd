extends SceneTree
const START = preload("res://scenes/entry/start_menu.tscn")
const DIR := "res://artifacts/start-menu/"
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
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
	event.pressed = true
	event.keycode = code
	root.push_input(event, true)
func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(DIR + "animation-" + label + ".png")

func run() -> void:
	create_timer(25).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0, true)
	DirAccess.make_dir_recursive_absolute(DIR)
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1920,1080)
	var page = START.instantiate()
	page.SaveSession.index_path = DIR + "animation-no-session-%d.json" % Time.get_ticks_usec()
	page.continue_fallback_path = ""
	root.add_child(page)
	current_scene = page
	var entrance = page.entrance
	check(entrance.active and page.primary_button.disabled and is_zero_approx(page.logo.modulate.a), "initial black scene locks invisible buttons")
	check(not page.continue_button.visible, "entrance preserves no-save hidden button")
	click(page.primary_button)
	page._begin_journey()
	check(not page._navigating and current_scene == page, "early click cannot navigate")
	var started := Time.get_ticks_msec()
	while entrance.active: await process_frame
	print("ENTRANCE_REMAINING_MS=", Time.get_ticks_msec() - started)
	check(not page.primary_button.disabled and page.logo.modulate.a == 1.0
		and page.logo.offset_top == 0.0 and not entrance._veil.visible, "real entrance finishes at configured final pose")
	for viewport in [Vector2i(1920,1080), Vector2i(2560,1440)]:
		root.size = viewport
		await settle()
		entrance._advance_elapsed(0.425)
		check(is_equal_approx(page.logo.modulate.a, 0.5), "title half-fade")
		check(is_equal_approx(page.logo.offset_top, 4.0 * viewport.x / 2560.0), "title rise scales with viewport")
		check(page.primary_button.modulate.a > 0 and page.primary_button.modulate.a < page.logo.modulate.a, "buttons reveal later as one group")
		check(is_equal_approx(page.menu_buttons[0].modulate.a, page.primary_button.modulate.a), "all menus share fade timing")
		entrance._veil.show()
		await capture("entrance-mid-%d" % viewport.x)
		entrance._advance_elapsed(0.85)
		await capture("entrance-end-%d" % viewport.x)
	click(page.primary_button)
	var transition = root.get_node_or_null("EntrySceneCrossfade")
	check(transition != null and page._navigating, "real button starts scene transition")
	click(page.primary_button)
	page._begin_journey()
	check(root.find_children("EntrySceneCrossfade", "", false, false).size() == 1, "repeated activation cannot create duplicate transition")
	while current_scene == page or current_scene == null: await process_frame
	check(current_scene.scene_file_path.ends_with("character_preparation.tscn") and current_scene.current_page == 1, "live destination is preparation page one")
	transition.set_process(false)
	transition._advance_elapsed(0.2)
	check(is_equal_approx(transition.snapshot.modulate.a, 0.5), "crossfade composites complete outgoing page at halfway")
	click(current_scene.primary_button)
	key(KEY_ESCAPE)
	key(KEY_SPACE)
	check(current_scene.current_page == 1 and not current_scene.page_transition.active, "transition blocks destination click and keyboard")
	await capture("crossfade-mid")
	transition.set_process(true)
	while is_instance_valid(transition): await process_frame
	await settle()
	await capture("destination")
	click(current_scene.primary_button)
	check(current_scene.page_transition.active, "destination input restored and existing page turn works")
	while current_scene.page_transition.active: await process_frame
	check(current_scene.current_page == 2, "existing four-page flow advances once")
	key(KEY_ESCAPE)
	await settle()
	check(current_scene.scene_file_path.ends_with("start_menu.tscn") and current_scene.entrance.active, "return to menu replays entrance")
	print("START_MENU_ANIMATION: %d checks; %d failures" % [checks, failures])
	quit(1 if failures else 0)
