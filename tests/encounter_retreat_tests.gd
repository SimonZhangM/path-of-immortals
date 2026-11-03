extends "res://tests/save_actions_tests.gd"

func run() -> void:
	create_timer(50).timeout.connect(func(): quit(2))
	directory = "res://artifacts/encounter-retreat-20261102/run-%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	Slots.auto_path = directory+"auto.json"
	Session.index_path = directory+"index.json"
	Session.clear_selection()
	AudioServer.set_bus_mute(0,true)
	for map_name: String in ["qingshihewan","wumingjiuci"]:
		var map = load("res://scenes/maps/"+map_name+".tscn").instantiate()
		map.inventory_save_path = directory+map_name+".json"
		map.defer_map_music = true
		map.defer_optional_views = true
		root.add_child(map)
		map.set_process(false)
		map.quest_story_controller.set_process(false)
		map.river_story_controller.set_process(false)
		check(map.startup_error.is_empty(),"actual map starts "+map_name)
		if not map.startup_error.is_empty(): quit(1); return
		var fixture: Dictionary = map.loadout.snapshot()
		fixture.quests[RiverQuest.ID].done = ["array"]
		check(map.loadout.restore(fixture).is_empty(),"suppress already seen optional array")
		for event: Dictionary in map.event_registry.events.values():
			if event.type!="encounter": continue
			var edges: Array = map.travel.adjacency[event.point_id]
			var prior: String = edges.filter(func(edge: Dictionary): return map.travel.edge_allowed(edge))[0].to
			map.loadout.set_map_location(map.definition.id,prior)
			map.travel.current_node_id = prior
			map.travel.map_position = map.travel.node_positions[prior]
			map.travel.stop_at_current_node()
			map._visit_exploration(prior)
			map.travel.paused = false
			map.travel.exploration_enabled = false
			check(map.travel.request_destination(event.point_id),"approach "+event.id)
			map.travel.advance(1000)
			check(map.event_state.phase=="encounter","encounter opens "+event.id)
			var actual_prior: String = map.loadout.map_previous_location.point_id
			check(actual_prior==prior,"previous node recorded "+event.id)
			map._retreat_encounter()
			check(map.travel.current_node_id==actual_prior and map.loadout.map_location.point_id==actual_prior,"cancel returns one actual edge "+event.id)
			check(not map.event_state.is_active() and not map.event_state.completed.has(event.id),"cancel leaves enemy alive "+event.id)
		var legacy: Dictionary = map.loadout.snapshot()
		legacy.erase("map_previous_location")
		check(map.loadout.restore(legacy).is_empty(),"old saves without approach remain valid")
		var invalid := legacy.duplicate(true)
		invalid.map_previous_location = {"map_id":map.definition.id,"point_id":"wrong-map"}
		check(not map.loadout.restore(invalid).is_empty(),"invalid approach is rejected")
		var encounter: Dictionary = map.event_registry.events.values().filter(func(event: Dictionary): return event.type=="encounter")[0]
		map.travel.current_node_id = encounter.point_id
		map.travel.map_position = map.travel.node_positions[encounter.point_id]
		map.loadout.map_previous_location.clear()
		var fallback: String = map._encounter_retreat_point()
		check(map.travel.adjacency[encounter.point_id].any(func(edge: Dictionary): return edge.to==fallback and map.travel.edge_allowed(edge)),"legacy fallback is a directly connected passable node")
		Meta.stop()
		map.deactivate_location()
		map.queue_free()
		await settle()
	print("ENCOUNTER RETREAT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
