extends "res://tests/save_actions_tests.gd"
const ListView = preload("res://scripts/map/map_task_list.gd")
const Tag = preload("res://scripts/map/map_task_category_tag.gd")

func run() -> void:
	var visual_only := OS.get_cmdline_user_args().has("--visual-only")
	create_timer(60).timeout.connect(func(): quit(2))
	directory = "res://artifacts/task-list/run-%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	Slots.auto_path = directory + "auto.json"
	Session.index_path = directory + "last.json"
	Session.clear_selection()
	root.get_node("SavePlaytime").set_process(false)
	root.get_node("GameSettings").apply_values({"background_pause":false,"background_mute":false})
	root.get_node("GameSettings").set_application_focus(true)
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(2560,1440)
	var map = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path = Slots.working_path()
	map.defer_map_music = true
	map.defer_optional_views = true
	root.add_child(map)
	current_scene = map
	await settle()
	map.set_process(false)
	check(map.startup_error.is_empty(), "isolated map starts")
	var before: Dictionary = map.loadout.snapshot().duplicate(true)
	map.set_task_open(true)
	await settle()
	var screen = map.task_screen
	var list = screen.task_list
	var id := "quest.prologue.yaoxiangruchang"
	check(list.cards.size() == 1 and list.cards.has(id), "only requested first task is displayed")
	check(list.entries[0].accepted_at == null and list.entries[0].updated_at == null, "display row does not invent acceptance or progress timestamps")
	var colors: Array = []
	for style: Dictionary in list.definitions.category_tags.values(): colors.append(style.color)
	var unique := {}
	for color: String in colors: unique[color] = true
	check(unique.size() == 8, "eight distinct category colors")
	await capture("normal-2560x1440")
	var location: Vector2 = map.travel.map_position
	if visual_only:
		list.select_task(id)
	else:
		await click(list.cards[id].find_child("TaskThumbnail", true, false))
		check(list.selected_task_id == id and list.cards[id].button_pressed, "thumbnail click selects card")
		await click(list.cards[id].find_child("TaskName", true, false))
		check(list.cards[id].button_pressed, "repeated selection remains highlighted")
	for resolution in [Vector2i(2560,1440),Vector2i(1920,1080)]:
		root.size = resolution
		await settle()
		var card: Button = list.cards[id]
		var bounds: Rect2 = screen.middle_panel.get_global_rect()
		check(bounds.encloses(card.get_global_rect()) and bounds.encloses(list.sort_button.get_global_rect()), "card and sort fit middle column at %s" % resolution)
		var summary: Label = card.find_child("TaskSummary", true, false)
		var text_size: Vector2 = summary.get_theme_font("font").get_string_size(summary.text, HORIZONTAL_ALIGNMENT_LEFT, -1, summary.get_theme_font_size("font_size"))
		check(summary.size.x >= text_size.x, "full approved summary fits one line at %s" % resolution)
		var frame_art: TextureRect = card.get_node("FrameArtwork")
		check(frame_art.texture.resource_path == ListView.SELECTED_FRAME, "selected authored frame is used")
		var art: TextureRect = card.find_child("TaskThumbnail", true, false)
		check(art.texture.get_image().has_mipmaps() and art.material.get_shader_parameter("corner_radius") == 3.0, "thumbnail mipmaps and three pixel mask")
		check(is_equal_approx(art.get_global_rect().position.x,card.get_global_rect().position.x), "thumbnail touches card left edge")
		check(absf((summary.get_global_rect().position.x-art.get_global_rect().end.x)/screen.stage.scale.x-10.0) < 1.0, "text starts ten pixels after thumbnail with integer container rounding")
		check(is_equal_approx(art.size.y,card.size.y) and is_equal_approx(art.size.aspect(),art.texture.get_size().aspect()) and is_zero_approx(art.position.y), "photo scales proportionally from left-center to full card height")
		check(frame_art.z_index < art.z_index and art.z_index < card.get_node("TaskTextPadding").z_index, "frame below photo below text")
		check(summary.get_theme_font("font") == ListView.HARMONY, "summary uses HarmonyOS regular")
		check(is_equal_approx(art.material.get_shader_parameter("image_opacity"),0.75) and is_equal_approx(art.material.get_shader_parameter("fade_start"),0.5) and is_equal_approx(art.material.get_shader_parameter("left_fade_fraction"),0.05) and is_equal_approx(art.material.get_shader_parameter("vertical_fade_fraction"),0.05), "thumbnail 75 percent opacity with left 5, vertical 5 and right 50 percent fades")
		var scroll_bounds: Rect2 = list.find_child("TaskRowsScroll",true,false).get_global_rect()
		check(scroll_bounds.encloses(frame_art.get_global_rect()), "complete frame artwork fits inside scroll clip")
		check(is_equal_approx(list.sort_button.size.x,174), "sort field narrows by two 18px characters")
		check(frame_art.texture.get_image().has_mipmaps(), "frame artwork has mipmaps")
		var bg: TextureRect = screen.middle_background_art
		check(bg.texture.resource_path == "res://assets/UI-task-mid-bg.webp" and bg.texture.get_image().has_mipmaps(), "middle background asset and mipmaps")
		check(bg.size.x >= screen.middle_panel.size.x and bg.size.y >= screen.middle_panel.size.y and is_equal_approx(bg.size.aspect(), bg.texture.get_size().aspect()), "middle background covers proportionally")
		check(Vector2(bg.material.get_shader_parameter("panel_size")).is_equal_approx(screen.middle_panel.size) and is_zero_approx(bg.material.get_shader_parameter("top_fade_fraction")), "middle image uses rounded panel clipping without fade")
		var right_bg: TextureRect = screen.right_background_art
		check(right_bg.self_modulate.is_equal_approx(Color.WHITE), "right background brightness is 100 percent with full opacity")
		check(right_bg.texture.resource_path == "res://assets/UI-task-right-bg.webp" and right_bg.texture.get_image().has_mipmaps(), "right artwork and mipmaps")
		check(Vector2(right_bg.material.get_shader_parameter("panel_size")).is_equal_approx(screen.right_panel.size) and is_equal_approx(right_bg.material.get_shader_parameter("corner_radius"),screen.Inventory.BOARD_PANEL_RADIUS), "right artwork clipped to current rounded boundary")
		check(is_equal_approx(right_bg.size.aspect(),right_bg.texture.get_size().aspect()) and right_bg.size.x >= screen.right_panel.size.x - 0.01 and right_bg.size.y >= screen.right_panel.size.y - 0.01, "right artwork covers panel proportionally")
		await capture("selected-%dx%d" % [resolution.x,resolution.y])
		if visual_only:
			card.set_pressed_no_signal(false)
			list._refresh_card_frame(card)
			check(frame_art.texture.resource_path == ListView.NORMAL_FRAME and scroll_bounds.encloses(frame_art.get_global_rect()), "complete default frame is displayed")
			await capture("normal-%dx%d" % [resolution.x,resolution.y])
			card.set_pressed_no_signal(true)
			list._refresh_card_frame(card)
	if visual_only:
		Meta.stop()
		map.deactivate_location()
		map.queue_free()
		await settle()
		print("TASK_LIST_VISUAL: %d checks; %d failures; no mouse tests" % [checks,failures])
		print("OUTPUT: " + directory)
		quit(1 if failures else 0)
		return
	await click(list.sort_button)
	await settle()
	var popup: PopupMenu = list.sort_button.get_popup()
	check(popup.visible and popup.item_count == 3, "sort click opens three choices")
	await capture("sort-open-1920x1080")
	# The three equal rows put the second item's hit area at the popup center.
	var pointer := InputEventMouseMotion.new()
	pointer.position = Vector2(popup.position) + Vector2(popup.size) * 0.5
	root.push_input(pointer, true)
	await process_frame
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = pointer.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await settle()
	check(list.sort_key == "accepted_location", "popup selection changes sorting mode (actual: %s)" % list.sort_key)
	await click(screen.sidebar.buttons.side)
	check(list.cards.is_empty(), "side category excludes main quest")
	await click(screen.sidebar.buttons.main)
	check(list.cards.size() == 1 and list.cards[id].button_pressed, "main filter restores selected first task")
	check(map.travel.map_position == location and map.loadout.snapshot() == before, "list interactions do not move player or modify gameplay")
	var original: Array = list.entries.duplicate(true)
	# Sorting contract tested with isolated records, never added to game content.
	list.entries = [
		{"id":"a","category":"main","accepted_at":10,"updated_at":40,"accepted_location":"B"},
		{"id":"b","category":"main","accepted_at":30,"updated_at":20,"accepted_location":"A"},
		{"id":"c","category":"main","accepted_at":20,"updated_at":50,"accepted_location":"A"},
		{"id":"d","category":"main","accepted_at":null,"updated_at":null,"accepted_location":""}]
	list.sort_key = "accepted_at"
	check(list.ordered_entries().map(func(e): return e.id) == ["b","c","a","d"], "acceptance newest first, unknown last")
	list.sort_key = "updated_at"
	check(list.ordered_entries().map(func(e): return e.id) == ["c","a","b","d"], "last progress update newest first")
	list.sort_key = "accepted_location"
	check(list.ordered_entries().map(func(e): return e.id) == ["b","c","a","d"], "location grouping then acceptance, unknown last")
	list.entries = original
	await _capture_palette(list.definitions.category_tags)
	Meta.stop()
	map.deactivate_location()
	map.queue_free()
	await settle()
	print("TASK_LIST: %d checks; %d failures" % [checks,failures])
	print("OUTPUT: " + directory)
	quit(1 if failures else 0)

func _capture_palette(styles: Dictionary) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(800,580)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("061725")
	background.size = Vector2(800,580)
	viewport.add_child(background)
	var title := Label.new()
	title.text = "任务类别标签 · 配色提案"
	title.position = Vector2(44,26)
	title.add_theme_font_override("font", ListView.HARMONY)
	title.add_theme_font_size_override("font_size",28)
	title.add_theme_color_override("font_color",Color("e8c880"))
	viewport.add_child(title)
	var index := 0
	for id: String in styles:
		var tag := Tag.new(styles[id])
		tag.position = Vector2(48,94+index*56)
		tag.size = Vector2(86,36)
		viewport.add_child(tag)
		var info := Label.new()
		info.position = Vector2(158,94+index*56)
		info.text = "%s任务    描边 #%s    底色 #%s" % [styles[id].label,styles[id].color,styles[id].fill]
		info.add_theme_font_override("font", ListView.HARMONY)
		info.add_theme_font_size_override("font_size",22)
		info.add_theme_color_override("font_color",Color("c5d0d7"))
		viewport.add_child(info)
		index += 1
	await settle()
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(directory+"category-palette.png")
	viewport.queue_free()
