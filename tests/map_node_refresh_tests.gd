extends "res://tests/save_actions_tests.gd"
var route_draws := 0

func render_frame() -> void:
	await process_frame
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw

func run() -> void:
	create_timer(55).timeout.connect(func(): quit(2))
	directory = "res://artifacts/map-node-refresh/run-%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	Slots.auto_path = directory+"auto.json"
	Session.index_path = directory+"session.json"
	Session.clear_selection()
	root.get_node("SavePlaytime").set_process(false)
	root.get_node("GameSettings").apply_values({"background_pause":false})
	root.get_node("GameSettings").set_application_focus(true)
	AudioServer.set_bus_mute(0,true)
	var map = load("res://scenes/maps/qingshizhen.tscn").instantiate()
	map.inventory_save_path = Slots.working_path()
	map.defer_map_music = true
	map.defer_optional_views = true
	root.add_child(map)
	current_scene = map
	await settle()
	map.set_process(false)
	check(map.startup_error.is_empty(),"isolated map starts")
	for route in map.content.get_node("Routes").get_children():
		route.draw.connect(func(): route_draws += 1)
	# Newly discovered point still updates the frontier and persists the visit.
	var point: String = map.definition.id+".point.n03"
	map.loadout.map_visited[map.definition.id] = []
	map._exploration_presented = false
	map._visit_exploration(map.travel.current_node_id)
	await render_frame()
	route_draws = 0
	map.loadout.set_map_location(map.definition.id,point)
	map._visit_exploration(point)
	map._save_location()
	await render_frame()
	check(map.exploration.visited.has(point),"new arrival recorded")
	for edge: Dictionary in map.travel.adjacency[point]:
		check(map.exploration.revealed.has(edge.to) and map.exploration.full_routes.has(edge.id),"new point reveals its frontier")
	if DisplayServer.get_name()!="headless":
		check(route_draws>0 and route_draws<map.content.get_node("Routes").get_child_count(),"discovery redraws only changed routes")
	check(Files.read(map.inventory_save_path).map_location.point_id==point and point in Files.read(map.inventory_save_path).map_visited[map.definition.id],"position and exploration still save immediately")
	route_draws = 0
	map._visit_exploration(point)
	await render_frame()
	check(route_draws==0,"revisiting point redraws no routes")
	map.loadout.map_visited[map.definition.id] = [point]
	map._visit_exploration(point)
	check(map.exploration.visited.size()==1,"restored exploration facts invalidate the cache even at an already visited point")
	# A complete explored route must flow through intermediate nodes normally.
	map.loadout.map_visited[map.definition.id] = map.travel.node_positions.keys()
	map._exploration_presented = false
	map._visit_exploration(point)
	await render_frame()
	map.travel.current_node_id = point
	map.travel.map_position = map.travel.node_positions[point]
	map.travel.stop_at_current_node()
	var target := ""
	var path: Array = []
	for candidate: String in map.travel.node_positions:
		var route: Array = map.travel.shortest_path(point,candidate)
		if route.size()<2: continue
		if route.any(func(edge): return map.exits_by_point.has(edge.to) or edge.to==QuestStory.data.shop.point_id): continue
		target = candidate
		path = route
		break
	check(not target.is_empty() and map.travel.request_destination(target),"multi-node route selected")
	var arrivals := []
	map.travel.node_arrived.connect(func(id: String): arrivals.append(id))
	route_draws = 0
	var steps := 0
	while map.travel.mode!="idle" and steps<10000:
		map.travel.advance(1.0/60)
		steps += 1
	await render_frame()
	check(map.travel.current_node_id==target and arrivals.size()==path.size() and not map.event_state.is_active(),"continuous movement crosses every intermediate node without an artificial stop")
	check(route_draws==0,"explored journey does not rebuild route drawings")
	check(Files.read(map.inventory_save_path).map_location.point_id==target,"final position committed")
	# The redraw optimization must not suppress a real quest arrival trigger.
	map.travel.current_node_id = QuestStory.data.shop.point_id
	map.travel.map_position = map.travel.node_positions[QuestStory.data.shop.point_id]
	map.travel.stop_at_current_node()
	map._on_node_arrived(QuestStory.data.shop.point_id)
	check(QuestStory.story(map.loadout).active=="morning" and map.event_state.phase=="dialogue","shop story arrival still pauses movement")
	Meta.stop()
	map.deactivate_location()
	map.free()
	print("MAP_NODE_REFRESH: %d checks; %d failures" % [checks,failures])
	print("OUTPUT: "+directory)
	quit(1 if failures else 0)
