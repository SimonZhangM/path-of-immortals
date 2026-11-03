extends SceneTree

const Session = preload("res://scripts/entry/game_save_session.gd")
const Slots = preload("res://scripts/entry/save_slot_policy.gd")
var checks := 0
var failures := 0
var directory := ""

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
func settle() -> void:
	for i in 5: await process_frame
func place(map: Node, point: String) -> void:
	map.travel.current_node_id = point
	map.travel.map_position = map.travel.node_positions[point]
	map.travel.stop_at_current_node()
	map.travel.paused = false
func approach(map: Node, event: Dictionary) -> void:
	var origin: String = map.travel.adjacency[event.point_id][0].to
	place(map, origin)
	check(map.travel.request_destination(event.point_id), "can approach " + event.id)
	map.travel.advance(1000)
func open_map(map_name: String) -> Node:
	var map = load("res://scenes/maps/" + map_name + ".tscn").instantiate()
	map.inventory_save_path = directory + map_name + ".json"
	map.defer_map_music = true
	map.defer_location_save = true
	map.defer_optional_views = true
	root.add_child(map)
	await settle()
	map.set_process(false)
	map.activate_location()
	for controller in [map.quest_story_controller, map.river_story_controller, map.herb_story_controller]:
		if controller != null: controller.set_process(false)
	# Test individual rest nodes independently of the quest's route unlocking.
	map.travel.exploration_enabled = false
	map.travel.blocked_routes.clear()
	map.travel.hidden_points.clear()
	check(map.startup_error.is_empty(), map_name + " actual map startup: " + map.startup_error)
	return map
func close_map(map: Node) -> void:
	map.deactivate_location()
	map.queue_free()
	await settle()

func run() -> void:
	create_timer(55).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0, true)
	directory = "res://artifacts/rest-first-visit-20261103/run-%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	Session.index_path = directory + "index.json"
	Slots.auto_path = directory + "auto.json"
	Session.clear_selection()
	var total_rest := 0
	var passed_through := 0
	for map_name in ["qingshihewan", "wumingjiuci", "qingshizhen"]:
		var map: Node = await open_map(map_name)
		if not map.startup_error.is_empty(): quit(1); return
		var rests: Array[Dictionary] = []
		for event: Dictionary in map.event_registry.events.values():
			if event.type == "rest": rests.append(event)
		for event in rests:
			total_rest += 1
			check(event.point_id not in map.loadout.map_visited.get(map.definition.id, []), "rest initially undiscovered: " + event.id)
			var before: Dictionary = map.player_status.resources.duplicate()
			var day := WorldCalendar.current_day(map.loadout.calendar)
			approach(map, event)
			check(map.rest_dialog.visible and map.event_state.active_id == event.id and map.travel.paused, "first arrival opens %s (actual %s at %s)" % [event.id, map.event_state.phase, map.travel.current_node_id])
			check(map.player_status.resources == before and WorldCalendar.current_day(map.loadout.calendar) == day, "opening consumes no resources or days")
			map._cancel_rest()
			check(not map.rest_dialog.visible and not map.travel.paused and not map.event_state.completed.has(event.id), "cancel keeps reusable site available")
			var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(map.inventory_save_path))
			check(event.point_id in saved.get("map_visited", {}).get(map.definition.id, []), "cancelled first encounter already persisted without resting")
			approach(map, event)
			check(map.travel.current_node_id == event.point_id and not map.travel.paused and not map.event_state.is_active(), "second arrival stays closed: " + event.id)
			check(map._try_start_event(event.point_id, "click", true), "stationary click still opens " + event.id)
			map._confirm_rest()
			check(not map.event_state.is_active() and WorldCalendar.current_day(map.loadout.calendar) == day + 1, "deliberate rest retains normal one-day recovery")
			approach(map, event)
			check(not map.rest_dialog.visible and not map.travel.paused, "arrival after successful rest also stays closed")
			# A revealed route can continue through a known rest site without stopping.
			var edges: Array = map.travel.adjacency[event.point_id]
			if edges.size() >= 2:
				place(map, edges[0].to)
				check(map.travel.request_destination(edges[1].to), "plan route beyond known rest")
				map.travel.advance(1000)
				check(map.travel.current_node_id == edges[1].to and not map.rest_dialog.visible, "passes through known rest to next node")
				passed_through += 1
				if map.event_state.phase == "encounter": map._retreat_encounter()
				if map.event_state.phase == "rest": map._cancel_rest()
				if map.event_state.phase in ["chest_observation", "chest"]: map._cancel_chest()
				if map.event_state.phase == "gathering": map._cancel_gathering()
		await close_map(map)
		map = await open_map(map_name)
		check(map.exploration_save_error.is_empty(), "exploration saves successfully")
		for event in rests:
			check(event.point_id in map.loadout.map_visited.get(map.definition.id, []), "saved visit restored for " + event.id)
			approach(map, event)
			check(not map.event_state.is_active() and not map.travel.paused, "scene reload does not reintroduce " + event.id)
			check(map._try_start_event(event.point_id, "click", true), "manual rest remains accessible after reload")
			map._cancel_rest()
		await close_map(map)
	check(total_rest == 5, "all five authored rest sites covered")
	check(passed_through > 0, "known-rest through-route exercised")
	print("REST FIRST VISIT: %d checks; %d failures; %d rest sites. %s" % [checks, failures, total_rest, directory])
	quit(1 if failures else 0)
