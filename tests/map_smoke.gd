extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var screen: Control = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	screen.inventory_save_path = ""
	root.add_child(screen)
	await _settle()
	_check(screen.startup_error.is_empty(), "map definition loads")
	var content: Node2D = screen.content
	var points: Node2D = content.get_node("Points")
	var routes: Node2D = content.get_node("Routes")
	_check(points.get_child_count() == 38, "38 marked stops including east road end")
	_check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/maps/qingshihewan.tscn", "F5 project main scene is the map preview")
	var east_exit := points.get_node("EastExit") as MapRoutePoint
	_check(east_exit != null and east_exit.visible and east_exit.texture.resource_path == "res://assets/mapdot.webp", "east road endpoint displays mapdot")
	_check(routes.get_child_count() == 41, "all reference route branches are present")
	_check(content.get_node("Background").texture.get_size() == Vector2(3220, 1830), "map uses original bitmap dimensions")
	_check(content.get_node("Background").texture.resource_path == screen.definition["background"], "background matches metadata")
	var background_image: Image = content.get_node("Background").texture.get_image()
	_check(background_image != null and not background_image.is_empty() and background_image.get_size() == Vector2i(3220, 1830), "imported background also decodes for editor image previews")
	_check(screen.find_child("GameManager", true, false) == null, "route preview does not start a battle")
	var identities: Dictionary = {}
	var neighbors: Dictionary = {}
	for point in points.get_children():
		var id: String = point.point_id
		_check(not identities.has(id) and id.begins_with("base.map.qingshihewan.point."), "unique stable point id")
		identities[id] = true
		neighbors[point] = []
	var curve_ids: Dictionary = {}
	for route: MapRoute in routes.get_children():
		_check(route._get_configuration_warnings().is_empty(), "route has valid endpoints and curve")
		_check(not identities.has(route.route_id), "unique route identity")
		identities[route.route_id] = true
		_check(not curve_ids.has(route.curve.get_instance_id()), "curve edits cannot alter another route")
		curve_ids[route.curve.get_instance_id()] = true
		var a := route.get_node(route.start_point) as Node2D
		var b := route.get_node(route.end_point) as Node2D
		neighbors[a].append(b)
		neighbors[b].append(a)
		_check(route.to_global(route.curve.get_point_position(0)).is_equal_approx(a.global_position), "route start meets marker center")
		_check(route.to_global(route.curve.get_point_position(route.curve.point_count - 1)).is_equal_approx(b.global_position), "route end meets marker center")
		_check(route.curve.get_baked_length() > 0, "route has visible geometry")
	var visited: Dictionary = {}
	var pending: Array = [points.get_child(0)]
	while not pending.is_empty():
		var point: Node2D = pending.pop_back()
		if visited.has(point):
			continue
		visited[point] = true
		pending.append_array(neighbors[point])
	_check(visited.size() == 38, "no disconnected islands or accidental missing joins")
	var first: MapRoute = routes.get_child(0)
	var marker := first.get_node(first.start_point) as Node2D
	var original := marker.position
	var middle := first.curve.get_point_position(1)
	marker.position += Vector2(20, 10)
	first.sync_endpoints()
	_check(first.to_global(first.curve.get_point_position(0)).is_equal_approx(marker.global_position), "editor marker adjustment updates route endpoint")
	_check(first.curve.get_point_position(1) == middle, "endpoint adjustment preserves interior curve editing")
	marker.position = original
	first.sync_endpoints()
	_check(is_equal_approx(screen.zoom_factor, 1.25), "default map magnification is 125 percent")
	_check(is_equal_approx(marker.global_scale.x, 0.224 * 1.25 * screen.size.x / 3220.0), "marker scales with width-based initial map view")
	var center := screen.size * 0.5
	var initial_position := content.position
	_button(MOUSE_BUTTON_LEFT, true, center)
	_motion(center + Vector2(80, 50), Vector2(80, 50), MOUSE_BUTTON_MASK_LEFT)
	_check(content.position.is_equal_approx(initial_position + Vector2(80, 50)), "native left drag pans map by pointer movement")
	_button(MOUSE_BUTTON_LEFT, false, center + Vector2(80, 50))
	_motion(center, Vector2(-80, -50), 0)
	_check(content.position.is_equal_approx(initial_position + Vector2(80, 50)), "released pointer no longer drags")
	var anchor := center + Vector2(50, -40)
	var anchored_point: Vector2 = (anchor - screen.map_viewport.position - content.position) / content.scale
	_button(MOUSE_BUTTON_WHEEL_UP, true, anchor)
	_check(screen.zoom_factor > 1.25, "wheel up enlarges map")
	_check(((anchor - screen.map_viewport.position - content.position) / content.scale).is_equal_approx(anchored_point), "zoom preserves location beneath pointer away from edges")
	_button(MOUSE_BUTTON_WHEEL_DOWN, true, anchor)
	_check(is_equal_approx(screen.zoom_factor, 1.25), "wheel down shrinks map")
	_button(MOUSE_BUTTON_LEFT, true, center)
	_motion(center + Vector2.ONE, Vector2(10000, 10000), MOUSE_BUTTON_MASK_LEFT)
	_check(content.position.is_equal_approx(Vector2.ZERO), "panning clamps at top left edge")
	_motion(center, Vector2(-20000, -20000), MOUSE_BUTTON_MASK_LEFT)
	_check(content.position.is_equal_approx(screen.map_viewport.size - Vector2(3220, 1830) * content.scale), "panning clamps at bottom right edge")
	_button(MOUSE_BUTTON_LEFT, false, center)
	for step in 20:
		_button(MOUSE_BUTTON_WHEEL_DOWN, true, center)
	_check(is_equal_approx(screen.zoom_factor, 1.0), "zoom stops at width-fit minimum")
	_check(is_zero_approx(content.position.x) and is_equal_approx(3220.0 * content.scale.x, screen.size.x), "minimum zoom fills width with no side bars")
	for step in 30:
		_button(MOUSE_BUTTON_WHEEL_UP, true, center)
	_check(is_equal_approx(screen.zoom_factor, 1.75), "zoom stops at 175 percent maximum")
	_button(MOUSE_BUTTON_LEFT, true, center)
	screen.notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	var stopped_position := content.position
	_motion(center + Vector2.ONE, Vector2(20, 20), MOUSE_BUTTON_MASK_LEFT)
	_check(content.position == stopped_position, "losing window focus cancels grab")
	_button(MOUSE_BUTTON_LEFT, false, center)
	_button(MOUSE_BUTTON_LEFT, true, center)
	_motion(center, Vector2(20, 20), 0)
	_check(content.position == stopped_position, "release outside window cannot leave a sticky grab")
	_button(MOUSE_BUTTON_LEFT, false, center)
	# Restore the authored opening view for visual captures at every aspect ratio.
	screen._zoom_at(1.25, center)
	content.position = screen.map_viewport.size * 0.5 - Vector2(3220, 1830) * content.scale * 0.5
	for dimensions in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(1280, 800), Vector2i(1720, 720)]:
		root.size = dimensions
		await _settle()
		var shown := Rect2(content.position, Vector2(3220, 1830) * content.scale)
		var fit := screen.size.x / 3220.0
		_check(is_equal_approx(content.scale.x, fit * 1.25), "opening view keeps 125 percent magnification across aspect ratios")
		_check(shown.get_center().is_equal_approx(screen.map_viewport.size * 0.5), "map stays centered")
		_check(is_equal_approx(content.scale.x, content.scale.y), "map geometry scales uniformly")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			_check(root.get_texture().get_image().save_png("res://artifacts/map_%dx%d.png" % [dimensions.x, dimensions.y]) == OK, "map render capture")
		screen._zoom_at(1.0, screen.size * 0.5)
		_check(is_zero_approx(content.position.x) and is_equal_approx(content.scale.x * 3220.0, screen.size.x), "100 percent has no side bars at every aspect ratio")
		# Even an attempted pan at minimum zoom cannot expose a side border.
		content.position.x += 100
		screen._clamp_position()
		_check(is_zero_approx(content.position.x), "minimum zoom horizontal pan stays within image")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			_check(root.get_texture().get_image().save_png("res://artifacts/map_min_%dx%d.png" % [dimensions.x, dimensions.y]) == OK, "minimum zoom render capture")
		screen._zoom_at(1.75, screen.size * 0.5)
		_check(is_equal_approx(content.scale.x * 3220.0, screen.size.x * 1.75), "maximum is 175 percent of screen width")
		screen._zoom_at(1.25, screen.size * 0.5)
		content.position = screen.map_viewport.size * 0.5 - Vector2(3220, 1830) * content.scale * 0.5
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1920, 1080)
		await _settle()
		screen._zoom_at(1.75, screen.size * 0.5)
		content.position = screen.map_viewport.size * 0.5 - east_exit.position * content.scale
		screen._clamp_position()
		await _settle()
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png("res://artifacts/map_east_end.png") == OK, "east endpoint and softened route shadow capture")
	screen.queue_free()
	await process_frame
	print("MAP RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

func _button(button: MouseButton, pressed: bool, position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT and pressed else 0
	root.push_input(event, true)

func _motion(position: Vector2, relative: Vector2, mask: int) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.relative = relative
	event.button_mask = mask
	root.push_input(event, true)

func _settle() -> void:
	for frame in 4:
		await process_frame

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)
