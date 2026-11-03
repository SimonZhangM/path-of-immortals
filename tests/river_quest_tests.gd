extends "res://tests/save_actions_tests.gd"

var map: Control
var state: MapLoadoutState
var path := ""
var render := false

func arrive(number: int) -> void:
	var point: String = map.definition.id+".point.n%02d"%number
	map.travel.current_node_id = point
	map.travel.map_position = map.travel.node_positions[point]
	map.travel.stop_at_current_node()
	map.player.position = map.travel.map_position
	map._on_node_arrived(point)

func finish_scene(id: String) -> void:
	check(RiverQuest.story(state).active==id,"active scene: "+id+" actual: "+str(RiverQuest.story(state).active))
	var count := 0
	while RiverQuest.story(state).active==id and not RiverQuest.story(state).reward_pending and count<40:
		map._advance_dialogue()
		count += 1
	check(count<40,"scene terminates: "+id)

func switch_to(name_: String, number: int) -> void:
	if map!=null:
		await settle()
		Meta.stop()
		map.deactivate_location()
		map.free()
	map = load("res://scenes/maps/"+name_+".tscn").instantiate()
	map.inventory_save_path = path
	map.arrival_point_id = "base.map."+name_+".point.n%02d"%number
	map.defer_map_music = true
	map.defer_optional_views = true
	root.add_child(map)
	current_scene = map
	state = map.loadout
	await settle()
	check(map.startup_error.is_empty(),"map starts: "+name_+": "+map.startup_error)

func shot(label: String) -> void:
	if render: await capture(label)

