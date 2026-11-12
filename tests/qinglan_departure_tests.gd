extends "res://tests/river_quest_tests.gd"
const Departure = preload("res://scripts/quests/qinglan_departure_quest.gd")

func finish_departure() -> void:
	var count := 0
	while not Departure.story(state).active.is_empty() and count<40:
		map._advance_dialogue()
		count += 1
	check(count<40,"chapter scene ends")

func task_entry() -> Dictionary:
	for row: Dictionary in QuestTracking.entries(state):
		if row.id==Departure.ID: return row
	return {}

func click_home() -> void:
	var point: Node2D = map.content.get_node("Points/N05")
	var pos := point.get_global_transform_with_canvas().origin
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = pos
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame

func run() -> void:
	create_timer(55).timeout.connect(func(): quit(2))
	directory = "res://artifacts/qinglan-departure-20261107/run-%d/"%Time.get_ticks_usec()
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
	await switch_to("baishacun",5)
	if not map.startup_error.is_empty(): quit(1); return
	check(Departure.configuration_error().is_empty(),"content valid")
	check(not Departure.available(state) and task_entry().is_empty(),"high test realm alone cannot unlock chapter")
	var fixture := state.snapshot()
	for goal: Dictionary in QuestState.definition.objectives: fixture.quests[QuestState.ID].counts[goal.id] = goal.required
	fixture.quests[QuestState.ID].story = QuestStory.migrated({"counts":fixture.quests[QuestState.ID].counts})
	fixture.quests[RiverQuest.ID].accepted_location = RiverQuest.RIVER
	fixture.quests[RiverQuest.ID].done = ["traces","injured","entrance","root","mirror","beasts_gone","medicine","return_jade","invite_doctor","pickup","clinic_arrival","gift_book","closing"]
	fixture.quests[MerchantRoadQuest.ID].accepted_location = "base.map.qingshizhen"
	fixture.quests[HomecomingQuest.ID].accepted_location = HomecomingQuest.data.shop.map_id
	fixture.quests[HomecomingQuest.ID].letter_received = true
	fixture.quests[HomecomingQuest.ID].home_reunited = true
	fixture.quests[HomecomingQuest.ID].guidance_completed = true
	fixture.narrative.flags[HomecomingQuest.FIRST_QI_FLAG] = true
	fixture.narrative.flags[HomecomingQuest.PREPARATION_FLAG] = true
	fixture.quests.erase(Departure.ID)
	check(state.restore(fixture).is_empty() and Departure.story(state)==Departure.initial(),"legacy save gains inactive chapter without invented progress")
	check(map.homecoming_story_controller.try_arrival(HomecomingQuest.data.home.point_id),"main three ending starts")
	while not HomecomingQuest.story(state).active.is_empty(): map._advance_dialogue()
	await create_timer(0.3).timeout
	check(HomecomingQuest.completed(state) and not map.travel.paused and not map.event_state.is_active(),"main three completion restores free movement")
	check(Departure.story(state).active.is_empty() and not Departure.accepted(state),"no automatic main four chain")
	var sign: Sprite2D = map.qinglan_departure_controller.signs.entries[HomecomingQuest.data.home.point_id].overlay
	check(sign.visible and not sign.get_meta("optional") and sign.position==Vector2(0,-223.928571),"home red marker at shared anchor")
	await shot("home-red-marker")
	var completed_three := state.snapshot()
	check(MapLoadoutStore.save(state,path).is_empty(),"save free state")
	await switch_to("baishacun",5)
	check(Departure.story(state).active.is_empty() and not map.travel.paused,"reload at home remains free before acceptance")
	await click_home()
	check(Departure.story(state).active=="mother" and map.travel.paused,"occupied-node mouse click starts chapter")
	if Departure.story(state).active.is_empty(): quit(1); return
	check(task_entry().objectives.size()==1 and state.quest_tracking.ids==[Departure.ID],"main four accepted and tracked at first conversation")
	await shot("01-mother")
	map._advance_dialogue()
	await switch_to("baishacun",5)
	check(Departure.story(state).active=="mother" and Departure.story(state).line==1,"started chapter resumes exact line")
	finish_departure()
	check(not map.travel.paused and Departure.story(state).done==["mother"],"first stage ends freely")
	check(task_entry().objectives.size()==4 and QuestTracking.targets(task_entry()).size()==3,"three town conversations available together")
	var after_mother := state.snapshot()
	# Independent branch proves leaving and returning triggers the same opening.
	check(state.restore(completed_three).is_empty(),"restore isolated unaccepted state")
	arrive(4); arrive(5)
	check(Departure.story(state).active=="mother","return home starts automatically")
	finish_departure()
	check(state.restore(after_mother).is_empty(),"restore first-stage completion")
	check(MapLoadoutStore.save(state,path).is_empty(),"save town departure")
	await switch_to("qingshizhen",2)
	arrive(1)
	check(Departure.story(state).active=="outpost_new","outpost may precede both farewells; strangers exchange names")
	await shot("04-outpost")
	map._advance_dialogue(); map._advance_dialogue()
	check(state.narrative.flags.get(Departure.NAME_FLAG,false),"name fact established after self introduction")
	map._advance_dialogue()
	await settle()
	var shown_text: String = map.dialogue.text_label.get_parsed_text()
	check(not shown_text.contains("{player.cultivation}") and shown_text.contains("化神"),"cultivation line reads actual realm rather than forcing qi one: "+shown_text)
	map._advance_dialogue()
	check(state.narrative.flags.get("base.story.xieyunshu.knows_cultivation",false),"cultivation knowledge follows spoken line")
	await switch_to("qingshizhen",1)
	check(Departure.story(state).active=="outpost_new" and Departure.story(state).line==4,"new acquaintance branch remains stable across reload")
	while Departure.story(state).line<Departure.data.scenes.outpost_new.lines.size()-1: map._advance_dialogue()
	var before := state.snapshot()
	check(not Departure.command(state,directory+"missing/fail.json","advance").is_empty() and state.snapshot()==before,"failed final save does not grant token or complete stage")
	map._advance_dialogue()
	check(Departure.story(state).token_received and Departure.story(state).done.has("outpost"),"token receipt recorded once at fourth-stage ending")
	check(task_entry().stage_id=="farewells_token" and QuestTracking.targets(task_entry()).size()==2,"early outpost still points to missing farewells")
	arrive(32)
	check(Departure.story(state).active=="clinic","clinic farewell can precede pharmacy")
	await shot("03-clinic")
	finish_departure()
	arrive(14)
	check(Departure.story(state).active=="pharmacy","pharmacy farewell follows independently")
	await shot("02-pharmacy")
	finish_departure()
	check(task_entry().stage_id=="road" and Departure.story(state).done.size()==4,"all four done but full main quest remains active")
	check(task_entry().objectives.back().id=="mountain_gate" and not task_entry().objectives.back().completed and QuestTracking.targets(task_entry()).is_empty(),"future mountain objective has no fabricated map target")
	check(not state.narrative.flags.get("base.story.qinglan.joined",false),"conversation does not grant admission")
	check(Departure.arrival(state,Departure.data.locations.pharmacy.map_id,Departure.data.locations.pharmacy.point_id).is_empty(),"completed farewell does not repeat")
	map.set_task_open(true)
	map.task_screen.task_list.select_task(Departure.ID)
	await shot("task-partial")
	map.set_task_open(false)
	# Verify old ordinary farewell content is retired without manufacturing history.
	for pair: Array in [["yesongnian","base.dialogue.yesongnian.story.departure"],["suqinghe","base.dialogue.suqinghe.story.depart"]]:
		var library := NpcDialogueLibrary.new()
		check(library.load_file("res://data/dialogues/"+pair[0]+".json").is_empty(),"ordinary library valid: "+pair[0])
		check(DialogueJournal.retired(state.narrative,library.segments[pair[1]]),"old farewell retired: "+pair[0])
	var known := after_mother.duplicate(true)
	known.narrative.flags[Departure.NAME_FLAG] = true
	check(state.restore(known).is_empty(),"known acquaintance fixture")
	check(MapLoadoutStore.save(state,path).is_empty(),"save known branch")
	await switch_to("qingshizhen",2)
	arrive(1)
	check(Departure.story(state).active=="outpost_known" and Departure.event("outpost_known",state).lines[0].begins_with("云舒"),"known person skips repeated introduction")
	finish_departure()
	check(Departure.story(state).token_received,"known version also records token")
	var result := {"checks":checks,"failures":failures,"directory":directory,"render":render}
	FileAccess.open(directory+"validation.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("QINGLAN_DEPARTURE "+JSON.stringify(result))
	map.deactivate_location(); map.free()
	quit(1 if failures else 0)
