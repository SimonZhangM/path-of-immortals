extends SceneTree

const PAGE := preload("res://scenes/entry/character_preparation.tscn")
const DIR := "res://artifacts/introduction-page/"
var checks := 0
var failures := 0
var requested_page := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	for frame in 6: await process_frame

func click(button: Control) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
	await settle()

func run() -> void:
	create_timer(40).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0, true)
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i.ZERO
	var page = PAGE.instantiate()
	root.add_child(page)
	current_scene = page
	await settle()
	check(page.preview_save_path != MapLoadoutStore.DEFAULT_PATH, "preview keeps a separate save path")
	for viewport_size in [Vector2i(2560, 1440), Vector2i(1920, 1080)]:
		root.size = viewport_size
		await settle()
		var bounds := page.get_global_rect() as Rect2
		check(page.description.get_child_count() == 4, "four complete introduction lines")
		for line: Label in page.description_lines:
			var width := line.get_theme_font("font").get_string_size(line.text, HORIZONTAL_ALIGNMENT_LEFT, -1, line.get_theme_font_size("font_size")).x
			check(width <= line.size.x and bounds.encloses(line.get_global_rect()), "introduction line fits viewport without truncation")
		check(page.title_art.get_global_rect().end.y < page.description.get_global_rect().position.y, "title and text do not overlap")
		check(page.description.get_global_rect().end.y < page.primary_button.get_global_rect().position.y, "text leaves landscape above button visible")
		check(bounds.encloses(page.progress.get_global_rect()), "progress fits viewport")
		check(page.progress_dots.size() == 4 and page.progress.get_child_count() == 4, "only four progress circles, without a number")
		check(page.background.get_index() < page.copy_shade.get_index() and page.copy_shade.get_index() < page.title_art.get_index(), "shade stays behind title and text")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var screenshot := root.get_texture().get_image()
			check(screenshot.get_size() == viewport_size, "capture uses requested resolution")
			screenshot.save_png(DIR + "page1-%d.png" % viewport_size.x)
	page.show_page(2)
	await settle()
	check(page.title_art.texture.atlas.resource_path == "res://assets/UI-start-bg2-title.webp", "page two uses its own title")
	check(page.description_lines[0].text == "仙门并非遥不可及", "corrected wording on page two")
	for viewport_size in [Vector2i(2560, 1440), Vector2i(1920, 1080)]:
		root.size = viewport_size
		await settle()
		for line: Label in page.description_lines:
			check(page.get_global_rect().encloses(line.get_global_rect()), "page two copy fits viewport")
		check(page.title_art.get_global_rect().end.y < page.description.get_global_rect().position.y, "page two title clears text")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(DIR + "page2-%d.png" % viewport_size.x)
	page.show_page(1)
	await settle()
	# Only this new page's navigation is exercised; no game or character creation.
	if OS.get_environment("INTRODUCTION_VISUAL_ONLY") != "1":
		page.continue_requested.connect(func(next: int): requested_page = next)
		var button_rect: Rect2 = page.primary_button.get_global_rect()
		for destination in [2, 3, 4]:
			if destination == 4:
				page.creation_draft.set_manual_name("张辰宇")
				page.identity_form._select_gender(0)
			await click(page.primary_button)
			check(requested_page == destination and page.current_page == destination, "continue advances exactly one page")
			check(page.background.texture.resource_path == "res://assets/UI-start-bg%d.webp" % destination, "navigation updates background")
			for index in 4:
				var style: StyleBoxFlat = page.progress_dots[index].get_theme_stylebox("normal")
				check((style.bg_color == Color("f6c567")) == (index + 1 == destination), "only the current page dot is lit")
			check(page.primary_button.get_global_rect().is_equal_approx(button_rect), "continue keeps its position across pages")
			if destination == 4:
				check(page.title_art.visible and page.title_art.texture.atlas.resource_path == "res://assets/UI-start-bg4-title.webp" and page.description_lines.size() == 2 and page.description_lines[0].text == "天地灵气，汇于七源", "page four has its own title and introduction")
		check(not page.primary_button.visible, "page four does not offer an undefined fifth page")
		page.show_page(5)
		check(page.current_page == 4, "page boundary is enforced")
		var escape := InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		escape.pressed = true
		root.push_input(escape, true)
		await settle()
		check(current_scene.scene_file_path == "res://scenes/entry/start_menu.tscn", "Escape returns to start menu")
		await click(current_scene.primary_button)
		check(current_scene.scene_file_path == "res://scenes/entry/character_preparation.tscn", "start game opens introduction")
	current_scene.queue_free()
	await settle()
	print("INTRODUCTION PAGE: %d checks; %d failures" % [checks, failures])
	quit(1 if failures else 0)
