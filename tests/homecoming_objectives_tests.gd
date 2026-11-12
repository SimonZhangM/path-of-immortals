extends "res://tests/save_actions_tests.gd"

func run() -> void:
	var registry := ContentRegistry.new()
	check(registry.load_base_content(),"content loads")
	var made := MapLoadoutStore.create_state(registry,registry.get_board("base.board.bag"))
	check(made.error.is_empty(),"isolated state created")
	var state: MapLoadoutState = made.state
	state.growth=CultivationGrowth.initial(0)
	var saved := HomecomingQuest.story(state)
	saved.accepted_location=HomecomingQuest.data.shop.map_id
	state.narrative.npcs[HomecomingQuest.MOTHER]={"done":[]}
	var ids := ["letter","home","mirror","past","guidance","cultivation_full","practice"]
	for step in 6:
		match step:
			1: saved.letter_received=true
			2: saved.home_reunited=true
			3: state.narrative.npcs[HomecomingQuest.MOTHER].done.append("base.dialogue.mother.mirror")
			4: state.narrative.npcs[HomecomingQuest.MOTHER].done.append("base.dialogue.mother.past")
			5: saved.guidance_completed=true
		var entry := HomecomingQuest.display_entry(state,{})
		var count := 7 if step==5 else step+1
		check(entry.stage_id==HomecomingQuest.OBJECTIVE_STAGES[step],"correct stage %d" % step)
		check(entry.objectives.map(func(row): return row.id)==ids.slice(0,count),"revealed history in order, no duplicates or future leak %d" % step)
		check(entry.objectives.slice(0,step).all(func(row): return row.completed and row.targets.is_empty()),"past goals completed and not navigated %d" % step)
		check(not entry.objectives[step].completed and entry.has_locked_next,"current goal pending, future stays locked %d" % step)
	var before := state.snapshot()
	var entry := HomecomingQuest.display_entry(state,{})
	check(not entry.objectives[5].completed and not entry.objectives[6].completed,"opening list never grants cultivation or qi success")
	check(state.snapshot()==before,"display is read-only")
	state.narrative.flags[HomecomingQuest.PRACTICE_STARTED_FLAG]=true
	entry=HomecomingQuest.display_entry(state,{})
	check(not entry.objectives[5].completed and not entry.objectives[6].completed,"old attempt history cannot satisfy cultivation prerequisite")
	check(entry.objectives[5].targets[0].point_id==HomecomingQuest.data.home.point_id and entry.objectives[6].targets.is_empty(),"old guidance save points home for supplementary teaching")
	state.narrative.flags[HomecomingQuest.PREPARATION_FLAG]=true
	state.growth.progress=CultivationGrowth.target(state.growth)-1
	entry=HomecomingQuest.display_entry(state,{})
	check(not entry.objectives[5].completed and entry.objectives[5].targets[0].map_id=="base.map.qingshihewan" and entry.objectives[6].targets.is_empty(),"below 100 percent points to battle cultivation only")
	state.growth.progress+=1
	entry=HomecomingQuest.display_entry(state,{})
	check(entry.objectives[5].completed and not entry.objectives[6].completed,"full ordinary cultivation completes prerequisite only")
	check(entry.objectives[5].targets.is_empty() and entry.objectives[6].targets[0].point_id==HomecomingQuest.data.home.point_id and entry.objectives[6].targets[0].point_marker,"100 percent switches tracking to mother's home")
	check(QuestTracking.objectives(entry).map(func(row): return row.id)==["practice"],"tracker drops historical objectives")
	state.growth.realm=1
	state.growth.progress=0
	entry=HomecomingQuest.display_entry(state,{})
	check(entry.objectives.all(func(row): return row.completed),"actual qi marks all revealed goals complete")
	check(entry.has_locked_next,"unimplemented report-to-mother stays locked")
	print("HOMECOMING OBJECTIVES: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