func run() -> void:
	create_timer(55).timeout.connect(func(): quit(2))
	directory = "res://artifacts/river-story-20261101/run-%d/"%Time.get_ticks_usec()
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
	await switch_to("qingshihewan",15)
	var original := state.snapshot()
	var legacy := original.duplicate(true)
	legacy.quests.erase(RiverQuest.ID)
	check(state.restore(legacy).is_empty(),"legacy quest schema migrates")
	check(RiverQuest.story(state).done.is_empty(),"migration does not invent story facts")
	for key in ["owned_units","growth","learning","map_location","map_visited"]: check(state.snapshot()[key]==original[key],"migration preserves "+key)
	var ready := state.snapshot()
	for id: String in ready.quests[QuestState.ID].counts: ready.quests[QuestState.ID].counts[id] = 1
	ready.quests[QuestState.ID].story = QuestStory.migrated({"counts":ready.quests[QuestState.ID].counts})
	check(state.restore(ready).is_empty(),"isolated first quest completed fixture")
	check(MapLoadoutStore.save(state,path).is_empty(),"save fixture")
	var river := RiverQuest.RIVER
	check(map.travel.blocked_routes.size()==2,"two river branch routes closed")
	check(not map.travel.request_destination(river+".point.n14"),"north branch cannot be walked")
	check(not map.travel.request_destination(river+".point.n16"),"south branch cannot be walked")
	check(map.travel.request_destination(river+".point.n37"),"bridge remains accessible")
	map.travel.advance(100)
	check(map.travel.current_node_id==river+".point.n37","walk across real bridge")
	check(map.travel.request_destination(river+".point.n40"),"new blood waypoint accessible")
	map.travel.advance(100)
	check(RiverQuest.story(state).active=="traces" and map.travel.paused,"blood lines trigger at route midpoint")
	await shot("blood-traces")
	map._advance_dialogue()
	await switch_to("qingshihewan",40)
	check(RiverQuest.story(state).line==1 and map.dialogue.visible,"blood cursor resumes on reload")
	finish_scene("traces")
	check(map.travel.request_destination(river+".point.n20"),"temple continuation accessible")
	map.travel.advance(100)
	check(not map.dialogue.picture.visible,"injured observation precedes illustration")
	check(map.dialogue.speaker_name.text==DialogueJournal.full_name(state.narrative),"first temple line is protagonist observation")
	map._advance_dialogue()
	check(map.dialogue.speaker_name.text=="青岚宗弟子","name not revealed prematurely")
	for i in 3: map._advance_dialogue()
	await shot("injured-illustration")
	finish_scene("injured")
	check(map.travel.blocked_routes.size()==2,"gate remains until loan receipt accepted")
	var jade_before := RiverQuest.item_count(state,"base.map_item.warm_jade")
	check(map.dialogue.visible and map.dialogue.picture.visible and not map.reward_dialog.shade.visible,"loan reward overlays intact dialogue and illustration without screen shade")
	check(map.dialogue.background.visible and map.dialogue.text_label.visible and map.dialogue.portrait.visible,"loan overlay retains actual dialogue bubble, words and portrait")
	check(map.dialogue._phase=="dialogue_paused","reward freezes dialogue auto playback")
	check(RiverQuest.story(state).line==18 and not map.dialogue.next_marker.visible,"loan receipt pauses at the handover line")
	await shot("loan-over-dialogue")
	if render:
		root.size = Vector2i(2560,1440)
		await shot("loan-over-dialogue-2k")
		root.size = Vector2i(1920,1080)
	await switch_to("qingshihewan",20)
	check(map.dialogue.visible and map.reward_dialog.visible and not map.reward_dialog.shade.visible,"pending loan restores both layers")
	await click(map.reward_dialog.accept_button)
	check(RiverQuest.story(state).active=="injured" and RiverQuest.story(state).line==19 and map.dialogue.visible,"receiving loan immediately continues the same dialogue")
	check(not RiverQuest.done(state,"injured") and map.travel.blocked_routes.size()==2,"remaining dialogue precedes path unlock")
	await switch_to("qingshihewan",20)
	check(RiverQuest.story(state).line==19 and (map.reward_dialog==null or not map.reward_dialog.visible),"post-receipt reload resumes conversation without giving loan twice")
	finish_scene("injured")
	check(RiverQuest.done(state,"injured") and map.travel.blocked_routes.is_empty(),"conversation and loan unlock north/south")
	if RiverQuest.story(state).active=="blood_herb": finish_scene("blood_herb")
	check(RiverQuest.item_count(state,"base.map_item.warm_jade")==jade_before+1,"loan granted once")
	check(RiverQuest.command(state,path,"accept").is_empty(),"duplicate reward confirmation is harmless")
	check(RiverQuest.item_count(state,"base.map_item.warm_jade")==jade_before+1,"duplicate does not create jade")
	var before_shrine := state.snapshot()
	var before_entry: Dictionary = QuestTracking.entries(state).filter(func(row): return row.id==RiverQuest.ID)[0]
	check(not before_entry.objectives.any(func(row): return "旧祠" in row.text),"temple destination unknown before detour")
	check(before_entry.objectives.filter(func(row): return row.id=="root")[0].targets[0].point_id==river+".point.n03","root search initially points to the pictured fork")
	arrive(3)
	check(RiverQuest.story(state).active=="detour","pictured N03 fork triggers beast detour")
	map._advance_dialogue()
	await switch_to("qingshihewan",3)
	check(RiverQuest.story(state).line==1,"detour dialogue resumes from saved line")
	await shot("detour-at-n03")
	finish_scene("detour")
	var discovered: Dictionary = QuestTracking.entries(state).filter(func(row): return row.id==RiverQuest.ID)[0]
	check(discovered.stage_id=="detour" and discovered.objectives.back().text=="前往无名旧祠","discovering shrine appends independent travel objective")
	check(discovered.objectives.back().targets[0].point_id==river+".point.n02","new shrine objective points to actual entrance")
	check(discovered.objectives.filter(func(row): return row.id=="root")[0].targets.is_empty(),"exact root location remains unknown outside shrine")
	var blood_ready: MapLoadoutState = MapLoadoutStore.candidate(state).state
	check(blood_ready.add_reward({"id":"base.map_reward.test.detour_blood","item_id":"base.material.zhixuecao","quantity":1}).is_empty(),"known blood herb fixture")
	var pending: Array = QuestTracking.objectives(RiverQuest.display_entry(blood_ready,discovered))
	check(pending.size()==2 and pending[0].id=="root" and pending[1].id=="shelter","with blood herb ready there are exactly two active objectives")
	var legacy_fork: MapLoadoutState = MapLoadoutStore.candidate(state).state
	var legacy_snapshot := before_shrine.duplicate(true)
	legacy_snapshot.map_location = {"map_id":river,"point_id":river+".point.n02"}
	check(legacy_fork.restore(legacy_snapshot).is_empty(),"pre-change entrance save valid")
	check(RiverQuest.command(legacy_fork,directory+"legacy-detour.json","begin","detour").is_empty(),"old entrance save receives detour without moving player")
	check(RiverQuest.valid(JSON.parse_string(JSON.stringify(RiverQuest.story(legacy_fork)))),"recovery point cursor survives JSON persistence")
	check(RiverQuest.arrival(state,river,river+".point.n03").is_empty(),"detour is shown once")
	await switch_to("wumingjiuci",1)
	finish_scene("entrance")
	check(RiverQuest.exit_blocked(state,RiverQuest.SHRINE),"first shrine visit locks exit")
	check(not map.content.get_node("Points/N04").visible,"central encounter node hidden")
	var hidden_routes := 0
	for route: MapRoute in map.content.get_node("Routes").get_children():
		if route.route_id in RiverQuest.data.shrine_hidden_routes:
			hidden_routes += 1
			check(not route.visible,"hidden node connected route invisible")
	check(hidden_routes==4,"all four central routes accounted for")
	check(not map.travel.request_destination(RiverQuest.data.shrine_hidden_point),"hidden node cannot be selected through travel API")
	map.travel.exploration_enabled = false
	var root_path: Array = map.travel.shortest_path(RiverQuest.SHRINE+".point.n01",RiverQuest.SHRINE+".point.n31")
	check(not root_path.is_empty(),"root remains reachable around the hidden central node")
	for edge: Dictionary in root_path: check(not map.travel.blocked_routes.has(edge.id),"root path uses only open routes")
	check(map.travel.shortest_path(RiverQuest.SHRINE+".point.n01",RiverQuest.SHRINE+".point.n05").is_empty(),"altar is inaccessible before the root")
	map.travel.current_node_id = RiverQuest.data.shrine_hidden_point
	check(not map.travel.shortest_path(map.travel.current_node_id,RiverQuest.SHRINE+".point.n03").is_empty(),"legacy save at hidden point can walk outward")
	check(not map._try_start_event(map.travel.current_node_id,"click",true),"legacy hidden point does not trigger its encounter")
	map.travel.current_node_id = RiverQuest.SHRINE+".point.n01"
	map.travel.exploration_enabled = true
	check(map.content.get_node("Points/N31/QuestSign").visible and not map.content.get_node("Points/N31/Sign").visible,"first herb sign replaced by event")
	map._try_open_exit(map.travel.current_node_id)
	finish_scene("blocked_exit")
	check(not map.is_exit_open(),"blocked door never opens transition confirmation")
	arrive(17)
	finish_scene("fox_notice")
	check(RiverQuest.story(state).active=="fox_choice" and map.river_story_controller.choices.visible,"fox offers rescue directly")
	await shot("fox-choice")
	await settle()
	await click(map.river_story_controller.choices.get_child(1))
	finish_scene("fox_leave")
	check(not RiverQuest.done(state,"fox_rescue") and not map.event_state.is_active(),"leave keeps fox alive and releases modal")
	check(map._try_start_event(map.travel.current_node_id,"click",true),"fox can be revisited without intro")
	await click(map.river_story_controller.choices.get_child(0))
	finish_scene("fox_rescue")
	check(RiverQuest.done(state,"fox_rescue") and not RiverQuest.done(state,"fox_release"),"rescue and release are independent facts")
	check(map.event_state.phase!="encounter","fox does not spawn an extra spider")
	arrive(33)
	finish_scene("wood_door")
	check(map.travel.adjacency[RiverQuest.SHRINE+".point.n33"].size()==1,"wooden door has no path through the lock")
	map._try_start_event(map.travel.current_node_id,"click",true)
	finish_scene("wood_door_again")
	arrive(26)
	check(map.event_state.phase=="encounter" and RiverQuest.story(state).active.is_empty(),"array also defaults to encounter before observation")
	map._retreat_encounter()
	arrive(23)
	check(map.event_state.phase=="encounter" and RiverQuest.story(state).active.is_empty(),"stone encounter precedes observation")
	map._retreat_encounter()
	arrive(31)
	check(RiverQuest.story(state).active=="root_discovery" and not map.gathering_dialog.visible,"first root starts discovery")
	var before_root := state.snapshot()
	var root_before := RiverQuest.item_count(state,"base.material.qingtenggen")
	var date_before: Dictionary = state.calendar.duplicate(true)
	finish_scene("root_discovery")
	check(map.gathering_dialog.visible and not RiverQuest.done(state,"root"),"discovery opens ordinary gathering")
	var root_event: Dictionary = map.event_state.active_event()
	var root_rng := RandomNumberGenerator.new()
	root_rng.seed = 33
	check(MapGatheringRewards.prepare(state,root_event,"base.gathering.quick",path,root_rng).is_empty(),"prepare ordinary root harvest")
	await switch_to("wumingjiuci",31)
	map._try_start_event(map.travel.current_node_id,"click",true)
	check(map.gathering_result.visible and not map.reward_dialog.visible,"pending harvest resumes through regular result dialog")
	map._accept_gathering()
	check(RiverQuest.done(state,"root") and RiverQuest.item_count(state,"base.material.qingtenggen")>root_before,"actual gathering claim completes root objective")
	check(WorldCalendar.current_day(state.calendar)==WorldCalendar.current_day(date_before)+1,"quick gathering costs its configured day")
	check(map.travel.hidden_points.is_empty(),"root reopens central node and routes")
	var root_sign: CanvasItem = map.content.get_node_or_null("Points/N31/QuestSign")
	check(root_sign==null or not root_sign.visible,"discovery sign is removed")
	map._try_start_event(map.travel.current_node_id,"click",true)
	check(not map.event_state.is_active(),"claimed harvest does not reopen on revisit")
	map._cancel_gathering()
	# Same-instance battle return restores the authoritative snapshot and gates.
	var cleared := state.snapshot()
	if not cleared.has("encounter_cooldowns"): cleared.encounter_cooldowns = {}
	cleared.encounter_cooldowns["base.map_event.wumingjiuci.encounter_n30"] = WorldCalendar.current_day(state.calendar)+20
	check(state.restore(cleared).is_empty(),"battle-style snapshot restore")
	check(map.travel.hidden_points.is_empty(),"retained map keeps story routes unlocked")
	arrive(1)
	finish_scene("courtyard_check")
	arrive(5)
	check(RiverQuest.story(state).active=="mirror","mirror tied to altar node")
	check(RiverQuest.data.scenes.mirror.lines.size()==14,"legacy mirror line indices retained for save compatibility")
	for i in 4: map._advance_dialogue()
	await shot("mirror-text")
	await switch_to("wumingjiuci",5)
	check(RiverQuest.story(state).line==4,"mirror cursor survives reload")
	finish_scene("mirror")
	check(state.narrative.flags.get("base.story.hewanfengxian.broken_mirror",false),"mirror possession recorded once as story fact")
	arrive(1)
	finish_scene("beasts_gone")
	check(map.is_exit_open() and not RiverQuest.exit_blocked(state,RiverQuest.SHRINE),"normal exit restored after beasts pass")
	await map._complete_exit()
	map = current_scene
	state = map.loadout
	await settle()
	check(map.definition.id==RiverQuest.RIVER and map.travel.current_node_id==RiverQuest.RIVER+".point.n02","actual original gate transitions back to river N02")
	finish_scene("fox_release")
	check(RiverQuest.done(state,"fox_release"),"release occurs at river/shrine connection")
	check(not map._try_start_event(map.travel.current_node_id,"click",true),"release not repeated")
	var entries := QuestTracking.entries(state)
	check(entries.size()==2 and entries[1].stage_id=="returning","second task remains unfinished at return-medicine objective")
	check(entries[1].objectives.back().text=="带着药材返回沈砚舟身边" and not entries[1].objectives.back().completed,"no unimplemented clinic completion")
	if RiverQuest.item_count(state,"base.material.zhixuecao")==0: check("还需备齐止血草" in entries[1].introductions.returning,"introduction does not claim missing herbs are ready")
	map.set_task_open(true)
	map.task_screen.task_list.select_task(RiverQuest.ID)
	check(map.task_screen.task_list.entries.size()==2 and map.task_screen.task_list.selected_task_id==RiverQuest.ID,"real task list exposes and selects second quest")
	map.quest_tracker_controller.toggle_task(RiverQuest.ID)
	check(RiverQuest.ID in state.quest_tracking.ids,"second quest can be tracked from the real task view")
	await shot("task-after-shrine")
	if render:
		root.size = Vector2i(2560,1440)
		await shot("task-after-shrine-2k")
		root.size = Vector2i(1920,1080)
	map.set_task_open(false)
	# Failure is atomic; old inventory alone does not count as the first root event.
	check(state.restore(before_root).is_empty(),"restore isolated pre-root fixture")
	var unchanged := state.snapshot()
	check(not RiverQuest.command(state,"res://artifacts/missing-parent/no-save.json","advance").is_empty(),"write failure reported")
	check(state.snapshot()==unchanged,"failed save keeps cursor and inventory intact")
	check(not RiverQuest.done(state,"root"),"existing root inventory does not skip first root event")
	var malformed := state.snapshot()
	malformed.quests[RiverQuest.ID].line = 999
	check(not state.restore(malformed).is_empty(),"invalid persisted cursor rejected")
	# Full bags retain the ordinary pending harvest until space is available.
	check(state.restore(before_root).is_empty(),"reset full-bag case")
	var without_root := state.snapshot()
	for unit: String in without_root.owned_units.keys():
		if without_root.owned_units[unit]=="base.material.qingtenggen": without_root.owned_units.erase(unit)
	check(state.restore(without_root).is_empty(),"full-bag fixture has no existing root stack")
	var original_limit: int = state.storage_capacity_rules.test_capacity_override
	state.storage_capacity_rules.test_capacity_override = maxi(1,state.storage_used_slots())
	while not RiverQuest.story(state).active.is_empty(): check(RiverQuest.command(state,path,"advance").is_empty(),"finish discovery")
	check(MapGatheringRewards.prepare(state,root_event,"base.gathering.quick",path,root_rng).is_empty(),"prepare pending root harvest")
	var full_before := state.snapshot()
	check(not MapGatheringRewards.claim(state,root_event,path).is_empty(),"full bag rejects normal receipt without overflowing")
	check(state.snapshot()==full_before,"full bag does not lose pending root or advance story")
	state.storage_capacity_rules.test_capacity_override = original_limit
	check(MapGatheringRewards.claim(state,root_event,path).is_empty() and RiverQuest.done(state,"root"),"claim harvest after making room")
	var count_after := RiverQuest.item_count(state,"base.material.qingtenggen")
	check(MapGatheringRewards.claim(state,root_event,path).is_empty() and RiverQuest.item_count(state,"base.material.qingtenggen")==count_after,"reclaim does not duplicate material")
	var legacy_reward: MapLoadoutState = MapLoadoutStore.candidate(state).state
	var legacy_reward_snapshot := before_root.duplicate(true)
	legacy_reward_snapshot.quests[RiverQuest.ID].active = "root"
	legacy_reward_snapshot.quests[RiverQuest.ID].line = RiverQuest.data.scenes.root.lines.size()-1
	legacy_reward_snapshot.quests[RiverQuest.ID].reward_pending = true
	check(legacy_reward.restore(JSON.parse_string(JSON.stringify(legacy_reward_snapshot))).is_empty(),"old last-line pending reward still loads")
	check(RiverQuest.story(legacy_reward).active=="root_discovery" and not RiverQuest.story(legacy_reward).reward_pending,"unclaimed old reward resumes discovery")
	check(state.restore(before_shrine).is_empty(),"restore no-fox fixture")
	check(not RiverQuest.done(state,"fox_rescue"),"optional fox not inferred by main quest")
	var legacy_temple: MapLoadoutState = MapLoadoutStore.candidate(state).state
	legacy_temple.quests[RiverQuest.ID] = RiverQuest.initial()
	legacy_temple.set_map_location(RiverQuest.RIVER,RiverQuest.RIVER+".point.n20")
	check(RiverQuest.arrival(legacy_temple,RiverQuest.RIVER,RiverQuest.RIVER+".point.n20")=="traces","old save at temple receives missing blood observation")
	check(RiverQuest.command(legacy_temple,directory+"legacy-temple.json","begin","traces").is_empty(),"temple migration observation has a valid saved cursor")
	var herb_fixture: MapLoadoutState = MapLoadoutStore.candidate(state).state
	herb_fixture.quests[RiverQuest.ID] = RiverQuest.initial()
	herb_fixture.quests[RiverQuest.ID].done = ["traces","injured"]
	herb_fixture.set_map_location(RiverQuest.RIVER,RiverQuest.RIVER+".point.n04")
	check(herb_fixture.add_reward({"id":"base.map_reward.test.river_herb","item_id":"base.material.zhixuecao","quantity":1}).is_empty(),"existing usable blood herb fixture")
	check(RiverQuest.arrival(herb_fixture,RiverQuest.RIVER,herb_fixture.map_location.point_id)=="blood_herb","actual or prior blood herb enables its conditional line")
	herb_fixture.quests[RiverQuest.ID].done.append("blood_herb")
	check(RiverQuest.arrival(herb_fixture,RiverQuest.RIVER,herb_fixture.map_location.point_id).is_empty(),"blood herb line is once only")
	Meta.stop()
	map.deactivate_location()
	map.free()
	print("River quest checks: %d, failures: %d; artifacts: %s"%[checks,failures,directory])
	quit(1 if failures else 0)
