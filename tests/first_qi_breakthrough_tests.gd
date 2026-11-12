extends "res://tests/save_actions_tests.gd"
const Run = preload("res://scripts/map/map_breakthrough_run.gd")
const GUIDE := "base.map_item.training_guide_stone"
var state: MapLoadoutState
var map: Control
var baseline: Dictionary
var path := ""

func restore_fixture() -> void:
	var error := state.restore(baseline)
	check(error.is_empty(),"restore isolated mortal fixture: "+error)
	if not error.is_empty(): quit(1)
	map.player_status.apply_growth(state.growth)

func new_run() -> RefCounted:
	var run := Run.new()
	run.bind(state,map.player_status,path)
	return run

func equip_guide() -> void:
	check(state.inventory.add_item("test.first_qi.guide",GUIDE,Vector2i.ZERO),"equip real guide stone")
	state.storage.take_one("test.first_qi.guide")

func seed_attempt(progress_cents: int, elapsed: int, guide := false) -> RefCounted:
	restore_fixture()
	if guide: equip_guide()
	state.growth.breakthrough_attempt={"version":2,"id":"base.breakthrough.first_qi","phase":"paused","progress":progress_cents,"elapsed_usec":elapsed}
	check(CultivationGrowth.valid(state.growth),"valid seeded boundary state")
	return new_run()

