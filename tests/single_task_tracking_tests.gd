extends SceneTree
const MAIN := QuestState.ID
const SIDE_A := "quest.test.side_a"
const SIDE_B := "quest.test.side_b"
var checks := 0
var failures := 0
var output := "res://artifacts/single-task-tracking-20261101/run-%d" % Time.get_ticks_usec()
var map: Control
var save_path: String

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func settle() -> void:
	for i in 4: await process_frame
func policy_checks() -> void:
	var available := [
		{"id":"quest.test.main_old","category":"main","accepted_at":1,"stage_id":"active"},
		{"id":"quest.test.main_new","category":"main","accepted_at":2,"stage_id":"active"},
		{"id":SIDE_A,"category":"side","stage_id":"active"},
		{"id":SIDE_B,"category":"personal","stage_id":"active"}]
	var initial := {"ids":[],"shown":false}
	var current := QuestTracking.normalized(initial,available)
	check(current.ids==["quest.test.main_new"] and not current.shown, "default latest active main, panel preference retained")
	check(not QuestTracking.toggle(current,"quest.test.main_new",available).error.is_empty(), "active main cannot be cancelled")
	var side := QuestTracking.toggle(current,SIDE_A,available)
	check(side.error.is_empty() and side.tracking.ids==[SIDE_A], "side replaces main")
	var other := QuestTracking.toggle(side.tracking,SIDE_B,available)
	check(other.error.is_empty() and other.tracking.ids==[SIDE_B], "another task replaces side")
	check(QuestTracking.toggle(other.tracking,SIDE_B,available).tracking.ids==["quest.test.main_new"], "cancel non-main returns to latest main")
	check(QuestTracking.toggle(side.tracking,"quest.test.main_old",available).tracking.ids==["quest.test.main_old"], "explicit main selection replaces side")
	available[1].stage_id = "completed"
	check(QuestTracking.toggle(side.tracking,SIDE_A,available).tracking.ids==["quest.test.main_old"], "completed main excluded from fallback")
	var old := {"ids":["quest.test.main_old",SIDE_A,SIDE_B],"shown":false}
	check(QuestTracking.valid(old,true) and not QuestTracking.valid(old), "old three-task saves accepted only for migration")
	check(QuestTracking.normalized(old,available).ids==[SIDE_B], "migration keeps most recently selected available task")
	check(initial=={"ids":[],"shown":false} and old.ids.size()==3, "policy commands do not mutate input")
	var nav = load("res://scripts/quests/quest_navigation.gd").new()
	check(nav.exit_toward("base.map.qingshizhen","base.map.xiyuanyaopo").point_id=="base.map.qingshizhen.point.n04", "town to slope uses actual exit")
	check(nav.exit_toward("base.map.qingshizhen","base.map.wumingjiuci").point_id=="base.map.qingshizhen.point.n25", "multi-scene route starts toward river")
	check(nav.exit_toward("base.map.wumingjiuci","base.map.xiyuanyaopo").point_id=="base.map.wumingjiuci.point.n01", "indirect route points at current scene exit")
	check(nav.exit_toward("base.map.qingshizhen","base.map.missing").is_empty(), "unconfigured route never invents a point")
	var entry := {"objectives":[{"completed":false,"targets":[{"map_id":"base.map.xiyuanyaopo","point_id":"base.map.xiyuanyaopo.point.n07"}]}]}
	check(nav.markers_for(entry,"base.map.xiyuanyaopo").size()==1, "task scene marks its target by default")
	entry.objectives[0].targets[0].point_marker = false
	check(nav.markers_for(entry,"base.map.xiyuanyaopo").is_empty(), "explicit scene exception hides pinpoint")
	entry.objectives[0].targets[0].point_marker = true
	check(nav.markers_for(entry,"base.map.xiyuanyaopo").size()==1, "explicit node permission enables pinpoint")

