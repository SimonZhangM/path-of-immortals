@tool
class_name MapRoute
extends Path2D

@export var route_id: String = ""
@export_node_path("Node2D") var start_point: NodePath
@export_node_path("Node2D") var end_point: NodePath
@export_range(8.0, 40.0, 1.0) var dash_spacing: float = 18.0:
	set(value):
		dash_spacing = value
		queue_redraw()
@export_range(2.0, 16.0, 0.5) var dash_length: float = 6.0:
	set(value):
		dash_length = value
		queue_redraw()
@export_range(1.0, 8.0, 0.5) var line_width: float = 4.0:
	set(value):
		line_width = value
		queue_redraw()
@export var light_color := Color("fff2af"):
	set(value):
		light_color = value
		queue_redraw()
@export var glow_color := Color("ffbf42"):
	set(value):
		glow_color = value
		queue_redraw()
@export var shadow_color := Color(0.10, 0.065, 0.035, 0.42):
	set(value):
		shadow_color = value
		queue_redraw()
@export_range(0.0, 16.0, 0.5) var shadow_width := 5.0:
	set(value):
		shadow_width = value
		queue_redraw()
var _connected_curve: Curve2D
var exploration_full := true
var exploration_hint_start := false
var exploration_hint_end := false
var exploration_hint_length := 72.0

func present_exploration(full: bool, from_start: bool, from_end: bool, hint_length: float) -> void:
	exploration_full = full
	exploration_hint_start = from_start and not full
	exploration_hint_end = from_end and not full
	exploration_hint_length = hint_length
	visible = full or from_start or from_end
	queue_redraw()

func display_spans() -> Array[Vector2]:
	var length := curve.get_baked_length() if curve != null else 0.0
	if exploration_full: return [Vector2(0, length)]
	# Even on short routes, two frontier hints must not meet in the middle.
	var hint := minf(exploration_hint_length, length * 0.22)
	var spans: Array[Vector2] = []
	if exploration_hint_start: spans.append(Vector2(0, hint))
	if exploration_hint_end: spans.append(Vector2(length - hint, length))
	return spans

func _ready() -> void:
	_watch_curve()
	sync_endpoints()
	set_process(Engine.is_editor_hint())

func _process(_delta: float) -> void:
	_watch_curve()
	sync_endpoints()

func _watch_curve() -> void:
	if _connected_curve == curve:
		return
	if _connected_curve != null and _connected_curve.changed.is_connected(queue_redraw):
		_connected_curve.changed.disconnect(queue_redraw)
	_connected_curve = curve
	if curve != null:
		curve.changed.connect(queue_redraw)
	queue_redraw()

func sync_endpoints() -> void:
	if curve == null or curve.point_count < 2:
		return
	for endpoint in [[start_point, 0], [end_point, curve.point_count - 1]]:
		var marker := get_node_or_null(endpoint[0]) as Node2D
		if marker == null:
			continue
		var position_in_route := to_local(marker.global_position)
		if not curve.get_point_position(endpoint[1]).is_equal_approx(position_in_route):
			curve.set_point_position(endpoint[1], position_in_route)

func _draw() -> void:
	if curve == null or curve.point_count < 2:
		return
	for span in display_spans():
		_draw_span(span.x, span.y)

func _draw_span(begin: float, end: float) -> void:
	if not exploration_full:
		_draw_hint(begin, end)
		return
	var points := curve.get_baked_points()
	if points.size() < 2:
		return
	var glow := glow_color
	var light := light_color
	# Layered translucent strokes work in both editor and Mobile renderer;
	# no world-environment bloom or modifications to the map bitmap required.
	var shadow_points := PackedVector2Array()
	for point in points:
		shadow_points.append(point + Vector2(0, 2))
	draw_polyline(shadow_points, shadow_color, line_width + shadow_width, true)
	draw_polyline(points, Color(glow, 0.08), line_width + 14, true)
	draw_polyline(points, Color(glow, 0.18), line_width + 6, true)
	draw_polyline(points, Color(glow, 0.28), line_width, true)
	var distance := begin
	while distance < end:
		var a := curve.sample_baked(distance)
		var b := curve.sample_baked(minf(distance + dash_length, end))
		draw_line(a, b, Color(glow, 0.38), line_width + 5, true)
		draw_line(a, b, light, line_width, true)
		draw_circle(a, line_width * 0.5, light, true, -1, true)
		draw_circle(b, line_width * 0.5, light, true, -1, true)
		distance += dash_spacing

static func hint_profile(progress: float) -> Vector2:
	# Keep the node end crisp, then diffuse the core as every layer fades to zero.
	var fade := 1.0 - smoothstep(0.22, 1.0, progress)
	var blur := smoothstep(0.18, 0.90, progress)
	return Vector2(fade, blur)

func _draw_hint(begin: float, end: float) -> void:
	var length := end - begin
	if length <= 0: return
	var from_start := is_zero_approx(begin)
	# Profiles are measured away from the visible node, including reverse curves.
	_draw_hint_piece(begin, end, 0, length, from_start, false)
	var offset := 0.0
	while offset < length:
		_draw_hint_piece(begin, end, offset, minf(offset + dash_length, length), from_start, true)
		offset += dash_spacing

func _draw_hint_piece(begin: float, end: float, first: float, last: float, from_start: bool, dashed: bool) -> void:
	var points := PackedVector2Array()
	var soft_colors := PackedColorArray()
	var middle_colors := PackedColorArray()
	var core_colors := PackedColorArray()
	var shadows := PackedColorArray()
	var shadow_points := PackedVector2Array()
	var offset := first
	while true:
		var point := curve.sample_baked(begin + offset if from_start else end - offset)
		var profile := hint_profile(offset / (end - begin))
		points.append(point)
		shadow_points.append(point + Vector2(0, 2))
		soft_colors.append(Color(Color("b8c0c4"), profile.x * (0.06 + 0.10 * profile.y)))
		middle_colors.append(Color(Color("c9d0d4"), profile.x * (0.26 if dashed else 0.10)))
		core_colors.append(Color(Color("dce1e3"), profile.x * (1.0 - profile.y) * (1.0 if dashed else 0.16)))
		shadows.append(Color(shadow_color, shadow_color.a * profile.x * (1.0 - profile.y)))
		if offset >= last: break
		offset = minf(offset + 1.5, last)
	if points.size() < 2: return
	if not dashed: draw_polyline_colors(shadow_points, shadows, line_width + shadow_width, true)
	draw_polyline_colors(points, soft_colors, line_width + 12, true)
	draw_polyline_colors(points, middle_colors, line_width + 5, true)
	draw_polyline_colors(points, core_colors, line_width, true)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if route_id.is_empty():
		warnings.append("请填写稳定的Route Id。")
	if curve == null or curve.point_count < 2:
		warnings.append("路线至少需要两个Curve2D控制点。")
	if get_node_or_null(start_point) == null or get_node_or_null(end_point) == null:
		warnings.append("请将Start Point和End Point关联到Points下的节点。")
	return warnings
