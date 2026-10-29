extends SceneTree

var checks := 0
var failures := 0
var save_path := "res://artifacts/exploration-%d.json" % Time.get_ticks_usec()
const PREFIX := "base.map.qingshihewan.point."
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func settle() -> void:
	for i in 8: await process_frame
func make_map(scene_path := "res://scenes/maps/qingshihewan.tscn") -> Node:
	var map = load(scene_path).instantiate()
	map.inventory_save_path = save_path
	map.defer_map_music = true
	root.add_child(map)
	map.set_process(false)
	await settle()
	check(map.startup_error.is_empty(), "actual map starts: " + map.startup_error)
	return map
func capture(map: Node, suffix: String) -> void:
	if DisplayServer.get_name() == "headless": return
	# Frame the current player area without moving the OS cursor.
	map.player.present(map.travel)
	map.content.position = map.map_viewport.size * 0.5 - map.travel.map_position * map.content.scale
	map._clamp_position()
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/exploration-%s.png" % suffix)
func verify_presentation(map: Node) -> void:
	for point: MapRoutePoint in map.content.get_node("Points").get_children():
		check(point.visible == map.exploration.revealed.has(point.point_id), "node visible exactly when revealed")
		if point.visible: check((point.material == null) == map.exploration.visited.has(point.point_id), "only frontier node gets grayscale material")
		var sign := point.get_node_or_null("Sign") as CanvasItem
		if sign != null:
			check(sign.material == null and not sign.use_parent_material, "sign keeps original colors")
			if not point.visible: check(not sign.is_visible_in_tree(), "hidden node hides sign")
	for route: MapRoute in map.content.get_node("Routes").get_children():
		if route.exploration_full:
			check(route.display_spans() == [Vector2(0, route.curve.get_baked_length())], "revealed connection fully drawn")
		else:
			var spans := route.display_spans()
			check(route.visible == not spans.is_empty(), "only frontier outgoing stubs visible")
			for span: Vector2 in spans: check(span.y - span.x <= 72.01 and span.y - span.x < route.curve.get_baked_length() * 0.23, "short clipped hint")
