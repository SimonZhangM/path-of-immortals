extends "res://tests/breakthrough_audio_tests.gd"

func run() -> void:
	if not await prepare_audio_fixture("res://artifacts/homecoming-preparation-20261106"): quit(1); return
	root.content_scale_size=Vector2i.ZERO
	root.size=Vector2i(1920,1080)
	root.get_node("GameSettings").apply_values({"dialogue_speed":"instant","dialogue_auto":false})
	map.set_breakthrough_open(false)
	state.growth.progress=CultivationGrowth.target(state.growth)-1
	var flow := new_run()
	var before := state.snapshot()
	check(not flow.start() and flow.error.contains("100%") and state.snapshot()==before,"below 100 percent start rejected without spending or saving")
	state.growth.breakthrough_attempt={"version":2,"id":"base.breakthrough.first_qi","phase":"paused","progress":9100,"elapsed_usec":9000000}
	flow=new_run(); before=state.snapshot()
	flow.set_paused(false)
	check(flow.phase=="paused" and flow.error.contains("100%") and state.snapshot()==before,"old unfinished attempt retained but cannot resume below 100 percent")
	state.growth.progress+=1
	flow.set_paused(false)
	check(flow.phase=="running" and flow.progress()==9100,"full ordinary cultivation permits continuing saved attempt")
	flow.set_paused(true)
	flow.reset()
	state.growth.progress=0
	state.narrative.flags.erase(HomecomingQuest.PREPARATION_FLAG)
	check(HomecomingQuest.configuration_error().is_empty(),"supplementary scene configuration valid")
	check(HomecomingQuest.arrival(state,HomecomingQuest.data.home.map_id,HomecomingQuest.data.home.point_id)=="preparation","legacy guidance-complete mortal gets only new explanation")
	var owned := state.carried_owned().duplicate(true)
	check(HomecomingQuest.command(state,path,"begin","preparation").is_empty(),"start supplemental teaching")
	check(HomecomingQuest.command(state,path,"advance").is_empty(),"advance to prerequisite explanation")
	var reloaded: MapLoadoutState=MapLoadoutStore.candidate(state).state
	check(MapLoadoutStore.load_into(reloaded,path).is_empty() and HomecomingQuest.story(reloaded).active=="preparation" and HomecomingQuest.story(reloaded).line==1,"teaching resumes at saved line after disk reload")
	map.homecoming_story_controller.present()
	if DisplayServer.get_name()!="headless": await capture("mother-preparation")
	while HomecomingQuest.story(state).line<HomecomingQuest.data.scenes.preparation.lines.size()-1:
		check(HomecomingQuest.command(state,path,"advance").is_empty(),"continue teaching")
	before=state.snapshot()
	check(not HomecomingQuest.command(state,directory+"missing/no.json","advance").is_empty() and state.snapshot()==before,"failed teaching completion save preserves cursor")
	map.homecoming_story_controller.advance()
	check(state.narrative.flags.get(HomecomingQuest.PREPARATION_FLAG,false) and HomecomingQuest.story(state).active.is_empty(),"teaching finishes with one-time receipt")
	check(state.carried_owned()==owned and state.growth.progress==0,"teaching grants no extra gifts or cultivation")
	check(HomecomingQuest.arrival(state,HomecomingQuest.data.home.map_id,HomecomingQuest.data.home.point_id).is_empty(),"returning home does not repeat teaching")
	map.set_task_open(true)
	map.task_screen.task_list.select_task(HomecomingQuest.ID)
	if DisplayServer.get_name()!="headless": await capture("two-practice-objectives")
	map.set_task_open(false)
	var completed := state.snapshot()
	# Finishing the original gift scene chains to teaching without changing its reward cursor.
	state.narrative.flags.erase(HomecomingQuest.PREPARATION_FLAG)
	var quest := HomecomingQuest.story(state)
	quest.guidance_completed=false; quest.active="guidance"
	quest.line=HomecomingQuest.data.scenes.guidance.lines.size()-1
	quest.location=HomecomingQuest.data.home.duplicate(true)
	check(HomecomingQuest.command(state,path,"advance").is_empty() and HomecomingQuest.story(state).active=="preparation" and HomecomingQuest.story(state).line==0,"new guidance completion chains into preparation")
	check(state.carried_owned()==owned,"chaining never repeats guide stone receipt")
	check(state.restore(completed).is_empty(),"restore taught fixture")
	# Ordinary mother chat selects the appropriate branch; opening a failed command is not a failed breakthrough.
	var library := NpcDialogueLibrary.new()
	check(library.load_file("res://data/dialogues/mother.json").is_empty(),"mother conditional dialogue loads")
	check(NpcDialogueActions.command(state,library,"visit",path).is_empty(),"visit mother")
	check(NpcDialogueActions.command(state,library,"advance",path).is_empty(),"finish greeting")
	check(DialogueJournal.next_segment(state.narrative,library,"chat",state.map_visited)=="base.dialogue.mother.practice_pending","unfinished cultivation receives preparation advice")
	state.growth.progress=CultivationGrowth.target(state.growth)
	QuestState.sync_flags(state)
	check(DialogueJournal.next_segment(state.narrative,library,"chat",state.map_visited)=="base.dialogue.mother.practice_ready","full cultivation receives readiness advice")
	state.growth.breakthrough_attempt={"version":2,"id":"base.breakthrough.first_qi","phase":"paused","progress":0,"elapsed_usec":Run.new().limit_usec()-1000000}
	flow=new_run()
	flow.set_paused(false); flow.advance(1.0)
	check(flow.phase=="failed" and state.narrative.flags.get(HomecomingQuest.BREAKTHROUGH_FAILED_FLAG,false),"actual timeout records failure")
	check(flow.reset(),"exit failed attempt")
	check(DialogueJournal.next_segment(state.narrative,library,"chat",state.map_visited)=="base.dialogue.mother.practice_failed","after exiting failure mother offers original reassurance")
	check(NpcDialogueActions.command(state,library,"select",path,"chat").is_empty(),"select failure dialogue")
	check(DialogueJournal.view(state.narrative,library,state.map_visited).rows.back().text=="娘，我照着练了，可还是留不住那口气。","failure line delivered through actual chat")
	check(flow.start() and not state.narrative.flags.get(HomecomingQuest.BREAKTHROUGH_FAILED_FLAG,true),"new attempt clears prior failure context")
	flow.set_paused(true)
	state.growth.breakthrough_attempt.progress=20000
	check(flow._settle_step(state,0.0).is_empty(),"settle actual first qi success")
	QuestState.sync_flags(state)
	check(HomecomingQuest.cultivation_full(state) and not HomecomingQuest.preparation_available(state),"success preserves cultivation objective and suppresses remedial teaching")
	check(not DialogueConditions.eligible(state.narrative,library.segments["base.dialogue.mother.practice_failed"],HomecomingQuest.MOTHER),"success disables failure dialogue")
	print("HOMECOMING PREPARATION: %d checks, %d failures; %s" % [checks,failures,directory])
	map.deactivate_location()
	map.free()
	quit(1 if failures else 0)
