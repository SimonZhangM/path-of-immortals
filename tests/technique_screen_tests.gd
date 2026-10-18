extends "res://tests/map_shop_tests.gd"

func key(code: Key, repeated := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	event.echo = repeated
	root.push_input(event, true)
	await settle()

func run() -> void:
	AudioServer.set_bus_mute(0, true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(2560, 1440)
	if DisplayServer.get_name() != "headless":
		await preview()
		return
	for scene_path in ["res://scenes/maps/qingshihewan.tscn", "res://scenes/maps/qingshizhen.tscn"]:
		var map = load(scene_path).instantiate()
		map.inventory_save_path = ""
		map.defer_map_music = true
		root.add_child(map)
		await settle()
		check(map.startup_error.is_empty(), "map startup: " + scene_path)
		if not map.startup_error.is_empty(): quit(1); return
		var before: Dictionary = map.loadout.snapshot().duplicate(true)
		await key(KEY_G)
		check(map.is_technique_open(), "G opens technique screen")
		check(not map.is_inventory_open(), "inventory stays closed")
		check(map.calendar_readout.visible, "technique screen shares inventory calendar")
		check(not map.status_header.map_title.visible, "travel title hidden")
		await key(KEY_G, true)
		check(map.is_technique_open(), "held G does not close repeatedly")
		await key(KEY_I)
		check(not map.is_technique_open() and map.is_inventory_open(), "I switches directly to inventory")
		map.inventory_screen.search_box.grab_focus()
		await key(KEY_G)
		check(map.is_inventory_open() and not map.is_technique_open(), "typing G in search does not switch")
		map.inventory_screen.search_box.text = ""
		map.inventory_screen.search_box.release_focus()
		await key(KEY_G)
		check(map.is_technique_open() and not map.is_inventory_open(), "G switches directly to techniques")
		var screen = map.technique_screen
		for viewport_size in [Vector2i(1920,1080), Vector2i(2560,1440), Vector2i(2560,1080)]:
			root.size = viewport_size
			var original = map.inventory_screen
			# Hidden Godot containers defer sorting; measure the displayed baseline.
			screen.hide()
			original.show()
			await settle()
			var old_left: Rect2 = original.sidebar.get_global_rect()
			var old_middle: Rect2 = original.board_panel.get_global_rect()
			var old_right: Rect2 = original.storage_panel.get_global_rect()
			original.hide()
			screen.show()
			await settle()
			var left: Rect2 = screen.left_panel.get_global_rect()
			var middle: Rect2 = screen.middle_panel.get_global_rect()
			var right: Rect2 = screen.right_panel.get_global_rect()
			check(absf(left.position.x-old_left.position.x)<2, "left edge stays fixed")
			check(absf(right.end.x-old_right.end.x)<2, "right edge stays fixed")
			check(absf(left.size.x-(left.size.y/3.0-50.0*screen.stage.scale.x))<2, "left column reduced fifty design pixels cumulatively")
			check(absf(right.size.x-right.size.y*5.0/12.0)<2, "right height to width is 12:5")
			check(absf((middle.position.x-left.end.x)-(old_middle.position.x-old_left.end.x))<2, "left gap unchanged")
			check(absf((right.position.x-middle.end.x)-(old_right.position.x-old_middle.end.x))<2, "right gap unchanged")
			check(absf(middle.position.y-old_middle.position.y)<2 and absf(middle.size.y-old_middle.size.y)<2, "vertical layout retained")
			check(sidebar_only(screen), "sidebar includes title, return, categories and 35 book cards")
		root.size = Vector2i(2560,1440)
		await settle()
		if DisplayServer.get_name() != "headless" and scene_path.contains("qingshihewan"):
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/technique-screen.png")
		var position: Vector2 = map.travel.map_position
		map._process(10.0)
		check(map.travel.map_position == position, "map travel does not advance while open")
		await key(KEY_G)
		check(not map.is_technique_open(), "G closes technique screen")
		await key(KEY_G)
		await key(KEY_ESCAPE)
		check(not map.is_technique_open(), "Esc returns to map")
		map.set_inventory_open(true)
		map.loadout.revision += 1
		map.inventory_save_path = "res://artifacts/missing-technique-test-directory/save.json"
		await key(KEY_G)
		check(map.is_inventory_open() and not map.is_technique_open(), "failed save keeps inventory open")
		for child in map.get_children():
			if child is AcceptDialog: child.queue_free()
		map.inventory_save_path = ""
		await settle()
		await key(KEY_G)
		check(not map.is_inventory_open() and map.is_technique_open(), "successful save permits direct switch")
		await click(screen.return_button)
		check(not map.is_technique_open() and not map.is_inventory_open(), "return button goes back to travel")
		map.event_state.phase = "rest"
		map.event_state.active_id = "test.active_event"
		map.set_technique_open(true)
		check(not map.is_technique_open(), "active event blocks technique screen")
		map.event_state.phase = ""
		map.event_state.active_id = ""
		map.set_process(false)
		var edge: Dictionary = map.travel.adjacency[map.travel.current_node_id][0]
		map.travel.request_destination(edge.to)
		map._process(0.01)
		check(map.travel.mode != "idle", "fixture starts a real route")
		position = map.travel.map_position
		await key(KEY_G)
		map._process(0.1)
		check(map.travel.map_position == position, "G pauses an in-progress journey")
		await key(KEY_ESCAPE)
		map._process(0.01)
		check(map.travel.map_position != position, "Esc resumes the same journey")
		check(map.loadout.snapshot() == before, "opening empty screen does not mutate player data")
		map.travel.stop_at_current_node()
		await special_contexts(map, scene_path)
		map.queue_free()
		await settle()
	print("TECHNIQUE SCREEN: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func preview() -> void:
	var map = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path = ""
	map.defer_map_music = true
	root.add_child(map)
	map.set_process(false)
	await settle()
	check(map.startup_error.is_empty(), "actual map starts")
	map.set_inventory_open(true)
	await settle()
	var calendar_rect: Rect2 = map.calendar_readout.get_global_rect()
	var calendar_caption: String = map.calendar_readout.caption.text
	var old_left: Rect2 = map.inventory_screen.sidebar.get_global_rect()
	var old_middle: Rect2 = map.inventory_screen.board_panel.get_global_rect()
	var old_right: Rect2 = map.inventory_screen.storage_panel.get_global_rect()
	var old_return: Rect2 = map.inventory_screen.return_button.get_global_rect()
	var reference: TextureRect = map.inventory_screen.sidebar.find_child("AttributesTitleArtwork", true, false)
	var reference_size := reference.size
	map.set_inventory_open(false)
	map.set_technique_open(true)
	await settle()
	var screen = map.technique_screen
	var left: Rect2 = screen.left_panel.get_global_rect()
	var middle: Rect2 = screen.middle_panel.get_global_rect()
	var right: Rect2 = screen.right_panel.get_global_rect()
	check(absf(left.size.x-(left.size.y/3.0-50.0*screen.stage.scale.x))<2, "left column reduced fifty design pixels cumulatively")
	check(absf(right.size.x-right.size.y*5.0/12.0)<2, "right height to width is 12:5")
	check(absf(left.position.x-old_left.position.x)<2 and absf(right.end.x-old_right.end.x)<2, "outer edges retained: new %s / %s, original %s / %s" % [left, right, old_left, old_right])
	check(absf((middle.position.x-left.end.x)-(old_middle.position.x-old_left.end.x))<2 and absf((right.position.x-middle.end.x)-(old_right.position.x-old_middle.end.x))<2, "both gaps retained")
	check(absf(middle.size.x/screen.stage.scale.x-1203.5)<2, "middle fills remaining design width")
	check(absf(left.size.y-old_left.size.y)<2 and absf(middle.size.y-old_middle.size.y)<2 and absf(right.size.y-old_right.size.y)<2, "all heights retained")
	for panel in [screen.left_panel, screen.middle_panel, screen.right_panel]:
		var rim: ColorRect = panel.find_child("Border", true, false)
		var art: TextureRect = panel.find_child("ColumnBackground", true, false)
		check(art.get_global_rect().get_center().is_equal_approx(panel.get_global_rect().get_center()), "column artwork shares panel center")
		check(art.size.x + 0.01 >= panel.size.x and art.size.y + 0.01 >= panel.size.y, "column artwork fully covers panel")
		check(is_equal_approx(art.size.x/art.texture.get_width(), art.size.y/art.texture.get_height()), "column artwork scales uniformly")
		check(art.texture.get_image().has_mipmaps(), "column artwork has mipmaps")
		check(art.material.shader.resource_path.ends_with("map_inventory_panel_art.gdshader") and art.material.get_shader_parameter("panel_size").is_equal_approx(panel.size), "rounded mask clips to actual panel size")
		check(art.material.get_shader_parameter("corner_radius") == rim.material.get_shader_parameter("corner_radius"), "art and border use identical corners")
		check(art.get_parent().get_index() < rim.get_parent().get_index() and art.get_parent().z_index < rim.get_parent().z_index, "background below border")
		check(rim != null, "column has explicit border")
		check(rim.material.get_shader_parameter("line_width") == 2.0, "same 2px stroke")
		check(rim.material.get_shader_parameter("line_color") == Color("d9bb72"), "same gold color")
	check(sidebar_only(screen), "sidebar includes title, return, categories and 35 book cards")
	check(screen.return_button.get_global_rect().is_equal_approx(old_return), "return button same size and screen position as inventory")
	check(screen.title_art.size.is_equal_approx(reference_size * (4.0 / 3.0)), "title enlarged one third from attributes title bounds")
	check(absf(screen.title_art.get_global_rect().get_center().x-left.get_center().x)<0.01, "title centered in left column")
	check(absf(screen.title_art.position.y+screen.title_art.size.y*0.5-112.0)<0.01, "title centered vertically in reference red box")
	check(screen.title_art.texture.atlas.get_image().has_mipmaps(), "new title has mipmaps")
	var original: TextureRect = map.inventory_screen.background_art
	check(screen.background_art.texture == original.texture, "same full-page artwork")
	check(screen.background_art.self_modulate == original.self_modulate, "same background opacity")
	check(screen.background_art.stretch_mode == original.stretch_mode, "same aspect-cover setting")
	check(screen.background_art.get_global_rect().is_equal_approx(original.get_global_rect()), "same background area below Head")
	check(map.calendar_readout.visible, "date shown in techniques")
	check(map.calendar_readout.get_global_rect().is_equal_approx(calendar_rect), "same date position and size")
	check(map.calendar_readout.caption.text == calendar_caption, "same actual game date")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/technique-screen.png")
	map.set_technique_open(false)
	check(not map.calendar_readout.visible, "date hidden again on travel map")
	print("TECHNIQUE SCREEN STATIC: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func sidebar_only(screen: Control) -> bool:
	return screen.body.find_children("*", "Label", true, false).size() == 100 and screen.body.find_children("*", "TextureRect", true, false).size() == 57 and screen.body.find_children("*", "BaseButton", true, false).size() == 43

func special_contexts(map: Node, scene_path: String) -> void:
	var home := scene_path.contains("qingshizhen")
	var point := "base.map.qingshizhen.point.n03" if home else "base.map.qingshihewan.point.n32"
	map.travel.current_node_id = point
	map.travel.map_position = map.travel.node_positions[point]
	map.travel.stop_at_current_node()
	check(map._try_start_event(point, "click", true), "open real home/cultivation context")
	if home:
		map._open_home_warehouse()
		await settle()
		await key(KEY_I)
		check(map.is_inventory_open() and map.inventory_screen.warehouse_id.is_empty() and not map.event_state.is_active(), "warehouse I opens normal inventory and closes rest context")
		map.set_inventory_open(false)
		map._try_start_event(point, "click", true)
		map._open_home_warehouse()
		await key(KEY_G)
		check(map.is_technique_open() and not map.is_inventory_open() and not map.event_state.is_active(), "warehouse G opens techniques and closes rest context")
		await click(map.technique_screen.return_button)
		check(not map.is_technique_open() and not map.travel.paused, "warehouse switch can return to travel")
	else:
		map._request_cultivation("balanced", 15)
		map._open_cultivation_inventory()
		await key(KEY_G)
		check(map.is_technique_open() and map._cultivation_adjusting and not map.cultivation_progress_dialog.visible, "cultivation context retained while switching to techniques")
		await key(KEY_I)
		check(map.is_inventory_open() and map._cultivation_adjusting, "switch back retains cultivation context")
		await key(KEY_G)
		await click(map.technique_screen.return_button)
		check(map.cultivation_progress_dialog.visible and not map.is_technique_open() and not map._cultivation_adjusting, "return button restores cultivation parent")
		map._close_cultivation()
