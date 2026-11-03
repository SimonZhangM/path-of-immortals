extends "res://tests/world_map_discovery_tests.gd"

const VILLAGE := "base.map.baishacun"
const VILLAGE_LOCATION := "base.world_location.baishacun"
const ACCEPTED := "base.story.chaoshengguichu.accepted"

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await settle()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output + "/" + label + ".png") == OK, "preview saved")

func place(map: Control, point_id: String) -> void:
	map.travel.stop_at_current_node()
	map.travel.current_node_id = point_id
	map.travel.map_position = map.travel.node_positions[point_id]
	map.travel.paused = false
	map.loadout.set_map_location(map.definition.id, point_id)
	map._visit_exploration(point_id)
	map.player.present(map.travel)

func find_map(map_id: String) -> Control:
	for child in root.get_children():
		if child.has_method("_try_open_exit") and child.definition.id == map_id:
			return child
	return null

func run() -> void:
	create_timer(55).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0, true)
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1920, 1080)
	output = "res://artifacts/baishacun-20261102/run-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(output)
	save_path = output + "/live_session.json"
	MapLoadoutStore.GameSaveSession.index_path = output + "/index.json"
	MapLoadoutStore.GameSaveSession.active_path = ""
	var town := await boot("qingshizhen", TOWN + ".point.n30")
	if not town.startup_error.is_empty(): quit(1); return
	town.activate_location()
	var view = load("res://scripts/map/map_world_map.gd").new()
	root.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.present(TOWN, town.loadout.map_visited)
	check(not view.landmark_markers[VILLAGE_LOCATION].visible, "unvisited village hidden")
	check(not view.is_location_discovered(VILLAGE_LOCATION), "village undiscovered before entry")
	view.select_location(VILLAGE_LOCATION)
	check(view.selected_location_id != VILLAGE_LOCATION, "unvisited village cannot be selected")
	check(view.world_position_for(VILLAGE) == Vector2(2511, 2061), "world marker matches supplied port")
	await capture("world-before-visit")
	view.hide()
	check(town._try_open_exit(TOWN + ".point.n30"), "south exit opens its status")
	check(town.exit_dialog.confirm_button.disabled and town.exit_dialog.error_label.text.contains("潮声归处"), "main three required before transfer")
	town._confirm_exit()
	town._complete_exit()
	await settle()
	check(find_map(VILLAGE) == null and not town.loadout.map_visited.has(VILLAGE), "locked confirmation cannot enter or discover village")
	await capture("south-exit-locked")
	town._cancel_exit()
	var raw: Dictionary = town.loadout.snapshot()
	raw.narrative.flags[ACCEPTED] = true
	check(town.loadout.restore(raw).is_empty(), "isolated future main-three acceptance fixture")
	check(town._save_loadout().is_empty(), "unlock condition persists")
	check(town._try_open_exit(TOWN + ".point.n30") and not town.exit_dialog.confirm_button.disabled, "accepted main three enables south exit")
	raw.narrative.flags[ACCEPTED] = false
	check(town.loadout.restore(raw).is_empty(), "acceptance revoked before deferred transfer")
	town._complete_exit()
	check(town.exit_dialog.confirm_button.disabled and find_map(VILLAGE) == null, "deferred transfer rechecks acceptance")
	town._cancel_exit()
	raw.narrative.flags[ACCEPTED] = true
	check(town.loadout.restore(raw).is_empty(), "restore accepted quest")
	check(town._try_open_exit(TOWN + ".point.n30") and not town.exit_dialog.confirm_button.disabled, "reopen accepted exit")
	var icon: Sprite2D = town.content.get_node("Points/N30/Sign/LocationIcon")
	check(icon.texture.atlas.resource_path == "res://assets/map-likai-down.webp", "town uses down exit icon")
	town.exit_dialog.confirm_button.pressed.emit()
	while is_instance_valid(town): await process_frame
	var village := find_map(VILLAGE)
	check(village != null, "real transition enters village")
	if village == null: quit(1); return
	village.set_process(false)
	check(village.startup_error.is_empty() and village.travel.current_node_id == VILLAGE + ".point.n01", "arrival at northwest village exit")
	check(not village.is_exit_open(), "arrival does not immediately prompt return")
	check(village.travel.node_positions.size() == 20, "all twenty drawn circles are nodes")
	check(village.content.get_node("Routes").get_child_count() == 23, "twenty-three authored route segments")
	check(not village.travel.request_destination(VILLAGE + ".point.n19"), "unexplored distant node cannot be selected")
	village.travel.exploration_enabled = false
	for id: String in village.travel.node_positions:
		if id != VILLAGE + ".point.n01":
			check(not village.travel.shortest_path(VILLAGE + ".point.n01", id).is_empty(), "connected branch " + id)
	village.travel.exploration_enabled = true
	place(village, VILLAGE + ".point.n02")
	check(village.travel.request_destination(VILLAGE + ".point.n03"), "revealed next node accepts travel")
	village.travel.advance(10.0)
	check(village.travel.current_node_id == VILLAGE + ".point.n03", "travel follows authored route to next node")
	for route: MapRoute in village.content.get_node("Routes").get_children():
		check(route.curve.get_point_position(0).is_equal_approx(route.get_node(route.start_point).position), "curve starts at node")
		check(route.curve.get_point_position(route.curve.point_count - 1).is_equal_approx(route.get_node(route.end_point).position), "curve ends at node")
	check(village.event_registry.events.size() == 2, "exactly two chest events")
	check(view.catalog._points_by_map[VILLAGE].size() == 20, "village nodes join world exploration count")
	check(view.catalog.region_progress("base.world_region.qinglanshanlu", {}).total == 144, "five maps contribute current valid nodes")
	icon = village.content.get_node("Points/N01/Sign/LocationIcon")
	check(icon.texture.atlas.resource_path == "res://assets/map-likai-zuo.webp", "village uses left exit icon")
	check((load("res://assets/map-baishacun.webp") as Texture2D).get_image().has_mipmaps(), "map background mipmaps")
	check(not village.status_header.map_title.visible, "unprovided village title does not show another location")
	for dimensions: Vector2i in [Vector2i(1920,1080), Vector2i(2560,1440)]:
		root.size = dimensions
		village.zoom_factor = 1.0
		village._fit_map()
		for point: MapRoutePoint in village.content.get_node("Points").get_children(): point.present_exploration(true, true)
		for route: MapRoute in village.content.get_node("Routes").get_children(): route.present_exploration(true, false, false, 72)
		await capture("village-overview-%d" % dimensions.x)
	view.present(VILLAGE, village.loadout.map_visited)
	check(view.landmark_markers[VILLAGE_LOCATION].visible and view.selected_location_id == VILLAGE_LOCATION, "first arrival reveals village and details")
	check(view.sidebar.location_name.text == "白沙村", "world detail uses village name")
	await capture("world-after-visit")
	view.hide()
	for number in [10, 19]:
		var id := VILLAGE + ".point.n%02d" % number
		place(village, id)
		check(village._try_start_event(id, "arrival", true), "marked chest starts on arrival")
		check(village.chest_observation_dialog.visible, "chest observation opens")
		var event: Dictionary = village.event_state.active_event()
		village._open_chest()
		check(village.chest_dialog.visible and MapChestRewards.items(village.loadout, event).size() == 2, "existing two-choice chest pool")
		village.chest_dialog.select_choice(0)
		village._accept_chest()
		check(village.loadout.has_reward(event.reward_id), "chest reward committed")
		check(not village.event_state.is_active(), "claimed chest closes")
	check(village._save_loadout().is_empty(), "village position and chest receipts saved")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	check(saved.map_location.map_id == VILLAGE and saved.narrative.flags[ACCEPTED], "save includes village and unlock flag")
	village.queue_free()
	await settle()
	var router = load("res://scripts/map/map_session_start.gd").new()
	router.inventory_save_path = save_path
	router.defer_map_music = true
	root.add_child(router)
	while find_map(VILLAGE) == null: await process_frame
	village = find_map(VILLAGE)
	check(village.travel.current_node_id == VILLAGE + ".point.n19", "session resumes last village node")
	check(village.loadout.has_reward("base.map_reward.baishacun.chest_n10") and village.loadout.has_reward("base.map_reward.baishacun.chest_n19"), "both chest receipts survive reload")
	place(village, VILLAGE + ".point.n01")
	check(village._try_open_exit(VILLAGE + ".point.n01") and not village.exit_dialog.confirm_button.disabled, "return to town is available")
	village.exit_dialog.confirm_button.pressed.emit()
	while is_instance_valid(village): await process_frame
	town = find_map(TOWN)
	check(town != null and town.travel.current_node_id == TOWN + ".point.n30", "return arrives at town south exit")
	check(not town.is_exit_open(), "return does not immediately prompt departure")
	view.present(TOWN, town.loadout.map_visited)
	check(view.landmark_markers[VILLAGE_LOCATION].visible, "village remains discovered after return and reload")
	view.queue_free()
	town.queue_free()
	await settle()
	print("BAISHACUN: %d checks, %d failures" % [checks, failures])
	print("OUTPUT: " + output)
	quit(1 if failures else 0)
