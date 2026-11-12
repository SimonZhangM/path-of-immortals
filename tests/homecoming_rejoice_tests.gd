extends "res://tests/breakthrough_audio_tests.gd"

func reload_home() -> void:
	map.deactivate_location()
	map.free()
	map=load("res://scenes/maps/baishacun.tscn").instantiate()
	map.inventory_save_path=path
	map.arrival_point_id=HomecomingQuest.data.home.point_id
	map.defer_map_music=true
	map.defer_optional_views=true
	root.add_child(map)
	current_scene=map
	state=map.loadout
	await settle()
	map.set_process(false)
	check(map.startup_error.is_empty(),"home reload succeeds")

func run() -> void:
	if not await prepare_audio_fixture("res://artifacts/homecoming-rejoice-20261106"): quit(1); return
	root.content_scale_size=Vector2i.ZERO
	root.size=Vector2i(1920,1080)
	root.get_node("GameSettings").apply_values({"dialogue_speed":"instant","dialogue_auto":false})
	state.narrative.flags[HomecomingQuest.PREPARATION_FLAG]=true
	baseline=state.snapshot()
	map.travel.current_node_id=HomecomingQuest.data.home.point_id
	map.travel.map_position=map.travel.node_positions[map.travel.current_node_id]
	map.travel.stop_at_current_node()
	map.player.position=map.travel.map_position
	check(HomecomingQuest.configuration_error().is_empty(),"new dialogue configuration")
	check(not HomecomingQuest.rejoice_available(state),"mortal cannot celebrate")
	var flow: RefCounted=map.breakthrough_session
	check(flow.start(),"start real breakthrough")
	state.growth.breakthrough_attempt.progress=19900
	flow.advance(9)
	check(flow.phase=="succeeded" and state.growth.realm==1 and state.narrative.flags.get(HomecomingQuest.FIRST_QI_FLAG,false),"real payment reaches qi")
	check(HomecomingQuest.story(state).active.is_empty() and not HomecomingQuest.completed(state),"success alone does not play or complete story")
	map.homecoming_story_controller._process(0)
	check(HomecomingQuest.story(state).active.is_empty(),"startup recovery cannot interrupt breakthrough overlay")
	await click(map.breakthrough_screen.start_button)
	var picture: MapEventPicture=map.breakthrough_screen.completion_illustration
	check(picture!=null and picture.visible and HomecomingQuest.story(state).active.is_empty(),"completed button shows illustration before results")
	picture._group_tween.pause()
	picture._group_tween.custom_step(1.001)
	picture.dismiss()
	picture._group_tween.pause()
	picture._group_tween.custom_step(1.001)
	check(map.breakthrough_screen.result_view.visible and not map.dialogue.visible,"success result precedes dialogue")
	await click(map.breakthrough_screen.result_view.review_button)
	check(HomecomingQuest.story(state).active.is_empty(),"review does not begin story")
	flow.activate_primary()
	var successful := state.snapshot()
	flow.runtime.save_path=directory+"missing/result.json"
	await click(map.breakthrough_screen.result_view.confirm_button)
	check(map.is_breakthrough_open() and state.snapshot()==successful and HomecomingQuest.story(state).active.is_empty(),"failed result confirmation does not launch story")
	flow.runtime.save_path=path
	await click(map.breakthrough_screen.result_view.confirm_button)
	check(map._breakthrough_result_tween!=null and HomecomingQuest.story(state).active.is_empty(),"return transition precedes mother dialogue")
	map._breakthrough_result_tween.pause()
	map._breakthrough_result_tween.custom_step(1.001)
	check(not map.is_breakthrough_open() and map.dialogue.visible,"confirmation automatically opens dialogue")
	check(HomecomingQuest.story(state).active=="rejoice" and HomecomingQuest.story(state).line==0,"starts at first line without clicking home")
	check(map.travel.paused and map.event_state.is_active(),"story owns map input")
	var entry := HomecomingQuest.display_entry(state,{})
	check(entry.stage_id=="rejoice" and not entry.has_locked_next and not entry.objectives.back().completed,"final conversation remains required")
	var resources := state.growth.duplicate(true)
	var owned := state.carried_owned().duplicate(true)
	for i in 3: map._advance_dialogue()
	check(HomecomingQuest.story(state).line==3,"advance to mother's happy confirmation")
	if DisplayServer.get_name()!="headless": await capture("mother-rejoice-1080p")
	await reload_home()
	check(HomecomingQuest.story(state).active=="rejoice" and HomecomingQuest.story(state).line==3 and map.dialogue.visible,"disk reload resumes exact dialogue line")
	while HomecomingQuest.story(state).line<HomecomingQuest.data.scenes.rejoice.lines.size()-1:
		map._advance_dialogue()
	var before := state.snapshot()
	check(not HomecomingQuest.command(state,directory+"missing/final.json","advance").is_empty() and state.snapshot()==before,"failed final save does not complete task")
	map._advance_dialogue()
	await create_timer(0.25).timeout
	check(HomecomingQuest.completed(state) and HomecomingQuest.story(state).active.is_empty(),"last line completes task once")
	check(not map.travel.paused,"main three completion restores movement without a training notice")
	check(not map.dialogue.visible and not map.travel.paused,"ending releases dialogue and movement")
	entry=HomecomingQuest.display_entry(state,{})
	check(entry.stage_id=="completed" and entry.objectives.all(func(row): return row.completed),"all prior goals retained in completed task")
	check(HomecomingQuest.ID not in state.quest_tracking.ids,"completed quest no longer tracked")
	check(state.growth==resources and state.carried_owned()==owned,"conversation does not grant growth or items again")
	await reload_home()
	check(not map.dialogue.visible and HomecomingQuest.arrival(state,HomecomingQuest.data.home.map_id,HomecomingQuest.data.home.point_id).is_empty(),"completed reload and revisit never repeat")
	# Legacy actual success without a dialogue receipt catches up at home once.
	check(state.restore(successful).is_empty(),"restore earlier real-success snapshot")
	check(MapLoadoutStore.save(state,path).is_empty(),"save old unreported success")
	await reload_home()
	check(HomecomingQuest.story(state).active=="rejoice" and HomecomingQuest.story(state).line==0,"old genuine success catches up automatically")
	# A failed attempt and a prototype high realm do not meet the story condition.
	check(state.restore(baseline).is_empty(),"restore mortal baseline")
	state.growth.breakthrough_attempt={"version":2,"id":"base.breakthrough.first_qi","phase":"paused","progress":0,"elapsed_usec":299000000}
	check(MapLoadoutStore.save(state,path).is_empty(),"save expiring attempt")
	await reload_home()
	map.set_breakthrough_open(true)
	flow=map.breakthrough_session
	flow.set_paused(false)
	flow.advance(1)
	check(flow.phase=="failed","actual deadline failure")
	flow.activate_primary()
	await click(map.breakthrough_screen.result_view.confirm_button)
	check(not map.is_breakthrough_open() and HomecomingQuest.story(state).active.is_empty() and not HomecomingQuest.completed(state),"failed result returns freely without success dialogue")
	state.growth=CultivationGrowth.initial(1)
	check(not HomecomingQuest.rejoice_available(state),"high realm without actual first-qi flag does not fake story")
	# Closing the successful panel via the ordinary T/Esc path also resumes the story.
	check(state.restore(successful).is_empty(),"restore success for ordinary close")
	map.breakthrough_session.runtime.bind(state,map.player_status,path)
	map.set_breakthrough_open(true)
	map.set_breakthrough_open(false)
	check(HomecomingQuest.story(state).active=="rejoice","ordinary successful close starts dialogue too")
	print("HOMECOMING REJOICE: %d checks, %d failures; %s"%[checks,failures,directory])
	map.deactivate_location()
	map.free()
	quit(1 if failures else 0)
