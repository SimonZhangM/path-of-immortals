extends "res://tests/save_actions_tests.gd"
const CATEGORY_IDS := ["all", "main", "side", "character", "inheritance", "commission", "sect", "encounter", "other"]
const CATEGORY_LABELS := ["全部任务", "主线任务", "支线任务", "人物任务", "传承任务", "委托任务", "宗门任务", "奇遇任务", "其他任务"]
var category_events: Array[String] = []

func run() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	var visual_only := OS.get_cmdline_user_args().has("--visual-only")
	directory = "res://artifacts/task-sidebar%s/run-%d/" % ["-visual" if visual_only else "", Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	Slots.auto_path = directory + "auto.json"
	Session.index_path = directory + "last.json"
	Session.clear_selection()
	root.get_node("SavePlaytime").set_process(false)
	root.get_node("GameSettings").apply_values({"background_pause": false, "background_mute": false})
	root.get_node("GameSettings").set_application_focus(true)
	AudioServer.set_bus_mute(0, true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(2560, 1440)
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
	var sidebar = screen.sidebar
	screen.category_changed.connect(func(id: String): category_events.append(id))
	check(sidebar.buttons.keys() == CATEGORY_IDS, "nine requested categories in exact order")
	check(sidebar.selected_category_id == "all" and sidebar.buttons.all.button_pressed, "all tasks selected initially")
	check(sidebar.title_art.texture.atlas.resource_path == "res://assets/UI-task-left-title.webp", "authored title used")
	check(sidebar.highlights.all.texture.atlas.resource_path == "res://assets/UI-task-left-selected.webp", "authored selected frame used")
	for index in CATEGORY_IDS.size():
		var id: String = CATEGORY_IDS[index]
		check(sidebar.captions[id].text == CATEGORY_LABELS[index], "requested category label: " + id)
		check(sidebar.icons[id].texture.atlas.get_image().has_mipmaps(), "category icon has mipmaps: " + id)
	var resolutions := [Vector2i(2560,1440), Vector2i(1920,1080)] if visual_only else [Vector2i(2560,1440), Vector2i(1920,1080), Vector2i(2560,1080)]
	for resolution: Vector2i in resolutions:
		root.size = resolution
		sidebar.select_category("all")
		await settle()
		var panel: Rect2 = screen.left_panel.get_global_rect()
		var title: Rect2 = sidebar.title_art.get_global_rect()
		var rows_fit := panel.encloses(title)
		var previous_end := title.end.y
		var aligned := true
		var first_icon_x: float = sidebar.icons.all.get_global_rect().position.x
		var first_label_x: float = sidebar.captions.all.get_global_rect().position.x
		for id: String in CATEGORY_IDS:
			var row: Rect2 = sidebar.buttons[id].get_global_rect()
			var icon: Rect2 = sidebar.icons[id].get_global_rect()
			var label: Rect2 = sidebar.captions[id].get_global_rect()
			rows_fit = rows_fit and panel.encloses(row) and row.encloses(icon) and row.encloses(label) and row.position.y >= previous_end - 0.5
			aligned = aligned and absf(icon.position.x - first_icon_x) < 1 and absf(label.position.x - first_label_x) < 1 and icon.end.x < label.position.x
			previous_end = row.end.y
		check(rows_fit, "title and all nine rows fit without overlap at " + str(resolution))
		check(aligned, "icons and labels align consistently at " + str(resolution))
		check(absf(screen.middle_panel.get_global_rect().end.x - map.status_header.bars.stamina.get_global_rect().get_center().x) < 1, "sidebar preserves three-column boundary")
		var shared_fill := true
		for task_panel: PanelContainer in [screen.left_panel, screen.middle_panel, screen.right_panel]:
			shared_fill = shared_fill and task_panel.get_theme_stylebox("panel").bg_color == Color("061725")
		check(shared_fill, "shared #061725 beneath three column artworks")
		var art: TextureRect = screen.left_background_art
		var source_size := art.texture.get_size()
		check(is_equal_approx(art.size.x, screen.left_panel.size.x) and is_equal_approx(art.size.x / source_size.x, art.size.y / source_size.y) and is_equal_approx(art.position.y + art.size.y, screen.left_panel.size.y + 30.0), "sidebar background fits width proportionally and shifts 30 design pixels below bottom alignment")
		var mask := art.material as ShaderMaterial
		check(is_equal_approx(mask.get_shader_parameter("top_fade_fraction"), 0.2) and mask.get_shader_parameter("panel_size") == screen.left_panel.size and mask.get_shader_parameter("art_position") == art.position and mask.get_shader_parameter("corner_radius") == 18.0, "20 percent top fade and rounded clipping use current layout")
		check(art.texture.resource_path == "res://assets/UI-task-left-bg.webp" and art.texture.get_image().has_mipmaps(), "requested sidebar artwork imported with mipmaps")
		var slot: Rect2 = sidebar.title_art.get_parent().get_global_rect()
		check(title.get_center().distance_to(slot.get_center()) < 0.01 and title.size.distance_to(slot.size * 0.8) < 0.01, "title is exactly 80 percent around unchanged center")
		var borders_match := true
		var all_regular := true
		for index in CATEGORY_IDS.size():
			var id: String = CATEGORY_IDS[index]
			var row: Rect2 = sidebar.buttons[id].get_global_rect()
			var frame: Rect2 = sidebar.highlights[id].get_global_rect()
			var atlas: AtlasTexture = sidebar.highlights[id].texture
			var stroke_scale := frame.size.y / atlas.region.size.y
			var top := frame.position.y + (98.0 - atlas.region.position.y) * stroke_scale
			var bottom := frame.position.y + (638.0 - atlas.region.position.y) * stroke_scale
			borders_match = borders_match and absf(top - row.position.y) < 0.01 and absf(bottom - row.end.y) < 0.01
			if index < CATEGORY_IDS.size() - 1:
				var divider: Rect2 = sidebar.buttons[id].get_node("CategoryDivider").get_global_rect()
				var next: Rect2 = sidebar.buttons[CATEGORY_IDS[index + 1]].get_global_rect()
				borders_match = borders_match and absf(divider.get_center().y - bottom) < 0.01 and absf(next.position.y - bottom) < 0.01
			var font: Font = sidebar.captions[id].get_theme_font("font")
			all_regular = all_regular and font is SystemFont and font.font_weight == 400
		check(borders_match, "shared separators coincide with every frame's gold strokes")
		check(all_regular, "all nine category labels use regular font")
		var first_center: Vector2 = sidebar.get_global_transform().affine_inverse() * sidebar.buttons.all.get_global_rect().get_center()
		check(absf(first_center.y - 135.0) < 0.5, "first row keeps top edge with 66px height")
		var resized_rows := true
		for id: String in CATEGORY_IDS:
			resized_rows = resized_rows and is_equal_approx(sidebar.buttons[id].size.y, 66.0) and sidebar.icons[id].size.is_equal_approx(Vector2(37.8,37.8))
		check(resized_rows, "nine rows grow ten percent and icons shrink ten percent")
		if DisplayServer.get_name() != "headless": await capture("all-%dx%d" % [resolution.x, resolution.y])
		if visual_only and DisplayServer.get_name() != "headless":
			for id: String in ["inheritance", "other"]:
				sidebar.select_category(id)
				await capture("%s-%dx%d" % [id, resolution.x, resolution.y])
	if visual_only:
		Meta.stop()
		map.deactivate_location()
		map.queue_free()
		await settle()
		print("TASK_SIDEBAR_VISUAL: %d checks; %d failures; no mouse tests" % [checks, failures])
		print("OUTPUT: " + directory)
		quit(1 if failures else 0)
		return
	root.size = Vector2i(2560, 1440)
	await settle()
	var position: Vector2 = map.travel.map_position
	for index in CATEGORY_IDS.size():
		var id: String = CATEGORY_IDS[index]
		# Exercise real input over artwork/text, not just emitting the button signal.
		await click(sidebar.icons[id] if index % 2 == 0 else sidebar.captions[id])
		await settle()
		var one_selected: bool = sidebar.selected_category_id == id
		for other: String in CATEGORY_IDS:
			one_selected = one_selected and sidebar.highlights[other].visible == (other == id) and sidebar.buttons[other].button_pressed == (other == id)
		check(one_selected, "click selects exactly one category through icon/label: " + id)
	check(category_events.size() == 8, "only real category changes emit once")
	await click(sidebar.buttons.other)
	await click(screen.middle_panel)
	check(sidebar.highlights.other.visible and category_events.size() == 8, "same selection and empty content clicks preserve category")
	check(map.travel.map_position == position, "category clicks do not move underlying map")
	await click(sidebar.icons.inheritance)
	await settle()
	if DisplayServer.get_name() != "headless": await capture("inheritance-2560x1440")
	await click(map.status_header.tasks_button)
	check(not map.is_task_open(), "shared header still closes tasks")
	await click(map.status_header.tasks_button)
	check(map.is_task_open() and sidebar.selected_category_id == "inheritance", "reopening retains UI category")
	check(map.loadout.snapshot() == before, "category UI does not mutate gameplay")
	Meta.stop()
	map.deactivate_location()
	map.queue_free()
	await settle()
	print("TASK_SIDEBAR: %d checks; %d failures" % [checks, failures])
	print("OUTPUT: " + directory)
	quit(1 if failures else 0)
