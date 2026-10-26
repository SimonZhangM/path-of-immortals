extends "res://tests/introduction_page_preview.gd"

func enter_name(form: Control, value: String) -> void:
	await click(form.name_input)
	form.name_input.select_all()
	var erase := InputEventKey.new()
	erase.keycode = KEY_BACKSPACE
	erase.pressed = true
	root.push_input(erase, true)
	for character in value:
		var event := InputEventKey.new()
		event.unicode = character.unicode_at(0)
		event.pressed = true
		root.push_input(event, true)
	await settle()

func run() -> void:
	create_timer(25).timeout.connect(func(): quit(2))
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1920, 1080)
	var page = PAGE.instantiate()
	root.add_child(page)
	current_scene = page
	await settle()
	check(not page.primary_button.disabled, "page one remains enabled")
	await click(page.primary_button)
	check(not page.primary_button.disabled, "page two remains enabled")
	await click(page.primary_button)
	var form = page.identity_form
	check(page.primary_button.disabled, "both empty disables button")
	check(page.primary_button.material.get_shader_parameter("disabled"), "disabled artwork uses grayscale")
	await click(page.primary_button)
	page._continue()
	check(page.current_page == 3, "mouse and command cannot advance")
	await enter_name(form, "陆青玄")
	check(page.primary_button.disabled, "name alone insufficient")
	await enter_name(form, "")
	await click(form.gender_buttons[0])
	check(page.primary_button.disabled, "gender alone insufficient")
	await enter_name(form, " 　 ")
	check(page.primary_button.disabled, "whitespace not a name")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(DIR + "page3-required-disabled.png")
	await enter_name(form, "陆青玄")
	check(not page.primary_button.disabled, "name and gender enable immediately")
	check(not page.primary_button.material.get_shader_parameter("disabled"), "valid artwork returns gold")
	await click(page.primary_button)
	check(page.current_page == 4, "valid entry reaches page four")
	await click(page.progress_dots[2])
	await enter_name(form, "")
	check(page.primary_button.disabled and page.progress_dots[3].disabled, "clearing name disables both routes")
	await click(page.progress_dots[3])
	page._revisit_page(4)
	check(page.current_page == 3, "visited dot cannot bypass required identity")
	await click(form.dice_button)
	check(page.primary_button.disabled, "empty remains blocked during dice roll")
	while form.is_rolling: await process_frame
	check(not page.primary_button.disabled and not page.progress_dots[3].disabled, "random name completion re-enables entry")
	await click(page.progress_dots[3])
	check(page.current_page == 4, "valid visited dot works")
	print("IDENTITY REQUIRED: %d checks; %d failures" % [checks, failures])
	quit(1 if failures else 0)
