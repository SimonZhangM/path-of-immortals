extends "res://tests/save_actions_tests.gd"

var library := NpcDialogueLibrary.new()
var save_path := ""
const NPC := "base.npc.yesongnian"

func command(state: MapLoadoutState, action: String, topic := "") -> String:
	return NpcDialogueActions.command(state,library,action,save_path,topic)

func finish(state: MapLoadoutState) -> void:
	var guard := 0
	while not QuestStory.story(state).active.is_empty() and not QuestStory.story(state).reward_pending and guard<60:
		var error := QuestStory.command(state,save_path,"advance")
		check(error.is_empty(),"dialogue advances atomically: "+error)
		if not error.is_empty(): break
		guard += 1
	check(guard<60,"dialogue terminates")

func gather(state: MapLoadoutState, event: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	check(MapGatheringRewards.prepare(state,event,"base.gathering.deep",save_path,rng).is_empty(),"prepare genuine gathering result")
	check(MapGatheringRewards.claim(state,event,save_path).is_empty(),"claim genuine gathering result")

func run() -> void:
	create_timer(58).timeout.connect(func(): quit(2))
	directory = "res://artifacts/task-quest/run-%d/" % Time.get_ticks_usec()
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
	map.set_process(false)
	check(map.startup_error.is_empty(),"isolated map starts: "+map.startup_error)
	var state: MapLoadoutState = map.loadout
	save_path = map.inventory_save_path
	check(library.load_file("res://data/dialogues/yesongnian.json").is_empty(),"updated dialogue definition validates")
	var raw := state.snapshot()
	raw.erase("quests")
	check(state.restore(raw).is_empty() and state.quests[QuestState.ID].counts.talk==0,"legacy save begins objective one without inferring progress")
	check(state.map_location==raw.map_location and state.spirit_stones==raw.spirit_stones and state.snapshot().owned_units==raw.owned_units,"migration preserves location/currency/items")
	var invalid := state.snapshot()
	invalid.quests[QuestState.ID].counts.kuaiye = 1
	var before := state.snapshot()
	check(not state.restore(invalid).is_empty() and state.snapshot()==before,"inconsistent quest save rejected without mutation")
	invalid = state.snapshot()
	invalid.map_location = []
	check(not state.restore(invalid).is_empty() and state.snapshot()==before,"malformed legacy location rejected before quest migration")
	map.set_task_open(true)
	map.task_screen.task_list.select_task(QuestState.ID)
	await settle()
	var screen = map.task_screen
	var body = screen.detail_body
	for resolution in [Vector2i(1920,1080),Vector2i(2560,1440)]:
		root.size = resolution
		await settle()
		check(body.visible and body.objective_rows.get_node_or_null("Objective_talk")!=null,"first objective visible at %s" % resolution)
		check(body.objective_rows.get_node_or_null("LockedNextObjective")!=null,"one locked preview")
		check(body.objective_rows.get_node("Objective_talk").get_node_or_null("ProgressCount")==null,"one-off objective has no count")
		for frame: Control in body.frames.values():
			check(screen.right_panel.get_global_rect().grow(0.01).encloses(frame.get_global_rect()),"frame stays within right panel")
		check(is_equal_approx(body.frames.people.position.x,29) and is_equal_approx(body.frames.rewards.get_rect().end.x,1259),"lower frames swapped, outer edges retained")
		check(body.people_slots.get_child(0).get_child(0).size.is_equal_approx(Vector2(118,118)),"square portrait slot")
		check(is_equal_approx(body.people_slots.get_child(0).get_global_rect().get_center().x,body.frames.people.get_global_rect().get_center().x),"one portrait centered")
		check(body.people_slots.get_child(0).get_child(0).get_node("PortraitBorder").get_theme_stylebox("panel").border_color==screen.Inventory.MAIN_PANEL_BORDER_COLOR,"portrait rim matches right panel")
		check(body.reward_slots.get_child(0).get_child(0).get_node("RewardQuantity").text=="+5","actual reward plus quantity badge")
		check(body.objective_rows.get_child(0) is HSeparator,"permanent first divider")
		await capture("initial-%dx%d" % [resolution.x,resolution.y])
	if "--visual-only" in OS.get_cmdline_user_args():
		await preview_slots(screen)
		Meta.stop()
		map.deactivate_location()
		map.queue_free()
		await settle()
		print("TASK_QUEST_VISUAL: %d checks; %d failures; no dialogue/gathering/mouse checks" % [checks,failures])
		print("OUTPUT: "+directory)
		quit(1 if failures else 0)
		return
	root.size = Vector2i(1920,1080)
	check(QuestTracking.commit(state,{"ids":[QuestState.ID],"shown":true},save_path).is_empty(),"track quest before real dialogue and gathering")
	var herb := {"id":"base.map_event.quest_test.kuaiye","item_id":"base.material.kuaiye","reward_prefix":"base.map_reward.quest_test.kuaiye"}
	var moss := {"id":"base.map_event.quest_test.xilutai","item_id":"base.material.xilutai","reward_prefix":"base.map_reward.quest_test.xilutai"}
	var rng := RandomNumberGenerator.new()
	check(MapGatheringRewards.prepare(state,herb,"base.gathering.quick",save_path,rng).is_empty(),"pre-quest gathering can exist")
	check(command(state,"visit").is_empty(),"visit elder")
	state.set_map_location(QuestStory.data.shop.map_id,QuestStory.data.shop.point_id)
	check(QuestStory.command(state,save_path,"begin","morning").is_empty(),"begin authored morning quest dialogue")
	check(state.quests[QuestState.ID].counts.talk==0,"starting dialogue alone does not complete objective")
	finish(state)
	check(state.quests[QuestState.ID].counts.talk==1,"hearing full gathering arrangement completes objective")
	await settle()
	check(QuestState.stage(state.quests)=="travel" and body.objective_rows.get_node_or_null("Objective_visit")!=null and body.objective_rows.get_node_or_null("Objective_kuaiye")==null and body.objective_rows.get_node_or_null("Objective_xilutai")==null,"before entering slope only travel goal is revealed")
	var travel_entry: Dictionary = QuestTracking.entries(state)[0]
	check(QuestTracking.objectives(travel_entry).size()==1 and QuestTracking.targets(travel_entry).size()==1,"tracker travel goal points only to slope entrance")
	await capture("travel-before-arrival")
	check(body.objective_rows.get_node("Objective_talk/ObjectiveText") is Label,"completed text stays plain, no strike-through")
	check(MapGatheringRewards.claim(state,herb,save_path).is_empty() and state.quests[QuestState.ID].counts.kuaiye==0,"pre-arrangement gathering and old inventory do not count")
	gather(state,herb)
	check(state.quests[QuestState.ID].counts.kuaiye==0,"collection before slope entry cannot advance the unrevealed gathering objective")
	state.set_map_location("base.map.xiyuanyaopo","base.map.xiyuanyaopo.point.n01")
	check(state.quests[QuestState.ID].counts.visit==1,"actual map arrival completes location objective")
	await settle()
	check(QuestState.stage(state.quests)=="gathering" and body.objective_rows.get_node_or_null("Objective_kuaiye")!=null and body.objective_rows.get_node_or_null("Objective_xilutai")!=null,"arrival reveals two parallel herb objectives")
	var gather_entry: Dictionary = QuestTracking.entries(state)[0]
	check(gather_entry.objectives.size()==4 and gather_entry.objectives[2].id=="kuaiye" and gather_entry.objectives[3].id=="xilutai","two herbs retain separate completion circles")
	await capture("gather-after-arrival")
	gather(state,moss)
	check(state.quests[QuestState.ID].counts.xilutai==3 and state.quests[QuestState.ID].counts.kuaiye==0,"reverse herb order retained independently")
	await settle()
	check(body.objective_rows.get_node("Objective_xilutai/ProgressCount").text=="3/3","parallel herb UI displays actual progress")
	gather_entry = QuestTracking.entries(state)[0]
	check(not gather_entry.objectives[2].completed and gather_entry.objectives[3].completed and QuestTracking.objectives(gather_entry).size()==1 and QuestTracking.objectives(gather_entry)[0].id=="kuaiye","partial collection checks only the collected herb and tracker hides it")
	check(body.objective_rows.size.y<=body.objective_scroll.size.y+0.01,"all current parallel objectives and lock fit in frame")
	await capture("parallel-moss-first")
	before = state.snapshot()
	check(MapGatheringRewards.claim(state,moss,save_path).is_empty() and state.snapshot()==before,"duplicate claim grants/counts nothing")
	var failed := MapLoadoutStore.candidate(state).state as MapLoadoutState
	check(not MapGatheringRewards.prepare(failed,herb,"base.gathering.quick",directory+"missing/save.json",rng).is_empty() and failed.snapshot()==before,"failed gathering save rolls back")
	gather(state,herb)
	check(QuestState.stage(state.quests)=="returning","both herbs unlock delivery")
	await settle()
	check(body.objective_rows.get_node_or_null("LockedNextObjective")==null,"last stage has no lock")
	check(body.objective_rows.get_node_or_null("Objective_deliver")!=null,"delivery objective revealed")
	# Read any queued gathering remarks before returning.
	while not QuestStory.story(state).pending.is_empty():
		check(QuestStory.command(state,save_path,"begin",QuestStory.story(state).pending[0]).is_empty(),"begin queued herb remark")
		finish(state)
	state.set_map_location(QuestStory.data.shop.map_id,QuestStory.data.shop.point_id)
	check(QuestStory.command(state,save_path,"begin","returning").is_empty(),"begin return conversation")
	finish(state)
	# Remove a required herb during a partially read delivery; final line must fail atomically.
	var ready := state.snapshot()
	var units := QuestState.delivery_units(state)
	var missing := state.snapshot()
	missing.owned_units.erase(units[0])
	# There may be extra herbs; remove all carried copies of one required kind.
	for entry: Dictionary in state.storage.entries():
		if entry.item_id=="base.material.kuaiye":
			for unit: Dictionary in entry.units: missing.owned_units.erase(unit.id)
	check(state.restore(missing).is_empty(),"simulate missing delivery inventory")
	before = state.snapshot()
	var error := QuestStory.command(state,save_path,"accept")
	check(not error.is_empty() and state.snapshot()==before and state.quests[QuestState.ID].counts.deliver==0,"receipt rechecks ownership and rolls back on shortage")
	check(state.restore(ready).is_empty(),"restore isolated ready fixture")
	before = state.snapshot()
	check(not QuestStory.command(state,directory+"missing/save.json","accept").is_empty() and state.snapshot()==before,"delivery save failure leaves all state unchanged")
	var money := state.spirit_stones
	var owned_count: int = state.snapshot().owned_units.size()
	check(QuestStory.command(state,save_path,"accept").is_empty(),"receive return payment")
	check(state.quests[QuestState.ID].counts.deliver==1 and state.spirit_stones==money+5,"delivery completes with exact authored payment")
	check(state.quest_tracking.ids.is_empty(),"real delivery automatically removes tracked quest")
	check(state.snapshot().owned_units.size()==owned_count-6,"only three of each herb consumed; extras retained")
	before = state.snapshot()
	check(QuestStory.command(state,save_path,"accept").is_empty() and state.spirit_stones==money+5,"completion cannot pay twice")
	var restored := MapLoadoutStore.candidate(state).state as MapLoadoutState
	var reload_error := MapLoadoutStore.load_into(restored,save_path)
	check(reload_error.is_empty() and restored.quests==state.quests and restored.spirit_stones==state.spirit_stones,"quest and payment persist across reload: %s; %s vs %s" % [reload_error,restored.quests,state.quests])
	check(Files.read(Slots.quick_path()).quest_tracking.ids.is_empty(),"completion quick save also removes tracking")
	check(Files.read(Slots.quick_path()).quests[QuestState.ID].counts.deliver==1,"completion quick save includes the completed quest")
	await settle()
	await capture("completed")
	await preview_slots(screen)
	Meta.stop()
	map.deactivate_location()
	map.queue_free()
	await settle()
	print("TASK_QUEST: %d checks; %d failures" % [checks,failures])
	print("OUTPUT: "+directory)
	quit(1 if failures else 0)

func preview_slots(screen: Control) -> void:
	var body = screen.detail_body
	var preview: Dictionary = screen.task_list.entries[0].duplicate(true)
	preview.people.append(preview.people[0].duplicate(true))
	preview.rewards = [
		{"kind":"cultivation","name":"修为","quantity":200},
		{"kind":"spirit_stones","name":"灵石","quantity":5},
		{"kind":"experience","name":"历练","quantity":10},
		{"kind":"item","name":"苦艾叶","item_id":"base.material.kuaiye","quantity":1}]
	body.show_entry(preview)
	await settle()
	var first: Rect2 = body.people_slots.get_child(0).get_global_rect()
	var second: Rect2 = body.people_slots.get_child(1).get_global_rect()
	check(absf((first.position.x+second.end.x)*0.5-body.frames.people.get_global_rect().get_center().x)<1.0,"two portraits centered as a group")
	check(is_equal_approx(body.people_slots.get_child(1).position.x-body.people_slots.get_child(0).get_rect().end.x,19),"portrait gap matches source reference")
	for tile: Control in body.reward_slots.get_children():
		check(body.frames.rewards.get_global_rect().encloses(tile.get_global_rect()),"future resource/item tile stays within frame")
		check(tile.get_child(0).get_node("RewardQuantity").text.begins_with("+"),"resource and item quantities share plus badge")
	check(body.reward_slots.get_child(3).get_child(0).get_child(0) is PanelContainer,"item reward reuses shop thumbnail")
	await capture("two-portrait-layout-fixture")
	body.show_entry(screen.task_list.entries[0])