func run() -> void:
	create_timer(50).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(2560,1440)
	var map := await make_map()
	check(map.exploration.visited.keys() == [PREFIX + "east_exit"], "first arrival only visited node")
	check(map.exploration.revealed.size() == 2 and map.exploration.revealed.has(PREFIX + "n15"), "first frontier uses actual topology")
	check(map.exploration.full_routes.size() == 1, "arrival connecting route remains full")
	verify_presentation(map)
	var hidden_point: Vector2 = map.travel.node_positions[PREFIX + "n14"]
	map.content.position = map.map_viewport.size * 0.5 - hidden_point * map.content.scale
	var pointer: Vector2 = map.map_to_screen(hidden_point)
	check(map._node_at(pointer).is_empty(), "hidden node excluded from mouse hit test")
	map._select_destination(pointer)
	check(map.travel.mode == "idle", "hidden point click cannot move player")
	check(not map.travel.request_destination(PREFIX + "n14"), "travel command rejects hidden target")
	await capture(map, "initial")
	var next: Vector2 = map.map_to_screen(map.travel.node_positions[PREFIX + "n15"])
	check(map._node_at(next) == PREFIX + "n15", "frontier point still clickable")
	map._select_destination(next)
	check(map.travel.destination_id == PREFIX + "n15", "frontier click starts known path")
	map.travel.advance(100)
	await settle()
	check(map.exploration.visited.has(PREFIX + "n15"), "arrival promotes node before event logic")
	for edge: Dictionary in map.travel.adjacency[PREFIX + "n15"]:
		check(map.exploration.revealed.has(edge.to), "arrival expands each adjacent node")
	verify_presentation(map)
	await capture(map, "expanded")
	check(map.travel.request_destination(PREFIX + "n14"), "road node reachable")
	map.travel.advance(100)
	await settle()
	check(not map.chest_dialog.visible and map.exploration.revealed.has(PREFIX + "n39"), "road reveals chest without opening it")
	# Reaching an event node reveals its surroundings before opening its dialog.
	check(map.travel.request_destination(PREFIX + "n39"), "newly revealed chest node is reachable")
	map.travel.advance(100)
	await settle()
	check(map.exploration.visited.has(PREFIX + "n39") and map.chest_observation_dialog.visible, "arrival expands and opens chest observation")
	map._cancel_chest()
	var chest_id: String = map.event_registry.by_point[PREFIX + "n39"]
	map.event_state.completed[chest_id] = true
	map._sync_completed_signs()
	map._visit_exploration(PREFIX + "n39")
	check(not map.content.get_node("Points/N39/Sign").visible, "exploration refresh never resurrects completed signs")
	map.event_state.completed.erase(chest_id)
	map.sign_motion.restore(PREFIX + "n39")
	var before: Dictionary = map.loadout.map_visited.duplicate(true)
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	check(saved.map_visited == before, "new visits are immediately persisted")
	var record: Dictionary = map.loadout.snapshot()
	check(map.loadout.restore(record).is_empty() and map.loadout.map_visited == before, "inventory round trip retains exploration")
	var invalid: Dictionary = record.duplicate(true)
	invalid.map_visited = {"base.map.qingshihewan": [PREFIX + "n15", PREFIX + "n15"]}
	check(not map.loadout.restore(invalid).is_empty() and map.loadout.map_visited == before, "invalid duplicate record rejected atomically")
	var old: Dictionary = record.duplicate(true)
	old.erase("map_visited")
	var old_registry := ContentRegistry.new()
	check(old_registry.load_base_content(), "old-save isolated content loads")
	var isolated := MapLoadoutStore.create_state(old_registry, old_registry.get_board(map.loadout.board.id))
	var old_error: String = isolated.state.restore(old)
	check(old_error.is_empty() and isolated.state.map_visited.is_empty(), "old saves default to unexplored: " + old_error)
	map.queue_free()
	await settle()
	var town := await make_map("res://scenes/maps/qingshizhen.tscn")
	check(town.exploration != null and town.travel.exploration_enabled, "town uses progressive exploration")
	check(town.loadout.map_visited[PREFIX.trim_suffix(".point.")] == before[PREFIX.trim_suffix(".point.")], "town arrival preserves river visits")
	check(town.loadout.map_visited.get(town.definition.id, []) == [town.travel.current_node_id], "town records only actual arrival")
	before = town.loadout.map_visited.duplicate(true)
	verify_presentation(town)
	check(town.exploration.revealed.size()<31, "town does not expose unexplored nodes")
	town.queue_free()
	await settle()
	# New map instance reads disk only: equivalent to restarting the game.
	map = await make_map()
	check(map.loadout.map_visited == before and map.exploration.visited.has(PREFIX + "n15"), "return and fresh process restore visited colors")
	check(map.content.get_node("Points/N15").material == null, "restored visited node is original color")
	map.queue_free()
	await settle()
	check_known_paths()
	print("MAP EXPLORATION: %d checks; %d failures" % [checks, failures])
	quit(1 if failures else 0)
func check_known_paths() -> void:
	var points := {"a": Vector2(0,100), "b": Vector2(0,0), "c": Vector2(10,0)}
	var edges: Array[Dictionary] = []
	for pair in [["a","b"], ["a","c"], ["b","c"]]:
		var curve := Curve2D.new()
		curve.add_point(points[pair[0]])
		curve.add_point(points[pair[1]])
		edges.append({"id":pair[0]+pair[1], "from":pair[0], "to":pair[1], "curve":curve})
	var travel := MapTravelState.new()
	check(travel.configure(points,edges,"a",100,200).is_empty(), "synthetic route graph loads")
	var exploration := MapExplorationState.new()
	exploration.rebuild(travel.adjacency,["a"])
	travel.exploration_enabled = true
	travel.revealed_points = exploration.revealed
	travel.revealed_routes = exploration.full_routes
	check(travel.shortest_path("b","c").size() == 2, "navigation never shortcuts through frontier-only hidden route")
