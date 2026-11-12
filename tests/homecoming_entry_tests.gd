extends "res://tests/river_quest_tests.gd"

func run() -> void:
	create_timer(55).timeout.connect(func(): quit(2))
	directory = "res://artifacts/homecoming-entry-20261103/run-%d/"%Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	Slots.auto_path = directory+"auto.json"
	Session.index_path = directory+"session.json"
	Session.clear_selection()
	path = Slots.working_path()
	root.get_node("SavePlaytime").set_process(false)
	root.get_node("GameSettings").apply_values({"background_pause":false,"background_mute":false,"dialogue_speed":"instant","dialogue_auto":false})
	root.get_node("GameSettings").set_application_focus(true)
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1920,1080)
	render = DisplayServer.get_name()!="headless"
	await switch_to("qingshizhen",30)
	check(not HomecomingQuest.available(state),"main three unavailable before rescue completion")
	var original := state.snapshot()
	check(state.restore(original).is_empty(),"normalize initial save fixture")
	original = state.snapshot()
	var legacy := original.duplicate(true)
	legacy.quests.erase(HomecomingQuest.ID)
	check(state.restore(legacy).is_empty() and HomecomingQuest.story(state)==HomecomingQuest.initial(),"old save gains inactive main three")
	for key in ["owned_units","growth","map_location","narrative"]:
		check(state.snapshot()[key]==original[key],"old save preserves "+key)
	var fixture := state.snapshot()
	for target: Dictionary in QuestState.definition.objectives: fixture.quests[QuestState.ID].counts[target.id] = target.required
	fixture.quests[QuestState.ID].story = QuestStory.migrated({"counts":fixture.quests[QuestState.ID].counts})
	var river: Dictionary = fixture.quests[RiverQuest.ID]
	river.done = ["traces","injured","entrance","root","mirror","beasts_gone","medicine","return_jade","invite_doctor","pickup","clinic_arrival","gift_book"]
	river.active = "closing"
	river.line = RiverQuest.data.scenes.closing.lines.size()-1
	river.location = {"map_id":RiverQuest.TOWN,"point_id":RiverQuest.TOWN+".point.n32"}
	river.accepted_location = RiverQuest.RIVER
	fixture.quest_tracking = {"ids":[RiverQuest.ID],"shown":true}
	check(state.restore(fixture).is_empty(),"main two final-line fixture")
	check(not HomecomingQuest.available(state),"final dialogue must finish before pharmacy unlock")
	check(RiverQuest.command(state,path,"advance").is_empty(),"finish main two through real command")
	check(HomecomingQuest.available(state) and not HomecomingQuest.accepted(state),"main three offered but not accepted")
	check(QuestTracking.ordered(state.quest_tracking,QuestTracking.entries(state)).is_empty(),"completion does not start a tracked task")
	check(not QuestTracking.entries(state).any(func(entry): return entry.id==HomecomingQuest.ID),"unaccepted main three absent from panel")
	check(map.quest_tracker_controller.markers.get_child_count()==0,"no target marker after main two")
	var sign: Sprite2D = map.content.get_node("Points/N14/QuestSign")
	check(sign.visible and not sign.get_meta("optional"),"pharmacy displays main quest sign")
	check(sign.get_node("StoryIcon/SwaySymbol")!=null,"main exclamation uses shared animated sign")
	check(map._exit_lock_hint(map.definition.exits[0]).is_empty(),"main two completion opens village route")
	map._visit_exploration(HomecomingQuest.data.shop.point_id)
	map.content.position = map.map_viewport.size*0.5-map.travel.node_positions[HomecomingQuest.data.shop.point_id]*map.content.scale
	map._clamp_position()
	await shot("main-three-available")
	if OS.get_environment("HOMECOMING_SIGN_ONLY")=="1":
		print("HOMECOMING_SIGN checks=%d failures=%d directory=%s"%[checks,failures,directory])
		map.deactivate_location()
		map.free()
		quit(1 if failures else 0)
		return
	await switch_to("qingshizhen",30)
	check(HomecomingQuest.available(state) and map.quest_tracker_controller.markers.get_child_count()==0,"offer and absent tracking survive reload")
	state.set_map_location(RiverQuest.TOWN,HomecomingQuest.data.shop.point_id)
	var before := state.snapshot()
	check(not HomecomingQuest.command(state,directory+"missing/fail.json","begin","merchant_intro").is_empty(),"failed acceptance save reported")
	check(state.snapshot()==before,"failed acceptance keeps quest and tracking unchanged")
	arrive(14)
	while HomecomingQuest.story(state).active=="merchant_intro": map._advance_dialogue()
	map._advance_dialogue()
	check(not HomecomingQuest.accepted(state) and MerchantRoadQuest.accepted(state) and HomecomingQuest.story(state).active=="intro","side quest accepted before letter dialogue; main waits for ending")
	check(map.homecoming_story_controller.owns_dialogue() and map.travel.paused,"shared dialogue owns modal")
	check(HomecomingQuest.ID not in state.quest_tracking.ids,"main tracking waits for pharmacy dialogue completion")
	check(not map.content.get_node("Points/N14/QuestSign").visible,"available sign clears on acceptance")
	check(not state.narrative.flags.get(HomecomingQuest.ACCEPTED_FLAG,false),"letter receipt still waits for completed dialogue")
	await shot("letter-introduction")
	map._advance_dialogue()
	map._accept_reward()
	map._advance_dialogue()
	await switch_to("qingshizhen",14)
	check(HomecomingQuest.story(state).line==2 and map.homecoming_story_controller.owns_dialogue(),"introduction resumes from saved line")
	while HomecomingQuest.story(state).line<HomecomingQuest.data.scenes.intro.lines.size()-1: map._advance_dialogue()
	before = state.snapshot()
	check(not HomecomingQuest.command(state,directory+"missing/fail.json","advance").is_empty(),"failed letter completion save reported")
	check(state.snapshot()==before,"letter flag and route stay atomic on failure")
	map._advance_dialogue()
	check(HomecomingQuest.story(state).letter_received and HomecomingQuest.story(state).active.is_empty(),"letter dialogue completes once")
	check(state.narrative.flags.get(HomecomingQuest.ACCEPTED_FLAG,false),"letter completion opens village route")
	check(map._exit_lock_hint(map.definition.exits[0]).is_empty(),"normal exit gate accepts new flag")
	check(HomecomingQuest.arrival(state,RiverQuest.TOWN,HomecomingQuest.data.shop.point_id).is_empty(),"pharmacy does not repeat accepted dialogue")
	check(not HomecomingQuest.command(state,path,"begin","intro").is_empty(),"direct duplicate acceptance rejected")
	var marker: Node = map.quest_tracker_controller.markers.get_child(0)
	check(marker.get_meta("point_id")==RiverQuest.TOWN+".point.n30","accepted objective guides toward village exit")
	await create_timer(0.2).timeout
	map.set_task_open(true)
	map.task_screen.task_list.select_task(HomecomingQuest.ID)
	await settle()
	check(map.task_screen.detail_header.task_id==HomecomingQuest.ID,"new quest selectable in task panel")
	check(map.task_screen.detail_header.artwork.texture.resource_path=="res://assets/UI-task-right-main-chaoshengguichu.webp","requested detail art")
	var entry: Dictionary = QuestTracking.entries(state).filter(func(row): return row.id==HomecomingQuest.ID)[0]
	check(entry.image=="res://assets/UI-task-mid-main-chaoshengguichu.webp","requested list art")
	for art_path: String in [entry.image,entry.detail_image]: check((load(art_path) as Texture2D).get_image().has_mipmaps(),"task art mipmaps")
	check(entry.stage_id=="homeward" and entry.has_locked_next and entry.objectives[1].text=="将叶伯的信带给母亲","homeward objective and later stages locked")
	await shot("homecoming-task-panel")
	map.set_task_open(false)
	check(MapLoadoutStore.save(state,path).is_empty(),"save accepted quest")
	await switch_to("baishacun",1)
	check(HomecomingQuest.story(state).letter_received and state.narrative.flags.get(HomecomingQuest.ACCEPTED_FLAG,false),"cross-map load preserves letter and open route")
	check(map.quest_tracker_controller.markers.get_child_count()==1 and map.quest_tracker_controller.markers.get_child(0).get_meta("point_id")==HomecomingQuest.data.home.point_id,"village target is assigned mother home")
	var result := {"checks":checks,"failures":failures,"render":render,"directory":directory}
	FileAccess.open(directory+"validation.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("HOMECOMING_ENTRY "+JSON.stringify(result))
	map.deactivate_location()
	map.free()
	quit(1 if failures else 0)
