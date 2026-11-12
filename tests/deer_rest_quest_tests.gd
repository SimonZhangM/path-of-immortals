extends "res://tests/river_quest_tests.gd"
const Deer = preload("res://scripts/quests/deer_rest_quest.gd")

func finish_deer() -> void:
	var guard := 0
	while not Deer.story(state).active.is_empty() and not Deer.story(state).choice_pending and not Deer.story(state).reward_pending and guard<30:
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
	await switch_to("diecuifeng",9)
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
	check(not map.content.get_node("Points/N09").has_node("Sign"),"N09 has no ordinary rest sign")
	check(not map.event_registry.by_point.has(Deer.data.tree.point_id),"N09 no longer binds a rest event")
	var ordinary: Array = map.event_registry.events.values().filter(func(e): return e.type=="encounter" and e.id!=Deer.data.battle.id)
	check(ordinary.size()==12,"twelve ordinary encounters including gated N11")
	for n in [6,21,27]:
		var event: Dictionary = map.event_registry.events["base.map_event.diecuifeng.encounter_n%02d"%n]
		check(event.enemy_id=="base.enemy.biyetengling" and event.respawn_days==20,"other vine unchanged N%d"%n)
	arrive(18)
	check(Deer.story(state).active=="deer" and map.travel.paused,"deer marker automatically starts dialogue on arrival")
	check(map._try_start_event(Deer.data.deer.point_id,"click",true),"click during active dialogue does not restart it")
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
	arrive(9)
	check(Deer.story(state).active=="inspect" and map.travel.paused,"tree marker automatically starts investigation after deer")
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
	await switch_to("diecuifeng",9)
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
	arrive(9)
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
	check(MapEventRegistry.is_unlocked(state,map.event_registry.events["base.map_event.diecuifeng.encounter_n11"]),"N11 unlocks immediately after driving vine before cleanup ends")
	check(not state.narrative.flags.has(Deer.LEGACY_REST_FLAG),"retired rest flag absent")
	map._advance_dialogue()
	await switch_to("diecuifeng",9)
	check(Deer.story(state).line==1 and Deer.story(state).active=="clear","cleanup resumes without another fight")
	var coins := state.spirit_stones
	while Deer.story(state).line<4: map._advance_dialogue()
	await settle()
	await shot("03-clear-leaf")
	finish_deer()
	check(Deer.story(state).reward_pending and Deer.story(state).stage=="cleared" and map.reward_dialog.visible,"completion waits for one material receipt")
	check(map.reward_dialog.card.entry.id==Deer.data.completion_reward.item_id,"receipt uses ancient tree quest leaf")
	check(state.records[Deer.data.completion_reward.item_id].quest_item and not MapShop.new()._sale_allowed(state,Deer.data.completion_reward.item_id),"ancient tree leaf is a protected task item")
	await shot("04-leaf-receipt")
	var pending := state.snapshot()
	map.inventory_save_path = directory+"missing/leaf.json"
	map._accept_reward()
	check(state.snapshot()==pending and map.reward_dialog.visible and not map.reward_dialog.accept_button.disabled,"failed reward save grants nothing and allows retry")
	map.inventory_save_path = path
	await switch_to("diecuifeng",9)
	check(Deer.story(state).reward_pending and map.reward_dialog.visible,"pending material receipt resumes after reload")
	var full: MapLoadoutState = MapLoadoutStore.candidate(state).state
	var packed := full.snapshot()
	for unit: String in packed.owned_units.keys():
		if packed.owned_units[unit]==Deer.data.completion_reward.item_id: packed.owned_units.erase(unit)
	check(full.restore(packed).is_empty(),"capacity fixture removes preexisting leaf stacks")
	full.storage_capacity_rules.test_capacity_override = full.storage_used_slots()
	var occupied_before := full.storage_used_slots()
	var full_error := Deer.command(full,directory+"full-bag.json","accept")
	check(full_error.is_empty() and Deer.story(full).stage=="completed" and full.storage_used_slots()==occupied_before,"full bag accepts quest leaf without capacity use: "+full_error)
	var before_leaves: int = state.carried_owned().values().count(Deer.data.completion_reward.item_id)
	map._accept_reward()
	check(Deer.story(state).stage=="completed" and not Deer.story(state).reward_pending,"material accepted completes quest: "+map.reward_dialog.error_label.text)
	if Deer.story(state).stage!="completed": quit(1); return
	check(state.carried_owned().values().count(Deer.data.completion_reward.item_id)==before_leaves+1 and state.has_reward(Deer.data.completion_reward.id),"exactly one task leaf granted with receipt")
	var received := state.snapshot()
	check(Deer.command(state,path,"accept").is_empty() and state.snapshot()==received,"repeated accept cannot duplicate reward")
	check(not map.travel.paused and state.spirit_stones==coins,"completion releases movement without extra coins")
	check(not map.content.get_node("Points/N09").has_node("Sign"),"completion adds no rest sign")
	check(not map.deer_rest_controller.signs.entries[Deer.data.tree.point_id].overlay.visible,"completed quest sign removed")
	check(not Deer.epilogue_available(state) and not click_tree() and not map.event_state.is_active(),"same-day click opens neither narration nor rest")
	var day := WorldCalendar.current_day(state.calendar)
	state.advance_days(1,"base.test.deer_coda_wait")
	check(WorldCalendar.current_day(state.calendar)==day+1,"one game day passes elsewhere")
	check(Deer.story(state).active.is_empty(),"time passing does not autoplay coda")
	check(click_tree() and Deer.story(state).active=="epilogue","next deliberate click starts coda")
	var resources: Dictionary = map.player_status.resources.duplicate()
	day = WorldCalendar.current_day(state.calendar)
	await settle()
	await shot("05-coda-no-basket")
	map._advance_dialogue()
	await switch_to("diecuifeng",9)
	check(Deer.story(state).active=="epilogue" and Deer.story(state).line==1,"coda resumes exact saved line")
	finish_deer()
	check(Deer.story(state).epilogue_done and not Deer.epilogue_available(state),"coda permanently read once")
	check(WorldCalendar.current_day(state.calendar)==day and map.player_status.resources==resources,"coda gives no free recovery or time cost")
	check(state.carried_owned().values().count(Deer.data.completion_reward.item_id)==before_leaves+1,"coda grants no second leaf")
	check(not click_tree() and not map.event_state.is_active() and Deer.story(state).active.is_empty(),"later clicks leave N09 as ordinary path")
	map.set_task_open(true)
	map.task_screen.task_list.select_task(Deer.ID)
	await settle()
	check(map.task_screen.detail_header.visible and map.task_screen.detail_header.title_label.text=="鹿眠处","task title remains visible with cover art")
	check(entry().objectives.all(func(o): return o.completed) and entry().rewards[0].item_id==Deer.data.completion_reward.item_id and entry().rewards[0].quantity==1,"finished goals and leaf reward")
	await shot("06-completed-task")
	map.set_task_open(false)
	var result := {"checks":checks,"failures":failures,"directory":directory,"render":render}
	FileAccess.open(directory+"validation.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("DEER_REST "+JSON.stringify(result))
	map.deactivate_location()
	map.free()
	quit(1 if failures else 0)
