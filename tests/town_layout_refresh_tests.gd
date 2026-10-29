extends "res://tests/save_actions_tests.gd"
const TOWN := "base.map.qingshizhen"

func run() -> void:
	create_timer(50).timeout.connect(func(): quit(2))
	directory = "res://artifacts/town-layout-update/"
	DirAccess.make_dir_recursive_absolute(directory)
	Slots.auto_path = directory+"auto.json"
	Session.index_path = directory+"last.json"
	Session.clear_selection()
	root.get_node("SavePlaytime").set_process(false)
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1920,1080)
	var map = load("res://scenes/maps/qingshizhen.tscn").instantiate()
	map.inventory_save_path = directory+"working.json"
	map.defer_map_music = true
	map.defer_optional_views = true
	root.add_child(map)
	current_scene = map
	await settle()
	map.set_process(false)
	check(map.startup_error.is_empty(),"updated town starts")
	var points: Node2D = map.content.get_node("Points")
	var routes: Node2D = map.content.get_node("Routes")
	check(points.get_child_count()==30 and routes.get_child_count()==40,"30 nodes and 40 routes")
	check(not points.has_node("N21") and points.has_node("N18/Sign"),"only removed board is gone")
	check(not routes.has_node("R26_N18_N21") and not routes.has_node("R30_N21_N26"),"both removed-board branches gone")
	check(map.content.get_node("Background").texture.get_size()==Vector2(3321,1867),"updated imported image dimensions")
	check(Vector2(map.definition.source_size[0],map.definition.source_size[1])==Vector2(3321,1867),"map coordinate extent matches image")
	for route: MapRoute in routes.get_children():
		check(route._get_configuration_warnings().is_empty(),"valid route endpoints")
		check(route.curve.get_point_position(0).distance_to(route.get_node(route.start_point).position)<0.01,"start aligned")
		check(route.curve.get_point_position(route.curve.point_count-1).distance_to(route.get_node(route.end_point).position)<0.01,"end aligned")
		check(route.light_color==Color("fff2af") and route.glow_color==Color("ffbf42"),"gold route style unchanged")
	var exploration_enabled: bool = map.travel.exploration_enabled
	map.travel.exploration_enabled = false
	for point: MapRoutePoint in points.get_children():
		check(point.point_id==map.travel.current_node_id or not map.travel.shortest_path(map.travel.current_node_id,point.point_id).is_empty(),"remaining node reachable")
	map.travel.exploration_enabled = exploration_enabled
	var original: Dictionary = map.loadout.snapshot()
	var saved := original.duplicate(true)
	saved.map_location = {"map_id":TOWN,"point_id":TOWN+".point.n21"}
	var fixture := directory+"retired-node.json"
	var file := FileAccess.open(fixture,FileAccess.WRITE)
	file.store_string(JSON.stringify(saved))
	file.close()
	var expected := {"map_id":TOWN,"point_id":TOWN+".point.n18"}
	var map_session = load("res://scripts/map/map_session_start.gd")
	check(map_session.saved_location(fixture)==expected,"session routing migrates removed stop")
	check(map.loadout.restore(saved).is_empty() and map.loadout.map_location==expected,"full snapshot migrates removed stop")
	map._restore_saved_location()
	check(map.travel.current_node_id==expected.point_id and map.player.position.distance_to(points.get_node("N18").position)<0.01,"restored player lands on neighbouring board")
	check(saved.map_location.point_id==TOWN+".point.n21","migration does not mutate source snapshot")
	check(MapLoadoutState.normalized_map_location(original.get("map_location",{}))==original.get("map_location",{}),"other locations unchanged")
	var catalog = preload("res://scripts/map/world_map_catalog.gd").new()
	check(catalog._points_by_map[TOWN].size()==30 and not catalog._points_by_map[TOWN].has(TOWN+".point.n21"),"exploration denominator excludes removed stop")
	var progress: Dictionary = catalog.region_progress(catalog.regions.keys()[0],{TOWN:[TOWN+".point.n21",TOWN+".point.n18"]})
	check(progress.total==89 and progress.visited==1,"stale visit ignored in region progress")
	if DisplayServer.get_name()!="headless":
		# Static layout review only: reveal artwork without travel or input events.
		for point: MapRoutePoint in points.get_children(): point.present_exploration(true,true)
		for route: MapRoute in routes.get_children(): route.present_exploration(true,false,false,72)
		map.sign_motion.set_process(false)
		map.content.scale = Vector2.ONE*minf(map.map_viewport.size.x/3321.0,map.map_viewport.size.y/1867.0)
		map.content.position = (map.map_viewport.size-Vector2(3321,1867)*map.content.scale)*0.5
		await capture("town-overview")
		map.content.scale = Vector2.ONE*1.5
		map.content.position = map.map_viewport.size*0.5-Vector2(1700,1170)*1.5
		await capture("town-board-area")
	Meta.stop()
	map.deactivate_location()
	map.queue_free()
	await settle()
	print("TOWN_REFRESH: %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)