func fixture(id: String) -> Dictionary:
	var base: Dictionary = QuestState.display_entry(map.loadout,QuestTracking.presentation.display_entries[0])
	base.id = id
	base.category = "side"
	base.title = "测试支线" if id==SIDE_A else "测试人物任务"
	base.stage_id = "active"
	base.objectives = [{"id":"fixture","text":"测试目标","completed":false,"show_count":false,
		"targets":[{"map_id":"base.map.qingshizhen","point_id":"base.map.qingshizhen.point.n03"}]}]
	return base

func travel_stage() -> void:
	var raw: Dictionary = map.loadout.snapshot()
	for key: String in raw.quests[MAIN].counts: raw.quests[MAIN].counts[key] = 0
	raw.quests[MAIN].counts.talk = 1
	raw.quests[MAIN].story = QuestStory.initial()
	raw.quests[MAIN].story.done = ["wake","morning"]
	raw.quest_tracking = {"ids":[MAIN],"shown":true}
	check(map.loadout.restore(raw).is_empty(), "restore after Ye Songnian conversation")
	map.quest_tracker_controller.refresh()

func click_tracking(id: String) -> void:
	map.task_screen.sidebar.select_category("all")
	map.task_screen.task_list.select_task(id)
	await settle()
	var button: Control = map.task_screen.detail_body.footer_buttons[0]
	check(not button.disabled, "selection can replace current task")
	var point := button.get_global_rect().get_center()
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
		await settle()

func ui_checks() -> void:
	var controller = map.quest_tracker_controller
	var saved_presentation: Dictionary = QuestTracking.presentation.duplicate(true)
	QuestTracking.presentation.display_entries.append_array([fixture(SIDE_A),fixture(SIDE_B)])
	map.set_task_open(true)
	map.task_screen.task_list.select_task(MAIN)
	await settle()
	var body: Control = map.task_screen.detail_body
	check(body.footer_buttons[0].disabled and body.footer_buttons[0].get_node("Caption").text=="正在追踪", "tracked main has disabled cancellation button")
	var before: Dictionary = map.loadout.snapshot().duplicate(true)
	controller.toggle_task(MAIN)
	check(not controller.last_error.is_empty() and map.loadout.snapshot()==before, "controller rejects direct main cancellation")
	await click_tracking(SIDE_A)
	check(map.loadout.quest_tracking.ids==[SIDE_A] and controller.tracker.cards.size()==1, "real button switches to one side task")
	check(JSON.parse_string(FileAccess.get_file_as_string(save_path)).quest_tracking.ids==[SIDE_A], "single selection saved")
	await click_tracking(SIDE_B)
	check(map.loadout.quest_tracking.ids==[SIDE_B] and controller.tracker.cards.size()==1, "real button switches from side to other task")
	await click_tracking(MAIN)
	check(map.loadout.quest_tracking.ids==[MAIN] and body.footer_buttons[0].disabled, "real button returns to main and locks cancel")
	await click_tracking(SIDE_A)
	var previous: Dictionary = map.loadout.snapshot().duplicate(true)
	var rejected := QuestTracking.toggle(map.loadout.quest_tracking,SIDE_B,QuestTracking.entries(map.loadout))
	check(not QuestTracking.commit(map.loadout,rejected.tracking,output+"/missing/save.json").is_empty() and map.loadout.snapshot()==previous, "failed switch save leaves active task unchanged")
	await click_tracking(SIDE_A)
	check(map.loadout.quest_tracking.ids==[MAIN] and controller.tracker.cards.size()==1, "cancelling side restores main")
	var legacy: Dictionary = map.loadout.snapshot()
	legacy.quest_tracking.ids = [MAIN,SIDE_A,SIDE_B]
	check(map.loadout.restore(legacy).is_empty() and map.loadout.quest_tracking.ids==[SIDE_B], "actual save restore migrates three selections")
	var normalized: Dictionary = map.loadout.snapshot()
	check(QuestTracking.valid(normalized.quest_tracking), "new snapshot has at most one selection")
	legacy.quest_tracking = {"ids":[],"shown":false}
	check(map.loadout.restore(legacy).is_empty() and map.loadout.quest_tracking.ids==[MAIN] and not map.loadout.quest_tracking.shown, "empty selection falls back to main without reopening panel")
	QuestTracking.presentation = saved_presentation
	check(map.loadout.restore(map.loadout.snapshot()).is_empty(), "remove isolated content fixtures")
	var completed: Dictionary = map.loadout.snapshot()
	for key: String in completed.quests[MAIN].counts: completed.quests[MAIN].counts[key] = 1
	completed.quests[MAIN].story = QuestStory.initial()
	completed.quests[MAIN].story.done = ["wake","morning","slope","returning"]
	completed.quests[RiverQuest.ID].accepted_location = "青石河湾"
	completed.quest_tracking.ids = [MAIN]
	check(map.loadout.restore(completed).is_empty() and map.loadout.quest_tracking.ids==[RiverQuest.ID], "completed main falls back to newly accepted next main in actual state")
	map.set_task_open(false)
	travel_stage()

