extends "res://tests/river_quest_tests.gd"
const Bench = preload("res://scripts/quests/old_bench_quest.gd")

func finish_bench() -> void:
	var limit := 0
	while not Bench.story(state).active.is_empty() and not Bench.story(state).reward_pending and not Bench.story(state).choice_pending and limit<25:
		map._advance_dialogue()
		limit += 1
	check(limit<25,"dialogue ends or waits for choice/transfer")

func entry() -> Dictionary:
	for row: Dictionary in QuestTracking.entries(state):
		if row.id==Bench.ID: return row
	return {}

func run() -> void:
	create_timer(55).timeout.connect(func(): quit(2))
	directory = "res://artifacts/old-bench-20261107/run-%d/"%Time.get_ticks_usec()
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
	await switch_to("qingshizhen",10)
	if not map.startup_error.is_empty(): quit(1); return
	check(Bench.configuration_error().is_empty(),"quest data valid")
	var legacy := state.snapshot()
	legacy.quests.erase(Bench.ID)
	legacy.map_visited["base.map.qingshizhen"] = [Bench.data.tree.point_id]
	check(state.restore(legacy).is_empty() and Bench.story(state).visits==0,"old discovered tree does not invent visit count")
	check(entry().is_empty(),"unaccepted task hidden from task list")
	arrive(11); arrive(10); arrive(11)
	check(Bench.story(state).active.is_empty() and Bench.story(state).visits==0,"visits alone do not unlock after prerequisite revision")
	var unlocked := state.snapshot()
	for goal: Dictionary in QuestState.definition.objectives: unlocked.quests[QuestState.ID].counts[goal.id] = goal.required
	unlocked.quests[QuestState.ID].story = QuestStory.migrated({"counts":unlocked.quests[QuestState.ID].counts})
	unlocked.quests[RiverQuest.ID].accepted_location = RiverQuest.RIVER
	unlocked.quests[RiverQuest.ID].done = ["traces","injured","entrance","root","mirror","beasts_gone","medicine","return_jade","invite_doctor","pickup","clinic_arrival","gift_book","closing"]
	unlocked.quests[MerchantRoadQuest.ID].accepted_location = "base.map.qingshizhen"
	unlocked.quests[MerchantRoadQuest.ID].stage = "completed"
	unlocked.quests[MerchantRoadQuest.ID].town_talk_done = true
	check(state.restore(unlocked).is_empty(),"completed side two fixture")
	arrive(10); arrive(11)
	check(Bench.story(state).active=="intro" and map.travel.paused,"first arrival after merchant ending opens bench offer")
	var sign: Sprite2D = map.old_bench_story_controller.signs.entries[Bench.data.tree.point_id].overlay
	check(sign.visible and sign.get_meta("optional") and sign.position==Vector2(0,-223.928571),"yellow marker uses unchanged shared anchor")
	check(map.dialogue.picture.requested_visible,"stage one illustration displayed")
	map._advance_dialogue(); map._advance_dialogue()
	check(map.dialogue.speaker_name.text=="周秉和","town head dialogue identity")
	await shot("01-tree")
	finish_bench()
	check(Bench.story(state).choice_pending and map.old_bench_story_controller.choice_dialog.visible,"offer waits for player choice")
	await shot("choice")
	await settle()
	await click(map.old_bench_story_controller.choice_dialog.cancel_button)
	finish_bench()
	check(not Bench.accepted(state) and Bench.story(state).offered and not map.travel.paused,"later option leaves movement and offer available")
	arrive(10); arrive(11)
	check(Bench.story(state).active=="offer","returning to yellow marker uses short offer")
	finish_bench()
	await click(map.old_bench_story_controller.choice_dialog.confirm_button)
	finish_bench()
	check(Bench.accepted(state) and entry().objectives.size()==1,"acceptance reveals first target only")
	check(Bench.story(state).visits==0,"old visit counter no longer advances")
	check(entry().people[1].portrait=="res://assets/ui-portrait-zhoubinghe.webp","town head portrait on task card")
	check(entry().image=="res://assets/UI-task-mid-zhi-shuxiajiudeng.webp" and entry().detail_image=="res://assets/UI-task-right-zhi-shuxiajiudeng.webp","both specified task images")
	arrive(23)
	check(Bench.story(state).active=="collect","smith arrival starts second stage")
	await shot("02-smith")
	finish_bench()
	check(Bench.story(state).line==5 and Bench.story(state).reward_pending,"tool receipt follows taking tools line")
	check(map.dialogue.visible and map.reward_dialog.visible and not map.reward_dialog.shade.visible,"receipt overlays dialogue without black shade")
	check(state.records[Bench.data.item_id].quest_item and not MapShop.new()._sale_allowed(state,Bench.data.item_id),"toolkit is protected quest item")
	await shot("tool-receipt")
	var capacity: Dictionary = state.storage_capacity_rules.duplicate(true)
	state.storage_capacity_rules.test_capacity_override = state.storage_used_slots()
	var full: MapLoadoutState = MapLoadoutStore.candidate(state).state
	full.storage_capacity_rules=state.storage_capacity_rules.duplicate(true)
	var occupied_before := full.storage_used_slots()
	check(Bench.command(full,directory+"full-bag.json","accept").is_empty() and not Bench.story(full).reward_pending and full.storage_used_slots()==occupied_before,"full bag accepts quest toolkit without capacity use")
	state.storage_capacity_rules = capacity
	var before := state.snapshot()
	map.inventory_save_path = directory+"missing/fail.json"
	map._accept_reward()
	check(state.snapshot()==before,"failed save grants no tools or progress")
	map.inventory_save_path = path
	await click(map.reward_dialog.accept_button)
	check(Bench.story(state).tools_received and Bench.story(state).line==6,"receipt continues remaining dialogue")
	check(state.carried_owned().values().count(Bench.data.item_id)==1,"exactly one toolkit granted")
	finish_bench()
	check(entry().objectives.size()==2 and entry().objectives[0].completed,"receiving parts reveals repair target")
	arrive(11)
	check(Bench.story(state).active=="repair","return to tree starts third stage")
	map._advance_dialogue()
	check(Bench.story(state).iron_used and not Bench.story(state).repaired,"iron committed before repair completion")
	await shot("03-repair")
	check(MapLoadoutStore.save(state,path).is_empty(),"save mid repair")
	await switch_to("qingshizhen",11)
	check(Bench.story(state).line==1 and Bench.story(state).iron_used,"repair resumes exact line after reload")
	finish_bench()
	check(Bench.story(state).repaired and not Bench.story(state).completed and entry().objectives.size()==3,"repair still requires returning tools")
	arrive(23)
	check(Bench.story(state).active=="returning","smith arrival starts fourth stage")
	await shot("04-return")
	map._advance_dialogue()
	check(map.reward_dialog.heading.text=="交出" and Bench.handing_over(state),"return line followed by toolkit handover")
	check(MapLoadoutStore.save(state,path).is_empty(),"save pending handover")
	await switch_to("qingshizhen",23)
	check(Bench.story(state).reward_pending and map.reward_dialog.visible,"pending handover survives reload")
	before = state.snapshot()
	map.inventory_save_path = directory+"missing/fail.json"
	map._accept_reward()
	check(state.snapshot()==before,"failed handover preserves toolkit and cursor")
	map.inventory_save_path = path
	await click(map.reward_dialog.accept_button)
	check(Bench.story(state).tools_returned and state.carried_owned().values().count(Bench.data.item_id)==0,"return removes exactly one toolkit")
	check(Bench.story(state).line==1,"handover resumes smith reply")
	var stones: int = state.spirit_stones
	finish_bench()
	check(Bench.story(state).reward_pending and not Bench.story(state).completed,"payment follows final dialogue")
	map._accept_reward()
	check(Bench.story(state).completed and state.spirit_stones==stones+2,"two spirit stones paid once")
	check(not map.travel.paused and not map.old_bench_story_controller.signs.entries[Bench.data.smith.point_id].overlay.visible,"completion restores free movement and sign")
	check(Bench.command(state,path,"accept").is_empty() and state.spirit_stones==stones+2,"double payment confirmation harmless")
	await switch_to("qingshizhen",11)
	check(Bench.story(state).completed and Bench.story(state).active.is_empty(),"finished task does not autoplay after reload")
	check(map.old_bench_story_controller.try_arrival(Bench.data.tree.point_id,true),"repaired bench can be viewed manually")
	finish_bench()
	check(state.spirit_stones==stones+2,"post-completion observation grants nothing")
	map.set_task_open(true)
	map.task_screen.task_list.select_task(Bench.ID)
	await shot("completed-task")
	var result := {"checks":checks,"failures":failures,"directory":directory,"render":render}
	FileAccess.open(directory+"validation.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("OLD_BENCH "+JSON.stringify(result))
	map.deactivate_location()
	map.free()
	quit(1 if failures else 0)
