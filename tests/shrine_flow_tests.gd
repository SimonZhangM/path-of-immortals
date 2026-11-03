extends "res://tests/river_quest_tests.gd"

const SHRINE := RiverQuest.SHRINE
const STONE_EVENT := "base.map_event.wumingjiuci.encounter_n23"
var entered: Dictionary

func place(number: int) -> void:
	var id := SHRINE + ".point.n%02d" % number
	state.set_map_location(SHRINE,id)
	map.travel.current_node_id = id
	map.travel.map_position = map.travel.node_positions[id]
	map.travel.stop_at_current_node()
	map.travel.paused = false
	map._visit_exploration(id)
	map.player.present(map.travel)
	map.content.position = map.map_viewport.size*0.5-map.travel.map_position*map.content.scale
	map._clamp_position()

func enter_stone_encounter() -> void:
	place(22)
	check(map.travel.request_destination(SHRINE+".point.n23"),"stone door is reached by its approach route")
	map.travel.advance(100)
	check(map.event_state.phase=="encounter" and RiverQuest.story(state).active.is_empty(),"stone encounter precedes observation")
	check(state.map_previous_location.point_id==SHRINE+".point.n22","actual approach recorded")

func battle_case(outcome: String) -> void:
	enter_stone_encounter()
	map._confirm_encounter()
	var presentation := root.get_node("MapPresentation")
	while current_scene==map or presentation.transitioning: await process_frame
	var battle := current_scene
	var manager: GameManager = battle.get_node("GameManager")
	manager.set_process(false)
	manager.start_battle()
	manager.party[0].hp = 0 if outcome=="defeat" else 17
	manager.simulation._finish(outcome,1000000)
	manager._process(0)
	var flow = battle.get_node("MapBattleReturn")
	check(flow.retreat_point_id==SHRINE+".point.n22","battle carries actual approach")
	check((await flow.return_to_map()).is_empty(),"battle returns after "+outcome)
	await settle()
	check(current_scene==map,"retained map resumes")
	var expected := SHRINE + (".point.n23" if outcome=="victory" else ".point.n22")
	check(map.travel.current_node_id==expected and state.map_location.point_id==expected,"position follows battle outcome")
	check(Files.read(path).map_location.point_id==expected and Files.read(Slots.quick_path()).map_location.point_id==expected,"return location saved to live and quick")
	if outcome=="victory":
		check(RiverQuest.story(state).active=="stone_door" and map.dialogue.visible,"victory automatically starts stone observation")
		finish_scene("stone_door")
	else:
		check(not RiverQuest.done(state,"stone_door") and RiverQuest.story(state).active.is_empty(),"failed encounter does not observe stone door")
		check(map.content.get_node("Points/N23/Sign").visible,"monster sign remains after failure")

