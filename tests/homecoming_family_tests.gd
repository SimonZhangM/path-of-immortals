extends "res://tests/river_quest_tests.gd"

func shot(label: String) -> void:
	if render:
		await create_timer(0.28).timeout
		await capture(label)

func npc_command(action: String, topic := "") -> void:
	check(NpcDialogueActions.command(state,map.clinic_dialog.library,action,path,topic).is_empty(),"mother command "+action+" "+topic)

func finish_topic(topic: String, segment: String) -> void:
	npc_command("select",topic)
	var limit := 0
	while not HomecomingQuest.topic_done(state,segment) and limit<60:
		npc_command("advance")
		limit += 1
	check(limit<60 and HomecomingQuest.topic_done(state,segment),"complete ordinary topic "+segment)
	map.clinic_dialog.refresh_dialogue()

func open_home() -> void:
	check(map._try_start_event(HomecomingQuest.data.home.point_id,"click",true),"click home opens popup")
	check(map.event_state.phase=="clinic" and map.clinic_dialog.visible,"shared ordinary conversation popup")
	check(map.clinic_dialog.library!=null,"mother library loaded")

func run() -> void:
	create_timer(55).timeout.connect(func(): quit(2))
	directory = "res://artifacts/homecoming-family-20261103/run-%d/"%Time.get_ticks_usec()
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
	check(not map._exit_lock_hint(map.definition.exits[0]).is_empty(),"village locked before rescue complete")
	var fixture := state.snapshot()
	for target: Dictionary in QuestState.definition.objectives: fixture.quests[QuestState.ID].counts[target.id] = target.required
	fixture.quests[QuestState.ID].story = QuestStory.migrated({"counts":fixture.quests[QuestState.ID].counts})
	fixture.quests[RiverQuest.ID].done = ["traces","injured","entrance","root","mirror","beasts_gone","medicine","return_jade","invite_doctor","pickup","clinic_arrival","gift_book","closing"]
	fixture.quests[RiverQuest.ID].accepted_location = RiverQuest.RIVER
	check(state.restore(fixture).is_empty(),"legacy completed rescue fixture")
	check(map._exit_lock_hint(map.definition.exits[0]).is_empty() and not HomecomingQuest.accepted(state),"main two completion opens village before main three")
	check(MapLoadoutStore.save(state,path).is_empty(),"save early access")
	await switch_to("baishacun",5)
	check(not map.event_state.is_active(),"early village visit does not accept main three")
	open_home()
	check(map.clinic_dialog.backing.texture.atlas.resource_path=="res://assets/tanchuang-baishacun-jia.webp","requested home background")
	check(not map.clinic_dialog.treatment_tab.visible and map.clinic_dialog.illustration.texture.resource_path=="res://assets/tanchuang-baishacun-home-boss.webp","home uses supplied left scene")
	check(not HomecomingQuest.ready_for_practice(state),"ordinary early visit cannot unlock practice")
	map._close_clinic()
	await switch_to("qingshizhen",14)
	check(HomecomingQuest.story(state).active=="intro","pharmacy starts main three")
	while not HomecomingQuest.story(state).active.is_empty():
		if HomecomingQuest.story(state).reward_pending: map._accept_reward()
		else: map._advance_dialogue()
	await switch_to("baishacun",5)
	check(HomecomingQuest.story(state).active=="reunion","first return with letter begins sea home scene")
	map._advance_dialogue()
	map._advance_dialogue()
	check(map.dialogue.portrait.visible and map.dialogue.portrait.texture.atlas.resource_path=="res://assets/ui-portrait-mom-linwanqing.webp","mother story portrait bound")
	check(map.dialogue.picture.visible and map.dialogue.picture.illustration.texture.resource_path=="res://assets/map-event-3-1.webp","reunion scene picture bound")
	await shot("mother-reunion")
	await switch_to("baishacun",5)
	check(HomecomingQuest.story(state).line==2,"reunion cursor resumes")
	while not HomecomingQuest.story(state).active.is_empty():
		if HomecomingQuest.story(state).reward_pending: map._accept_reward()
		else: map._advance_dialogue()
	check(HomecomingQuest.story(state).home_reunited,"home reunion and letter delivery recorded")
	check(map.dialogue.picture.visible and map.dialogue.background.visible,"picture and dialogue remain together while exiting")
	await create_timer(0.07).timeout
	check(map.dialogue.background.modulate.a<1 and map.dialogue.background.modulate.a>0 and map.dialogue.picture.modulate.a<1,"both layers fade out together")
	check(not map.event_state.is_active() and not map.travel.paused and (not is_instance_valid(map.clinic_dialog) or not map.clinic_dialog.visible),"reunion ends to free exploration without popup")
	await create_timer(0.25).timeout
	check(not map.dialogue.visible,"story dialogue closes after reunion")
	open_home()
	check(HomecomingQuest.ready_for_practice(state)==false,"practice still gated after reunion")
	finish_topic("mirror","mirror")
	check(not HomecomingQuest.ready_for_practice(state),"mirror conversation alone does not advance")
	npc_command("select","past")
	npc_command("advance")
	var seen: int = state.narrative.npcs[HomecomingQuest.MOTHER].seen["base.dialogue.mother.past"]
	check(not HomecomingQuest.topic_done(state,"past"),"partly read past is incomplete")
	map.clinic_dialog.refresh_dialogue()
	await shot("mother-ordinary-chat")
	map._close_clinic()
	arrive(6)
	check(not map.event_state.is_active() and not map.travel.paused,"can leave home to explore mid-topic")
	check(not HomecomingQuest.ready_for_practice(state),"leaving does not complete topic")
	await switch_to("baishacun",5)
	check(not map.event_state.is_active(),"return visit leaves home closed until clicked")
	open_home()
	check(state.narrative.npcs[HomecomingQuest.MOTHER].seen["base.dialogue.mother.past"]==seen,"popup resumes saved partial topic")
	finish_topic("past","past")
	check(not HomecomingQuest.ready_for_practice(state) and HomecomingQuest.guidance_available(state),"third and fourth segments unlock fifth, not practice")
	check(map.clinic_dialog.visible and map.event_state.phase=="clinic","finishing chats does not start story automatically")
	check(map.content.get_node("Points/N05/QuestSign").visible and not map.content.get_node("Points/N05/QuestSign").get_meta("optional"),"home shows red main story exclamation")
	check(DialogueJournal.next_segment(state.narrative,map.clinic_dialog.library,"past",state.map_visited).is_empty(),"fifth segment retired from ordinary chat")
	await shot("mother-three-topics-and-left-art")
	map._close_clinic()
	check(HomecomingQuest.arrival(state,map.definition.id,HomecomingQuest.data.home.point_id)=="guidance","red marker permits arrival-triggered fifth scene")
	check(not map.event_state.is_active() and not map.travel.paused,"closing ordinary chat releases movement")
	await shot("home-red-exclamation")
	if OS.get_environment("MOTHER_GUIDANCE_MARKER_ONLY")=="1":
		check(map.content.get_node("Points/N05/QuestSign").is_visible_in_tree(),"home marker is visible on map")
		print("MOTHER_GUIDANCE_MARKER checks=%d failures=%d directory=%s"%[checks,failures,directory])
		map.deactivate_location()
		map.free()
		quit(1 if failures else 0)
		return
	var pending_guidance := state.snapshot()
	check(not HomecomingQuest.command(state,directory+"missing/fail.json","begin","guidance").is_empty(),"failed fifth-scene begin reported")
	check(state.snapshot()==pending_guidance,"failed fifth-scene save preserves marker and cursor")
	arrive(6)
	arrive(5)
	check(HomecomingQuest.story(state).active=="guidance","walking to red marker starts fifth scene")
	await switch_to("baishacun",5)
	check(map.event_state.is_active() and HomecomingQuest.story(state).line==0,"reload resumes arrival-triggered scene")
	check(HomecomingQuest.story(state).active=="guidance" and map.dialogue.visible and map.dialogue.picture.requested_visible and map.dialogue.picture.illustration.texture.resource_path=="res://assets/map-event-3-2.webp","fifth scene is standalone with requested illustration")
	var active_marker: Node = map.content.get_node_or_null("Points/N05/QuestSign")
	check(active_marker==null or not active_marker.visible,"arrival consumes available marker")
	var growth := state.growth.duplicate(true)
	map._advance_dialogue()
	map._advance_dialogue()
	await switch_to("baishacun",5)
	check(HomecomingQuest.story(state).active=="guidance" and HomecomingQuest.story(state).line==2,"fifth-scene interruption resumes saved line")
	await shot("fifth-standalone-dialogue")
	while HomecomingQuest.story(state).line<HomecomingQuest.data.scenes.guidance.lines.size()-1:
		if HomecomingQuest.story(state).reward_pending: map._accept_reward()
		else: map._advance_dialogue()
	var before := state.snapshot()
	check(not HomecomingQuest.command(state,directory+"missing/fail.json","advance").is_empty(),"failed fifth-scene completion save reported")
	check(state.snapshot()==before,"failed completion does not award guidance")
	map._advance_dialogue()
	check(HomecomingQuest.ready_for_practice(state) and state.narrative.flags.get(HomecomingQuest.GUIDED_FLAG,false),"finished fifth scene opens next main stage")
	while HomecomingQuest.story(state).active=="preparation": map._advance_dialogue()
	check(state.growth==growth,"talking does not award cultivation")
	check(not map.event_state.is_active() and not map.travel.paused,"fifth ends to free exploration")
	check(not HomecomingQuest.guidance_available(state),"completed fifth never repeats")
	await create_timer(0.25).timeout
	map.set_task_open(true)
	map.task_screen.task_list.select_task(HomecomingQuest.ID)
	check(map.task_screen.detail_body.people_slots.get_child(0).get_child(0).get_child(0).texture.resource_path=="res://assets/ui-portrait-mom-linwanqing.webp","task portrait uses mother asset")
	await shot("family-task-after-talks")
	map.set_task_open(false)
	# Earlier saves keep fully read guidance and resume partial old chat in the scene.
	var old_library := NpcDialogueLibrary.new()
	check(old_library.load_file("res://data/dialogues/mother.json").is_empty(),"load compatibility library")
	var legacy := pending_guidance.duplicate(true)
	legacy.quests[HomecomingQuest.ID].erase("guidance_completed")
	legacy.narrative.flags.erase("base.story.chaoshengguichu.guidance_standalone")
	check(DialogueJournal.select(legacy.narrative,old_library,"past",0,legacy.map_visited).is_empty(),"make old partial guidance journal")
	check(DialogueJournal.advance(legacy.narrative,old_library,0).is_empty(),"old guidance second line")
	check(state.restore(legacy).is_empty() and HomecomingQuest.guidance_available(state),"partial old journal restores pending scene")
	check(HomecomingQuest.command(state,path,"begin","guidance").is_empty() and HomecomingQuest.story(state).line==1,"old partial guidance resumes corresponding line")
	while "base.dialogue.mother.cultivation" not in legacy.narrative.npcs[HomecomingQuest.MOTHER].done:
		check(DialogueJournal.advance(legacy.narrative,old_library,0).is_empty(),"finish old guidance journal")
	check(state.restore(legacy).is_empty() and HomecomingQuest.ready_for_practice(state),"completed old guidance stays completed")
	check(not HomecomingQuest.guidance_available(state),"completed old guidance has no red marker")
	var previous_library := NpcDialogueLibrary.new()
	check(previous_library.load_file("res://data/dialogues/yesongnian.json").is_empty(),"existing NPC portrait data still validates")
	var result := {"checks":checks,"failures":failures,"render":render,"directory":directory}
	FileAccess.open(directory+"validation.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("HOMECOMING_FAMILY "+JSON.stringify(result))
	map.deactivate_location()
	map.free()
	quit(1 if failures else 0)
