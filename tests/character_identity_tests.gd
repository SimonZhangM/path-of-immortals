extends "res://tests/introduction_page_preview.gd"

var faces: Array[int] = []
var completed_rolls := 0

func capture_identity(suffix: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(DIR + "page3-" + suffix + ".png")

func run() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0, true)
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(2560, 1440)
	var page = PAGE.instantiate()
	root.add_child(page)
	current_scene = page
	await settle()
	check(page.highest_visited_page == 1 and page.progress_dots[3].disabled, "future dots start locked")
	await click(page.progress_dots[3])
	check(page.current_page == 1, "unvisited dot cannot skip ahead")
	await click(page.primary_button)
	await click(page.progress_dots[0])
	check(page.current_page == 1 and not page.progress_dots[1].disabled, "visited page stays unlocked after going back")
	await click(page.progress_dots[1])
	check(page.current_page == 2, "visited dot can reopen a later page")
	await click(page.primary_button)
	var form = page.identity_form
	check(page.current_page == 3 and form.visible and page.button_label.text == "选择灵根", "third page shows the form and new action caption")
	check(form.name_input.text.is_empty() and form.name_input.placeholder_text == "请输入姓名", "name starts with centered placeholder")
	check(page.creation_draft.gender.is_empty(), "no gender silently selected")
	await click(form.gender_buttons[0])
	check(page.creation_draft.gender == "male" and form.gender_buttons[0].button_pressed and not form.gender_buttons[1].button_pressed, "male selection is exclusive")
	for viewport_size in [Vector2i(2560, 1440), Vector2i(1920, 1080)]:
		root.size = viewport_size
		await settle()
		check(absf(form.gender_row.size.x - page._config.identity_form.name_rect[2] * viewport_size.x / 2560.0) < 1, "two gender buttons plus gap match name artwork width")
		check(absf(form.gender_buttons[0].size.x - form.gender_buttons[1].size.x) <= 1.0 and is_equal_approx(form.gender_buttons[0].size.y, form.gender_buttons[1].size.y), "gender buttons split the available pixels equally, allowing one rounding pixel")
		check(form.name_input.alignment == HORIZONTAL_ALIGNMENT_CENTER, "typed text and placeholder use centered alignment")
		check(page.get_global_rect().encloses(form.dice_button.get_global_rect()), "dice fits the viewport")
		await capture_identity("%d" % viewport_size.x)
	await click(form.gender_buttons[1])
	check(page.creation_draft.gender == "female" and not form.gender_buttons[0].button_pressed and form.gender_buttons[1].button_pressed, "female replaces male selection")
	await click(form.name_input)
	for character in "陆青玄":
		var input := InputEventKey.new()
		input.unicode = character.unicode_at(0)
		input.pressed = true
		root.push_input(input, true)
	await settle()
	check(form.name_input.text == "陆青玄" and page.creation_draft.full_name == "陆青玄", "manual Unicode input updates draft")
	form.dice_face_changed.connect(func(face: int): faces.append(face))
	form.roll_finished.connect(func(_name: String): completed_rolls += 1)
	var drawn: Array[String] = []
	for roll in 6:
		faces.clear()
		var initial_face: int = form.dice_face
		var old_name: String = form.name_input.text
		var start := Time.get_ticks_msec()
		await click(form.dice_button)
		check(form.is_rolling and form.name_input.text == old_name, "name is unchanged during the dice animation")
		form.start_roll()
		check(form.dice_button.disabled and not form.name_input.editable, "in-flight roll ignores repeated activation")
		while form.is_rolling: await process_frame
		var elapsed := Time.get_ticks_msec() - start
		check(elapsed >= 1000 and elapsed < 1400, "roll completes in one presentation second")
		check(faces.size() == 30, "one second contains thirty dice faces")
		var previous := initial_face
		var distinct_neighbors := true
		for face in faces:
			if face == previous: distinct_neighbors = false
			previous = face
		check(distinct_neighbors, "adjacent dice frames always differ")
		check(completed_rolls == roll + 1, "only one name is drawn per completed roll")
		drawn.append(form.name_input.text)
		check(page.creation_draft.full_name == form.name_input.text and form.name_input.editable, "completed name is in both draft and input")
		print("ROLL %d: %d ms; %d frames" % [roll + 1, elapsed, faces.size()])
	var unique := {}
	for index in 5: unique[drawn[index]] = true
	check(unique.size() == 5 and drawn[4] != drawn[5], "initial dice draws do not repeat")
	await capture_identity("female-random")
	var saved_name: String = page.creation_draft.full_name
	await click(page.progress_dots[0])
	check(not form.visible and page.button_label.text == "继 续", "returning restores the earlier page caption")
	await click(page.progress_dots[2])
	check(form.name_input.text == saved_name and form.gender_buttons[1].button_pressed, "name and gender survive page review")
	await click(page.primary_button)
	check(page.current_page == 4 and page.highest_visited_page == 4, "choose roots enters fourth page")
	await click(page.progress_dots[2])
	check(page.current_page == 3 and form.name_input.text == saved_name, "third page can be reviewed from fourth page")
	# More shuffle cycles exercise refill without waiting for the presentation.
	for cycle in 3:
		var pool_state = preload("res://scripts/entry/character_creation_draft.gd").new(JSON.parse_string(FileAccess.get_file_as_string("res://data/character_name_pool.json")).names)
		var previous_name := ""
		for block in 3:
			var seen := {}
			for index in 100:
				var name: String = pool_state.draw_name()
				check(not seen.has(name) and name != previous_name, "shuffle bag remains unique within and across rounds")
				seen[name] = true
				previous_name = name
	page.queue_free()
	await settle()
	print("CHARACTER IDENTITY: %d checks; %d failures" % [checks, failures])
	quit(1 if failures else 0)
