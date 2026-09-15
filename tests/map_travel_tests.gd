extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	var points := {"a": Vector2(0, 0), "b": Vector2(100, 0), "c": Vector2(200, 0), "d": Vector2(300, 0), "e": Vector2(400, 0), "f": Vector2(500, 0)}
	var edges: Array[Dictionary] = []
	var ids := ["a", "b", "c", "d", "e", "f"]
	for i in 5:
		edges.append(_edge(ids[i], ids[i + 1], [points[ids[i]], points[ids[i + 1]]]))
	var state := _state(points, edges)
	_check(state.mode == "idle" and state.map_position == Vector2.ZERO, "starts idle on start point")
	state.request_destination("c")
	_check(state.mode == "walk" and state.journey_node_count == 2, "two nodes excluding start uses walk")
	state.advance(0.5)
	_check(state.map_position.is_equal_approx(Vector2(50, 0)), "walk uses 100 source pixels per second")
	state.advance(1.5)
	_check(state.mode == "idle" and state.current_node_id == "c", "walk lands precisely and idles")
	state = _state(points, edges)
	state.request_destination("d")
	_check(state.mode == "run" and state.journey_node_count == 3, "three nodes excluding start uses run")
	state.advance(100.0 / 180.0)
	_check(state.current_node_id == "b" and state.mode == "run", "run remains run with two nodes remaining")
	state = _state(points, edges)
	state.request_destination("e")
	_check(state.mode == "run" and state.journey_node_count == 4, "four nodes excluding start uses run")
	state.advance(100.0 / 180.0)
	_check(state.current_node_id == "b" and state.mode == "run", "run stays run with only three nodes remaining")
	state.request_destination("e")
	_check(state.pending_destination_id.is_empty() and state.mode == "run", "same destination does not restart journey")
	state.advance(300.0 / 180.0)
	_check(state.current_node_id == "e" and state.mode == "idle", "run arrives at 180 source pixels per second")
	state = _state(points, edges)
	state.request_destination("e")
	state.advance(50.0 / 180.0)
	state.request_destination("d")
	state.request_destination("c")
	state.advance(40.0 / 180.0)
	_check(state.current_node_id == "a" and state.map_position.is_equal_approx(Vector2(90, 0)) and state.mode == "run", "diversion waits for next node and keeps old speed")
	state.advance(10.0 / 180.0)
	_check(state.current_node_id == "b" and state.destination_id == "c" and state.mode == "walk", "latest request replans at node and uses new journey count")
	state.advance(1.0)
	_check(state.current_node_id == "c" and state.mode == "idle", "diversion finishes correctly")
	state = _state(points, edges)
	state.request_destination("f")
	state.advance(0.1)
	state.request_destination("b")
	state.advance(1.0)
	_check(state.current_node_id == "b" and state.mode == "idle", "request next node stops there")
	state = _state(points, edges)
	state.request_destination("f")
	state.advance(0.1)
	state.request_destination("a")
	state.advance((100.0 - 18.0) / 180.0 + 0.5)
	_check(state.current_node_id == "b" and state.map_position.is_equal_approx(Vector2(50, 0)), "return to start turns around only after next node")
	_check(not state.request_destination("missing"), "unknown destination is rejected")
	var other := _state(points, edges)
	state = _state(points, edges)
	state.request_destination("f")
	other.request_destination("f")
	state.advance(1.4)
	for i in 140:
		other.advance(0.01)
	_check(state.map_position.is_equal_approx(other.map_position) and state.current_node_id == other.current_node_id, "delta partition does not change travel result")
	var before := state.map_position
	state.advance(-1.0)
	_check(state.map_position == before, "negative delta cannot rewind travel")
	state.advance(1000)
	_check(state.current_node_id == "f" and state.mode == "idle", "large delta crosses several nodes without overshoot")
	# One direct edge is geometrically longer than the four-edge route.
	var detour := _edge("a", "e", [Vector2.ZERO, Vector2(0, 500), Vector2(400, 500), Vector2(400, 0)])
	var with_detour: Array[Dictionary] = edges.duplicate()
	with_detour.append(detour)
	state = _state(points, with_detour)
	state.request_destination("e")
	_check(state.journey_node_count == 4 and state.mode == "run", "Dijkstra chooses shorter distance over fewer nodes")
	var bend_points := {"a": Vector2.ZERO, "b": Vector2(200, 0)}
	var bend := _edge("a", "b", [Vector2.ZERO, Vector2(100, 100), Vector2(200, 0)])
	state = _state(bend_points, [bend])
	state.request_destination("b")
	state.advance(bend.curve.get_baked_length() * 0.5 / 100.0)
	_check(state.map_position.distance_to(Vector2(100, 100)) < 1.0, "follows curve instead of straight node chord")
	state.advance(100)
	state.request_destination("a")
	state.advance(bend.curve.get_baked_length() * 0.5 / 100.0)
	_check(state.map_position.distance_to(Vector2(100, 100)) < 1.0, "reverse travel follows same curve")
	var disconnected := points.duplicate()
	disconnected["island"] = Vector2(999, 999)
	state = _state(disconnected, edges)
	_check(not state.request_destination("island") and state.mode == "idle", "unreachable target does not start motion")
	state.request_destination("a")
	_check(state.mode == "idle", "clicking occupied node remains idle")
	_check(not MapTravelState.new().configure(points, edges, "missing", 100, 180).is_empty(), "invalid start rejected before movement")
	print("MAP TRAVEL RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _state(points: Dictionary, edges: Array[Dictionary]) -> MapTravelState:
	var state := MapTravelState.new()
	_check(state.configure(points, edges, "a", 100, 180).is_empty(), "valid graph configuration")
	return state

func _edge(a: String, b: String, points: Array) -> Dictionary:
	var curve := Curve2D.new()
	curve.bake_interval = 1
	for p: Vector2 in points:
		curve.add_point(p)
	return {"id": a + "_" + b, "from": a, "to": b, "curve": curve}

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
