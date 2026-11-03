extends "res://tests/river_quest_tests.gd"

const SHRINE := RiverQuest.SHRINE
const HERB := "base.material.zhixuecao"
const ROOT_HERB := "base.material.qingtenggen"

func entry() -> Dictionary:
	for task: Dictionary in QuestTracking.entries(state):
		if task.id==RiverQuest.ID: return task
	return {}
func goal(id: String) -> Dictionary:
	for row: Dictionary in entry().objectives:
		if row.id==id: return row
	return {}
func marker(number: int) -> void:
	var target := "base_map_wumingjiuci_point_n%02d" % number
	check(map.quest_tracker_controller.markers.has_node(target), "location targets N%02d" % number)
	var other := "base_map_wumingjiuci_point_n%02d" % (5 if number==1 else 1)
	check(not map.quest_tracker_controller.markers.has_node(other), "no competing courtyard location")
func counts() -> void:
	for pair in [["zhixuecao",HERB],["root",ROOT_HERB]]:
		check(goal(pair[0]).current==RiverQuest.bag_count(state,pair[1]), "actual bag quantity for " + pair[0])
		check(goal(pair[0]).required==1 and goal(pair[0]).inline_count, "inline denominator remains one")

func run() -> void:
	create_timer(55).timeout.connect(func(): quit(2))
	directory = "res://artifacts/shrine-gate-navigation-20261103/run-%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	Slots.auto_path = directory+"auto.json"
	Session.index_path = directory+"index.json"
	Session.clear_selection()
	path = Slots.working_path()
	root.get_node("SavePlaytime").set_process(false)
	root.get_node("GameSettings").apply_values({"background_pause":false,"background_mute":false,"dialogue_speed":"instant","dialogue_auto":false})
	root.get_node("GameSettings").set_application_focus(true)
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1920,1080)
	render = DisplayServer.get_name()!="headless"
	await switch_to("wumingjiuci",31)
	var fixture := state.snapshot()
	for id: String in fixture.quests[QuestState.ID].counts: fixture.quests[QuestState.ID].counts[id] = 1
	fixture.quests[QuestState.ID].story = QuestStory.migrated({"counts":fixture.quests[QuestState.ID].counts})
	# An early, pre-harvest exit attempt must not satisfy the new return visit.
	fixture.quests[RiverQuest.ID].done = ["traces","injured","detour","entrance","blocked_exit","root"]
	fixture.quests[RiverQuest.ID].accepted_location = RiverQuest.RIVER
	fixture.quest_tracking = {"ids":[RiverQuest.ID],"shown":true}
	check(state.restore(fixture).is_empty(), "post-harvest fixture")
	for pair in [[HERB,3],[ROOT_HERB,2]]:
		check(state.add_reward({"id":"base.map_reward.test.gate."+pair[0],"item_id":pair[0],"quantity":pair[1]}).is_empty(), "multiple herb units")
	counts()
	check(goal("zhixuecao").current>=3 and goal("root").current>=2, "quantities do not clamp at one")
	var ready := state.snapshot()
	map.set_task_open(true)
	map.task_screen.task_list.select_task(RiverQuest.ID)
	for dimensions in [Vector2i(1920,1080),Vector2i(2560,1440)]:
		root.size = dimensions
		await settle()
		for id in ["zhixuecao","root"]:
			var row: Dictionary = goal(id)
			var control: Node = map.task_screen.detail_body.objective_rows.get_node("Objective_"+id)
			check(control.get_node("ObjectiveText").text==row.text+"（%d/1）"%row.current, "inline actual count rendered for " + id)
			check(not control.has_node("ProgressCount"), "no duplicate right-hand count")
		await shot("herb-counts-%d" % dimensions.x)
	map.set_task_open(false)
	root.size = Vector2i(1920,1080)
	for id in [HERB,ROOT_HERB]:
		check(state.transfer_warehouse("base.warehouse.qingshizhen.home",id,false,false,RiverQuest.bag_count(state,id)).is_empty(), "store herbs in warehouse")
	counts()
	check(goal("zhixuecao").current==0 and goal("root").current==0, "warehouse herbs excluded from bag counts")
	check(state.restore(ready).is_empty(), "restore stocked bag")
	var parcel_case := MapLoadoutStore.candidate(state)
	var parcel_snapshot: Dictionary = parcel_case.state.snapshot()
	parcel_snapshot.quests[RiverQuest.ID].parcels.root = RiverQuest.data.scenes.root.reward.duplicate(true)
	check(parcel_case.state.restore(parcel_snapshot).is_empty(), "unclaimed root parcel fixture")
	var parcel_entry := RiverQuest.display_entry(parcel_case.state,entry())
	for row: Dictionary in parcel_entry.objectives:
		if row.id=="root": check(row.current==RiverQuest.bag_count(state,ROOT_HERB), "unclaimed parcel excluded from bag count")
	check(MapLoadoutStore.save(state,path).is_empty(), "save stocked post-harvest state")
	marker(1)
	check(RiverQuest.exit_blocked(state,SHRINE), "cannot leave before mirror")
	arrive(5)
	check(RiverQuest.story(state).active.is_empty(), "passing altar before gate check does not pick up mirror")
	marker(1)
	arrive(1)
	check(RiverQuest.story(state).active=="courtyard_check" and map.dialogue.visible and not map.is_exit_open(), "gate automatically starts existing observation")
	marker(1)
	map._advance_dialogue()
	check(RiverQuest.story(state).line==1 and not RiverQuest.done(state,"courtyard_check"), "last observation line still keeps gate target")
	marker(1)
	var before := state.snapshot()
	map.inventory_save_path = directory+"missing/fail.json"
	map._advance_dialogue()
	check(state.snapshot()==before, "failed observation save does not switch target")
	map.inventory_save_path = path
	await switch_to("wumingjiuci",1)
	check(RiverQuest.story(state).active=="courtyard_check" and RiverQuest.story(state).line==1, "gate dialogue cursor resumes")
	marker(1)
	finish_scene("courtyard_check")
	check(not map.is_exit_open() and RiverQuest.exit_blocked(state,SHRINE), "observing beasts does not open exit")
	marker(5)
	check(Files.read(path).quests[RiverQuest.ID].done.has("courtyard_check"), "gate check persisted before marker switches")
	await switch_to("wumingjiuci",1)
	marker(5)
	check(RiverQuest.story(state).active.is_empty(), "completed gate observation does not repeat on reload")
	arrive(5)
	finish_scene("mirror")
	marker(1)
	arrive(1)
	finish_scene("beasts_gone")
	check(map.is_exit_open() and not RiverQuest.exit_blocked(state,SHRINE), "mirror and final observation retain normal exit")
	map._cancel_exit()
	# Existing mirror saves resume without inventing a forced trip back to the gate.
	for active in [true,false]:
		var legacy := ready.duplicate(true)
		if active:
			legacy.quests[RiverQuest.ID].active = "mirror"
			legacy.quests[RiverQuest.ID].line = 4
			legacy.quests[RiverQuest.ID].location = {"map_id":SHRINE,"point_id":SHRINE+".point.n05"}
		else: legacy.quests[RiverQuest.ID].done.append("mirror")
		check(state.restore(legacy).is_empty(), "legacy mirror state accepted")
		check(RiverQuest.done(state,"courtyard_check") and state.snapshot().owned_units==legacy.owned_units, "legacy mirror bypass preserves inventory")
		check(RiverQuest.story(state).active==("mirror" if active else ""), "legacy cursor retained")
	var old_gate := ready.duplicate(true)
	old_gate.quests[RiverQuest.ID].active = "blocked_exit"
	old_gate.quests[RiverQuest.ID].line = 1
	old_gate.quests[RiverQuest.ID].location = {"map_id":SHRINE,"point_id":SHRINE+".point.n01"}
	check(state.restore(old_gate).is_empty(), "legacy post-harvest gate warning accepted")
	check(RiverQuest.story(state).active=="courtyard_check" and RiverQuest.story(state).line==1, "same gate dialogue cursor adopts new navigation boundary")
	old_gate.quests[RiverQuest.ID].done.erase("root")
	check(state.restore(old_gate).is_empty() and RiverQuest.story(state).active=="blocked_exit", "pre-harvest gate warning remains ordinary warning")
	Meta.stop()
	map.deactivate_location()
	map.queue_free()
	map = null
	await settle()
	print("SHRINE GATE NAVIGATION: %d checks; %d failures. %s" % [checks,failures,directory])
	quit(1 if failures else 0)
