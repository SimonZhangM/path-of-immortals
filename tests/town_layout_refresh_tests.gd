extends "res://tests/save_actions_tests.gd"
const TOWN := "base.map.qingshizhen"

func run() -> void:
	create_timer(50).timeout.connect(func(): quit(2))
	directory = "res://artifacts/town-node-rework-20261031/run-%d/" % Time.get_ticks_usec()
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
	check(points.get_child_count()==31 and routes.get_child_count()==42,"31 nodes and 42 routes")
	check(not points.has_node("N12") and points.has_node("N32/Sign") and points.has_node("N33"),"old alchemy removed and clinic/junction added")
	for route_name in ["R08_N06_N12","R09_N06_N17","R17_N12_N14","R18_N12_N22"]:
		check(not routes.has_node(route_name),"removed old courtyard branch or crossing diagonal")
	for pair in [["n08","n32","r43"],["n11","n32","r44"],["n32","n33","r45"],["n06","n33","r46"],["n33","n14","r47"],["n33","n17","r48"]]:
		var matches: Array = map.travel.adjacency[TOWN+".point."+pair[0]].filter(func(edge):return edge.to==TOWN+".point."+pair[1] and edge.id==TOWN+".route."+pair[2])
		check(matches.size()==1,"marked route connects exact endpoints")
	check(map.travel.adjacency[TOWN+".point.n32"].size()==3 and map.travel.adjacency[TOWN+".point.n33"].size()==4,"clinic has three exits and junction has four including clinic")
	check(points.get_node("N23").position.distance_to(Vector2(2168.96,1354.63))<0.01 and points.get_node("N27").position.distance_to(Vector2(3066.57,1618.94))<0.01,"forge and shrine match red circles")
	check(points.get_node("N32").position.distance_to(Vector2(2090.9,650.24))<0.01 and points.get_node("N33").position.distance_to(Vector2(2275.48,821.12))<0.01,"new nodes match marked circles")
	check(points.get_node("N19").location_note=="炼丹房" and points.get_node("N32").location_note=="医馆","service names relocated")
	check(points.get_node("N19/Sign/LocationIcon").texture.atlas.resource_path.ends_with("map-liandan.webp") and points.get_node("N32/Sign/LocationIcon").texture.atlas.resource_path.ends_with("map-yiguan.webp"),"correct service sign icons")
	check(map.event_registry.by_point.get(TOWN+".point.n32")=="base.map_event.qingshizhen.clinic" and map.event_registry.by_point.get(TOWN+".point.n19")=="base.map_event.qingshizhen.alchemy","actual event bindings relocated")
	check(not points.has_node("N21") and points.has_node("N18/Sign"),"only removed board is gone")
	check(not routes.has_node("R26_N18_N21") and not routes.has_node("R30_N21_N26"),"both removed-board branches gone")
	check(map.content.get_node("Background").texture.get_size()==Vector2(3321,1862),"updated imported image dimensions")
	check(Vector2(map.definition.source_size[0],map.definition.source_size[1])==Vector2(3321,1862),"map coordinate extent matches image")
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
	# Exercise only the moved service entry commands, without treatment or trading.
	for service in [["n32","clinic"],["n19","alchemy"]]:
		var id: String = TOWN+".point."+service[0]
		map.travel.current_node_id = id
		map.travel.map_position = map.travel.node_positions[id]
		map.travel.stop_at_current_node()
		check(map._try_start_event(id,"click",true),"moved service entry opens")
		await settle()
		check(map.event_state.active_id=="base.map_event.qingshizhen."+service[1],"correct moved event active")
		if service[1]=="clinic":
			check(map.clinic_dialog.visible and map.clinic_dialog.title_label.text=="青石医馆","new clinic opens Su Qinghe interface")
			map._close_clinic()
		else:
			check(map.shop_dialog.visible and map.shop_dialog.title_label.text=="炼丹房","old clinic opens alchemy interface")
			map._close_shop()
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
	check(catalog._points_by_map[TOWN].size()==31 and not catalog._points_by_map[TOWN].has(TOWN+".point.n21") and not catalog._points_by_map[TOWN].has(TOWN+".point.n12"),"exploration denominator excludes removed stops")
	var progress: Dictionary = catalog.region_progress(catalog.regions.keys()[0],{TOWN:[TOWN+".point.n21",TOWN+".point.n18"]})
	check(progress.total==144 and progress.visited==1,"stale visit ignored in region progress")
	saved.map_location.point_id = TOWN+".point.n12"
	file = FileAccess.open(fixture,FileAccess.WRITE)
	file.store_string(JSON.stringify(saved))
	file.close()
	expected.point_id = TOWN+".point.n19"
	check(map_session.saved_location(fixture)==expected,"old alchemy session resumes at new alchemy")
	check(map.loadout.restore(saved).is_empty() and map.loadout.map_location==expected,"old alchemy full snapshot migrates")
	map._restore_saved_location()
	check(map.travel.current_node_id==expected.point_id and map.player.position.distance_to(points.get_node("N19").position)<0.01,"old alchemy restored character lands at new alchemy")
	check(saved.map_location.point_id==TOWN+".point.n12","alchemy migration leaves source snapshot unchanged")
	if DisplayServer.get_name()!="headless":
		# Static layout review only: reveal artwork without travel or input events.
		for point: MapRoutePoint in points.get_children(): point.present_exploration(true,true)
		for route: MapRoute in routes.get_children(): route.present_exploration(true,false,false,72)
		map.sign_motion.set_process(false)
		map.content.scale = Vector2.ONE*minf(map.map_viewport.size.x/3321.0,map.map_viewport.size.y/1862.0)
		map.content.position = (map.map_viewport.size-Vector2(3321,1862)*map.content.scale)*0.5
		await capture("town-overview")
		map.content.scale = Vector2.ONE*1.1
		map.content.position = map.map_viewport.size*0.5-Vector2(2250,780)*1.1
		await capture("town-clinic-junction")
		map.content.scale = Vector2.ONE*1.1
		map.content.position = map.map_viewport.size*0.5-Vector2(2610,1440)*1.1
		await capture("town-forge-shrine")
	Meta.stop()
	map.deactivate_location()
	map.queue_free()
	await settle()
	print("TOWN_REFRESH: %d checks; %d failures" % [checks,failures])
	print("OUTPUT: "+directory)
	quit(1 if failures else 0)
