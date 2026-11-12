extends "res://tests/river_quest_tests.gd"

func prerequisites(id: String, done_list: Array) -> void:
	for required: String in RiverQuest.data.scenes[id].requires:
		prerequisites(required,done_list)
		if required not in done_list: done_list.append(required)

func run() -> void:
	create_timer(55).timeout.connect(func(): quit(2))
	await scenario()
	map.deactivate_location(); map.free()
	state=null
	await settle()
	quit(1 if failures else 0)

func scenario() -> void:
	directory="res://artifacts/river-training-20261106/run-%d/"%Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	Slots.auto_path=directory+"auto.json"
	Session.index_path=directory+"session.json"
	Session.clear_selection()
	path=Slots.working_path()
	root.get_node("SavePlaytime").set_process(false)
	root.get_node("GameSettings").apply_values({"background_pause":false,"dialogue_speed":"instant","dialogue_auto":false})
	root.get_node("GameSettings").set_application_focus(true)
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size=Vector2i.ZERO
	root.size=Vector2i(1920,1080)
	render=DisplayServer.get_name()!="headless"
	await switch_to("qingshizhen",32)
	check(not map.content.get_node("Points/N05/Sign").visible,"town sign disabled before receiving board")
	var fixture:=state.snapshot()
	fixture.growth=CultivationGrowth.initial(0)
	fixture.board_id="base.board.bag"
	fixture.placements=[]
	fixture.learning={"version":1,"learned":{},"practice":{}}
	for id: String in fixture.quests[QuestState.ID].counts: fixture.quests[QuestState.ID].counts[id]=1
	fixture.quests[QuestState.ID].story=QuestStory.migrated({"counts":fixture.quests[QuestState.ID].counts})
	var saved: Dictionary=fixture.quests[RiverQuest.ID]
	saved.done=[]
	prerequisites("gift_board",saved.done)
	saved.active="gift_board"; saved.line=6; saved.reward_pending=true
	saved.location={"map_id":RiverQuest.TOWN,"point_id":RiverQuest.data.scenes.gift_board.point_id}
	var restore_error:=state.restore(fixture)
	check(restore_error.is_empty(),"pre-board mortal fixture: "+restore_error)
	if not restore_error.is_empty(): map.free(); quit(1); return
	check(state.add_reward(RiverQuest.data.scenes.gift_book.reward).is_empty(),"book already received")
	check(MapLoadoutStore.save(state,path).is_empty(),"fixture persists")
	map.river_story_controller.present()
	check(not RiverQuest.training_notice_pending(state) and map.river_story_controller.completion_notice==null,"board receipt not yet confirmed: no notice")
	var before:=state.snapshot()
	map.inventory_save_path=directory+"missing/receive.json"
	map._accept_reward()
	check(state.snapshot()==before and map.river_story_controller.completion_notice==null,"failed item save neither grants nor unlocks")
	map.inventory_save_path=path
	# Explicitly reserved boards must not unlock until actually claimed.
	var branch: MapLoadoutState=MapLoadoutStore.candidate(state).state
	branch.storage_capacity_rules=state.storage_capacity_rules.duplicate(true)
	var packed:=branch.snapshot()
	for unit: String in packed.owned_units.keys():
		if packed.owned_units[unit]=="base.map_item.qinglan_board_1": packed.owned_units.erase(unit)
	check(branch.restore(packed).is_empty(),"reserved board has no existing inventory stack")
	branch.storage_capacity_rules.test_capacity_override=branch.storage_used_slots()
	check(not RiverQuest.command(branch,"","accept").is_empty(),"full bag does not silently grant board")
	check(RiverQuest.command(branch,"","reserve").is_empty() and not RiverQuest.training_notice_pending(branch),"reserve does not unlock or notify")
	branch.storage_capacity_rules.test_capacity_override=999
	check(RiverQuest.command(branch,"","claim_parcels").is_empty() and RiverQuest.training_notice_pending(branch),"actual parcel receipt queues notice")
	map._accept_reward()
	await settle()
	var dialog: Control=map.river_story_controller.completion_notice
	check(dialog!=null and dialog.visible and RiverQuest.training_notice_pending(state),"receiving board immediately shows notice")
	check(RiverQuest.story(state).active=="gift_board" and RiverQuest.story(state).line==7,"remaining thanks preserved behind notice")
	check(dialog.message.text==RiverQuest.data.training_notice and not dialog.cancel_button.visible,"notice names available river site and offers confirmation")
	check(map.travel.paused and map.event_state.phase=="notice" and not map.dialogue.visible,"notice pauses story and movement")
	if render: await shot("board-training-notice")
	map._advance_dialogue()
	check(RiverQuest.story(state).line==7 and dialog.visible,"story advance cannot skip confirmation")
	var escape:=InputEventKey.new()
	escape.keycode=KEY_ESCAPE; escape.pressed=true
	root.push_input(escape,true)
	check(dialog.visible,"escape cannot dismiss notice")
	await switch_to("qingshizhen",32)
	dialog=map.river_story_controller.completion_notice
	check(dialog!=null and dialog.visible,"unconfirmed receipt resumes notice on reload")
	before=state.snapshot()
	map.inventory_save_path=directory+"missing/confirm.json"
	await click(dialog.confirm_button)
	check(dialog.visible and not dialog.error_label.text.is_empty() and state.snapshot()==before,"failed confirmation keeps notice and state")
	map.inventory_save_path=path
	await click(dialog.confirm_button)
	check(not dialog.visible and state.narrative.flags.get(RiverQuest.CULTIVATION_UNLOCKED_FLAG,false),"confirmation persistently unlocks")
	check(map.dialogue.visible and RiverQuest.story(state).line==7,"confirmation resumes player's thanks")
	check(not map.content.get_node("Points/N05/Sign").visible,"town sign stays disabled after unlock")
	var town_event: Dictionary=map.event_registry.events["base.map_event.qingshizhen.cultivation"]
	check(not map.event_state.try_start(town_event.point_id,town_event.point_id,true,"click") and not MapEventRegistry.is_unlocked(state,town_event),"town popup remains unavailable")
	finish_scene("gift_board")
	finish_scene("closing")
	check(not map.event_state.is_active() and not RiverQuest.training_notice_pending(state),"main two finishes without another notice")
	await switch_to("qingshihewan",32)
	arrive(32)
	var river_event: Dictionary=map.event_registry.events["base.map_event.qingshihewan.cultivation_n32"]
	check(map.content.get_node("Points/N32/Sign").visible and map.event_state.active_id==river_event.id,"unlocked river site opens on arrival")
	check(state.growth.realm==0,"river cultivation available before qi breakthrough")
	check(state.select_board("base.map_item.qinglan_board_1").is_empty(),"mortal can equip received Xiaolan")
	map._request_cultivation("cultivation",10)
	check(map.cultivation_session!=null and map.cultivation_session.active and map.cultivation_progress_dialog.visible,"mortal enters actual river cultivation session")
	map._toggle_cultivation_pause()
	check(map.cultivation_session.started and not map.cultivation_session.paused and map.cultivation_session.error.is_empty(),"mortal starts cultivation using Xiaolan")
	map._close_cultivation()
	map.event_state.active_id=""; map.event_state.phase=""
	var locked:=state.snapshot()
	locked.narrative.flags.erase(RiverQuest.CULTIVATION_UNLOCKED_FLAG)
	locked.narrative.flags["base.story.chaoshengguichu.cultivation_unlocked"]=true
	check(state.restore(locked).is_empty(),"legacy completion flag fixture")
	check(not map.content.get_node("Points/N32/Sign").visible,"legacy main-three flag cannot open river site")
	check(not map.event_state.try_start(river_event.point_id,river_event.point_id,true,"arrival",true) and not map.event_state.try_start(river_event.point_id,river_event.point_id,true,"click"),"locked river site blocks arrival and click")
	check(RiverQuest.training_notice_pending(state),"old board recipients get one replacement notice")
	check(RiverQuest.command(state,path,"acknowledge_training_notice").is_empty(),"old receipt can confirm")
	check(not RiverQuest.training_notice_pending(state) and map.content.get_node("Points/N32/Sign").visible,"confirmation restores river sign without moving node")
	var objective: Dictionary=HomecomingQuest.data.objectives.practice[0]
	check(objective.text=="积累修为至100%，具备突破条件" and objective.targets[0].point_id==river_event.point_id,"practice objective points to available river site")
	check(HomecomingQuest.data.objectives.practice[1].text=="在母亲家尝试突破，达到炼气一层","objective omits keyboard instruction")
	for line: String in HomecomingQuest.data.scenes.preparation.lines:
		check("100%" not in line and "按T" not in line and "气血和体力" not in line,"mother dialogue stays in character")
	print("RIVER TRAINING: %d checks, %d failures; %s"%[checks,failures,directory])
