extends "res://tests/river_quest_tests.gd"

const GUIDE := "base.map_item.training_guide_stone"
const BOARD := "base.map_item.qinglan_board_1"
const Run = preload("res://scripts/map/map_breakthrough_run.gd")

func finish_home() -> void:
	var count := 0
	while not HomecomingQuest.story(state).active.is_empty() and count<40:
		if HomecomingQuest.story(state).reward_pending: map._accept_reward()
		else: map._advance_dialogue()
		count += 1
	check(count<40,"home scene terminates")

func run() -> void:
	create_timer(55).timeout.connect(func(): quit(2))
	directory="res://artifacts/prologue-training-gifts-20261105/run-%d/"%Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	Slots.auto_path=directory+"auto.json"
	Session.index_path=directory+"session.json"
	Session.clear_selection()
	path=Slots.working_path()
	root.get_node("SavePlaytime").set_process(false)
	root.get_node("GameSettings").apply_values({"background_pause":false,"dialogue_speed":"instant","dialogue_auto":false})
	root.content_scale_size=Vector2i.ZERO
	root.size=Vector2i(1920,1080)
	render=DisplayServer.get_name()!="headless"
	await switch_to("qingshizhen",31)
	var fixture := state.snapshot()
	fixture.board_id="base.board.bag"
	fixture.placements=[]
	fixture.growth=CultivationGrowth.initial(0)
	fixture.growth.resources={"hp":5000,"stamina":5000,"spirit":5000}
	fixture.learning={"version":1,"learned":{},"practice":{}}
	for objective: Dictionary in QuestState.definition.objectives: fixture.quests[QuestState.ID].counts[objective.id]=objective.required
	fixture.quests[QuestState.ID].story=QuestStory.migrated({"counts":fixture.quests[QuestState.ID].counts})
	fixture.quests[RiverQuest.ID].done=["traces","injured","entrance","root","mirror","beasts_gone","medicine","return_jade","invite_doctor","pickup","clinic_arrival"]
	fixture.quests[RiverQuest.ID].accepted_location=RiverQuest.RIVER
	check(state.restore(fixture).is_empty(),"mortal clinic fixture")
	check(state.records[GUIDE].quest_item and "任务物品" in state.registry.get_item(GUIDE).tags,"guide is protected before qi")
	var shop := MapShop.new()
	shop.profile={"categories":[{"id":"artifact","inventory_categories":["artifact"]}]}
	check(not shop._sale_allowed(state,GUIDE),"protected guide cannot be sold")
	arrive(32)
	finish_scene("gift_book")
	map._accept_reward()
	finish_scene("gift_book")
	check(RiverQuest.story(state).active=="gift_board","book continues into board explanation")
	finish_scene("gift_board")
	check(map.reward_dialog.card.entry.id==BOARD and not map.reward_dialog.shade.visible,"board receipt overlays clinic dialogue")
	await shot("xiaolan-gift")
	var before := state.snapshot()
	check(not RiverQuest.command(state,directory+"missing/fail.json","accept").is_empty() and state.snapshot()==before,"failed board save grants nothing")
	var board_count := state.carried_owned().values().count(BOARD)
	map._accept_reward()
	check(state.carried_owned().values().count(BOARD)==board_count+1,"one board granted")
	await click(map.river_story_controller.completion_notice.confirm_button)
	check(RiverQuest.command(state,path,"accept").is_empty() and state.carried_owned().values().count(BOARD)==board_count+1,"board receipt is idempotent")
	finish_scene("gift_board")
	finish_scene("closing")
	check(RiverQuest.done(state,"closing"),"clinic still completes main two")
	arrive(14)
	finish_home()
	await switch_to("baishacun",5)
	finish_home()
	# Use the real ordinary conversation journal to satisfy both prerequisite topics.
	check(map._try_start_event(HomecomingQuest.data.home.point_id,"click",true),"open mother's chat")
	for topic: String in ["mirror","past"]:
		check(NpcDialogueActions.command(state,map.clinic_dialog.library,"select",path,topic).is_empty(),"select mother topic "+topic)
		var steps := 0
		while not HomecomingQuest.topic_done(state,topic) and steps<45:
			check(NpcDialogueActions.command(state,map.clinic_dialog.library,"advance",path).is_empty(),"advance mother topic")
			steps+=1
	map._close_clinic()
	arrive(6)
	arrive(5)
	while HomecomingQuest.story(state).line<=HomecomingQuest.data.scenes.guidance.reward_after_line and not HomecomingQuest.story(state).reward_pending:
		map._advance_dialogue()
	check(HomecomingQuest.story(state).reward_pending and map.reward_dialog.card.entry.id==GUIDE,"mother gives guide at authored line")
	check(map.dialogue.visible and not map.reward_dialog.shade.visible,"guide receipt retains dialogue")
	await shot("guide-stone-gift")
	await switch_to("baishacun",5)
	check(HomecomingQuest.story(state).reward_pending and map.reward_dialog.visible,"pending guide survives reload")
	before=state.snapshot()
	check(not HomecomingQuest.command(state,directory+"missing/fail.json","accept").is_empty() and state.snapshot()==before,"guide save failure is atomic")
	var count := state.carried_owned().values().count(GUIDE)
	map.reward_dialog.request_close()
	check(state.carried_owned().values().count(GUIDE)==count+1,"closing receipt receives one guide")
	check(HomecomingQuest.command(state,path,"accept").is_empty() and state.carried_owned().values().count(GUIDE)==count+1,"guide cannot be received twice")
	finish_home()
	check(HomecomingQuest.ready_for_practice(state),"guidance completed after thanks")
	check(state.select_board(BOARD).is_empty(),"equip gifted board")
	var unit: String = "reward."+HomecomingQuest.data.scenes.guidance.reward.id+".0"
	check(state.inventory.add_item(unit,GUIDE,Vector2i.ZERO),"quest guide can be placed for first breakthrough")
	state.storage.take_one(unit)
	state.growth.progress=CultivationGrowth.target(state.growth)
	map.player_status.apply_growth(state.growth)
	var flow := Run.new()
	flow.bind(state,map.player_status,path)
	check(flow.start(),"start real first qi with the gifted items")
	check(state.carried_owned().values().count(GUIDE)==count+1,"starting training does not grant an extra guide")
	flow.set_paused(true)
	map.set_breakthrough_open(true)
	await settle()
	check(map.breakthrough_screen.assistance_view.names[2].text=="导引石" and map.breakthrough_screen.assistance_view.categories[2].text=="辅助物品","guide replaces home assistance card")
	await shot("guide-assistance")
	map.set_breakthrough_open(false)
	# A failed success transaction must leave both description and sale protection intact.
	var near := state.snapshot()
	near.growth.breakthrough_attempt.progress=19900
	check(state.restore(near).is_empty(),"seed near-target real attempt")
	flow=Run.new()
	flow.bind(state,map.player_status,directory+"missing/fail.json")
	var candidate: MapLoadoutState=MapLoadoutStore.candidate(state).state
	candidate.growth.breakthrough_attempt.progress=20000
	check(flow._settle_step(candidate,0.0).is_empty(),"candidate reaches actual success")
	check(candidate.restore(candidate.snapshot()).is_empty(),"candidate refreshes ordinary guide")
	check(not candidate.records[GUIDE].quest_item and state.records[GUIDE].quest_item,"candidate progression is isolated")
	check(not flow._commit(candidate) and state.records[GUIDE].quest_item and "任务物品" in state.registry.get_item(GUIDE).tags,"failed save keeps task protection and tooltip")
	flow=Run.new()
	flow.bind(state,map.player_status,path)
	flow.set_paused(false)
	flow.advance(6)
	check(flow.phase=="succeeded","actual guide activation completes first qi")
	check(int(state.growth.realm)==1 and not state.records[GUIDE].quest_item,"success converts guide to ordinary training item")
	check("任务物品" not in state.registry.get_item(GUIDE).tags and shop._sale_allowed(state,GUIDE),"ordinary guide has normal tooltip and sale rules")
	await switch_to("baishacun",5)
	check(not state.records[GUIDE].quest_item and state.registry.get_item(GUIDE).training,"ordinary training item persists after reload")
	var result := {"checks":checks,"failures":failures,"directory":directory,"render":render}
	FileAccess.open(directory+"validation.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("PROLOGUE_TRAINING_GIFTS "+JSON.stringify(result))
	map.deactivate_location()
	map.free()
	quit(1 if failures else 0)
