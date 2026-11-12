extends "res://tests/breakthrough_audio_tests.gd"

func seed_new(progress_value: int, elapsed: int, with_guide := false) -> RefCounted:
	restore_fixture()
	if with_guide: equip_guide()
	state.growth.breakthrough_attempt={"version":2,"id":"base.breakthrough.first_qi","phase":"paused","progress":progress_value,"elapsed_usec":elapsed,"recent_gains":[]}
	check(CultivationGrowth.valid(state.growth),"new timing seed is valid")
	return new_run()

func shown(grid: BattleStatusIcons) -> Array[String]:
	var names: Array[String]=[]
	for child: Control in grid.get_children():
		if child.visible: names.append(child.name)
	return names

func run() -> void:
	root.content_scale_size=Vector2i.ZERO
	root.size=Vector2i(2560,1440)
	if not await prepare_audio_fixture("res://artifacts/breakthrough-day-buffs-20261105"): quit(1); return
	var flow: RefCounted=map.breakthrough_session
	var screen: Control=map.breakthrough_screen
	check(flow.reset(),"reset isolated setup")
	restore_fixture(); equip_guide()
	var day_before := WorldCalendar.current_day(state.calendar)
	check(flow.start(),"start revised first qi")
	check(flow.runtime.target()==20000 and flow.runtime.limit_usec()==300000000,"200 points and 30 ten-second days")
	check(screen.progress_required.text=="200" and screen.remaining_value.text=="30天","new target visible")
	check(not screen.element_buffs.visible,"empty buff bar hidden")
	flow.advance(6)
	check(flow.runtime.progress()==800 and state.growth.day_usec==36000000,"CD remains six real simulation seconds, calendar uses sixfold fraction")
	flow.advance(4)
	check(WorldCalendar.current_day(state.calendar)==day_before+1 and state.growth.day_usec==0 and flow.runtime.remaining_days()==29,"ten board seconds advance one actual calendar day")
	flow.advance(6)
	check(flow.runtime.progress()==1600 and flow.runtime.recent_gain()==800,"efficiency includes only most recent ten seconds")
	flow.advance(2)
	check(flow.runtime.recent_gain()==1600,"two paid activations in ten-second window")
	flow.set_paused(true)
	var before := state.snapshot()
	flow.advance(20)
	check(state.snapshot()==before,"pause stops calendar and progress")
	var sim: CultivationTraining=flow.runtime.training.simulation
	var actor: PartyMemberState=flow.runtime.status_member()
	actor.definition.status_capacity=30
	var time: int=sim.state.time_usec
	for word: String in ["轻灵","生机","润脉","反锋","附炎","坚韧","雷蕴"]:
		check(sim.t01.apply_status(actor,word,3,actor,time),"apply real elemental buff "+word)
	check(sim.t01.apply_status(actor,"流血",2,actor,time),"debuff fixture")
	actor.armor=9
	actor.barrier=8
	flow.runtime.changed.emit()
	var grid: BattleStatusIcons=screen.element_buffs
	check(grid.slots.size()==7 and shown(grid)==["轻灵","生机","润脉","反锋","附炎","坚韧","雷蕴"],"only elemental buffs in acquisition order")
	var battle := BattleStatusIcons.new()
	battle.show_all_for_testing=false
	root.add_child(battle); battle.configure(); battle.refresh(actor)
	for word: String in grid.slots:
		check(grid.counts[word].text==battle.counts[word].text and grid.slots[word].get_node("Icon").texture==battle.slots[word].get_node("Icon").texture,"same battle icon and layer badge "+word)
	await settle()
	for word: String in grid.slots:
		var label: Label=grid.counts[word]
		check(label.get_children().all(func(edge): return edge.size.is_equal_approx(label.size)),"layer outline stays aligned "+word)
	battle.free()
	for resolution: Vector2i in [Vector2i(2560,1440),Vector2i(1920,1080)]:
		root.size=resolution
		await settle()
		var rect: Rect2=screen._rect(screen.layout_reference.element_buffs.rect)
		check(rect.encloses(Rect2(grid.position,grid.size*grid.scale)),"seven buffs fit base strip "+str(resolution.x))
		if DisplayServer.get_name()!="headless": await capture("element-buffs-"+str(resolution.x))
	flow.set_paused(false); flow.advance(1)
	check(grid.counts["生机"].text=="2" and grid.counts["润脉"].text=="2","actual status tick updates layer count")
	sim.t01.consume(actor,"轻灵",99)
	sim.t01.apply_status(actor,"轻灵",1,actor,sim.state.time_usec)
	flow.runtime.changed.emit()
	check(shown(grid).back()=="轻灵" and grid.counts["轻灵"].text=="1","reapplied buff moves to end like battle")
	check(flow.reset() and not grid.visible,"reset clears transient buff strip")
	# Exact deadline, target and failed-save boundaries, without replaying unrelated UI.
	var last := seed_new(19950,294000000,true)
	last.set_paused(false); last.advance(10)
	check(last.phase=="succeeded" and last.elapsed_usec()==300000000 and last.progress()==20000,"target at deadline succeeds at 200")
	check(int(state.growth.realm)==1,"actual realm promotion")
	var timeout := seed_new(10000,299500000)
	timeout.set_paused(false); timeout.advance(2)
	check(timeout.phase=="failed" and timeout.progress()==0 and timeout.elapsed_usec()==300000000,"timeout clears attempt at 300 seconds")
	var failed := seed_new(19950,0,true)
	failed.set_paused(false); failed.advance(5)
	before=state.snapshot()
	failed.training.save_path=directory+"missing/fail.json"
	failed.advance(1)
	check(failed.phase=="paused" and state.snapshot()==before,"failure cannot spend or promote")
	# Old ongoing saves preserve elapsed days and earned points, without forged rates.
	var old := baseline.duplicate(true)
	old.growth.breakthrough_attempt={"version":1,"id":"base.breakthrough.first_qi","phase":"paused","progress":8000,"elapsed_usec":120000000,"recent_gains":[{"at_usec":119000000,"amount":100}]}
	check(state.restore(old).is_empty(),"legacy ongoing save accepted")
	check(state.growth.breakthrough_attempt.version==2 and state.growth.breakthrough_attempt.elapsed_usec==20000000 and state.growth.breakthrough_attempt.progress==8000,"legacy two days and eighty points preserved")
	var resumed := new_run()
	check(resumed.phase=="paused" and resumed.remaining_days()==28 and resumed.recent_gain()==0,"legacy reload pauses and resets obsolete rate samples")
	check(state.restore(state.snapshot()).is_empty() and state.growth.breakthrough_attempt.elapsed_usec==20000000,"migration idempotent")
	old.growth.realm=1
	old.growth.breakthrough_attempt={"version":1,"id":"base.breakthrough.first_qi","phase":"succeeded","progress":10000,"elapsed_usec":200000000}
	check(state.restore(old).is_empty() and new_run().phase=="succeeded" and int(state.growth.realm)==1,"legacy success remains earned")
	check(new_run().target()==10000 and new_run().remaining_days()==27,"legacy completion retains historical target and elapsed days")
	# Ordinary cultivation still uses sixty seconds per day.
	restore_fixture(); equip_guide()
	var ordinary := MapCultivationSession.new()
	ordinary.begin({"id":"base.map_event.qingshizhen.cultivation","durations":[5],"modes":[{"id":"cultivation","name":"修炼"}]},"cultivation",5,WorldCalendar.current_day(state.calendar))
	check(ordinary.bind(state,map.player_status,path),"ordinary cultivation starts")
	day_before=WorldCalendar.current_day(state.calendar)
	ordinary.set_paused(false,0); ordinary.advance(10)
	check(WorldCalendar.current_day(state.calendar)==day_before and state.growth.day_usec==10000000,"ordinary ten seconds are still one sixth day")
	ordinary.advance(50)
	check(WorldCalendar.current_day(state.calendar)==day_before+1 and state.growth.day_usec==0,"ordinary full day remains sixty seconds")
	map.deactivate_location(); map.free()
	await settle()
	var result := {"checks":checks,"failures":failures,"directory":directory}
	FileAccess.open(directory+"validation.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("BREAKTHROUGH_DAY_BUFFS "+JSON.stringify(result))
	quit(1 if failures else 0)
