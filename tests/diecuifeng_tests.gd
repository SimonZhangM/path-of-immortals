extends "res://tests/world_map_discovery_tests.gd"

const PEAK := "base.map.diecuifeng"

func place(map: Control, n: int) -> void:
	var id := PEAK + ".point.n%02d" % n
	map.travel.stop_at_current_node()
	map.travel.current_node_id = id
	map.travel.map_position = map.travel.node_positions[id]
	map.travel.paused = false
	map.loadout.set_map_location(PEAK, id)
	map._visit_exploration(id)
	map.player.present(map.travel)

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await settle()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output + "/" + label + ".png") == OK, "save preview")

func find_map(id: String) -> Control:
	for child in root.get_children():
		if child.has_method("_try_open_exit") and child.definition.id == id: return child
	return null

func run() -> void:
	create_timer(55).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0, true)
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1920,1080)
	output = "res://artifacts/diecuifeng-test/run-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(output)
	save_path = output + "/live_session.json"
	MapLoadoutStore.GameSaveSession.index_path = output + "/index.json"
	MapLoadoutStore.GameSaveSession.clear_selection()
	var map := await boot("diecuifeng")
	check(map.startup_error.is_empty(), "startup: " + map.startup_error)
	if not map.startup_error.is_empty(): quit(1); return
	# This map fixture represents arriving after the four departure conversations.
	var departure_fixture: Dictionary = map.loadout.snapshot()
	departure_fixture.quests[QinglanDepartureQuest.ID].accepted_location = QinglanDepartureQuest.data.accepted_location
	departure_fixture.quests[QinglanDepartureQuest.ID].done = ["mother", "pharmacy", "clinic", "outpost"]
	departure_fixture.quests[QinglanDepartureQuest.ID].token_received = true
	for step: String in departure_fixture.quests[QinglanDepartureQuest.ID].done:
		departure_fixture.narrative.flags["base.story.qinglanchujie."+step+"_done"] = true
	check(map.loadout.restore(departure_fixture).is_empty(), "departed for the mountain fixture")
	map.activate_location()
	check(map.travel.node_positions.size() == 33, "33 circles")
	check(map.content.get_node("Routes").get_child_count() == 35, "35 routes")
	check(map.event_registry.events.size() == 18, "17 ordinary bindings plus one task battle")
	check(map.status_header.map_title.visible, "dedicated plaque is visible")
	var seen := {PEAK+".point.n01":true}
	var pending: Array = seen.keys()
	while not pending.is_empty():
		var id: String = pending.pop_back()
		for edge: Dictionary in map.travel.adjacency[id]:
			if not seen.has(edge.to): seen[edge.to]=true; pending.append(edge.to)
	check(seen.size() == 33, "all branches connected")
	var curves_match := true
	for route: MapRoute in map.content.get_node("Routes").get_children():
		curves_match = curves_match and route.curve.get_point_position(0).is_equal_approx(route.get_node(route.start_point).position)
		curves_match = curves_match and route.curve.get_point_position(route.curve.point_count-1).is_equal_approx(route.get_node(route.end_point).position)
	check(curves_match, "every curve matches its two endpoints")
	check(not map.content.get_node("Points/N31").visible, "distant node initially hidden")
	for point: MapRoutePoint in map.content.get_node("Points").get_children(): point.present_exploration(true, true)
	for route: MapRoute in map.content.get_node("Routes").get_children(): route.present_exploration(true, false, false, 72)
	map.zoom_factor = 1.0
	map._fit_map()
	await capture("overview")
	var enemies := {2:"苔背石灵",6:"碧叶藤灵",7:"溪纹灵螈",20:"苔背石灵",21:"碧叶藤灵",22:"溪纹灵螈",24:"溪纹灵螈",27:"碧叶藤灵",28:"苔背石灵",30:"岩臂灵猿·护果",33:"苔背石灵"}
	for n: int in enemies:
		place(map, 1 if n == 2 else 3)
		place(map, n)
		check(map._try_start_event(map.travel.current_node_id,"arrival",true), "encounter opens N%d" % n)
		var event: Dictionary = map.event_state.active_event()
		check(map.loadout.registry.get_enemy(event.enemy_id).name == enemies[n] and event.respawn_days == 20 and not event.get("pending_enemy",false), "assigned actual enemy N%d" % n)
		check(map.encounter_dialog.enemy_name.text == enemies[n] and map.encounter_dialog.location_illustration.texture != null and not map.encounter_dialog.fight_button.disabled, "ready encounter UI N%d" % n)
		if n == 2: await capture("ready-encounter")
		map._retreat_encounter()
		if n == 2: check(map.travel.current_node_id == PEAK+".point.n01", "cancel returns to previous node")
	for n in [16,32]:
		place(map,n)
		check(not map._try_open_exit(map.travel.current_node_id) and map.content.get_node("Points/N%02d/Sign" % n).visible, "future exit keeps sign without transfer")
	for n in [13,23]:
		place(map,n)
		check(map._try_start_event(map.travel.current_node_id,"arrival",true,true) and map.rest_dialog.illustration.texture != null, "rest opens with assigned picture")
		map._cancel_rest()
	for n in [8,15]:
		place(map,n)
		check(map._try_start_event(map.travel.current_node_id,"arrival",true) and map.chest_observation_dialog.location_illustration.texture != null, "chest observation assigned picture")
		map._open_chest()
		check(MapChestRewards.items(map.loadout,map.event_state.active_event()).size() == 2, "existing chest pool opens")
		map._cancel_chest()
	place(map,31)
	check(map._try_start_event(map.travel.current_node_id,"arrival",true), "herb opens")
	check(map.event_state.active_event().item_id == "base.material.kuaiye" and map.gathering_dialog.location_illustration.texture != null, "existing herb and assigned scene")
	map._cancel_gathering()
	check(map._save_loadout().is_empty(), "save new map location")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	check(saved.map_location.map_id == PEAK and saved.map_location.point_id == PEAK+".point.n31", "saved location")
	map.queue_free()
	await settle()
	var router = load("res://scripts/map/map_session_start.gd").new()
	router.inventory_save_path=save_path
	router.defer_map_music=true
	root.add_child(router)
	for i in 120:
		await process_frame
		map=find_map(PEAK)
		if map!=null and map.loadout!=null: break
	check(map!=null and map.travel.current_node_id==PEAK+".point.n31", "session resumes new map")
	if map==null: quit(1); return
	place(map,1)
	check(map._try_open_exit(PEAK+".point.n01"), "return to town confirmation")
	map.exit_dialog.confirm_button.pressed.emit()
	while is_instance_valid(map): await process_frame
	var town := find_map(TOWN)
	check(town!=null and town.travel.current_node_id==TOWN+".point.n02", "arrive town north exit")
	if town!=null:
		check(town._try_open_exit(TOWN+".point.n02"), "town to peak confirmation")
		town.exit_dialog.confirm_button.pressed.emit()
		while is_instance_valid(town): await process_frame
		map=find_map(PEAK)
		check(map!=null and map.travel.current_node_id==PEAK+".point.n01", "arrive peak southwest entrance")
	if is_instance_valid(map): map.queue_free()
	await settle()
	print("DIE CUI FENG: %d checks, %d failures; output=%s" % [checks,failures,output])
	quit(1 if failures else 0)
