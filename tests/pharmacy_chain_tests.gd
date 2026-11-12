extends "res://tests/river_quest_tests.gd"

func advance_to_last(scene: String) -> void:
	var guard:=0
	while HomecomingQuest.story(state).active==scene and HomecomingQuest.story(state).line<HomecomingQuest.data.scenes[scene].lines.size()-1 and guard<40:
		map._advance_dialogue(); guard+=1
	check(guard<40,"reaches last line "+scene)

func run() -> void:
	create_timer(55).timeout.connect(func(): quit(2))
	directory="res://artifacts/pharmacy-chain-20261106/run-%d/"%Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	Slots.auto_path=directory+"auto.json"; Session.index_path=directory+"session.json"
	Session.clear_selection(); path=Slots.working_path()
	root.get_node("SavePlaytime").set_process(false)
	root.get_node("GameSettings").apply_values({"background_pause":false,"dialogue_speed":"instant","dialogue_auto":false})
	root.get_node("GameSettings").set_application_focus(true)
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size=Vector2i.ZERO; root.size=Vector2i(1920,1080)
	render=DisplayServer.get_name()!="headless"
	await switch_to("qingshizhen",30)
	check(not HomecomingQuest.available(state),"no offer before main two")
	var fixture:=state.snapshot()
	for goal: Dictionary in QuestState.definition.objectives: fixture.quests[QuestState.ID].counts[goal.id]=goal.required
	fixture.quests[QuestState.ID].story=QuestStory.migrated({"counts":fixture.quests[QuestState.ID].counts})
	fixture.quests[RiverQuest.ID].done=["traces","injured","entrance","root","mirror","beasts_gone","medicine","return_jade","invite_doctor","pickup","clinic_arrival","gift_book","closing"]
	fixture.quests[RiverQuest.ID].accepted_location=RiverQuest.RIVER
	check(state.restore(fixture).is_empty(),"completed main two fixture")
	check(HomecomingQuest.available(state) and not HomecomingQuest.accepted(state) and not MerchantRoadQuest.accepted(state),"both quests unaccepted at pharmacy offer")
	check(map.content.get_node("Points/N14/QuestSign").visible and not map.content.get_node("Points/N14/QuestSign").get_meta("optional"),"pharmacy keeps original red main marker")
	check(not QuestTracking.entries(state).any(func(e): return e.id in [MerchantRoadQuest.ID,HomecomingQuest.ID]),"neither task appears early")
	arrive(14)
	check(HomecomingQuest.story(state).active=="merchant_intro" and map.homecoming_story_controller.owns_dialogue(),"arrival starts side opening in common dialogue")
	check(not HomecomingQuest.accepted(state) and not MerchantRoadQuest.accepted(state),"starting conversation does not accept quests")
	map._advance_dialogue(); map._advance_dialogue()
	await switch_to("qingshizhen",14)
	check(HomecomingQuest.story(state).active=="merchant_intro" and HomecomingQuest.story(state).line==2,"side opening resumes exact line after reload")
	advance_to_last("merchant_intro")
	check(HomecomingQuest.data.scenes.merchant_intro.lines.back()=="好的，知道了。","requested final wording")
	var before:=state.snapshot()
	map.inventory_save_path=directory+"missing/side.json"
	map._advance_dialogue()
	check(state.snapshot()==before and map.dialogue.visible and map.travel.paused,"failed side acceptance keeps dialogue and state")
	map.inventory_save_path=path
	map._advance_dialogue()
	check(MerchantRoadQuest.accepted(state) and not HomecomingQuest.accepted(state),"only side accepted after final reply")
	check(HomecomingQuest.story(state).active=="bridge" and map.dialogue.visible and map.travel.paused and map.event_state.is_active(),"no release or fade-out between openings")
	check(HomecomingQuest.data.scenes.bridge.lines[0]=="对了，稍等。","Ye transition is exact")
	var entries:=QuestTracking.entries(state)
	check(entries.any(func(e):return e.id==MerchantRoadQuest.ID) and not entries.any(func(e):return e.id==HomecomingQuest.ID),"side appears alone before main acceptance")
	if render: await shot("pharmacy-bridge")
	await switch_to("qingshizhen",14)
	check(HomecomingQuest.story(state).active=="bridge" and MerchantRoadQuest.accepted(state),"bridge reload does not repeat or lose side acceptance")
	map._advance_dialogue()
	check(HomecomingQuest.story(state).active=="intro" and HomecomingQuest.story(state).line==0 and map.travel.paused,"bridge continues original first main line")
	check(not HomecomingQuest.accepted(state),"main remains unaccepted during letter scene")
	map._advance_dialogue()
	check(HomecomingQuest.story(state).reward_pending and map.reward_dialog.visible,"original letter receipt timing preserved")
	map._accept_reward()
	check(HomecomingQuest.story(state).line==1 and not HomecomingQuest.accepted(state),"receiving letter resumes without early main acceptance")
	advance_to_last("intro")
	before=state.snapshot()
	map.inventory_save_path=directory+"missing/main.json"
	map._advance_dialogue()
	check(state.snapshot()==before and not HomecomingQuest.accepted(state),"failed final save cannot accept main")
	map.inventory_save_path=path
	map._advance_dialogue()
	check(HomecomingQuest.accepted(state) and MerchantRoadQuest.accepted(state),"both tasks active after main opening")
	check(not map.travel.paused and not map.event_state.is_active(),"only final main line releases movement")
	check(state.quest_tracking.ids==[HomecomingQuest.ID],"main tracking starts on completion")
	entries=QuestTracking.entries(state)
	check(entries.any(func(e):return e.id==MerchantRoadQuest.ID) and entries.any(func(e):return e.id==HomecomingQuest.ID),"both tasks retained independently")
	var merchant:=MerchantRoadQuest.display_entry(state,{})
	check(merchant.objectives.size()==1 and merchant.objectives[0].targets[0].point_id=="base.map.qingshihewan.point.n17" and merchant.rewards[0].quantity==10,"side target and documented reward shown without payout")
	check(state.spirit_stones==before.spirit_stones,"acceptance grants no completion reward")
	if render:
		map.set_task_open(true)
		map.task_screen.task_list.select_task(MerchantRoadQuest.ID)
		await shot("merchant-task")
		map.set_task_open(false)
	check(HomecomingQuest.arrival(state,RiverQuest.TOWN,HomecomingQuest.data.shop.point_id).is_empty(),"no repeat pharmacy opening")
	# Legacy main intro keeps its exact cursor and does not prepend the new side speech.
	var old:=state.snapshot()
	old.quests.erase(MerchantRoadQuest.ID)
	old.quests[HomecomingQuest.ID].merge({"active":"intro","line":2,"location":HomecomingQuest.data.shop.duplicate(true),"letter_received":false},true)
	check(state.restore(old).is_empty() and HomecomingQuest.arrival(state,RiverQuest.TOWN,HomecomingQuest.data.shop.point_id)=="intro" and HomecomingQuest.story(state).line==2,"old active letter scene resumes unchanged")
	old.quests[HomecomingQuest.ID].merge({"active":"","line":0,"location":{},"letter_received":true},true)
	check(state.restore(old).is_empty() and HomecomingQuest.available(state),"old accepted main can pick up missing side on revisit")
	arrive(14); advance_to_last("merchant_intro"); map._advance_dialogue()
	check(MerchantRoadQuest.accepted(state) and HomecomingQuest.story(state).active.is_empty() and not map.travel.paused,"old main is not replayed or reset after side opening")
	print("PHARMACY CHAIN: %d checks, %d failures; %s"%[checks,failures,directory])
	FileAccess.open(directory+"validation.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures}))
	map.deactivate_location(); map.free()
	quit(1 if failures else 0)
