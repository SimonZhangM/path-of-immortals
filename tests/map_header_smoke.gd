extends SceneTree

var checks := 0
var failures := 0
var screen: Control

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	MapEventState.session_completed.clear()
	screen = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	screen.inventory_save_path = ""
	root.add_child(screen)
	await _settle()
	screen.set_process(false)
	_check(screen.startup_error.is_empty(), "map header initializes without starting battle")
	var header: MapStatusHeader = screen.status_header
	_check(header.get_parent() == screen and header.is_visible_in_tree(), "header is persistent outside map transform")
	_check(header.hero_name.text == "张辰宇" and header.hero_rank.text == "凡人", "map identity uses actual character cultivation rank")
	_check(header.hero_age.text == "年龄 15岁  |  寿元 80年", "prologue age and lifespan come from map state")
	_check(header.spirit_stones.text == "灵石" and header.experience.text == "历练" and header.spirit_stones_value.text == "0" and header.experience_value.text == "0", "currency and experience display configured zero values")
	_check(header.find_children("SettingsPlaceholder", "", true, false).is_empty(), "map settings glyph is removed")
	for key in ["hp", "stamina", "spirit"]:
		_check(header.values[key].text == ("0/0" if key == "spirit" else "50/50"), "initial resource from character definition: " + key)
	screen.player_status.set_resource("spirit", 5)
	_check(header.values.spirit.text == "0/0" and header.bars.spirit.ratio == 0, "mortal zero spirit cap remains empty even after attempted restoration")
	_check(header.values.cultivation.text == "0/100" and header.bars.cultivation.value == 0, "authored cultivation preview has no automatic progress")
	_check(header.cultivation_caption.text == "修为 0%", "cultivation percentage follows caption with one space")
	screen.player_status.cultivation_progress = 25
	screen.player_status.changed.emit()
	_check(header.cultivation_caption.text == "修为 25%" and header.values.cultivation.text == "25/100" and header.bars.cultivation.value == 25, "cultivation percentage, value and bar refresh from the same state")
	screen.player_status.cultivation_progress = 0
	screen.player_status.changed.emit()
	screen.player_status.set_resource("hp", 23)
	_check(header.values.hp.text == "23/50" and header.bars.hp.value == 23, "state changes refresh label and fill together")
	screen.player_status.set_resource("hp", 200)
	_check(header.values.hp.text == "50/50", "resource updates respect authoritative maximum")
	var original_camera: Vector2 = screen.content.position
	var original_zoom: float = screen.zoom_factor
	var original_destination: String = screen.travel.destination_id
	_button(MOUSE_BUTTON_LEFT, true, Vector2(600, 35))
	_motion(Vector2(680, 40), Vector2(80, 5), MOUSE_BUTTON_MASK_LEFT)
	_button(MOUSE_BUTTON_LEFT, false, Vector2(680, 40))
	_button(MOUSE_BUTTON_WHEEL_UP, true, Vector2(600, 35))
	_check(screen.content.position == original_camera and screen.zoom_factor == original_zoom and screen.travel.destination_id == original_destination, "header clicks, drags and wheel cannot operate map underneath")
	var header_position := header.get_global_rect()
	var title_position := header.map_title.get_global_rect()
	_button(MOUSE_BUTTON_LEFT, true, Vector2(900, 500))
	_motion(Vector2(940, 530), Vector2(40, 30), MOUSE_BUTTON_MASK_LEFT)
	_button(MOUSE_BUTTON_LEFT, false, Vector2(940, 530))
	_button(MOUSE_BUTTON_WHEEL_UP, true, Vector2(900, 500))
	_check(screen.zoom_factor > original_zoom and screen.content.position != original_camera, "ordinary map pan and zoom still work")
	_check(header.get_global_rect() == header_position, "map pan and zoom never move or scale header")
	_check(header.map_title.get_global_rect() == title_position, "hanging map title stays fixed during pan and zoom")
	for dimensions in [Vector2i(1920, 1080), Vector2i(1280, 800)]:
		root.size = dimensions
		await _settle()
		var view: Control = screen.map_viewport
		_check(header.map_title.is_visible_in_tree() and is_equal_approx(header.map_title.size.aspect(), 236.0 / 1031.0), "hanging map title retains source artwork aspect")
		_check(view.clip_contents and screen.content.get_parent() == view, "map renders only inside its independent clipped viewport")
		_check(is_equal_approx(view.position.y, header.size.y) and view.get_rect().end.is_equal_approx(screen.size), "map starts immediately below gold rule and reaches screen bottom")
		_check(is_equal_approx(view.position.y, header.CONNECTION_Y * header.content.scale.y), "map boundary uses gold rule, not protruding head3 ornament")
		var below_line := Vector2(2, header.CONNECTION_Y + 8)
		_check(not Geometry2D.is_point_in_polygon(below_line, header.fill.polygon) and not Geometry2D.is_point_in_polygon(Vector2(1900, below_line.y), header.fill.polygon), "no added background below gold rule, including head3 lower left")
		_check(screen._node_at(Vector2(900, view.position.y - 1)).is_empty(), "reserved header region has no selectable map nodes")
		var start: Vector2 = header.left_art.position + header.LEFT_TIP * header.left_art.size.x / header.LEFT_REGION.size.x
		_check(is_equal_approx(start.y, header.CONNECTION_Y) and header.connection.points[0].is_equal_approx(start - Vector2(3, 0)) and header.connection.points[-1].is_equal_approx(Vector2(1920, start.y)), "gold line connects head3 and reaches screen right edge")
		_check(header.left_art.position.is_equal_approx(Vector2(-35.32, -19.12)) and is_equal_approx(header.left_art.size.x, 562.68), "head3 and its content move another2px left at unchanged size")
		_check(header._has_point(Vector2(1918, start.y - 2) * header.content.scale), "header fills lower right gaps through straight baseline")
		for key in ["stamina", "spirit", "cultivation"]:
			_check(is_equal_approx(header.bars[key].global_position.y, header.bars.hp.global_position.y), "all four progress tracks share baseline: " + key)
		_check(is_equal_approx(header.resource_row.position.y + header.resource_row.size.y * 0.5, header.CONNECTION_Y * 0.5), "four status groups centered vertically inside header")
		_check(is_equal_approx(header.right_art.get_rect().end.x, 1921) and is_equal_approx(header.right_art.position.y + header.RIGHT_TIP.y * header.right_art.size.y / header.RIGHT_REGION.size.y, 90.92), "head2 moves right/down by one reference pixel")
		_check(is_equal_approx(header.left_art.size.x / header.left_art.size.y, 887.0 / 231.0) and is_equal_approx(header.right_art.size.x / header.right_art.size.y, 1171.0 / 689.0), "ornaments retain source aspect ratio")
		await _capture("map_header_%dx%d" % [dimensions.x, dimensions.y])
	root.size = Vector2i(1920, 1080)
	await _settle()
	var point: Node2D = screen.content.get_node("Points/N37")
	screen.travel.request_destination(point.point_id)
	screen.travel.advance(1000)
	screen.player.present(screen.travel)
	var target: Vector2 = screen.map_to_screen(point.position)
	_click(target)
	await _settle()
	_check(screen.dialogue.visible and header.is_visible_in_tree() and header.z_index > screen.dialogue.z_index, "header stays visible above dialogue overlay")
	_click(Vector2(600, 35))
	_check(screen.event_state.line_index == 1, "click on visible header advances active modal dialogue")
	await _capture("map_header_dialogue")
	for i in 4:
		_click(Vector2(600, 35))
	_check(not screen.dialogue.visible and header.is_visible_in_tree(), "header remains after dialogue completion")
	var camera_after: Vector2 = screen.content.position
	_button(MOUSE_BUTTON_WHEEL_UP, true, Vector2(600, 35))
	_check(screen.content.position == camera_after, "header map input guard resumes after modal closes")
	screen.queue_free()
	await process_frame
	MapEventState.session_completed.clear()
	print("MAP HEADER RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _settle() -> void:
	for i in 4:
		await process_frame

func _capture(file_name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png("res://artifacts/" + file_name + ".png") == OK, "capture " + file_name)

func _click(point: Vector2) -> void:
	_button(MOUSE_BUTTON_LEFT, true, point)
	_button(MOUSE_BUTTON_LEFT, false, point)

func _button(index: MouseButton, pressed: bool, point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = index
	event.pressed = pressed
	event.position = point
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed and index == MOUSE_BUTTON_LEFT else 0
	root.push_input(event, true)
	if pressed and index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		event.pressed = false
		root.push_input(event, true)

func _motion(point: Vector2, relative: Vector2, buttons: int) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.relative = relative
	event.button_mask = buttons
	root.push_input(event, true)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
