class_name MapTravelState
extends RefCounted

# Curves and coordinates are detached content data. No Nodes or wall-clock access.
var node_positions: Dictionary = {}
var adjacency: Dictionary = {}
var current_node_id := ""
var destination_id := ""
var pending_destination_id := ""
var map_position := Vector2.ZERO
var mode := "idle"
var journey_node_count := 0
var walk_speed := 100.0
var run_speed := 180.0
var _path: Array[Dictionary] = []
var _edge_index := 0
var _edge_distance := 0.0

func configure(points: Dictionary, edges: Array[Dictionary], start_id: String, walk: float, run: float) -> String:
	if not points.has(start_id) or walk <= 0 or run <= 0:
		return "地图玩家起点或移动速度无效。"
	node_positions = points.duplicate()
	adjacency.clear()
	for id in points:
		if not points[id] is Vector2:
			return "地图节点坐标无效。"
		adjacency[id] = []
	var edge_ids := {}
	for edge in edges:
		if not edge.has_all(["id", "from", "to", "curve"]):
			return "地图路线字段不完整。"
		if edge_ids.has(edge.id) or not points.has(edge.from) or not points.has(edge.to) or not edge.curve is Curve2D:
			return "地图路线ID、连接或曲线无效。"
		edge_ids[edge.id] = true
		var curve: Curve2D = edge.curve.duplicate()
		if curve.point_count < 2 or curve.get_baked_length() <= 0:
			return "地图路线长度无效。"
		if not curve.get_point_position(0).is_equal_approx(points[edge.from]) or not curve.get_point_position(curve.point_count - 1).is_equal_approx(points[edge.to]):
			return "地图路线端点与节点不吻合。"
		var forward := {"id": edge.id, "from": edge.from, "to": edge.to, "curve": curve, "reverse": false, "length": curve.get_baked_length()}
		var backward := forward.duplicate()
		backward.from = edge.to
		backward.to = edge.from
		backward.reverse = true
		adjacency[edge.from].append(forward)
		adjacency[edge.to].append(backward)
	for id in adjacency:
		adjacency[id].sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
	walk_speed = walk
	run_speed = run
	current_node_id = start_id
	destination_id = start_id
	map_position = points[start_id]
	pending_destination_id = ""
	mode = "idle"
	_path.clear()
	journey_node_count = 0
	return ""

func shortest_path(start_id: String, target_id: String) -> Array[Dictionary]:
	if not node_positions.has(start_id) or not node_positions.has(target_id) or start_id == target_id:
		return []
	var distances := {start_id: 0.0}
	var previous := {}
	var open: Array = node_positions.keys()
	open.sort()
	while not open.is_empty():
		var nearest := -1
		var best := INF
		for i in open.size():
			var distance: float = distances.get(open[i], INF)
			if distance < best:
				best = distance
				nearest = i
		if nearest < 0:
			break
		var node: String = open[nearest]
		open.remove_at(nearest)
		if node == target_id:
			break
		for edge: Dictionary in adjacency[node]:
			var candidate: float = best + edge.length
			if candidate < float(distances.get(edge.to, INF)):
				distances[edge.to] = candidate
				previous[edge.to] = edge
	if not previous.has(target_id):
		return []
	var result: Array[Dictionary] = []
	var cursor := target_id
	while cursor != start_id:
		var edge: Dictionary = previous[cursor]
		result.push_front(edge)
		cursor = edge.from
	return result

func request_destination(target_id: String) -> bool:
	if not node_positions.has(target_id):
		return false
	if mode != "idle":
		# Repeating the existing destination cancels a pending diversion, without
		# restarting this journey or changing its chosen animation midway.
		pending_destination_id = "" if target_id == destination_id else target_id
		return true
	return _plan(target_id)

func _plan(target_id: String) -> bool:
	var next_path := shortest_path(current_node_id, target_id)
	if target_id != current_node_id and next_path.is_empty():
		return false
	_path = next_path
	_edge_index = 0
	_edge_distance = 0.0
	destination_id = target_id
	journey_node_count = _path.size()
	mode = "idle" if _path.is_empty() else ("walk" if journey_node_count <= 2 else "run")
	return true

func advance(delta: float) -> void:
	var remaining := maxf(delta, 0.0)
	while remaining > 0 and mode != "idle":
		var edge := _path[_edge_index]
		var speed := run_speed if mode == "run" else walk_speed
		var time_to_node: float = (edge.length - _edge_distance) / speed
		if remaining + 0.000000001 < time_to_node:
			_edge_distance += remaining * speed
			var offset: float = edge.length - _edge_distance if edge.reverse else _edge_distance
			map_position = edge.curve.sample_baked(offset)
			return
		remaining = maxf(remaining - time_to_node, 0.0)
		current_node_id = edge.to
		map_position = node_positions[current_node_id]
		_edge_index += 1
		_edge_distance = 0.0
		if not pending_destination_id.is_empty():
			var next_target := pending_destination_id
			pending_destination_id = ""
			mode = "idle"
			_plan(next_target)
		elif _edge_index >= _path.size():
			mode = "idle"
