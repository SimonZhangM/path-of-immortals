extends SceneTree

var checks := 0
var failures := 0
var screen: Control

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	screen = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	screen.inventory_save_path = ""
	root.add_child(screen)
	for frame in 4:
		await process_frame
	screen.set_process(false)
	_check(screen.startup_error.is_empty(), "player loads with map")
	var player: MapPlayer = screen.player
	var travel: MapTravelState = screen.travel
	var points: Node2D = screen.content.get_node("Points")
	_check(travel.current_node_id == points.get_node("EastExit").point_id and travel.mode == "idle", "starts idle at east exit")
	player.present(travel)
	_check(player.flip_h, "initial idle faces left and stationary presentation preserves facing")
	_check(Rect2(Vector2.ZERO, screen.size).has_point(_screen_point("EastExit")), "initial camera shows player start")
	_hover(Vector2(40, 40))
	_check(screen.mouse_default_cursor_shape == Control.CURSOR_ARROW, "ordinary map uses normal arrow")
	_hover(_screen_point("N15"))
	_check(screen.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "node hover uses link hand")
	var node_target := _screen_point("N15")
	_button(true, node_target)
	_check(screen.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "press alone is not map dragging")
	screen.notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	_check(screen.mouse_default_cursor_shape == Control.CURSOR_ARROW, "focus loss clears cursor and press")
	_button(false, node_target)
	_check(travel.mode == "idle", "cancelled press does not move player")
	for action in ["idle", "walk", "run"]:
		var frames := player.sprite_frames
		_check(frames.get_frame_count(action) == {"idle": 16, "walk": 26, "run": 16}[action], "playback frame count: " + action)
		_check(is_equal_approx(frames.get_animation_speed(action), {"idle": 12.0, "walk": 26.0, "run": 16.0 / 0.75}[action]), "authored animation pace: " + action)
		var cell := Vector2(360, 360)
		for i in frames.get_frame_count(action):
			var texture := frames.get_frame_texture(action, i) as AtlasTexture
			var columns := 6 if action == "walk" else 4
			var expected := Rect2(Vector2((i % columns) * 360, (i / columns) * 360), cell)
			_check(texture.region == expected, "exact source cell in authored playback order")
		player.play(action)
		_check(is_equal_approx(cell.y * player.scale.y, 144.0), "animation padding compensated to retain actor size")
		var feet_y: float = {"idle": 316.0, "walk": 314.0, "run": 315.0}[action]
		_check(is_zero_approx((feet_y - cell.y * 0.5 + player.offset.y) * player.scale.y), "feet remain anchored across sheet resolutions")
		var changes := [0]
		var count_change := func() -> void: changes[0] += 1
		player.frame_changed.connect(count_change)
		await create_timer(0.5).timeout
		player.frame_changed.disconnect(count_change)
		_check(changes[0] > 0 and player.is_playing(), "actual frame switching: " + action)
	player.play("idle")
	var target := _screen_point("N15")
	_click(target)
	_check(travel.destination_id == points.get_node("N15").point_id and travel.mode == "walk", "native click sends adjacent-node movement")
	var position_before := travel.map_position
	travel.advance(0.5)
	player.present(travel)
	var path := travel.shortest_path(points.get_node("EastExit").point_id, points.get_node("N15").point_id)
	var segment: Dictionary = path[0]
	var offset: float = segment.length - 100.0 if segment.reverse else 100.0
	_check(travel.map_position.is_equal_approx(segment.curve.sample_baked(offset)), "half-second walk advances 100 source pixels at doubled speed")
	_check(player.animation == &"walk" and player.position.distance_to(position_before) > 20 and player.flip_h, "walking follows model and faces left")
	var pending_before := travel.pending_destination_id
	_button(true, target)
	var motion := InputEventMouseMotion.new()
	motion.position = target + Vector2(40, 20)
	motion.relative = Vector2(40, 20)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion, true)
	_check(screen.mouse_default_cursor_shape == Control.CURSOR_MOVE, "dragging map uses move cursor")
	_button(false, motion.position)
	_check(screen.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "release over translated node restores hand")
	_hover(Vector2(40, 40))
	_check(screen.mouse_default_cursor_shape == Control.CURSOR_ARROW, "leaving node restores arrow")
	_check(travel.pending_destination_id == pending_before, "dragging near a node never orders movement")
	_click(_screen_point("N14"))
	_check(travel.pending_destination_id == points.get_node("N14").point_id and travel.current_node_id == points.get_node("EastExit").point_id, "click during walking queues diversion")
	travel.advance(100)
	player.present(travel)
	_check(travel.current_node_id == points.get_node("N14").point_id and player.animation == &"idle", "queued destination reached then idle")
	travel.request_destination(points.get_node("N01").point_id)
	player.present(travel)
	_check(travel.journey_node_count > 2 and player.animation == &"run", "long actual map route starts run")
	var run_path := travel.shortest_path(travel.current_node_id, travel.destination_id)
	var run_segment: Dictionary = run_path[0]
	travel.advance(0.4)
	var run_offset: float = run_segment.length - 144.0 if run_segment.reverse else 144.0
	_check(travel.map_position.is_equal_approx(run_segment.curve.sample_baked(run_offset)), "0.4 second run advances 144 source pixels at doubled speed")
	player.present(travel)
	var snapshot := travel.map_position
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = screen.size * 0.5
	root.push_input(wheel, true)
	_check(travel.map_position == snapshot, "camera zoom never changes travel progress")
	if DisplayServer.get_name() != "headless":
		for action in ["run", "walk", "idle"]:
			if action == "walk":
				travel.advance(1000)
				travel.request_destination(points.get_node("N02").point_id)
				travel.advance(0.8)
			elif action == "idle":
				travel.advance(1000)
			player.present(travel)
			screen.content.position = screen.map_viewport.size * 0.5 - player.position * screen.content.scale
			screen._clamp_position()
			await create_timer(0.2).timeout
			await RenderingServer.frame_post_draw
			_check(root.get_texture().get_image().save_png("res://artifacts/map_player_%s.png" % action) == OK, "player render: " + action)
	screen.queue_free()
	await process_frame
	print("MAP PLAYER RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _screen_point(name: String) -> Vector2:
	var point: Node2D = screen.content.get_node("Points/" + name)
	return screen.map_to_screen(point.position)

func _click(position: Vector2) -> void:
	_button(true, position)
	_button(false, position)

func _hover(position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	root.push_input(event, true)

func _button(pressed: bool, position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(event, true)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
