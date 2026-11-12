extends "res://tests/river_quest_tests.gd"
const Deer = preload("res://scripts/quests/deer_rest_quest.gd")

func finish_deer() -> void:
	var guard := 0
	while not Deer.story(state).active.is_empty() and not Deer.story(state).choice_pending and guard<30:
		map._advance_dialogue()
		guard += 1
	check(guard<30,"dialogue terminates or waits at choice")

func entry() -> Dictionary:
	for row: Dictionary in QuestTracking.entries(state):
		if row.id==Deer.ID: return row
	return {}

func click_tree() -> bool:
	return map._try_start_event(Deer.data.tree.point_id,"click",true)

func run() -> void:
	create_timer(55).timeout.connect(func(): quit(2))
	directory = "res://artifacts/deer-rest-20261111/run-%d/"%Time.get_ticks_usec()
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
	await switch_to("diecuifeng",11)
	if not map.startup_error.is_empty(): quit(1); return
	check(Deer.configuration_error().is_empty(),"quest data valid: "+Deer.configuration_error())
	var original := state.snapshot()
	var legacy := original.duplicate(true)
	legacy.quests.erase(Deer.ID)
	legacy.encounter_cooldowns = {}
	legacy.encounter_cooldowns["base.map_event.diecuifeng.encounter_n11"] = WorldCalendar.current_day(state.calendar)+20
	legacy.encounter_cooldowns["base.map_event.diecuifeng.encounter_n06"] = WorldCalendar.current_day(state.calendar)+20
	check(state.restore(legacy).is_empty() and Deer.story(state).stage=="unseen","legacy adds only initial task state")
	check(state.encounter_cooldowns==legacy.encounter_cooldowns,"old monster cooldowns preserved")
	check(entry().is_empty() and not click_tree(),"tree before deer has no task, encounter or rest")
	check(not map.content.get_node("Points/N11/Sign").visible,"locked rest has no original sign")
	check(map.event_registry.by_point[Deer.data.tree.point_id]=="base.map_event.diecuifeng.rest_n11","N11 binds rest rather than ordinary vine")
	var ordinary: Array = map.event_registry.events.values().filter(func(e): return e.type=="encounter" and e.id!=Deer.data.battle.id)
	check(ordinary.size()==11,"eleven ordinary encounters remain")
	for n in [6,21,27]:
		var event: Dictionary = map.event_registry.events["base.map_event.diecuifeng.encounter_n%02d"%n]
		check(event.enemy_id=="base.enemy.biyetengling" and event.respawn_days==20,"other vine unchanged N%d"%n)
	arrive(18)
	check(Deer.story(state).active.is_empty(),"passing deer does not interrupt movement")
	check(map._try_start_event(Deer.data.deer.point_id,"click",true),"click deer begins")
	check(map.dialogue.speaker_name.text=="旁白","narrator identity")
	check(map.dialogue.portrait.texture.atlas.resource_path=="res://assets/ui-portrait-pangbai.webp","chosen narrator portrait")
	check(map.dialogue.picture.requested_visible,"opening scene art is shown")
	await shot("01-narrator")
	map._advance_dialogue()
	check(map.dialogue.speaker_name.text==DialogueJournal.full_name(state.narrative),"player identity returns on self-talk")
	await switch_to("diecuifeng",18)
	check(Deer.story(state).line==1 and map.dialogue.visible,"opening cursor resumes")
	finish_deer()
	check(Deer.accepted(state) and entry().objectives.size()==1 and not map.travel.paused,"first scene accepts task and releases movement")
	var sign: Sprite2D = map.deer_rest_controller.signs.entries[Deer.data.tree.point_id].overlay
	check(sign.visible and sign.get_meta("optional") and sign.position==Vector2(0,-223.928571),"yellow task sign uses shared anchor")
	arrive(11)
	check(click_tree(),"tree investigation begins after deer")
	finish_deer()
	check(Deer.story(state).choice_pending and map.deer_rest_controller.choices.visible,"two story choices appear")
	check(map.encounter_dialog==null or not map.encounter_dialog.visible,"no encounter popup")
	check(entry().objectives.size()==2 and entry().objectives[0].completed,"investigation reveals drive objective")
	await settle()
	await shot("02-choices")
	await click(map.deer_rest_controller.leave_button)
	finish_deer()
	check(Deer.story(state).stage=="battle" and not map.travel.paused,"leave preserves task and freedom")
	check(click_tree(),"tree can retry")
	var before := state.snapshot()
	map.inventory_save_path = directory+"missing/fight.json"
	map.deer_rest_controller.choose("fight")
	check(state.snapshot()==before and map.deer_rest_controller.choices.visible,"failed choice save does not start battle")
	map.inventory_save_path = path
	await switch_to("diecuifeng",11)
	check(Deer.story(state).choice_pending and map.deer_rest_controller.choices.visible,"pending choice resumes")
	await click(map.deer_rest_controller.fight_button)
	await create_timer(3.5).timeout
	var battle := current_scene
	check(battle!=map and battle.has_node("MapBattleReturn"),"choice opens actual battle directly")
	if battle==map: quit(1); return
	var manager: GameManager = battle.get_node("GameManager")
	var flow = battle.get_node("MapBattleReturn")
	check(manager.startup_error.is_empty() and manager.enemy_id=="base.enemy.biyetengling","real configured vine loaded")
	check(not map.encounter_dialog.visible,"encounter popup stays hidden during battle")
	check(manager.simulation.state.phase==GameState.Phase.PREPARATION and manager.simulation.state.time_usec==0,"battle entry waits for explicit start")
	manager.set_process(false)
	manager.start_battle()
	manager.simulation._finish("defeat",0)
	flow._record_result()
	check(manager._durable_snapshot.quests[Deer.ID].stage=="battle","defeat does not clear quest")
	check((await flow.return_to_map()).is_empty(),"defeat returns to map")
	await settle()
	state = map.loadout
	check(Deer.story(state).active.is_empty() and not map.travel.paused,"defeat restores free movement")
	arrive(11)
	check(click_tree(),"failed fight can retry")
	await settle()
	await click(map.deer_rest_controller.fight_button)
	await create_timer(3.5).timeout
	battle = current_scene
	if battle==map: check(false,"retry enters battle"); quit(1); return
	manager = battle.get_node("GameManager")
	flow = battle.get_node("MapBattleReturn")
	manager.set_process(false)
	manager.start_battle()
	manager.simulation._finish("victory",0)
	flow.save_path = directory+"missing/victory.json"
	flow._record_result()
	check(not flow.reward_error.is_empty() and manager._durable_snapshot.quests[Deer.ID].stage=="battle","failed victory save does not publish success")
	flow.save_path = path
	flow._record_result()
	check(flow.reward_error.is_empty() and manager._durable_snapshot.quests[Deer.ID].stage=="cleared","victory and loot committed together")
	check(manager._durable_snapshot.encounter_cooldowns==legacy.encounter_cooldowns,"task victory leaves every ordinary cooldown untouched")
	check((await flow.return_to_map()).is_empty(),"victory returns")
	await settle()
	state = map.loadout
	check(Deer.story(state).active=="clear" and map.dialogue.visible,"victory automatically starts cleanup")
	check(not state.narrative.flags.get(Deer.REST_FLAG,false),"rest waits for cleanup completion")
	map._advance_dialogue()
	await switch_to("diecuifeng",11)
	check(Deer.story(state).line==1 and Deer.story(state).active=="clear","cleanup resumes without another fight")
	var coins := state.spirit_stones
	finish_deer()
	check(Deer.story(state).stage=="completed" and state.narrative.flags.get(Deer.REST_FLAG,false),"cleanup completes task and unlocks rest")
	check(not map.travel.paused and state.spirit_stones==coins,"completion releases movement without extra coins")
	check(map.content.get_node("Points/N11/Sign").visible,"rest sign restored after yellow overlay retires")
	check(not map.deer_rest_controller.signs.entries[Deer.data.tree.point_id].overlay.visible,"completed quest sign removed")
	check(not Deer.epilogue_available(state) and click_tree() and map.event_state.phase=="rest","same-day click opens rest without narration")
	var day := WorldCalendar.current_day(state.calendar)
	map._confirm_rest()
	await settle()
	check(WorldCalendar.current_day(state.calendar)==day+1,"outdoor rest costs one game day")
	check(Deer.story(state).active.is_empty(),"rest does not autoplay coda")
	if map.event_state.is_active(): map._close_rest()
	check(click_tree() and Deer.story(state).active=="epilogue","next deliberate click starts coda")
	var resources: Dictionary = map.player_status.resources.duplicate()
	day = WorldCalendar.current_day(state.calendar)
	map._advance_dialogue()
	await switch_to("diecuifeng",11)
	check(Deer.story(state).active=="epilogue" and Deer.story(state).line==1,"coda resumes exact saved line")
	finish_deer()
	check(Deer.story(state).epilogue_done and not Deer.epilogue_available(state),"coda permanently read once")
	check(WorldCalendar.current_day(state.calendar)==day and map.player_status.resources==resources,"coda gives no free recovery or time cost")
	check(click_tree() and map.event_state.phase=="rest" and Deer.story(state).active.is_empty(),"later clicks only rest")
	map._close_rest()
	map.set_task_open(true)
	map.task_screen.task_list.select_task(Deer.ID)
	await settle()
	check(map.task_screen.detail_header.visible and map.task_screen.detail_header.title_label.text=="鹿眠处","task title remains visible with cover art")
	check(entry().objectives.all(func(o): return o.completed) and entry().rewards[0].name=="树下歇息","finished goals and actual unlock reward")
	await shot("03-completed-task")
	map.set_task_open(false)
	var result := {"checks":checks,"failures":failures,"directory":directory,"render":render}
	FileAccess.open(directory+"validation.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("DEER_REST "+JSON.stringify(result))
	map.deactivate_location()
	map.free()
	quit(1 if failures else 0)
