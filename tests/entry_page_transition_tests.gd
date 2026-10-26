extends SceneTree
## Isolated preparation UI checks; never loads or writes gameplay saves.
const PAGE := preload("res://scenes/entry/character_preparation.tscn")
const DIR := "res://artifacts/introduction-page/"
var checks := 0
var failures := 0
var continued: Array[int] = []

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func settle(count := 6) -> void:
	for index in count: await process_frame

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

func key(code: Key, unicode := 0) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.unicode = unicode
		event.pressed = pressed
		root.push_input(event, true)

func finish_turn(page: Control) -> void:
	while page.page_transition.active: await process_frame
	await settle()

func capture(suffix: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(DIR + "page-turn-" + suffix + ".png")

func run() -> void:
	create_timer(35).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0, true)
	DirAccess.make_dir_recursive_absolute(DIR)
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1920, 1080)
	var page = PAGE.instantiate()
	root.add_child(page)
	current_scene = page
	await settle(12)
	var turn = page.page_transition
	page.continue_requested.connect(func(number: int): continued.append(number))
	check(not turn.active and page.content_layer.position == Vector2.ZERO, "initial page is static")
	check(page.copy_shade.get_index() < turn._old_layer.get_index()
		and turn._old_layer.get_index() < page.content_layer.get_index(), "old composite stays behind all foreground")
	check(turn.get_index() > page.content_layer.get_index(), "input shield is above content")
	click(page.progress_dots[3])
	check(page.current_page == 1 and not turn.active, "unvisited dots cannot skip pages")
	var before := Time.get_ticks_msec()
	click(page.primary_button)
	check(turn.active and page.current_page == 1 and turn.direction == 1, "real click starts forward transition without immediate content swap")
	check(turn._old_background.texture.resource_path.ends_with("bg1.webp")
		and page.background.texture.resource_path.ends_with("bg2.webp"), "two backgrounds prepared for crossfade")
	click(page.primary_button)
	page._continue()
	page._revisit_page(1)
	key(KEY_ENTER)
	key(KEY_SPACE)
	key(KEY_TAB)
	key(KEY_ESCAPE)
	check(page.current_page == 1 and current_scene == page, "repeated click and keyboard including Escape are blocked")
	await finish_turn(page)
	var elapsed := Time.get_ticks_msec() - before
	print("REAL_PAGE_TURN_MS=", elapsed)
	check(elapsed >= 400 and page.current_page == 2 and continued == [2], "one timed turn finishes and emits one navigation signal")
	check(not turn._old_layer.visible and turn._old_background.texture == null
		and turn.mouse_filter == Control.MOUSE_FILTER_IGNORE, "completion releases overlay texture and input lock")

	# Exact visual poses, including the content/dot swap at the invisible midpoint.
	click(page.primary_button)
	turn.set_process(false)
	turn._advance_elapsed(0.1)
	check(page.current_page == 2 and is_equal_approx(page.content_layer.modulate.a, 0.5), "outgoing content fades as one group")
	check(is_equal_approx(page.content_layer.position.x, -7.5 * 0.75), "outgoing content moves left by scaled design distance")
	check(is_equal_approx(turn._old_layer.modulate.a, 0.84375), "background dissolves smoothly over all 0.4 seconds")
	check(page.background.position == Vector2.ZERO and turn._old_background.position == Vector2.ZERO, "backgrounds never slide")
	await capture("forward-out")
	turn._advance_elapsed(0.2)
	check(page.current_page == 3 and is_zero_approx(page.content_layer.modulate.a)
		and is_equal_approx(page.content_layer.position.x, 15.0 * 0.75), "incoming content begins 15 design pixels right at midpoint")
	for index in 4:
		check((page.progress_dots[index].get_theme_stylebox("normal").bg_color == Color("f6c567")) == (index == 2), "progress dot follows incoming page")
	await capture("midpoint")
	turn._advance_elapsed(0.3)
	check(is_equal_approx(page.content_layer.modulate.a, 0.5)
		and is_equal_approx(page.content_layer.position.x, 7.5 * 0.75), "incoming content fades and returns together")
	await capture("forward-in")
	turn._advance_elapsed(0.4)
	await settle()
	click(page.primary_button)
	page._continue()
	check(page.current_page == 3 and not turn.active, "identity requirement still blocks next page")
	page.creation_draft.gender = "male"
	var chosen_name: String = page.creation_draft.draw_name()
	page.identity_form.name_input.text = chosen_name
	page.identity_form._select_gender(0)
	var bags: Dictionary = page.creation_draft._bags.duplicate(true)
	var draft = page.creation_draft
	click(page.primary_button)
	check(turn.active, "identity enables navigation")
	await finish_turn(page)
	check(page.current_page == 4 and page.creation_draft == draft, "page four shares original draft")
	check(page.root_panel.get_parent() == page.content_layer
		and page.root_selection_art.get_parent() == page.content_layer, "both root regions belong to animated foreground")
	click(page.root_panel.random_button)
	check(page.root_selection_spin.active, "root selection remains usable after turn")
	while page.root_selection_spin.active: await process_frame
	var selected: Dictionary = draft.root_selection.duplicate(true)
	check(not selected.is_empty(), "root result completes normally")
	click(page.root_panel.random_button)
	click(page.progress_dots[2])
	turn.set_process(false)
	check(turn.active and turn.direction == -1 and not page.root_selection_spin.active, "backward navigation cancels pending roll immediately")
	turn._advance_elapsed(0.1)
	check(page.content_layer.position.x > 0, "backward outgoing content moves right")
	await capture("backward-out")
	turn._advance_elapsed(0.2)
	check(page.content_layer.position.x < 0 and page.current_page == 3, "backward incoming content starts left")
	# Even a programmatically focused text input cannot receive keys during a turn.
	page.identity_form.name_input.grab_focus()
	key(KEY_A, 65)
	click(page.identity_form.gender_buttons[1])
	click(page.identity_form.dice_button)
	check(draft.full_name == chosen_name and draft.gender == "male"
		and not page.identity_form.is_rolling, "transition blocks editing, gender and dice")
	turn._advance_elapsed(0.3)
	root.size = Vector2i(2560, 1440)
	await settle()
	check(is_equal_approx(page.content_layer.position.x, -7.5), "resize rescales transition offset without accumulating drift")
	check(turn._old_background.size == Vector2(2560, 1440), "crossfade covers resized window")
	await capture("backward-in-2560")
	turn._advance_elapsed(0.4)
	await settle()
	check(page.content_layer.position == Vector2.ZERO and page.content_layer.size == page.size
		and page.content_layer.modulate == Color.WHITE, "completion restores exact full-rect layout and opacity")
	check(draft.full_name == chosen_name and draft._bags == bags and draft.root_selection == selected, "name, shuffle bag and completed roots survive navigation")
	page.identity_form.name_input.text = ""
	draft.set_manual_name("")
	page._refresh_navigation()
	click(page.progress_dots[3])
	page._revisit_page(4)
	check(not turn.active and page.current_page == 3, "visited page four cannot bypass cleared identity")
	draft.set_manual_name(chosen_name)
	page.identity_form.name_input.text = chosen_name
	page._refresh_navigation()
	click(page.progress_dots[3])
	await finish_turn(page)
	check(page.root_panel.root_name.text == selected.name
		and page.root_selection_effects.get_selected_roots() == selected.elements, "revisited root panel and highlights show preserved result")
	check(continued == [2, 3, 4], "dot revisits do not emit extra continue events")
	for viewport in [Vector2i(2560, 1440), Vector2i(1920, 1080)]:
		root.size = viewport
		await settle()
		check(page.get_global_rect().encloses(page.root_panel.get_global_rect()), "root panel stays within viewport after turns")
		check(page.content_layer.position == Vector2.ZERO, "resize after transition has no offset")
		await capture("complete-" + str(viewport.x))
	click(page.progress_dots[0])
	await finish_turn(page)
	check(page.current_page == 1 and draft.root_selection == selected, "nonadjacent dot return preserves draft")
	key(KEY_ESCAPE)
	await settle()
	check(current_scene.scene_file_path == "res://scenes/entry/start_menu.tscn", "Escape works again after transition")
	print("ENTRY_PAGE_TRANSITION: %d checks; %d failures" % [checks, failures])
	quit(1 if failures else 0)
