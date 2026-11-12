extends "res://tests/river_quest_tests.gd"

const Net = preload("res://scripts/quests/fishing_net_quest.gd")

func finish_net() -> void:
	var limit := 0
	while not Net.story(state).active.is_empty() and not Net.story(state).reward_pending and limit<35:
		map._advance_dialogue()
		limit += 1
	check(limit<35,"dialogue terminates or pauses for transfer")

func run() -> void:
	create_timer(55).timeout.connect(func(): quit(2))
	directory = "res://artifacts/fishing-net-20261106/run-%d/"%Time.get_ticks_usec()
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
	await switch_to("baishacun",18)
	check(Net.configuration_error().is_empty(),"quest content valid")
	check(map.travel.node_positions.size()==21,"21 village points")
	check(map.travel.hidden_points.has(Net.data.reef.point_id),"reef hidden before quest")
	check(not map.content.get_node("Points/N21").visible and not map.content.get_node("Routes/R24_N18_N21").visible,"no point or route before quest")
	check(not map.travel.request_destination(Net.data.reef.point_id),"hidden reef cannot be clicked or pathed")
	check(Net.arrival(state,Net.data.dock.map_id,Net.data.dock.point_id).is_empty(),"no errand before mother reunion")
	var legacy := state.snapshot()
	legacy.quests.erase(Net.ID)
	check(state.restore(legacy).is_empty() and Net.story(state)==Net.initial(),"old save receives inactive quest")
	var fixture := state.snapshot()
	for target: Dictionary in QuestState.definition.objectives: fixture.quests[QuestState.ID].counts[target.id] = target.required
	fixture.quests[QuestState.ID].story = QuestStory.migrated({"counts":fixture.quests[QuestState.ID].counts})
	fixture.quests[RiverQuest.ID].done = ["traces","injured","entrance","root","mirror","beasts_gone","medicine","return_jade","invite_doctor","pickup","clinic_arrival","gift_book","closing"]
	fixture.quests[RiverQuest.ID].accepted_location = RiverQuest.RIVER
	fixture.quests[HomecomingQuest.ID].accepted_location = RiverQuest.TOWN
	fixture.quests[HomecomingQuest.ID].letter_received = true
	fixture.quests[HomecomingQuest.ID].home_reunited = true
	fixture.map_visited["base.map.baishacun"].erase(Net.data.route_start)
	check(state.restore(fixture).is_empty(),"post-reunion fixture")
	check(Net.arrival(state,Net.data.dock.map_id,Net.data.dock.point_id)=="intro","reunion unlocks dock dialogue")
	var sign: Sprite2D = map.fishing_net_story_controller.signs.entries[Net.data.dock.point_id].overlay
	check(sign!=null and sign.visible and sign.get_meta("optional"),"yellow side-quest marker at dock")
	check(sign.position==Vector2(0,-223.928571),"shared marker anchor preserved")
	arrive(14)
	check(Net.story(state).active=="intro" and map.travel.paused,"dock arrival directly enters dialogue")
	check(not Net.accepted(state) and map.travel.hidden_points.has(Net.data.reef.point_id),"route remains closed throughout introduction")
	await shot("dock-intro")
	finish_net()
	check(Net.accepted(state) and not map.travel.paused,"intro finishes and restores free movement")
	check(not map.travel.hidden_points.has(Net.data.reef.point_id),"route opens after final introduction line")
	check(map.content.get_node("Points/N21").visible and map.content.get_node("Routes/R24_N18_N21").visible,"new point and route revealed by introduction even before N18 visit")
	check(not state.map_visited["base.map.baishacun"].has(Net.data.reef.point_id),"revealing new route does not credit an actual visit")
	check(not map.travel.shortest_path("base.map.baishacun.point.n18",Net.data.reef.point_id).is_empty(),"new path is navigable")
	check(MapLoadoutStore.save(state,path).is_empty(),"save accepted errand")
	await switch_to("baishacun",18)
	check(not map.travel.hidden_points.has(Net.data.reef.point_id),"unlocked route survives reload")
	await shot("reef-route")
	arrive(21)
	check(Net.story(state).active=="retrieve","reef arrival automatically begins second scene")
	finish_net()
	check(Net.story(state).reward_pending and not Net.story(state).net_received,"net granted only after second scene")
	check(map.reward_dialog.visible and map.dialogue.visible and not map.reward_dialog.shade.visible,"receipt overlays dialogue without black shade")
	check(map.reward_dialog.card.entry.icon=="res://assets/item-qita-rw-yuwang.webp","net uses specified art")
	check(state.records[Net.data.item_id].quest_item and not MapShop.new()._sale_allowed(state,Net.data.item_id),"net is protected task item")
	await shot("net-receipt")
	var capacity: Dictionary = state.storage_capacity_rules.duplicate(true)
	state.storage_capacity_rules.test_capacity_override = state.storage_used_slots()
	map._accept_reward()
	check(Net.story(state).reward_pending and map.fishing_net_story_controller.defer_receipt_button.visible,"full bag offers safe receipt deferral")
	map.fishing_net_story_controller.defer_receipt_button.pressed.emit()
	check(not map.travel.paused and not map.reward_dialog.visible and Net.story(state).reward_pending,"full bag can leave dialogue with receipt retained")
	state.storage_capacity_rules = capacity
	check(map.fishing_net_story_controller.try_arrival(Net.data.reef.point_id,true) and map.reward_dialog.visible,"returning to reef resumes pending receipt")
	var pending := state.snapshot()
	map.inventory_save_path = directory+"missing/fail.json"
	map._accept_reward()
	check(state.snapshot()==pending and map.reward_dialog.visible,"failed receipt save changes no inventory or cursor")
	map.inventory_save_path = path
	map._accept_reward()
	check(Net.story(state).net_received and state.carried_owned().values().count(Net.data.item_id)==1,"one net received: "+map.reward_dialog.error_label.text)
	if not Net.story(state).net_received:
		quit(1)
		return
	check(not map.travel.paused,"receipt restores movement")
	check(Net.command(state,path,"accept").is_empty() and state.carried_owned().values().count(Net.data.item_id)==1,"duplicate acceptance does not duplicate net")
	var entries := QuestTracking.entries(state)
	var entry: Dictionary = {}
	for row: Dictionary in entries:
		if row.id==Net.ID: entry = row
	check(entry.stage_id=="returning" and entry.objectives.size()==3,"task objectives advance to handover")
	check(entry.people[0].name=="许长海" and entry.rewards[0].quantity==2,"person and two-stone reward connected")
	check(entry.image=="res://assets/UI-task-mid-zhi-jiuwangdaichao.webp" and entry.detail_image=="res://assets/UI-task-right-jiuwangdaichao.webp","task images connected")
	arrive(14)
	check(Net.story(state).active=="returning" and Net.story(state).line==0,"third scene begins with returning line")
	check(state.carried_owned().values().count(Net.data.item_id)==1,"net remains while first line is visible")
	map._advance_dialogue()
	check(Net.handing_over(state) and map.reward_dialog.heading.text=="交出","first line followed by net handover")
	await shot("net-handover")
	check(MapLoadoutStore.save(state,path).is_empty(),"save pending handover")
	await switch_to("baishacun",14)
	check(Net.story(state).reward_pending and map.reward_dialog.heading.text=="交出","handover resumes across reload")
	var before := state.snapshot()
	map.inventory_save_path = directory+"missing/fail.json"
	map._accept_reward()
	check(state.snapshot()==before,"failed handover save preserves net")
	map.inventory_save_path = path
	if render: await click(map.reward_dialog.accept_button)
	else: map._accept_reward()
	check(Net.story(state).net_returned and Net.story(state).line==1,"handover continues at uncle receiving net")
	check(state.carried_owned().values().count(Net.data.item_id)==0,"handover removes exactly one net")
	check(Net.command(state,path,"accept").is_empty() and Net.story(state).line==1,"double handover confirmation is harmless")
	var stones: int = state.spirit_stones
	finish_net()
	check(Net.story(state).reward_pending and not Net.story(state).completed,"completion reward after entire closing dialogue")
	map._accept_reward()
	check(Net.story(state).completed and state.spirit_stones==stones+2,"completion awards two stones once")
	check(not map.travel.paused and not map.fishing_net_story_controller.signs.entries[Net.data.dock.point_id].overlay.visible,"completion restores movement and removes marker")
	check(Net.arrival(state,Net.data.dock.map_id,Net.data.dock.point_id).is_empty(),"completed task does not auto-repeat")
	check(MapLoadoutStore.save(state,path).is_empty(),"completed save valid")
	await switch_to("baishacun",14)
	check(Net.story(state).completed and state.spirit_stones==stones+2,"completion and currency survive reload")
	check(map.fishing_net_story_controller.try_arrival(Net.data.dock.point_id,true),"manual completed response available")
	finish_net()
	check(state.spirit_stones==stones+2,"completed response grants no extra reward")
	map.set_task_open(true)
	map.task_screen.task_list.select_task(Net.ID)
	await shot("completed-task")
	var result := {"checks":checks,"failures":failures,"directory":directory,"render":render}
	FileAccess.open(directory+"validation.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("FISHING_NET "+JSON.stringify(result))
	map.deactivate_location()
	map.free()
	quit(1 if failures else 0)
