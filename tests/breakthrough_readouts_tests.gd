extends "res://tests/first_qi_breakthrough_tests.gd"
## Only readout settlement and static rendering: no simulated mouse interaction.

func run() -> void:
	directory="res://artifacts/breakthrough-labels-rate-20261105/"
	DirAccess.make_dir_recursive_absolute(directory)
	Slots.auto_path=directory+"auto.json"
	Session.index_path=directory+"session.json"
	Session.clear_selection()
	path=""
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
	check(map.startup_error.is_empty(),"isolated map starts")
	if not map.startup_error.is_empty(): quit(1); return
	state=map.loadout
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
	restore_fixture(); equip_guide()
	map.set_breakthrough_open(true)
	var screen: Control=map.breakthrough_screen
	var flow: RefCounted=map.breakthrough_session
	var active: RefCounted=flow.runtime
	check(screen.chance_value.text+screen.chance_percent.text=="100%" and screen.remaining_value.text=="30天","initial chance and whole days")
	check(screen.efficiency_number.text=="0.0" and screen.efficiency_unit.text=="/天","initial efficiency zero, requested unit")
	for side: String in ["left","right"]:
		var view: TextureRect=screen.left_inscription if side=="left" else screen.right_inscription
		var cfg: Dictionary=screen.layout_reference.first_breakthrough_inscriptions[side]
		check(view.texture.resource_path.ends_with("progress-"+side+"1.webp"),"correct first pair picture "+side)
		check(view.texture.get_image().has_mipmaps(),"inscription mipmaps "+side)
		check(view.size==Vector2(64,192) and screen._rect(cfg.well_rect).encloses(view.get_rect()),"proportional inscription contained inside gold well "+side)
	screen.present_pair(1)
	check(not screen.left_inscription.visible and not screen.right_inscription.visible,"first pair pictures hidden for later breakthrough")
	screen.present_pair(0)
	check(screen.left_inscription.visible and screen.right_inscription.visible,"first pair pictures restored")
	check(flow.start(),"actual training starts")
	active.advance(6)
	check(active.recent_gain()==600 and active.progress()==600,"two real payments total 6.0, never projected to daily rate")
	check(state.growth.breakthrough_attempt.recent_gains[0].at_usec==3000000,"sample uses exact simulation payment timestamp")
	check(screen.efficiency_number.text=="6.0" and screen.remaining_value.text=="30天","fractional yield rounded once, no fractional day display")
	active.advance(3)
	check(active.elapsed_usec()==9000000 and active.remaining_days()==30,"9 active seconds still has 30 days")
	check(active.recent_gain()==900,"window sums actual resource-spending gain, not total divided by elapsed")
	active.set_paused(true)
	var paused_snapshot := state.snapshot()
	active.advance(300)
	check(state.snapshot()==paused_snapshot and active.recent_gain()==900,"pause freezes rolling window and remaining days")
	active.set_paused(false)
	active.advance(1)
	check(active.elapsed_usec()==10000000 and active.remaining_days()==29 and screen.remaining_value.text=="29天","one complete active day deducts exactly one day")
	check(screen.efficiency_number.text=="9.0" and screen.efficiency_unit.text=="/天","ten-second actual gain displayed with day unit")
	active.set_paused(true)
	var before_view := state.snapshot()
	if DisplayServer.get_name()!="headless":
		await capture("readouts-2560")
		root.size=Vector2i(1920,1080)
		await settle()
		check(screen.efficiency_value.get_global_rect().encloses(screen.efficiency_unit.get_global_rect()),"rate number and unit fit at 1080p")
		await capture("readouts-1920")
	check(state.snapshot()==before_view,"static previews never mutate gameplay")
	var disk_path := directory+"window.json"
	check(MapLoadoutStore.save(state,disk_path).is_empty(),"persist rolling window")
	var clone := MapLoadoutStore.candidate(state)
	check(clone.error.is_empty() and MapLoadoutStore.load_into(clone.state,disk_path).is_empty(),"load persisted samples")
	var restored := Run.new()
	restored.bind(clone.state,map.player_status,"")
	check(restored.phase=="paused" and restored.recent_gain()==900 and restored.remaining_days()==29,"reload retains metric and pauses")
	active.set_paused(false)
	active.advance(6)
	check(active.elapsed_usec()==16000000 and active.recent_gain()==900,"sample exactly 10 seconds old expires")
	active.advance(42)
	check(active.progress()==4800 and active.recent_gain()==0,"no new resource payment gives zero current efficiency despite accumulated progress")
	check(active.reset() and active.recent_gain()==0 and active.remaining_days()==30,"red-exit command resets displayed metrics")
	var old := seed_attempt(5000,20000000)
	check(old.recent_gain()==0 and old.remaining_days()==28,"legacy attempt without samples does not invent history or lifetime average")
	var invalid: Dictionary=state.growth.duplicate(true)
	invalid.breakthrough_attempt.recent_gains=[{"at_usec":20000001,"amount":100}]
	check(not CultivationGrowth.valid(invalid),"reject future sample timestamps")
	var broken := seed_attempt(19950,0,true)
	broken.set_paused(false); broken.advance(2)
	broken.training.save_path=directory+"missing/window.json"
	var before_failure := state.snapshot()
	broken.advance(1)
	check(state.snapshot()==before_failure and broken.recent_gain()==0,"failed payment write rolls back statistics with resources and progression")
	broken.set_paused(false); broken.advance(6)
	check(broken.phase=="succeeded" and broken.recent_gain()==50,"target-clamped last payment records only actual credited growth")
	# The third callback argument does not affect ordinary training without a hook.
	restore_fixture(); equip_guide()
	var ordinary := MapCultivationSession.new()
	state.growth.progress=0
	ordinary.begin({"id":"base.map_event.qingshizhen.cultivation","durations":[5],"modes":[{"id":"cultivation","name":"修炼"}]},"cultivation",5,WorldCalendar.current_day(state.calendar))
	check(ordinary.bind(state,map.player_status,""),"ordinary training binds")
	ordinary.set_paused(false,0); ordinary.advance(6)
	check(state.growth.progress==72 and not state.growth.has("breakthrough_attempt"),"ordinary training remains independent of rolling metrics")
	map.queue_free()
	await settle()
	print("Breakthrough readout checks: ",checks," failures: ",failures)
	quit(1 if failures else 0)
