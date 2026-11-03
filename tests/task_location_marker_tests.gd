extends "res://tests/single_task_tracking_tests.gd"
## Focused routing and presentation checks. No mouse input or real player saves.

func capture_location(label: String, point_id: String) -> void:
	if DisplayServer.get_name()=="headless": return
	for dimensions: Vector2i in [Vector2i(1920,1080),Vector2i(2560,1440)]:
		root.size = dimensions
		await settle()
		var point: Vector2 = map.travel.node_positions[point_id]
		map.content.position = map.map_viewport.size*0.5-point*map.content.scale
		map._clamp_position()
		await settle()
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output+"/%s-%d.png"%[label,dimensions.x])==OK,"save location preview")

func run() -> void:
	create_timer(55).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	output = "res://artifacts/task-location-markers-20261102/run-%d"%Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(output)
	save_path = output+"/live_session.json"
	MapLoadoutStore.GameSaveSession.index_path = output+"/index.json"
	MapLoadoutStore.GameSaveSession.active_path = ""
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1920,1080)
	policy_checks()
	map = load("res://scenes/maps/qingshizhen.tscn").instantiate()
	map.inventory_save_path = save_path
	map.defer_map_music = true
	map.defer_location_save = true
	map.defer_optional_views = true
	root.add_child(map)
	map.set_process(false)
	check(map.startup_error.is_empty(),"actual town starts")
	if not map.startup_error.is_empty(): quit(1); return
	await settle()
	travel_stage()
	# The player already visited the shop to accept this delivery task.
	map._visit_exploration("base.map.qingshizhen.point.n14")
	var controller = map.quest_tracker_controller
	check(controller.markers.get_child_count()==1 and controller.markers.get_child(0).name=="base_map_qingshizhen_point_n04","travel points toward slope exit")
	await capture_location("slope-exit","base.map.qingshizhen.point.n04")
	var raw: Dictionary = map.loadout.snapshot()
	raw.quests[MAIN].counts.visit = 1
	check(map.loadout.restore(raw).is_empty(),"restore gathering stage")
	var entry: Dictionary = QuestTracking.entries(map.loadout)[0]
	check(controller.navigation.markers_for(entry,"base.map.xiyuanyaopo").size()==4,"all four current herb nodes marked")
	raw.quests[MAIN].counts.kuaiye = 3
	check(map.loadout.restore(raw).is_empty(),"restore one herb complete")
	entry = QuestTracking.entries(map.loadout)[0]
	check(controller.navigation.markers_for(entry,"base.map.xiyuanyaopo").size()==2,"completed herb targets removed")
	raw.quests[MAIN].counts.xilutai = 3
	check(map.loadout.restore(raw).is_empty(),"restore delivery stage")
	for herb: String in ["kuaiye","xilutai"]:
		check(map.loadout.add_reward({"id":"base.map_reward.test.marker."+herb,"item_id":"base.material."+herb,"quantity":3}).is_empty(),"supply delivery herb")
	controller.refresh()
	map.quest_story_controller.refresh_signs()
	check(controller.markers.get_child_count()==1 and controller.markers.get_child(0).name=="base_map_qingshizhen_point_n14","delivery marker appears at herbalist N14")
	var art: TextureRect = controller.markers.get_child(0).get_child(0)
	check(art.texture.atlas.resource_path=="res://assets/UI-task-right-map-location.webp","requested location artwork")
	var sign: Sprite2D = map.quest_story_controller.signs.entries["base.map.qingshizhen.point.n14"].overlay
	check(sign.is_visible_in_tree() and sign.texture.atlas.resource_path=="res://assets/mapdot4o.webp","active task sign uses new frame")
	check(sign.texture.atlas.get_image().has_mipmaps(),"new frame has mipmaps")
	check(sign.texture.region.encloses(Rect2(sign.texture.atlas.get_image().get_used_rect())),"frame crop preserves visible artwork")
	check(sign.get_node("StoryIcon/SwaySymbol")!=null,"shared task icon sway retained")
	await capture_location("deliver-herbs","base.map.qingshizhen.point.n14")
	raw = map.loadout.snapshot()
	raw.quest_tracking.shown = false
	check(map.loadout.restore(raw).is_empty(),"restore hidden tracker")
	check(not controller.tracker.visible and controller.markers.get_child_count()==1,"hidden panel keeps tracked location")
	var saved: Dictionary = map.loadout.snapshot()
	check(MapLoadoutStore.save(map.loadout,save_path).is_empty(),"save isolated delivery state")
	travel_stage()
	check(map.loadout.restore(JSON.parse_string(FileAccess.get_file_as_string(save_path))).is_empty(),"reload delivery state")
	check(controller.markers.get_child(0).name=="base_map_qingshizhen_point_n14" and map.loadout.snapshot()==saved,"reload keeps delivery marker and state")
	raw = map.loadout.snapshot()
	for key: String in raw.quests[MAIN].counts: raw.quests[MAIN].counts[key] = 1
	raw.quests[MAIN].story.done = ["wake","morning","slope","returning"]
	check(map.loadout.restore(raw).is_empty(),"restore completed quest")
	entry = QuestTracking.entries(map.loadout)[0]
	check(controller.navigation.markers_for(entry,"base.map.qingshizhen").is_empty(),"completed task has no obsolete marker")
	map.queue_free()
	await settle()
	print("TASK LOCATION MARKERS: %d checks, %d failures"%[checks,failures])
	print("OUTPUT: "+output)
	quit(1 if failures else 0)
