extends "res://tests/save_actions_tests.gd"

func run() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	directory = "res://artifacts/task-detail/run-%d/" % Time.get_ticks_usec()
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
	var detail = screen.detail_header
	var original: Array = list.entries.duplicate(true)
	var id := "quest.prologue.yaoxiangruchang"
	check(not detail.visible, "no unselected task details are invented")
	list.select_task(id)
	await settle()
	check(detail.visible and detail.task_id == id and detail.title_label.text == "药香如常", "selecting the card populates its detail header")
	check(detail.icon.texture == screen.sidebar.icons.main.texture and detail.category_tag.caption.text == "主线任务", "detail uses the selected task category icon and full category tag")
	check(detail.artwork.texture.resource_path == "res://assets/UI-task-right-main-yaoxiangruchang.webp" and detail.artwork.texture.get_image().has_mipmaps(), "requested detail image imported with mipmaps")
	for resolution in [Vector2i(2560,1440),Vector2i(1920,1080)]:
		root.size = resolution
		await settle()
		var frame: Rect2 = screen.right_panel.get_global_rect()
		var picture: Rect2 = detail.artwork.get_global_rect()
		check(picture.position.is_equal_approx(frame.position) and is_equal_approx(picture.end.x, frame.end.x), "picture top and both sides align with right panel at %s" % resolution)
		# Global transform composition can differ by subpixel floating-point roundoff.
		check(is_equal_approx(detail.artwork.size.aspect(), detail.artwork.texture.get_size().aspect()) and frame.grow(0.01).encloses(picture), "full image fits proportionally at %s; panel %s, image %s, local size %s, source %s" % [resolution,frame,picture,detail.artwork.size,detail.artwork.texture.get_size()])
		check(Vector2(detail.artwork.material.get_shader_parameter("panel_size")).is_equal_approx(screen.right_panel.size), "rounded clipping follows actual right panel")
		check(detail.title_label.get_global_rect().position.x > detail.icon.get_global_rect().end.x and detail.category_tag.get_global_rect().position.y >= detail.title_label.get_global_rect().end.y, "icon sits left of task name with category below the name")
		check(detail.introduction.get_global_rect().position.y >= detail.category_tag.get_global_rect().end.y, "introduction starts in a separate row below heading")
		for stage_id: String in ["morning", "gathering", "returning"]:
			var changed := original.duplicate(true)
			changed[0].stage_id = stage_id
			list.set_entries(changed)
			await settle()
			check(detail.stage_id == stage_id and detail.introduction.text == changed[0].introductions[stage_id], "stage data refreshes introduction without reopening: %s at %s" % [stage_id,resolution])
			check(picture.encloses(detail.introduction.get_global_rect()) and detail.introduction.get_line_count() == detail.introduction.get_visible_line_count(), "complete introduction fits within image area: %s at %s" % [stage_id,resolution])
			await capture("%s-%dx%d" % [stage_id,resolution.x,resolution.y])
	list.set_category("side")
	check(not detail.visible and detail.task_id.is_empty(), "empty category hides previous task details")
	list.set_category("main")
	check(detail.visible and detail.task_id == id, "returning to category restores selected task details")
	list.set_entries([])
	check(not detail.visible, "removing the selected task clears its details")
	list.set_entries(original)
	check(detail.visible and detail.stage_id == "morning", "restored data uses its supplied stage")
	check(map.loadout.snapshot() == before, "selection and introduction presentation never advance quests or modify game state")
	Meta.stop()
	map.deactivate_location()
	map.queue_free()
	await settle()
	print("TASK_DETAIL_HEADER: %d checks; %d failures; no mouse tests" % [checks,failures])
	print("OUTPUT: " + directory)
	quit(1 if failures else 0)
