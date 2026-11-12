extends "res://tests/spirit_encounter_tests.gd"

func edge(from: String, to: String, points: Array) -> Dictionary:
	var curve := Curve2D.new()
	for point: Vector2 in points: curve.add_point(point)
	return {"id": from+to, "from": from, "to": to, "curve": curve}

func check_last_edge() -> void:
	var map = load("res://scripts/map/map_screen.gd").new()
	map.definition = {"id": MAP}
	map.loadout = MapLoadoutState.new()
	map.loadout.map_previous_location = {"map_id": MAP, "point_id": "a"}
	map.travel = MapTravelState.new()
	var points := {"a": Vector2.ZERO, "b": Vector2(100,0), "c": Vector2(200,0)}
	var edges: Array[Dictionary] = [edge("a","b",[points.a,points.b]), edge("b","c",[points.b,points.c]), edge("a","c",[points.a,Vector2(0,500),points.c])]
	check(map.travel.configure(points,edges,"a",100,180).is_empty(), "multi-edge graph configured")
	map.travel.request_destination("c")
	map.travel.advance(10)
	check(map.travel.last_arrival == {"from":"b","to":"c"}, "long journey records last edge, not departure")
	check(map._encounter_retreat_point()=="b", "actual incoming edge wins over stale adjacent departure in save")
	map.travel.request_destination("c")
	map.travel.stop_at_current_node()
	check(map._encounter_retreat_point()=="b", "stopping and clicking current node preserve arrival")
	map.travel.request_destination("a")
	map.travel.advance(0.1)
	map.travel.request_destination("c")
	map.travel.advance(10)
	check(map._encounter_retreat_point()=="b", "mid-journey diversion records final approach")
	map.travel.last_arrival.clear()
	check(map._encounter_retreat_point()=="a", "reload without live history retains save fallback")
	map.travel.last_arrival={"from":"a","to":"b"}
	check(map._encounter_retreat_point()=="a", "unrelated stale live arrival ignored")
	map.travel.configure(points,edges,"a",100,180)
	check(map.travel.last_arrival.is_empty(), "new map configuration clears prior edge")
	map.free()

func run() -> void:
	create_timer(45).timeout.connect(func():quit(2))
	AudioServer.set_bus_mute(0,true)
	check_last_edge()
	saved = "res://artifacts/encounter-last-edge-20261110/run-%d.json" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute("res://artifacts/encounter-last-edge-20261110")
	Session.index_path=saved+".index.json"
	Session.clear_selection()
	MapEventState.session_completed.clear()
	var map = load("res://scenes/maps/diecuifeng.tscn").instantiate()
	map.inventory_save_path=saved
	map.defer_map_music=true
	map.defer_optional_views=true
	root.add_child(map)
	current_scene=map
	map.set_process(false)
	check(map.startup_error.is_empty(), "actual map starts")
	map.travel.exploration_enabled=false
	var selected: Dictionary = {}
	var route: Array = []
	for event: Dictionary in map.event_registry.events.values():
		if event.type!="encounter": continue
		for start: String in map.travel.node_positions:
			var path: Array = map.travel.shortest_path(start,event.point_id)
			if path.size()<3: continue
			var intermediates: Array = path.slice(0,path.size()-1)
			if intermediates.any(func(e: Dictionary): return map.event_registry.by_point.has(e.to) or map.exits_by_point.has(e.to)): continue
			selected=event
			route=path
			break
		if not selected.is_empty(): break
	check(not route.is_empty(), "find real uninterrupted multi-edge approach")
	if route.is_empty(): map.queue_free(); quit(1); return
	var start: String=route[0].from
	var prior: String=route[-1].from
	map._place_after_encounter(start)
	map.loadout.set_map_location(MAP,start)
	map.travel.paused=false
	map.travel.exploration_enabled=false
	check(map.travel.request_destination(selected.point_id), "request distant encounter")
	map.travel.advance(1000)
	check(map.event_state.phase=="encounter" and map.travel.current_node_id==selected.point_id, "real movement arrives and opens encounter")
	check(map._encounter_retreat_point()==prior and prior!=start, "retreat resolves immediately preceding node")
	await map._start_encounter_battle()
	var battle := current_scene
	check(battle!=map, "actual battle entered")
	if battle==map: map.queue_free(); quit(1); return
	var game: GameManager=battle.get_node("GameManager")
	game.set_process(false)
	var flow=battle.get_node("MapBattleReturn")
	check(flow.retreat_point_id==prior, "battle captures final incoming node")
	game.start_battle()
	game.party[0].hp=0
	game.simulation._finish("defeat",game.simulation.state.time_usec)
	game._process(0)
	var error: String=await flow.return_to_map()
	check(error.is_empty(), "actual defeat returns: "+error)
	await settle()
	check(current_scene==map and map.travel.current_node_id==prior, "defeat lands one node back, not journey origin")
	check(map.loadout.map_location.point_id==prior and map.travel.last_arrival.is_empty(), "landing saved and old approach cleared")
	check(not map.event_state.completed.has(selected.id), "defeat leaves encounter alive")
	var clone: MapLoadoutState=MapLoadoutStore.candidate(map.loadout).state
	check(MapLoadoutStore.load_into(clone,saved).is_empty() and clone.map_location.point_id==prior, "reloaded save retains nearest prior node")
	map.queue_free()
	await settle()
	root.get_node("MapPresentation").music.stop()
	await create_timer(0.2).timeout
	print("ENCOUNTER LAST EDGE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