func render_checks() -> void:
	for dimensions: Vector2i in [Vector2i(1920,1080),Vector2i(2560,1440)]:
		root.size = dimensions
		await settle()
		var controller = map.quest_tracker_controller
		var point: Vector2 = map.travel.node_positions["base.map.qingshizhen.point.n04"]
		map.content.position = map.map_viewport.size*0.5-point*map.content.scale
		map._clamp_position()
		check(controller.tracker.cards.size()==1 and controller.tracker.visible, "one visible tracked task")
		check(controller.markers.get_child_count()==1, "one exit marker")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output+"/slope-exit-%d.png"%dimensions.x)

func run() -> void:
	create_timer(55).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1920,1080)
	DirAccess.make_dir_recursive_absolute(output)
	save_path = output+"/live_session.json"
	MapLoadoutStore.GameSaveSession.index_path = output+"/index.json"
	MapLoadoutStore.GameSaveSession.active_path = ""
	if "--visual-only" not in OS.get_cmdline_user_args(): policy_checks()
	map = load("res://scenes/maps/qingshizhen.tscn").instantiate()
	map.inventory_save_path = save_path
	map.defer_map_music = true
	map.defer_location_save = true
	map.defer_optional_views = true
	root.add_child(map)
	map.set_process(false)
	check(map.startup_error.is_empty(), "actual town starts")
	if not map.startup_error.is_empty(): quit(1); return
	await settle()
	var controller = map.quest_tracker_controller
	check(map.loadout.quest_tracking.ids==[MAIN] and not controller.tracker.visible, "new game defaults to main with panel closed")
	check(controller.markers.get_child_count()==1 and controller.markers.get_child(0).name=="base_map_qingshizhen_point_n14", "morning marker is explicitly at herbalist")
	travel_stage()
	check(controller.markers.get_child_count()==1 and controller.markers.get_child(0).name=="base_map_qingshizhen_point_n04", "after dialogue arrow moves to slope exit")
	var art: TextureRect = controller.markers.get_child(0).get_child(0)
	check(art.texture.atlas.resource_path=="res://assets/UI-task-right-map-location.webp", "exact requested pointer artwork")
	var entry: Dictionary = QuestTracking.entries(map.loadout)[0]
	check(controller.navigation.markers_for(entry,"base.map.xiyuanyaopo")[0].point_id=="base.map.xiyuanyaopo.point.n01", "travel target points at slope entrance")
	var raw: Dictionary = map.loadout.snapshot()
	raw.quests[MAIN].counts.visit = 1
	check(map.loadout.restore(raw).is_empty(), "restore gathering stage")
	entry = QuestTracking.entries(map.loadout)[0]
	check(controller.navigation.markers_for(entry,"base.map.xiyuanyaopo").size()==4, "gathering stage marks four herb nodes by default")
	travel_stage()
	if "--visual-only" in OS.get_cmdline_user_args():
		await render_checks()
	else:
		await ui_checks()
	map.queue_free()
	await settle()
	print("SINGLE TASK TRACKING: %d checks, %d failures"%[checks,failures])
	print("OUTPUT: "+output)
	quit(1 if failures else 0)
