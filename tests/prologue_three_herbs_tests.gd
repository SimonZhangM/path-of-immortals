extends "res://tests/save_actions_tests.gd"

const QUEST := QuestState.ID
var state: MapLoadoutState
var save_path: String

func finish_dialogue() -> void:
	var steps := 0
	while not QuestStory.story(state).active.is_empty() and not QuestStory.story(state).reward_pending and steps < 40:
		check(QuestStory.command(state,save_path,"advance").is_empty(),"advance actual quest dialogue")
		steps += 1
	check(steps < 40,"dialogue terminates")

func run() -> void:
	create_timer(50).timeout.connect(func(): quit(2))
	directory = "res://artifacts/prologue-three-herbs-20261102/run-%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	Slots.auto_path = directory + "auto.json"
	Session.index_path = directory + "index.json"
	Session.clear_selection()
	save_path = Slots.working_path()
	AudioServer.set_bus_mute(0,true)
	var map = load("res://scenes/maps/qingshizhen.tscn").instantiate()
	map.inventory_save_path = save_path
	map.defer_map_music = true
	map.defer_location_save = true
	map.defer_optional_views = true
	root.add_child(map)
	map.set_process(false)
	map.quest_story_controller.set_process(false)
	check(map.startup_error.is_empty(),"actual map starts with updated quest")
	if not map.startup_error.is_empty(): quit(1); return
	state = map.loadout
	var base := state.snapshot()
	base.quests[QUEST].counts.talk = 1
	base.quests[QUEST].counts.visit = 1
	base.quests[QUEST].story = QuestStory.initial()
	base.quests[QUEST].story.done = ["wake","morning","slope"]
	base.map_location = {"map_id":"base.map.xiyuanyaopo","point_id":"base.map.xiyuanyaopo.point.n01"}
	check(state.restore(base).is_empty(),"accepted gathering fixture")
	for herb: String in ["kuaiye","xilutai"]:
		check(QuestState.required_quantity(herb)==3,"configured three " + herb)
		QuestState.gathered(state,{"quest_id":QUEST,"item_id":"base.material."+herb,"quantity":1})
	check(QuestState.stage(state.quests)=="gathering" and QuestStory.story(state).pending.is_empty(),"one of each does not finish or claim enough herbs")
	var entry: Dictionary = QuestTracking.entries(state)[0]
	var objectives := QuestTracking.objectives(entry)
	check(objectives.size()==2 and objectives[0].current==1 and objectives[0].required==3 and not objectives[0].completed,"UI exposes one of three and incomplete targets")
	QuestState.gathered(state,{"quest_id":QUEST,"item_id":"base.material.kuaiye","quantity":1})
	check(QuestState.stage(state.quests)=="gathering" and QuestStory.story(state).pending.is_empty(),"two remains incomplete")
	QuestState.gathered(state,{"quest_id":QUEST,"item_id":"base.material.kuaiye","quantity":1})
	check(QuestStory.story(state).pending==["kuaiye_only"] and QuestTracking.objectives(QuestTracking.entries(state)[0]).size()==1,"three completes only the matching herb")
	QuestState.gathered(state,{"quest_id":QUEST,"item_id":"base.material.xilutai","quantity":5})
	check(state.quests[QUEST].counts.xilutai==3 and QuestState.stage(state.quests)=="returning" and "both" in QuestStory.story(state).pending,"counts cap at three and both required before return")
	# Legacy saves retain real progress and never consume or grant during migration.
	var legacy := base.duplicate(true)
	legacy.quests[QUEST].counts.kuaiye = 1
	legacy.quests[QUEST].counts.xilutai = 1
	legacy.quests[QUEST].story.done.append_array(["kuaiye_only","both"])
	legacy.quests[QUEST].story.active = "returning"
	legacy.quests[QUEST].story.line = QuestStory.data.scenes.returning.lines.size()-1
	legacy.quests[QUEST].story.location = QuestStory.data.shop.duplicate(true)
	legacy.quests[QUEST].story.reward_pending = true
	check(state.restore(legacy).is_empty(),"legacy pending one-per-herb reward loads")
	check(QuestState.stage(state.quests)=="gathering" and QuestStory.story(state).active.is_empty() and not QuestStory.story(state).reward_pending,"legacy pending reward resumes gathering")
	check(state.quests[QUEST].counts.kuaiye==1 and "both" not in QuestStory.story(state).done,"legacy counters retained and premature completion remark cleared")
	check(state.snapshot().owned_units==legacy.owned_units and state.spirit_stones==int(legacy.spirit_stones),"migration does not settle inventory or reward")
	var completed := base.duplicate(true)
	for id: String in completed.quests[QUEST].counts: completed.quests[QUEST].counts[id] = 1
	completed.quests[QUEST].story.done.append("returning")
	check(state.restore(completed).is_empty(),"legacy completed quest loads")
	check(state.quests[QUEST].counts.kuaiye==3 and state.quests[QUEST].counts.xilutai==3 and QuestTracking.entries(state)[0].stage_id=="completed","completed legacy quest stays completed with full display counts")
	var before := state.snapshot()
	check(QuestStory.command(state,save_path,"accept").is_empty() and state.snapshot()==before,"completed legacy quest cannot pay twice")
	# Exercise current collection, dialogue, exact deduction and durable settlement.
	check(state.restore(base).is_empty(),"reset isolated gathering fixture")
	for herb: String in ["xilutai","kuaiye"]:
		var event := {"id":"base.map_event.test.three_herbs."+herb,"item_id":"base.material."+herb,"reward_prefix":"base.map_reward.test.three_herbs."+herb}
		var rng := RandomNumberGenerator.new()
		rng.seed = 33
		check(MapGatheringRewards.prepare(state,event,"base.gathering.deep",save_path,rng).is_empty(),"prepare actual three-or-more gathering")
		check(MapGatheringRewards.claim(state,event,save_path).is_empty(),"claim actual gathering")
		before = state.snapshot()
		check(MapGatheringRewards.claim(state,event,save_path).is_empty() and state.snapshot()==before,"duplicate gathering receipt does not advance or grant")
		while not QuestStory.story(state).pending.is_empty():
			check(QuestStory.command(state,save_path,"begin",QuestStory.story(state).pending[0]).is_empty(),"start appropriate completion remark")
			finish_dialogue()
		check(state.add_reward({"id":"base.map_reward.test.extra."+herb,"item_id":"base.material."+herb,"quantity":1}).is_empty(),"extra carried herb fixture")
	check(QuestState.delivery_units(state).size()==6,"delivery selects three units per herb")
	state.set_map_location(QuestStory.data.shop.map_id,QuestStory.data.shop.point_id)
	check(QuestStory.actionable_shop(state),"full herb counts and stock enable delivery")
	check(QuestStory.command(state,save_path,"begin","returning").is_empty(),"begin real delivery")
	finish_dialogue()
	check(QuestStory.story(state).reward_pending,"payment waits for confirmation")
	var ready := state.snapshot()
	var missing := ready.duplicate(true)
	var retained := 0
	for row: Dictionary in state.storage.entries():
		if row.item_id!="base.material.kuaiye": continue
		for unit: Dictionary in row.units:
			retained += 1
			if retained>2: missing.owned_units.erase(unit.id)
	check(state.restore(missing).is_empty(),"only two bitter herbs at confirmation")
	before = state.snapshot()
	check(QuestState.delivery_units(state).is_empty() and not QuestStory.command(state,save_path,"accept").is_empty() and state.snapshot()==before,"two herbs cannot settle and preserve pending payment")
	check(state.restore(ready).is_empty(),"restore full stock")
	before = state.snapshot()
	check(not QuestStory.command(state,directory+"missing/save.json","accept").is_empty() and state.snapshot()==before,"failed save consumes nothing")
	var money := state.spirit_stones
	var selected := QuestState.delivery_units(state)
	var owned_count: int = state.snapshot().owned_units.size()
	check(QuestStory.command(state,save_path,"accept").is_empty(),"confirm exact delivery")
	check(state.spirit_stones==money+5 and state.snapshot().owned_units.size()==owned_count-6,"six herbs consumed and five stones awarded")
	for unit_id: String in selected:
		check(not state.snapshot().owned_units.has(unit_id),"selected delivery unit removed")
	check(RiverQuest.bag_count(state,"base.material.kuaiye")>=1 and RiverQuest.bag_count(state,"base.material.xilutai")>=1,"extra herbs retained")
	before = state.snapshot()
	check(QuestStory.command(state,save_path,"accept").is_empty() and state.snapshot()==before,"repeat confirmation has no effect")
	var restored: MapLoadoutState = MapLoadoutStore.candidate(state).state
	check(MapLoadoutStore.load_into(restored,save_path).is_empty() and restored.quests==state.quests and restored.snapshot().owned_units==state.snapshot().owned_units,"new counts and delivery persist on reload")
	check(Files.read(Slots.quick_path()).quests[QUEST].counts.kuaiye==3,"quick checkpoint contains new count")
	Meta.stop()
	map.queue_free()
	await settle()
	print("PROLOGUE THREE HERBS: %d checks, %d failures" % [checks,failures])
	print("OUTPUT: "+directory)
	quit(1 if failures else 0)
