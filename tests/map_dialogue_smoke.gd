extends SceneTree

var checks := 0
var failures := 0
var screen: Control

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	MapEventState.session_completed.clear()
	await _load_map()
	_check(screen.startup_error.is_empty(), "map with event registry starts")
	var point = screen.content.get_node("Points/N37")
	var sign = point.get_node("Sign")
	var other_sign = screen.content.get_node("Points/N20/Sign")
	_click(_point("N37"))
	_check(not screen.dialogue.visible and screen.travel.mode == "walk", "first remote click only starts two-node walk")
	screen.travel.advance(1000)
	screen.player.present(screen.travel)
	_check(screen.travel.current_node_id == point.point_id and screen.travel.mode == "idle" and not screen.dialogue.visible, "arrival does not auto trigger")
	_click(_point("N37"))
	_check(screen.event_state.is_active() and screen.dialogue.visible, "second native node click opens dialogue")
	_check(screen.event_state.line_index == 0 and screen.dialogue.text_label.text == "河水最近又浅了不少。", "opening click does not skip first line")
	_check(sign.is_visible_in_tree(), "sign remains until completion")
	var overlay: MapDialogue = screen.dialogue
	var camera: Vector2 = screen.content.position
	var zoom: float = screen.zoom_factor
	var player_position: Vector2 = screen.travel.map_position
	var destination: String = screen.travel.destination_id
	for dimensions in [Vector2i(1920, 1080), Vector2i(1280, 800)]:
		root.size = dimensions
		await _settle()
		var panel_rect := overlay.background.get_rect()
		_check(panel_rect.get_center().is_equal_approx(Vector2(screen.size.x * 0.5, screen.size.y * 0.75)), "dialogue center is screen 50/75 percent")
		_check(Rect2(Vector2.ZERO, screen.size).encloses(panel_rect), "whole panel fits viewport")
		var factor := panel_rect.size.x / 1807.0
		var slot := Rect2(panel_rect.position + Vector2(62, 20.5) * factor, Vector2(368, 368) * factor)
		_check(slot.grow(0.01).encloses(overlay.portrait.get_rect()), "portrait stays inside authored circular window")
		_check(overlay.portrait.get_rect().get_center().is_equal_approx(slot.get_center()), "portrait centered in circular aperture")
		_check(is_equal_approx(overlay.portrait.size.x / overlay.portrait.size.y, 1.0), "portrait original aspect preserved")
		_check(panel_rect.encloses(overlay.text_label.get_rect()) and overlay.text_label.size.y >= overlay.text_label.get_minimum_size().y, "text fits right panel: panel=%s text=%s min=%s" % [panel_rect, overlay.text_label.get_rect(), overlay.text_label.get_minimum_size()])
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			_check(root.get_texture().get_image().save_png("res://artifacts/map_dialogue_%dx%d.png" % [dimensions.x, dimensions.y]) == OK, "dialogue render")
	root.size = Vector2i(1920,1080)
	await _settle()
	camera = screen.content.position
	var outside := Vector2(100, 100)
	_button(MOUSE_BUTTON_RIGHT, true, outside)
	_button(MOUSE_BUTTON_RIGHT, false, outside)
	_button(MOUSE_BUTTON_WHEEL_UP, true, outside)
	_button(MOUSE_BUTTON_WHEEL_DOWN, true, outside)
	_check(screen.event_state.line_index == 0 and screen.zoom_factor == zoom, "right click and wheel do not advance or zoom")
	_button(MOUSE_BUTTON_LEFT, true, outside)
	var motion := InputEventMouseMotion.new()
	motion.position = outside + Vector2(100, 50)
	motion.relative = Vector2(100, 50)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion, true)
	_button(MOUSE_BUTTON_LEFT, false, motion.position)
	_check(screen.event_state.line_index == 0 and screen.content.position.is_equal_approx(camera), "drag does not advance or pan")
	_button(MOUSE_BUTTON_LEFT, true, outside)
	overlay.notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	_button(MOUSE_BUTTON_LEFT, false, outside)
	_check(screen.event_state.line_index == 0, "focus loss cancels pending click")
	_click(_point("N15"))
	_check(screen.event_state.line_index == 1 and screen.travel.destination_id == destination, "clicking another node advances text without movement")
	_click(overlay.portrait.get_rect().get_center())
	_check(screen.event_state.line_index == 2 and overlay.text_label.text == "岸边怎么这么多脚印。", "portrait click advances exactly once")
	_click(overlay.text_label.get_rect().get_center())
	_check(screen.event_state.line_index == 3, "text click advances exactly once")
	_click(outside)
	_check(screen.event_state.line_index == 4 and overlay.text_label.text == "不好！有血……" and sign.visible, "final paragraph remains until one more click")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png("res://artifacts/map_dialogue_last.png") == OK, "last paragraph render")
	_click(_point("N15"))
	_check(not overlay.visible and not screen.event_state.is_active(), "final click closes dialogue")
	_check(not sign.visible and not sign.get_node("StoryIcon").is_visible_in_tree(), "completion hides both sign and icon")
	_check(point.visible and other_sign.visible and screen.content.get_node("Points").get_child_count() == 38 and screen.content.get_node("Routes").get_child_count() == 41, "node, other signs and graph remain intact")
	_check(screen.travel.map_position == player_position and screen.travel.destination_id == destination and screen.travel.mode == "idle", "closing click never leaks to map")
	_click(_point("N37"))
	_check(not overlay.visible, "completed node click cannot repeat")
	_click(_point("N15"))
	_check(screen.travel.mode == "walk", "map movement resumes after dialogue")
	screen.travel.advance(1000)
	screen.player.present(screen.travel)
	_click(_point("N37"))
	screen.travel.advance(1000)
	screen.player.present(screen.travel)
	_click(_point("N37"))
	_check(not overlay.visible and not sign.visible, "revisiting completed node cannot repeat")
	screen.queue_free()
	await process_frame
	await _load_map()
	_check(not screen.content.get_node("Points/N37/Sign").visible, "map reload retains run-scoped completion")
	screen.queue_free()
	await process_frame
	MapEventState.session_completed.clear()
	await _load_map()
	_check(screen.content.get_node("Points/N37/Sign").visible, "fresh run starts with sign restored")
	screen.queue_free()
	await process_frame
	print("MAP DIALOGUE RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _load_map() -> void:
	screen = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	root.add_child(screen)
	await _settle()
	screen.set_process(false)

func _settle() -> void:
	for i in 4:
		await process_frame

func _point(node_name: String) -> Vector2:
	return screen.content.position + screen.content.get_node("Points/" + node_name).position * screen.content.scale

func _click(position: Vector2) -> void:
	_button(MOUSE_BUTTON_LEFT, true, position)
	_button(MOUSE_BUTTON_LEFT, false, position)

func _button(index: MouseButton, pressed: bool, position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = index
	event.pressed = pressed
	event.position = position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if index == MOUSE_BUTTON_LEFT and pressed else 0
	root.push_input(event, true)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