func run() -> void:
	create_timer(55).timeout.connect(func(): quit(2))
	directory = "res://artifacts/shrine-flow-20261102/run-%d/" % Time.get_ticks_usec()
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
	await switch_to("wumingjiuci",1)
	var fixture := state.snapshot()
	for objective: Dictionary in QuestState.definition.objectives:
		fixture.quests[QuestState.ID].counts[objective.id] = objective.required
	fixture.quests[QuestState.ID].story = QuestStory.initial()
	fixture.quests[QuestState.ID].story.done = ["wake","morning","slope","returning"]
	fixture.quests[RiverQuest.ID].done = ["traces","injured","detour","entrance"]
	fixture.quests[RiverQuest.ID].accepted_location = RiverQuest.RIVER
	fixture.quest_tracking = {"ids":[RiverQuest.ID],"shown":true}
	check(state.restore(fixture).is_empty(),"restore first shrine entry")
	entered = state.snapshot()
	check(not map.quest_tracker_controller.markers.has_node("base_map_wumingjiuci_point_n05"),"no premature courtyard location marker")
	check(map.quest_tracker_controller.markers.has_node("base_map_wumingjiuci_point_n31"),"root search retains its own marker")
	check(map.travel.hidden_points.has(RiverQuest.data.shrine_hidden_point),"courtyard remains locked before harvest")
	await shot("first-entry")
	place(22)
	var sign: Sprite2D = map.content.get_node("Points/N23/Sign")
	check(sign.visible and sign.has_node("EnemyIcon") and map.content.get_node("Points/N23").get_node_or_null("QuestSign")==null,"stone door displays the original encounter sign")
	await shot("stone-encounter-sign")
	enter_stone_encounter()
	var old_path: String = map.inventory_save_path
	map.inventory_save_path = directory+"missing/save.json"
	map._retreat_encounter()
	check(map.event_state.phase=="encounter" and map.travel.current_node_id==SHRINE+".point.n23","failed retreat save keeps encounter retryable")
	map.inventory_save_path = old_path
	map._retreat_encounter()
	check(map.travel.current_node_id==SHRINE+".point.n22" and not map.event_state.is_active(),"cancel returns to approach node")
	check(Files.read(path).map_location.point_id==SHRINE+".point.n22","cancel return is durable")
	enter_stone_encounter()
	check(MapLoadoutStore.save(state,path).is_empty(),"save while at encounter")
	map.event_state.cancel_encounter()
	map.encounter_dialog.hide()
	await switch_to("wumingjiuci",23)
	check(map._encounter_retreat_point()==SHRINE+".point.n22","reload preserves actual approach")
	check(map._try_start_event(SHRINE+".point.n23","click",true),"encounter reopens after reload")
	map._retreat_encounter()
	check(map.travel.current_node_id==SHRINE+".point.n22","reloaded encounter cancels to approach")
	await battle_case("retreat")
	await battle_case("defeat")
	await battle_case("victory")
	# Discovery does not grant roots. Actual collection is the progression boundary.
	check(state.restore(entered).is_empty(),"restore pre-harvest state")
	place(31)
	check(map._try_start_event(SHRINE+".point.n31","arrival",true),"root discovery begins")
	var before_count := RiverQuest.item_count(state,"base.material.qingtenggen")
	finish_scene("root_discovery")
	check(RiverQuest.done(state,"root_discovery") and not RiverQuest.done(state,"root"),"discovery and collection are distinct")
	check(map.gathering_dialog.visible and map.event_state.phase=="gathering","discovery opens normal gathering dialog")
	check(RiverQuest.item_count(state,"base.material.qingtenggen")==before_count and not map.reward_dialog.visible,"discovery grants no automatic item")
	check(map.travel.hidden_points.has(RiverQuest.data.shrine_hidden_point),"discovery alone does not unlock courtyard")
	await shot("root-gathering")
	map._cancel_gathering()
	check(not RiverQuest.done(state,"root"),"cancel gathering leaves root objective incomplete")
	check(map._try_start_event(SHRINE+".point.n31","click",true) and map.gathering_dialog.visible,"revisit opens harvesting without replay")
	var event: Dictionary = map.event_state.active_event()
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	check(MapGatheringRewards.prepare(state,event,"base.gathering.careful",path,rng).is_empty(),"prepare ordinary herbal collection")
	check(not RiverQuest.done(state,"root"),"prepared loot alone does not complete root objective")
	map._show_gathering_result()
	var pending := state.snapshot()
	map.inventory_save_path = directory+"missing/save.json"
	map._accept_gathering()
	check(state.snapshot()==pending and not RiverQuest.done(state,"root"),"failed claim save preserves pending harvest")
	map.inventory_save_path = path
	map._accept_gathering()
	check(RiverQuest.done(state,"root") and RiverQuest.item_count(state,"base.material.qingtenggen")>before_count,"normal claim grants roots and completes objective")
	check(not map.travel.hidden_points.has(RiverQuest.data.shrine_hidden_point) and map.quest_tracker_controller.markers.has_node("base_map_wumingjiuci_point_n01"),"harvest unlocks courtyard and directs to original gate first")
	var claimed := state.snapshot()
	check(MapGatheringRewards.claim(state,event,path).is_empty() and state.snapshot()==claimed,"harvest receipt cannot grant twice")
	var legacy := entered.duplicate(true)
	legacy.quests[RiverQuest.ID].active = "root"
	legacy.quests[RiverQuest.ID].location = {"map_id":SHRINE,"point_id":SHRINE+".point.n31"}
	legacy.quests[RiverQuest.ID].reward_pending = true
	check(state.restore(legacy).is_empty() and RiverQuest.story(state).active=="root_discovery" and not RiverQuest.story(state).reward_pending,"legacy unclaimed automatic reward migrates to discovery")
	check(state.snapshot().owned_units==legacy.owned_units,"legacy migration does not add items")
	check(state.restore(claimed).is_empty(),"restore claimed collection")
	var legacy_completed := entered.duplicate(true)
	legacy_completed.quests[RiverQuest.ID].done.append("root")
	check(state.restore(legacy_completed).is_empty() and RiverQuest.done(state,"root"),"previously completed root story remains complete")
	Meta.stop()
	map.deactivate_location()
	map.queue_free()
	await settle()
	print("SHRINE FLOW: %d checks, %d failures" % [checks,failures])
	print("OUTPUT: "+directory)
	quit(1 if failures else 0)
