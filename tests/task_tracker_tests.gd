extends "res://tests/task_navigation_footer_tests.gd"

func run() -> void:
	create_timer(110).timeout.connect(func(): quit(2))
	directory = "res://artifacts/task-tracker/run-%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	Slots.auto_path = directory+"auto.json"
	Session.index_path = directory+"last.json"
	Session.clear_selection()
	root.get_node("SavePlaytime").set_process(false)
	root.get_node("GameSettings").apply_values({"background_pause":false,"background_mute":false})
	root.get_node("GameSettings").set_application_focus(true)
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1920,1080)
	var map = load("res://scenes/maps/qingshizhen.tscn").instantiate()
	map.inventory_save_path = Slots.working_path()
	map.defer_map_music = true
	map.defer_optional_views = true
	root.add_child(map)
	current_scene = map
	await settle()
	check(map.startup_error.is_empty(),"map starts with tracker")
	var controller = map.quest_tracker_controller
	var tracker = controller.tracker
	check(controller.available() and not tracker.visible,"tracker available but initially closed on pure map")
	var original: Dictionary = map.loadout.snapshot()
	var legacy := original.duplicate(true)
	legacy.erase("quest_tracking")
	check(map.loadout.restore(legacy).is_empty() and map.loadout.quest_tracking==QuestTracking.initial(),"old saves adopt empty tracker")
	await key(KEY_F)
	check(tracker.visible and map.loadout.quest_tracking.shown,"F opens initially closed tracker")
	await key(KEY_F,true)
	check(tracker.visible,"repeat does not close opened tracker")
	await key(KEY_F)
	check(not tracker.visible and not map.loadout.quest_tracking.shown,"F hides tracker completely")
	await key(KEY_F,true)
	check(not tracker.visible,"repeat ignored")
	await click(map.status_header.tasks_button)
	check(tracker.visible and not map.is_task_open(),"header opens tracker, not task page")
	await click(map.status_header.tasks_button)
	check(not tracker.visible and not map.loadout.quest_tracking.shown,"second header click hides tracker")
	await click(map.status_header.tasks_button)
	check(tracker.visible and map.loadout.quest_tracking.shown,"third header click opens tracker again")
	await click(tracker.close_button)
	check(not tracker.visible,"square button hides tracker")
	for code in [KEY_I,KEY_G,KEY_T,KEY_M]:
		await key(code)
		await key(KEY_F)
		await click(map.status_header.tasks_button)
		check(not map.loadout.quest_tracking.shown,"F/header preserve hidden state inside large interface")
		await key(KEY_ESCAPE)
	await key(KEY_F)
	for code in [KEY_I,KEY_G,KEY_T,KEY_M]:
		await key(code)
		await key(KEY_F)
		check(map.loadout.quest_tracking.shown and tracker.visible and not controller.available(),"large interfaces cover tracker without changing its original form")
		await key(KEY_ESCAPE)
		check(tracker.visible,"tracker restored after large interface")
	map._ensure_event_views()
	for phase in ["shop","gathering","rest","encounter","cultivation"]:
		map.event_state.phase = phase
		map.event_state.active_id = "test.tracker.modal"
		await key(KEY_F)
		await click(map.status_header.tasks_button)
		check(map.loadout.quest_tracking.shown,"event blocks tracker commands: "+phase)
	map.event_state.phase = ""
	map.event_state.active_id = ""
	map._open_system_menu()
	await key(KEY_F)
	check(map.loadout.quest_tracking.shown,"system modal preserves tracker state")
	map.system_menu_controller.close()
	map.reward_dialog.show()
	await key(KEY_F)
	check(map.loadout.quest_tracking.shown,"visible view-only popup also blocks")
	map.reward_dialog.hide()
	if "--toggle-only" in OS.get_cmdline_user_args():
		Meta.stop()
		map.deactivate_location()
		map.queue_free()
		await settle()
		print("TASK_TRACKER_TOGGLE: %d checks; %d failures" % [checks,failures])
		print("OUTPUT: "+directory)
		quit(1 if failures else 0)
		return
	var bindings: Dictionary = Settings.values_snapshot().bindings.duplicate(true)
	bindings.map_task_tracker = KEY_H
	check(root.get_node("GameSettings").apply_values({"bindings":bindings}).is_empty(),"tracker key can be rebound")
	await key(KEY_F)
	check(map.loadout.quest_tracking.shown,"old tracker key inactive after remap")
	await key(KEY_H)
	check(not map.loadout.quest_tracking.shown,"new tracker key hides")
	await key(KEY_H)
	bindings.map_task_tracker = KEY_F
	root.get_node("GameSettings").apply_values({"bindings":bindings})
	await click(tracker.list_button)
	check(map.is_task_open(),"tracker footer opens task list")
	map.task_screen.task_list.select_task(QuestState.ID)
	await settle()
	var body = map.task_screen.detail_body
	await click(body.footer_buttons[0])
	check(map.loadout.quest_tracking.ids==[QuestState.ID],"task button tracks real quest")
	check(body.footer_buttons[0].get_node("Caption").text=="正在追踪" and body.footer_buttons[0].disabled,"tracked main cannot be cancelled")
	var saved: Dictionary = Files.read(Slots.working_path())
	check(saved.get("quest_tracking",{}).get("ids",[])==[QuestState.ID],"tracking saved")
	await key(KEY_ESCAPE)
	check(tracker.cards.size()==1 and controller.markers.get_child_count()==1,"one tracked task and local shop marker")
	var character_position: Vector2 = map.player.position
	var before_visits: Dictionary = map.loadout.map_visited.duplicate(true)
	await click(tracker.cards[0])
	check(map.player.position==character_position and map.travel.mode=="idle","locating does not walk character")
	var target: Vector2 = map.travel.node_positions["base.map.qingshizhen.point.n14"]
	check(map.map_viewport.get_rect().has_point(map.map_to_screen(target)),"shop target in visible camera area")
	var marker_art: Control = controller.markers.get_child(0).get_child(0)
	var before_y := marker_art.position.y
	await create_timer(0.18).timeout
	check(not is_equal_approx(before_y,marker_art.position.y),"local marker breathes vertically")
	for resolution in [Vector2i(1920,1080),Vector2i(2560,1440)]:
		root.size = resolution
		await settle()
		check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(tracker.get_global_rect()),"tracker inside viewport")
		await capture("tracked-"+str(resolution.x))
	# Single selection and main fallback with isolated presentation fixtures only.
	var entry: Dictionary = QuestTracking.entries(map.loadout)[0]
	var fixtures := []
	for i in 4:
		var item := entry.duplicate(true)
		item.id = "quest.test."+str(i)
		item.category = ["side","main","main","sect"][i]
		fixtures.append(item)
	var tracking := QuestTracking.initial()
	for i in [0,2,1]: tracking = QuestTracking.toggle(tracking,fixtures[i].id,fixtures).tracking
	var ordered := QuestTracking.ordered(tracking,fixtures)
	check(ordered.map(func(e): return e.id)==[fixtures[1].id],"last selected task replaces previous selection")
	tracking = QuestTracking.toggle(tracking,fixtures[3].id,fixtures).tracking
	check(tracking.ids==[fixtures[3].id],"another task can replace occupied single slot")
	tracking = QuestTracking.toggle(tracking,fixtures[3].id,fixtures).tracking
	check(tracking.ids==[fixtures[2].id],"cancel non-main falls back to latest main")
	check(not QuestTracking.toggle(tracking,fixtures[2].id,fixtures).error.is_empty(),"current main cannot be cancelled")
	await key(KEY_T)
	map.loadout.quest_tracking.ids = [fixtures[0].id]
	body.show_entry(entry)
	check(not body.footer_buttons[0].disabled,"single occupied slot still allows switching")
	map.loadout.quest_tracking.ids = [QuestState.ID]
	body.show_entry(entry)
	check(body.footer_buttons[0].disabled,"selected main cancellation is disabled")
	map.loadout.quest_tracking.ids = [QuestState.ID]
	await key(KEY_ESCAPE)
	tracker.display(ordered)
	await capture("single-task-layout")
	check(tracker.cards.size()==1,"tracker displays one task")
	controller.refresh()
	# Parallel gathering goals and cross-region navigation from the real quest.
	var next: Dictionary = map.loadout.snapshot()
	next.quests[QuestState.ID].counts.talk = 1
	next.quests[QuestState.ID].counts.visit = 1
	check(map.loadout.restore(next).is_empty(),"parallel target fixture valid")
	await settle()
	var gathering: Dictionary = QuestTracking.entries(map.loadout)[0]
	check(QuestTracking.objectives(gathering).size()==2 and QuestTracking.targets(gathering).size()==4,"two herbs show together with four actual gathering nodes")
	await capture("parallel-targets")
	check(tracker.size.y<400,"height shrinks again when returning to one task")
	await click(tracker.cards[0])
	check(not map.is_world_map_open() and controller.markers.get_child_count()==1,"cross-region card locates scene exit")
	map.set_world_map_open(true)
	var world_id := "base.world_location.xiyuanyaopo"
	map.world_map.landmark_markers[world_id].hide()
	map.world_map._clamp_map()
	check(not map.world_map.quest_markers.has(world_id),"undiscovered world location remains hidden")
	await capture("cross-region-target")
	check(map.loadout.map_visited==before_visits,"viewing target does not discover nodes")
	await key(KEY_ESCAPE)
	# Entering the task scene marks the current herb targets by default.
	var slope = load("res://scenes/maps/xiyuanyaopo.tscn").instantiate()
	slope.inventory_save_path = directory+"slope.json"
	slope.defer_map_music = true
	slope.defer_optional_views = true
	check(MapLoadoutStore.save(map.loadout,slope.inventory_save_path).is_empty(),"isolated slope snapshot written")
	map.hide()
	root.add_child(slope)
	await settle()
	check(slope.startup_error.is_empty(),"slope starts with persisted tracked task")
	check(slope.quest_tracker_controller.markers.get_child_count()==4,"four herb nodes are marked by default")
	var slope_entry: Dictionary = QuestTracking.entries(slope.loadout)[0]
	var seen_before: Dictionary = slope.loadout.map_visited.duplicate(true)
	var player_before: Vector2 = slope.player.position
	slope.quest_tracker_controller.locate(slope_entry)
	check(slope.player.position==player_before and slope.loadout.map_visited==seen_before,"local gathering focus does not walk or discover")
	await capture("slope-four-markers")
	var partial: Dictionary = slope.loadout.snapshot()
	partial.quests[QuestState.ID].counts.kuaiye = 3
	check(slope.loadout.restore(partial).is_empty(),"one parallel objective completes")
	check(slope.quest_tracker_controller.markers.get_child_count()==2,"only remaining herb nodes stay marked")
	slope.deactivate_location()
	slope.queue_free()
	await settle()
	map.show()
	await settle()
	# Save failure keeps the previous published selection.
	var before: Dictionary = map.loadout.snapshot()
	var cleared := QuestTracking.initial()
	var error := QuestTracking.commit(map.loadout,cleared,directory)
	check(not error.is_empty() and map.loadout.snapshot()==before,"failed tracking write rolls back")
	var complete := before.duplicate(true)
	for id: String in complete.quests[QuestState.ID].counts: complete.quests[QuestState.ID].counts[id] = 1
	check(map.loadout.restore(complete).is_empty() and map.loadout.quest_tracking.ids.is_empty(),"completion removes tracked task")
	check(controller.markers.get_child_count()==0,"completion clears map marker")
	# Reject invalid serialized tracking records without altering state.
	var bad: Dictionary = map.loadout.snapshot()
	bad.quest_tracking.ids = [QuestState.ID,QuestState.ID]
	check(not map.loadout.restore(bad).is_empty(),"duplicate tracked IDs rejected")
	map.loadout.restore(original)
	Meta.stop()
	map.deactivate_location()
	map.queue_free()
	await settle()
	print("TASK_TRACKER: %d checks; %d failures" % [checks,failures])
	print("OUTPUT: "+directory)
	quit(1 if failures else 0)
