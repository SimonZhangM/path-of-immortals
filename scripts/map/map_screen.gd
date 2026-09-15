@tool
extends Control

const MIN_ZOOM := 1.0
const MAX_ZOOM := 1.75
const ZOOM_STEP := 1.1

@export_file("*.json") var definition_path := "res://data/maps/qingshihewan.json"
var definition: Dictionary = {}
var startup_error: String = ""
var zoom_factor := 1.25
var _dragging := false
var _pointer_down := false
var _press_position := Vector2.ZERO
var _drag_delta := Vector2.ZERO
var _suppress_click := false
var _cursor_position := Vector2(-1, -1)
var travel: MapTravelState
var player: MapPlayer
var event_registry: MapEventRegistry
var event_state: MapEventState
var dialogue: MapDialogue
var _last_view_size := Vector2.ZERO
@onready var content: Node2D = $MapContent

func _ready() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(definition_path))
	if not raw is Dictionary or not raw.has("source_size") or raw["source_size"].size() != 2:
		startup_error = "地图元信息无效：" + definition_path
		push_error(startup_error)
		return
	definition = raw
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	mouse_exited.connect(_clear_hover)
	resized.connect(_fit_map)
	_fit_map()
	if not Engine.is_editor_hint():
		_setup_player()
		if startup_error.is_empty():
			_setup_events()

func _setup_events() -> void:
	var files: Variant = definition.get("event_files", [])
	if not files is Array:
		startup_error = "地图事件文件列表无效。"
		push_error(startup_error)
		return
	event_registry = MapEventRegistry.new()
	startup_error = event_registry.load_files(files, travel.node_positions.keys())
	if not startup_error.is_empty():
		push_error(startup_error)
		return
	dialogue = MapDialogue.new()
	startup_error = dialogue.prepare(event_registry)
	if not startup_error.is_empty():
		push_error(startup_error)
		dialogue.free()
		dialogue = null
		return
	event_state = MapEventState.new(event_registry)
	add_child(dialogue)
	dialogue.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialogue.advance_requested.connect(_advance_dialogue)
	_sync_completed_signs()

func _sync_completed_signs() -> void:
	for point: MapRoutePoint in content.get_node("Points").get_children():
		var event_id: String = event_registry.by_point.get(point.point_id, "")
		if event_state.completed.has(event_id) and point.has_node("Sign"):
			point.get_node("Sign").hide()

func _advance_dialogue() -> void:
	if event_state == null or not event_state.is_active():
		return
	var completed_id := event_state.advance()
	if not completed_id.is_empty():
		dialogue.hide()
		_sync_completed_signs()
		_end_drag()
		_clear_hover()
	else:
		dialogue.present(event_state.active_event(), event_state.current_line(), event_state.current_speaker_id(), event_state.phase)

func _setup_player() -> void:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/player.json"))
	var positions := {}
	for point: MapRoutePoint in content.get_node("Points").get_children():
		positions[point.point_id] = content.to_local(point.global_position)
	var edges: Array[Dictionary] = []
	for route: MapRoute in content.get_node("Routes").get_children():
		route.sync_endpoints()
		var curve := Curve2D.new()
		curve.bake_interval = route.curve.bake_interval
		for i in route.curve.point_count:
			var p := route.curve.get_point_position(i)
			var mapped := content.to_local(route.to_global(p))
			var incoming := content.to_local(route.to_global(p + route.curve.get_point_in(i))) - mapped
			var outgoing := content.to_local(route.to_global(p + route.curve.get_point_out(i))) - mapped
			curve.add_point(mapped, incoming, outgoing)
		edges.append({"id": route.route_id, "from": route.get_node(route.start_point).point_id, "to": route.get_node(route.end_point).point_id, "curve": curve})
	travel = MapTravelState.new()
	startup_error = travel.configure(positions, edges, config.start_point, config.walk_speed, config.run_speed)
	if not startup_error.is_empty():
		push_error(startup_error)
		travel = null
		return
	player = MapPlayer.new()
	player.name = "MapPlayer"
	startup_error = player.configure(config)
	if not startup_error.is_empty():
		push_error(startup_error)
		player.free()
		player = null
		travel = null
		return
	content.add_child(player)
	player.position = travel.map_position
	# Start with the player visible. Subsequent camera movement stays manual.
	content.position = size * 0.5 - player.position * content.scale
	_clamp_position()

func _process(delta: float) -> void:
	if travel != null and player != null:
		if event_state == null or not event_state.is_active():
			travel.advance(delta)
		player.present(travel)

