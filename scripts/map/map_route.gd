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
	var points := curve.get_baked_points()
	if points.size() < 2:
		return
	# Layered translucent strokes work in both editor and Mobile renderer;
	# no world-environment bloom or modifications to the map bitmap required.
	var shadow_points := PackedVector2Array()
	for point in points:
		shadow_points.append(point + Vector2(0, 2))
	draw_polyline(shadow_points, shadow_color, line_width + shadow_width, true)
	draw_polyline(points, Color(glow_color, 0.08), line_width + 14, true)
	draw_polyline(points, Color(glow_color, 0.18), line_width + 6, true)
	draw_polyline(points, Color(glow_color, 0.28), line_width, true)
	var length := curve.get_baked_length()
	var distance := 0.0
	while distance < length:
		var a := curve.sample_baked(distance)
		var b := curve.sample_baked(minf(distance + dash_length, length))
		draw_line(a, b, Color(glow_color, 0.38), line_width + 5, true)
		draw_line(a, b, light_color, line_width, true)
		draw_circle(a, line_width * 0.5, light_color, true, -1, true)
		draw_circle(b, line_width * 0.5, light_color, true, -1, true)
		distance += dash_spacing

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if route_id.is_empty():
		warnings.append("请填写稳定的Route Id。")
	if curve == null or curve.point_count < 2:
		warnings.append("路线至少需要两个Curve2D控制点。")
	if get_node_or_null(start_point) == null or get_node_or_null(end_point) == null:
		warnings.append("请将Start Point和End Point关联到Points下的节点。")
	return warnings
