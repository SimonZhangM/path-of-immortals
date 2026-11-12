extends "res://tests/river_quest_tests.gd"
const Bounty = preload("res://scripts/quests/river_bounty_quest.gd")
const Bench = preload("res://scripts/quests/old_bench_quest.gd")

func finish_bounty() -> void:
	var count := 0
	while not Bounty.story(state).active.is_empty() and not Bounty.story(state).choice_pending and not Bounty.story(state).reward_pending and count<20:
		map._advance_dialogue()
		count += 1
	check(count<20,"finite commission dialogue")

func commission_entry() -> Dictionary:
	for row: Dictionary in QuestTracking.entries(state):
		if row.id==Bounty.ID: return row
	return {}

func town_fixture() -> Dictionary:
	var fixture := state.snapshot()
	for goal: Dictionary in QuestState.definition.objectives: fixture.quests[QuestState.ID].counts[goal.id] = goal.required
	fixture.quests[QuestState.ID].story = QuestStory.migrated({"counts":fixture.quests[QuestState.ID].counts})
	fixture.quests[RiverQuest.ID].accepted_location = RiverQuest.RIVER
	fixture.quests[RiverQuest.ID].done = ["traces","injured","entrance","root","mirror","beasts_gone","medicine","return_jade","invite_doctor","pickup","clinic_arrival","gift_book","closing"]
	return fixture