func _select_destination(pointer: Vector2) -> void:
	if travel == null or (event_state != null and event_state.is_active()):
		return
	var closest_id := _node_at(pointer)
	if not closest_id.is_empty():
		if event_state != null and event_state.try_start(closest_id, travel.current_node_id, travel.mode == "idle"):
			_end_drag()
			_clear_hover()
			dialogue.present(event_state.active_event(), event_state.current_line(), event_state.current_speaker_id(), event_state.phase)
			return
		travel.request_destination(closest_id)
		player.present(travel)

func _node_at(pointer: Vector2) -> String:
	if not is_instance_valid(content) or not Rect2(Vector2.ZERO, size).has_point(pointer):
		return ""
	var closest_id := ""
	var closest_distance := INF
	# Constant minimum hit target, expanding with the drawn marker when zoomed.
	var radius := maxf(18.0, 22.4 * content.scale.x + 4.0)
	for point: MapRoutePoint in content.get_node("Points").get_children():
		var screen_position := content.position + content.to_local(point.global_position) * content.scale
		var distance := pointer.distance_to(screen_position)
		if distance <= radius and distance < closest_distance:
			closest_id = point.point_id
			closest_distance = distance
	return closest_id

func _refresh_cursor() -> void:
	if event_state != null and event_state.is_active():
		mouse_default_cursor_shape = Control.CURSOR_ARROW
	elif _dragging:
		mouse_default_cursor_shape = Control.CURSOR_MOVE
	else:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not _node_at(_cursor_position).is_empty() else Control.CURSOR_ARROW

func _clear_hover() -> void:
	_cursor_position = Vector2(-1, -1)
	_refresh_cursor()

func _source_size() -> Vector2:
	return Vector2(definition["source_size"][0], definition["source_size"][1])

func _fit_scale() -> float:
	# 100% means the image width exactly fills the viewport.
	return size.x / _source_size().x

func _fit_map() -> void:
	if definition.is_empty() or size.x <= 0 or size.y <= 0:
		return
	var focus := _source_size() * 0.5
	if _last_view_size != Vector2.ZERO:
		focus = (_last_view_size * 0.5 - content.position) / content.scale
	content.scale = Vector2.ONE * _fit_scale() * zoom_factor
	content.position = size * 0.5 - focus * content.scale
	_last_view_size = size
	_clamp_position()

func _clamp_position() -> void:
	var extent := _source_size() * content.scale
	for axis in 2:
		if extent[axis] <= size[axis]:
			content.position[axis] = (size[axis] - extent[axis]) * 0.5
		else:
			content.position[axis] = clampf(content.position[axis], size[axis] - extent[axis], 0.0)
	_refresh_cursor()

func _zoom_at(factor: float, anchor: Vector2) -> void:
	var next_zoom := clampf(factor, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(next_zoom, zoom_factor):
		return
	var map_position := (anchor - content.position) / content.scale
	zoom_factor = next_zoom
	content.scale = Vector2.ONE * _fit_scale() * zoom_factor
	content.position = anchor - map_position * content.scale
	_clamp_position()

func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or definition.is_empty():
		return
	if event_state != null and event_state.is_active():
		accept_event()
		return
	if event is InputEventMouse:
		_cursor_position = event.position
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_pointer_down = true
				_dragging = false
				_suppress_click = false
				_press_position = event.position
				_drag_delta = Vector2.ZERO
			else:
				if _pointer_down and not _dragging and not _suppress_click and event.position.distance_to(_press_position) <= 6.0:
					_select_destination(event.position)
				_end_drag()
			accept_event()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP]:
			_suppress_click = true
			var direction := 1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
			_zoom_at(zoom_factor * pow(ZOOM_STEP, direction), event.position)
			accept_event()
	elif event is InputEventMouseMotion and _pointer_down:
		# Also recover if the mouse was released outside the game window.
		if (event.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			_end_drag()
			return
		if not _dragging:
			_drag_delta += event.relative
			if _drag_delta.length() <= 6.0:
				_refresh_cursor()
				return
			_dragging = true
			mouse_default_cursor_shape = Control.CURSOR_MOVE
			content.position += _drag_delta
		else:
			content.position += event.relative
		_clamp_position()
		accept_event()
	_refresh_cursor()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_end_drag()
		_clear_hover()

func _end_drag() -> void:
	_dragging = false
	_pointer_down = false
	_refresh_cursor()