func run() -> void:
	create_timer(55).timeout.connect(func(): quit(2))
	directory="res://artifacts/first-qi-20261105/run-%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	Slots.auto_path=directory+"auto.json"
	Session.index_path=directory+"session.json"
	Session.clear_selection()
	path=directory+"working.json"
	root.get_node("SavePlaytime").set_process(false)
	root.get_node("GameSettings").apply_values({"background_pause":false,"background_mute":false})
	root.get_node("GameSettings").set_application_focus(true)
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size=Vector2i.ZERO
	root.size=Vector2i(2560,1440)
	map=load("res://scenes/maps/baishacun.tscn").instantiate()
	map.inventory_save_path=""
	map.defer_map_music=true; map.defer_optional_views=true
	root.add_child(map)
	await settle()
	map.set_process(false)
	check(map.startup_error.is_empty(),"map startup: "+map.startup_error)
	if not map.startup_error.is_empty(): quit(1); return
	state=map.loadout
	var original := state.snapshot()
	var high := new_run()
	check(not high.start() and state.snapshot()==original,"high realm cannot fake first qi or be downgraded")
	baseline=state.snapshot()
	baseline.placements=[]
	baseline.board_id="base.board.qinglan_1"
	baseline.growth=CultivationGrowth.initial(0)
	baseline.growth.progress=CultivationGrowth.target(baseline.growth)
	baseline.growth.resources={"hp":5000,"stamina":5000,"spirit":5000}
	baseline.learning={"version":1,"learned":{},"practice":{}}
	baseline.map_location=HomecomingQuest.data.home.duplicate(true)
	baseline.owned_units["test.first_qi.guide"]=GUIDE
	baseline.content_grants["training.guide.v1"]=true
	baseline.narrative.flags.erase(Run.FIRST_QI_FLAG)
	for target: Dictionary in QuestState.definition.objectives: baseline.quests[QuestState.ID].counts[target.id]=target.required
	baseline.quests[QuestState.ID].story=QuestStory.migrated({"counts":baseline.quests[QuestState.ID].counts})
	baseline.quests[RiverQuest.ID].done=["traces","injured","entrance","root","mirror","beasts_gone","medicine","return_jade","invite_doctor","pickup","clinic_arrival","gift_book","closing"]
	baseline.quests[RiverQuest.ID].accepted_location=RiverQuest.RIVER
	var quest: Dictionary=baseline.quests[HomecomingQuest.ID]
	quest.active=""; quest.line=0; quest.location={}; quest.reward_pending=false
	quest.accepted_location=HomecomingQuest.data.shop.map_id
	quest.letter_received=true; quest.home_reunited=true; quest.guidance_completed=true
	restore_fixture()
	var goals := HomecomingQuest.display_entry(state,{}).objectives as Array
	check(goals.map(func(row): return row.id)==["letter","home","mirror","past","guidance","cultivation_full","practice"],"practice retains revealed history and separates cultivation from qi success")
	check(goals.slice(0,6).all(func(row): return row.completed) and not goals[6].completed,"full cultivation checked while qi remains pending")
	HomecomingQuest.story(state).guidance_completed=false
	var locked := new_run()
	var before := state.snapshot()
	check(not locked.start() and state.snapshot()==before,"mother guidance gate")
	restore_fixture()
	state.map_location=HomecomingQuest.data.shop.duplicate(true)
	check(not new_run().start(),"first attempt requires mother's home")
	restore_fixture()
	check(state.select_board("base.map_item.bag_board").is_empty(),"basic bag fixture equipped")
	var bag_run := new_run()
	before=state.snapshot()
	check(not bag_run.start() and bag_run.error.contains("晓岚") and state.snapshot()==before,"basic bag rejects start without changing state")
	restore_fixture()
	var paused_run := new_run()
	check(paused_run.start(),"Xiaolan can start")
	goals=HomecomingQuest.display_entry(state,{}).objectives
	check(goals[5].completed and not goals[6].completed,"starting marks attempt only, never qi success")
	paused_run.set_paused(true)
	check(state.select_board("base.map_item.bag_board").is_empty(),"paused attempt equips basic bag")
	before=state.snapshot()
	paused_run.set_paused(false)
	check(paused_run.phase=="paused" and paused_run.error.contains("基础行囊") and state.snapshot()==before,"basic bag cannot resume or consume resources")
	check(state.select_board("base.map_item.qinglan_board_1").is_empty(),"paused attempt restores Xiaolan")
	paused_run.set_paused(false)
	check(paused_run.phase=="running","Xiaolan allows resume")
	paused_run.set_paused(true)
	restore_fixture()
	map.inventory_save_path=path
	map.set_breakthrough_open(true)
	await settle()
	var screen: Control=map.breakthrough_screen
	var flow: RefCounted=map.breakthrough_session
	check(screen.progress_current.text=="0.0" and screen.progress_required.text=="200" and screen.remaining_value.text=="30天","real initial target and whole-day deadline")
	await click(screen.start_button)
	check(flow.phase=="running" and not screen.primary_start_art.visible and screen.primary_running_art.visible,"start click begins real attempt")
	map._process(6)
	check(flow.runtime.progress()==0 and flow.runtime.elapsed_usec()==6000000,"empty board never earns imaginary cultivation")
	await click(screen.pause_button)
	before=state.snapshot()
	map._process(60)
	check(flow.phase=="paused" and state.snapshot()==before,"pause freezes value resources and deadline")
	check(not screen.change_button.disabled,"pause permits adjustment")
	equip_guide()
	await click(screen.pause_button)
	check(screen.board_view.cooldown_state("test.first_qi.guide").entry==3000000,"breakthrough view shows real insertion cooldown")
	map._process(3)
	check(flow.runtime.progress()==0,"newly inserted item retains shared three-second entry cooldown")
	check(screen.board_view.cooldown_state("test.first_qi.guide").remaining==3000000,"view reads remaining training cooldown")
	map._process(3)
	check(flow.runtime.progress()==300,"actual guide payment produces three points from three stamina without spirit")
	check(int(state.growth.resources.stamina)==4700 and int(state.growth.resources.spirit)==0,"actual stamina and spirit costs persisted")
	check(screen.progress_fill.value>0 and screen.progress_current.text=="3.0" and screen.progress_required.text=="200","progress view reads actual fractional value")
	map._process(0.25)
	check(screen.board_view.cooldown_state("test.first_qi.guide").remaining==2750000,"CD presentation smoothly interpolates authoritative fractional time")
	map.set_breakthrough_open(false)
	check(flow.phase=="paused" and flow.runtime.elapsed_usec()==12250000,"temporary close flushes fraction and preserves attempt")
	var frozen_cd: Dictionary=screen.board_view.cooldown_state("test.first_qi.guide")
	map._process(5)
	check(screen.board_view.cooldown_state("test.first_qi.guide")==frozen_cd,"paused cooldown visuals stay frozen")
	var timers_before: Dictionary=flow.runtime.training.simulation.timeline.timers.duplicate(true)
	var queue_before: int=flow.runtime.training.simulation.state.time_usec
	flow.runtime.cooldown_snapshot()
	check(flow.runtime.training.simulation.timeline.timers==timers_before and flow.runtime.training.simulation.state.time_usec==queue_before,"cooldown presentation never mutates simulation timers")
	var reopened := new_run()
	check(reopened.phase=="paused" and reopened.progress()==300 and reopened.elapsed_usec()==12250000,"saved attempt reopens paused")
	var durable := MapLoadoutStore.candidate(state)
	check(durable.error.is_empty() and MapLoadoutStore.load_into(durable.state,path).is_empty(),"load ongoing attempt from disk")
	var durable_run := Run.new()
	durable_run.bind(durable.state,map.player_status,path)
	check(durable_run.phase=="paused" and durable_run.progress()==300 and durable_run.elapsed_usec()==12250000,"disk reload preserves value and limit without auto-resume")
	var legacy := MapCultivationSession.new()
	legacy.loadout=state
	check(not legacy.breakthrough(),"legacy settlement cannot bypass active attempt")
	map.set_breakthrough_open(true)
	if DisplayServer.get_name()!="headless": await capture("paused-2560")
	var resources_before: Dictionary=state.growth.resources.duplicate(true)
	var calendar_before: Dictionary=state.calendar.duplicate(true)
	await click(screen.exit_button)
	await click(map.breakthrough_exit_dialog.confirm_button)
	check(not map.is_breakthrough_open() and not state.growth.has("breakthrough_attempt"),"red exit clears actual attempt")
	check(HomecomingQuest.display_entry(state,{}).objectives[5].completed,"exiting attempt preserves full cultivation objective")
	check(state.growth.resources==resources_before and state.calendar==calendar_before,"red exit never refunds costs or days")
	map.set_breakthrough_open(true)
	check(screen.primary_start_art.visible and not screen.primary_running_art.visible and flow.elapsed_usec==0,"red exit restores initial pictures and circle")
	root.size=Vector2i(1920,1080)
	await settle()
	if DisplayServer.get_name()!="headless": await capture("ready-1920")
	map.set_breakthrough_open(false)
	# Exact deadline, cap, success priority, and no extra old one-day charge.
	var limit: int=Run.new().limit_usec()
	var success := seed_attempt(19950,limit-3000000,true)
	var day_before := WorldCalendar.current_day(state.calendar)
	success.set_paused(false)
	success.advance(20)
	check(success.phase=="succeeded" and success.elapsed_usec()==limit,"target on deadline wins over timeout, large delta stops there")
	check(state.growth.realm==1 and state.growth.layer==1 and state.growth.progress==0,"real realm and layer transition")
	check(success.progress()==20000 and state.narrative.flags.get(Run.FIRST_QI_FLAG,false),"clamped target and actual story flag")
	check(WorldCalendar.current_day(state.calendar)==day_before and state.growth.day_usec==18000000,"no extra fixed one-day settlement")
	var entry := HomecomingQuest.display_entry(state,{})
	check(entry.objectives.filter(func(row): return row.id=="practice")[0].completed,"sixth-stage objective reads actual qi realm")
	if DisplayServer.get_name()!="headless":
		flow.runtime=success
		success.changed.connect(flow._sync_runtime)
		flow._sync_runtime()
		root.size=Vector2i(2560,1440)
		map.set_breakthrough_open(true)
		await capture("success-2560")
		map.set_breakthrough_open(false)
	before=state.snapshot()
	success.advance(600)
	check(state.snapshot()==before and not success.start(),"success cannot settle twice")
	check(success.reset() and state.growth.realm==1,"exit after success preserves earned realm")
	var timeout := seed_attempt(9000,limit-500000)
	state.growth.day_usec=59500000
	day_before=WorldCalendar.current_day(state.calendar)
	resources_before=state.growth.resources.duplicate(true)
	timeout.set_paused(false)
	timeout.advance(50)
	check(timeout.phase=="failed" and timeout.progress()==0 and timeout.elapsed_usec()==limit,"fractional deadline fails and clears progress")
	check(state.growth.realm==0 and not state.narrative.flags.get(Run.FIRST_QI_FLAG,false),"timeout never grants qi or story success")
	check(state.growth.resources==resources_before and WorldCalendar.current_day(state.calendar)==day_before+1,"timeout has no extra penalty and retains elapsed day")
	check(timeout.reset() and timeout.start() and timeout.progress()==0 and timeout.elapsed_usec()==0,"retry starts from zero with full new limit")
	check(WorldCalendar.current_day(state.calendar)==day_before+1,"retry does not rewind calendar")
	# A write failure must not partially spend, award, advance a day, or promote.
	var broken := seed_attempt(19950,0,true)
	broken.set_paused(false)
	broken.advance(2)
	broken.training.save_path=directory+"missing/working.json"
	before=state.snapshot()
	broken.advance(1)
	check(not broken.error.is_empty() and broken.phase=="paused","write failure pauses visibly")
	check(state.snapshot()==before,"failed write leaves progress resources calendar and realm unchanged")
	broken.save_path=path
	broken.set_paused(false)
	broken.advance(3)
	check(broken.phase=="succeeded","retry after write failure uses committed state and can succeed")
	check(broken.elapsed_usec()==5000000,"early success stops well before the 30-day limit, preserving committed time")
	# Storage hydration rejects forged attempt data and durable load remains paused.
	var saved := MapLoadoutStore.candidate(state)
	check(saved.error.is_empty() and MapLoadoutStore.load_into(saved.state,path).is_empty(),"attempt and outcome reload from isolated file")
	var invalid: Dictionary=baseline.growth.duplicate(true)
	invalid.breakthrough_attempt={"version":2,"id":"base.breakthrough.first_qi","phase":"failed","progress":9000,"elapsed_usec":limit}
	check(not CultivationGrowth.valid(invalid),"invalid failed progress rejected")
	restore_fixture()
	var start_failure := new_run()
	start_failure.save_path=directory+"missing/start.json"
	before=state.snapshot()
	check(not start_failure.start() and state.snapshot()==before,"failed start save does not consume prior state")
	var exit_failure := seed_attempt(2000,6000000)
	exit_failure.save_path=directory+"missing/exit.json"
	before=state.snapshot()
	check(not exit_failure.reset() and state.snapshot()==before,"failed exit save cannot silently clear progress")
	# Shared training still writes ordinary cultivation when no breakthrough hook is set.
	restore_fixture(); equip_guide()
	state.growth.progress=0
	state.growth.resources.stamina=6000
	var ordinary := MapCultivationSession.new()
	ordinary.begin({"id":"base.map_event.qingshizhen.cultivation","durations":[5],"modes":[{"id":"cultivation","name":"修炼"}]},"cultivation",5,WorldCalendar.current_day(state.calendar))
	check(ordinary.bind(state,map.player_status,""),"ordinary training binds unchanged")
	ordinary.set_paused(false,0); ordinary.advance(6)
	check(state.growth.progress==72 and not state.growth.has("breakthrough_attempt"),"ordinary training retains existing growth and does not create attempt")
	ordinary.advance(54)
	check(state.growth.progress==600 and state.growth.budget==600,"ordinary cultivation still stops income at its daily allowance")
	# A saved ordinary allowance must never suppress breakthrough income.
	restore_fixture(); equip_guide()
	state.growth.budget=680
	var uncapped := new_run()
	check(uncapped.start(),"breakthrough starts with previously exhausted ordinary allowance")
	uncapped.advance(36)
	check(uncapped.progress()==3600 and state.growth.budget==0,"breakthrough exceeds six points in one day without consuming ordinary allowance")
	uncapped.set_paused(true)
	var resumed := new_run()
	resumed.set_paused(false)
	resumed.advance(6)
	check(resumed.progress()==4200 and state.growth.budget==0,"reload and resume retain uncapped breakthrough income")
	check(int(state.growth.resources.stamina)==800 and int(state.growth.resources.spirit)==0,"uncapped income still pays real resource costs")
	restore_fixture()
	state.content_grants.erase("training.guide.v1")
	var grant := new_run()
	var owned: Dictionary=state.snapshot().owned_units.duplicate(true)
	check(grant.start() and not state.content_grants.get("training.guide.v1",false) and state.snapshot().owned_units==owned,"first breakthrough does not replace mother's story gift")
	check(grant.reset() and grant.start() and state.snapshot().owned_units==owned,"retry does not grant another guide")
	map.queue_free()
	await settle()
	print("First qi breakthrough checks: ",checks," failures: ",failures)
	quit(1 if failures else 0)