func run() -> void:
	create_timer(55).timeout.connect(func(): quit(2))
	directory = "res://artifacts/river-bounty-20261107/run-%d/"%Time.get_ticks_usec()
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
	await switch_to("qingshizhen",18)
	if not map.startup_error.is_empty(): quit(1); return
	check(Bounty.configuration_error().is_empty(),"commission data valid")
	var fixture := town_fixture()
	fixture.quests.erase(Bounty.ID)
	fixture.quests[Bench.ID].visits = 2
	check(state.restore(fixture).is_empty(),"legacy save loads without commission")
	check(not Bounty.available(state) and not Bench.available(state),"main two completion and two tree visits no longer unlock either task")
	arrive(18); arrive(11)
	check(not map.event_state.is_active() and Bench.story(state).active.is_empty() and Bounty.story(state).active.is_empty(),"locked arrivals do not open story")
	arrive(18)
	fixture = state.snapshot()
	fixture.quests[Bench.ID].visits = 0
	var merchant: Dictionary = fixture.quests[MerchantRoadQuest.ID]
	merchant.accepted_location = "base.map.qingshizhen"
	merchant.stage = "escorting"
	merchant.town_talk_done = true
	merchant.active = "shop_return"
	merchant.line = MerchantRoadQuest.data.scenes.shop_return.lines.size()-1
	merchant.location = MerchantRoadQuest.data.shop.duplicate(true)
	merchant.reward_pending = true
	check(state.restore(fixture).is_empty(),"merchant ending before settlement fixture")
	check(not Bounty.available(state) and not Bench.available(state),"rescue and return alone do not unlock before side two ends")
	check(MerchantRoadQuest.command(state,path,"accept").is_empty(),"finish side two through actual reward transaction")
	check(Bounty.available(state) and Bench.available(state) and Bench.story(state).visits==0,"both offers unlock with zero tree visits")
	check(Bounty.marker_points(state,"base.map.qingshizhen")==[Bounty.board().point_id],"commission begins at announcement board only")
	check(Bench.data.tree.point_id in Bench.marker_points(state,"base.map.qingshizhen"),"bench offer independently visible")
	var board_sign: Sprite2D = map.river_bounty_controller.signs.entries[Bounty.board().point_id].overlay
	var tree_sign: Sprite2D = map.old_bench_story_controller.signs.entries[Bench.data.tree.point_id].overlay
	check(board_sign.visible and tree_sign.visible and board_sign.get_meta("optional") and tree_sign.get_meta("optional"),"both non-main tasks have yellow exclamations")
	check(board_sign.position==Vector2(0,-223.928571),"board uses unchanged common anchor")
	check(commission_entry().is_empty(),"offer does not accept task automatically")
	check(MapLoadoutStore.save(state,path).is_empty(),"save unlocked state")
	await switch_to("qingshizhen",17)
	arrive(18)
	check(Bounty.story(state).active=="notice" and map.travel.paused and not map.dialogue.picture.requested_visible,"arrival opens direct announcement dialogue without invented picture")
	await create_timer(0.4).timeout
	await shot("01-notice")
	finish_bounty()
	check(map.river_bounty_controller.choice_dialog.visible,"announcement waits for accept or decline")
	await settle()
	await click(map.river_bounty_controller.choice_dialog.cancel_button)
	finish_bounty()
	check(not Bounty.accepted(state) and not map.travel.paused,"decline leaves task available and free movement: "+str(Bounty.story(state))+" event="+str(map.event_state.active_id))
	map._try_start_event(Bounty.board().point_id,"click",true)
	check(Bounty.story(state).active=="notice","occupied board click reopens offer")
	finish_bounty()
	await click(map.river_bounty_controller.choice_dialog.confirm_button)
	finish_bounty()
	check(Bounty.accepted(state) and not Bounty.story(state).informed and commission_entry().category=="commission","acceptance creates commission category entry")
	check(Bounty.marker_points(state,"base.map.qingshizhen")==[Bounty.data.mayor.point_id],"accepted task guides to actual mayor away from board")
	var blank := state.snapshot()
	for id: String in blank.owned_units.keys():
		if blank.owned_units[id] in ["base.material.shanlang_fang","base.material.cslz_tusk"]: blank.owned_units.erase(id)
	check(state.restore(blank).is_empty(),"clear only isolated material fixture")
	check(state.add_reward({"id":"base.map_reward.test.bounty.wolf","item_id":"base.material.shanlang_fang","quantity":3}).is_empty(),"existing wolf materials allowed")
	check(state.add_reward({"id":"base.map_reward.test.bounty.boar","item_id":"base.material.cslz_tusk","quantity":2}).is_empty(),"existing boar materials allowed")
	check(not Bounty.story(state).completed and commission_entry().objectives.size()==1,"existing materials cannot bypass briefing")
	arrive(11)
	check(Bounty.story(state).active=="details" and Bench.story(state).active.is_empty(),"mayor briefing has priority while bench remains available")
	map._advance_dialogue()
	check(MapLoadoutStore.save(state,path).is_empty(),"save briefing cursor")
	await switch_to("qingshizhen",11)
	check(Bounty.story(state).active=="details" and Bounty.story(state).line==1,"briefing resumes exact line")
	finish_bounty()
	check(Bounty.story(state).informed and commission_entry().objectives.size()==4,"briefing reveals ready inventory and delivery")
	map.set_task_open(true)
	map.task_screen.task_list.select_task(Bounty.ID)
	await create_timer(0.4).timeout
	await shot("02-task")
	map.set_task_open(false)
	arrive(10); arrive(11)
	check(Bounty.story(state).active=="delivery","return to mayor starts delivery")
	finish_bounty()
	check(Bounty.story(state).reward_pending and map.reward_dialog.visible and map.dialogue.visible and not map.reward_dialog.shade.visible,"confirmation stays above dialogue")
	await create_timer(0.4).timeout
	await shot("03-delivery")
	var before := state.snapshot()
	check(not Bounty.command(state,directory+"missing/fail.json","accept").is_empty() and state.snapshot()==before,"failed save neither consumes proof nor pays reward")
	# Materials moved away while delivery is pending must be rechecked.
	var missing := before.duplicate(true)
	for id: String in missing.owned_units.keys():
		if missing.owned_units[id]=="base.material.cslz_tusk": missing.owned_units.erase(id)
	check(state.restore(missing).is_empty(),"inventory changed fixture")
	var empty_before := state.snapshot()
	check(not Bounty.command(state,path,"accept").is_empty() and state.snapshot()==empty_before,"missing materials fail without partial deduction")
	check(commission_entry().objectives[2].current==0 and not commission_entry().objectives[3].completed,"counts follow live inventory")
	map.river_bounty_controller.defer_receipt_button.pressed.emit()
	check(not map.travel.paused and Bounty.story(state).active.is_empty(),"failed delivery can defer and collect materials")
	# A legacy accepted bench keeps its progress even before the new prerequisite.
	var legacy := state.snapshot()
	legacy.quests[Bench.ID].accepted_location = Bench.data.accepted_location
	legacy.quests[MerchantRoadQuest.ID] = MerchantRoadQuest.initial()
	check(state.restore(legacy).is_empty() and Bench.available(state),"accepted bench survives prerequisite change without restart")
	check(state.restore(before).is_empty(),"restore ready delivery fixture")
	map.river_bounty_controller.present()
	var coins := state.spirit_stones
	await click(map.reward_dialog.accept_button)
	check(Bounty.story(state).completed and state.spirit_stones==coins+8,"confirmed delivery grants eight stones once")
	check(Bounty.quantity(state,"base.material.shanlang_fang")==1 and Bounty.quantity(state,"base.material.cslz_tusk")==1,"exactly two fangs and one tusk consumed, extra stock retained")
	var settled := state.snapshot()
	check(Bounty.command(state,path,"accept").is_empty() and state.snapshot()==settled,"repeat confirmation cannot repay")
	check(commission_entry().stage_id=="completed" and commission_entry().objectives.all(func(row):return row.completed),"completion remains checked after material deduction")
	check(Bounty.marker_points(state,"base.map.qingshizhen").is_empty(),"commission markers retire after completion")
	arrive(10); arrive(11)
	check(Bench.story(state).active=="intro" and Bench.story(state).visits==0,"bench starts on first visit after unlock with no visit requirement")
	await create_timer(0.4).timeout
	await shot("04-bench")
	print("RIVER_BOUNTY "+JSON.stringify({"checks":checks,"failures":failures,"directory":directory}))
	FileAccess.open(directory+"validation.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	map.deactivate_location(); map.free()
	quit(1 if failures else 0)
