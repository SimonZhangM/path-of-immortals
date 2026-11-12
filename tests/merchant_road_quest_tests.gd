extends "res://tests/river_quest_tests.gd"

const Merchant=preload("res://scripts/quests/merchant_road_quest.gd")

func finish_merchant(scene: String) -> void:
	var guard:=0
	while Merchant.story(state).active==scene and not Merchant.story(state).reward_pending and guard<40:
		map._advance_dialogue(); guard+=1
	check(guard<40,"finite merchant scene "+scene)

func art(expected: String) -> void:
	check(map.dialogue.picture.requested_visible==not expected.is_empty(),"picture visibility "+expected)
	if not expected.is_empty(): check(map.dialogue.picture.illustration.texture.resource_path=="res://assets/"+expected+".webp","correct scene picture "+expected)

func run() -> void:
	create_timer(55).timeout.connect(func():quit(2))
	directory="res://artifacts/merchant-art-20261107/run-%d/"%Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	Slots.auto_path=directory+"auto.json"; Session.index_path=directory+"session.json"
	Session.clear_selection(); path=Slots.working_path()
	root.get_node("SavePlaytime").set_process(false)
	root.get_node("GameSettings").apply_values({"background_pause":false,"dialogue_speed":"instant","dialogue_auto":false})
	root.get_node("GameSettings").set_application_focus(true)
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size=Vector2i.ZERO; root.size=Vector2i(1920,1080)
	render=DisplayServer.get_name()!="headless"
	check(Merchant.configuration_error().is_empty(),"merchant configuration valid")
	await switch_to("qingshihewan",15)
	var fixture:=state.snapshot()
	for goal:Dictionary in QuestState.definition.objectives: fixture.quests[QuestState.ID].counts[goal.id]=goal.required
	fixture.quests[QuestState.ID].story=QuestStory.migrated({"counts":fixture.quests[QuestState.ID].counts})
	fixture.quests[RiverQuest.ID].done=["traces","injured","entrance","root","mirror","beasts_gone","medicine","return_jade","invite_doctor","pickup","clinic_arrival","gift_book","closing"]
	fixture.quests[RiverQuest.ID].accepted_location=RiverQuest.RIVER
	fixture.quests[Merchant.ID]={"accepted_at":1,"updated_at":1,"accepted_location":RiverQuest.TOWN}
	fixture.encounter_cooldowns={Merchant.data.ordinary_encounter_id:WorldCalendar.current_day(state.calendar)+20}
	check(state.restore(fixture).is_empty() and Merchant.story(state).stage=="searching","legacy accepted record migrates without progress")
	check(not MapEventRegistry.is_unlocked(state,JSON.parse_string(FileAccess.get_file_as_string("res://data/map_events/qingshizhen_shop.json"))),"merchant absent from shop during rescue")
	var before:=state.snapshot()
	Merchant.record_victory(state,Merchant.data.ordinary_encounter_id)
	check(state.snapshot()==before,"ordinary earlier victory cannot rescue merchant")
	state.set_map_location(Merchant.data.road.map_id,Merchant.data.road.point_id)
	before=state.snapshot()
	check(not Merchant.command(state,directory+"missing/begin.json","begin","ambush").is_empty() and state.snapshot()==before,"failed opening save cannot revive the old beast")
	arrive(12)
	check(Merchant.story(state).active=="ambush" and map.merchant_story_controller.owns_dialogue(),"road arrival starts dedicated opening despite old cooldown")
	check(int(state.encounter_cooldowns[Merchant.data.ordinary_encounter_id])==0 and not map.event_state.completed.has(Merchant.data.ordinary_encounter_id),"entering scene two revives the exact road node immediately")
	art("map-event-z2-1")
	if render: await create_timer(0.3).timeout; await shot("ambush")
	map._advance_dialogue()
	check(Merchant.story(state).line==1,"first scene advances")
	await switch_to("qingshihewan",12)
	check(Merchant.story(state).active=="ambush" and Merchant.story(state).line==1,"opening resumes exact saved line")
	check(not map.event_state.completed.has(Merchant.data.ordinary_encounter_id),"revived node remains alive after reload")
	finish_merchant("ambush")
	check(Merchant.story(state).stage=="battle" and map.event_state.phase=="encounter" and map.event_state.active_id==Merchant.data.battle.id,"opening leads to dedicated rescue battle")
	check(map.content.get_node("Points/N12/Sign").visible,"revived beast sign returns after the opening")
	check(map.event_state.active_event().enemy_id=="base.enemy.chisong_liaozhu","existing full beast definition used")
	var battle=load("res://scenes/main/main.tscn").instantiate()
	var manager:GameManager=battle.get_node("GameManager")
	manager.loadout_save_path=path; manager.use_saved_loadout=true; manager.enemy_id=Merchant.data.battle.enemy_id
	root.add_child(battle); manager.set_process(false); await settle()
	check(manager.startup_error.is_empty(),"real battle entry loads")
	var flow=load("res://scripts/map/map_battle_return.gd").new()
	flow.manager=manager; flow.events=map.event_state; flow.event_id=Merchant.data.battle.id; flow.save_path=path
	manager.start_battle(); manager.simulation._finish("defeat",0); flow._record_result()
	check(manager._durable_snapshot.quests[Merchant.ID].stage=="battle","defeat grants no rescue")
	manager.restart(); manager.start_battle(); manager.simulation._finish("victory",0)
	flow._recorded=false; flow._battle_id="merchant-rescue-check"; flow._loot_rolls=[0.99,0.99,0.99,0.99,0.99]
	flow.save_path=directory+"missing/battle.json"
	flow._record_result()
	check(not flow.reward_error.is_empty() and manager._durable_snapshot.quests[Merchant.ID].stage=="battle","failed battle save cannot publish rescue")
	flow.save_path=path; flow._record_result()
	check(flow.reward_error.is_empty() and manager._durable_snapshot.quests[Merchant.ID].stage=="rescued","victory saves rescue with normal loot transaction")
	check(not manager._durable_snapshot.narrative.flags.get(Merchant.RESCUE_FLAG,false),"formal rescue fact waits until return to shop")
	check(map.resume_after_battle(manager._durable_snapshot).is_empty(),"retained map resumes settled rescue")
	flow.free(); battle.free(); await settle()
	state=map.loadout
	check(Merchant.story(state).active=="rescued","battle return automatically starts third scene")
	art("map-event-z2-2")
	if render: await create_timer(0.3).timeout; await shot("rescued")
	finish_merchant("rescued")
	check(Merchant.story(state).stage=="escorting" and not map.travel.paused,"postbattle talk starts persistent escort")
	var detail:=Merchant.display_entry(state,{})
	check(detail.objectives.size()==4 and detail.objectives.slice(0,3).all(func(o):return o.completed) and not detail.objectives[3].completed,"escort retains completed objectives")
	await switch_to("qingshizhen",25)
	check(Merchant.story(state).active=="town_arrival","first town node starts three-line return talk")
	check(Merchant.data.scenes.town_arrival.lines.size()==3,"town talk is exactly three requested lines")
	art("")
	if render: await shot("town-arrival-without-picture")
	finish_merchant("town_arrival")
	check(Merchant.story(state).town_talk_done and not map.travel.paused,"town talk recorded once and releases movement")
	check(Merchant.arrival(state,RiverQuest.TOWN,Merchant.data.town_entry.point_id).is_empty(),"town talk does not repeat")
	arrive(16)
	check(Merchant.story(state).active=="shop_return","shop arrival starts final dialogue")
	art("map-event-z2-3")
	if render: await create_timer(0.3).timeout; await shot("shop-return")
	finish_merchant("shop_return")
	check(Merchant.story(state).reward_pending and state.narrative.flags.get(Merchant.NAME_FLAG,false),"normal name introduction recorded before reward")
	var coins:=state.spirit_stones
	before=state.snapshot(); map.inventory_save_path=directory+"missing/reward.json"
	map._accept_reward()
	check(state.snapshot()==before and map.reward_dialog.visible,"failed reward save retains pending dialogue and currency")
	map.inventory_save_path=path; map._accept_reward()
	check(Merchant.story(state).stage=="completed" and state.spirit_stones==coins+10,"shop reward completes quest once")
	check(state.narrative.flags.get(Merchant.RESCUE_FLAG,false) and not Merchant.shop_away(state),"formal rescue unlocks ordinary shop")
	check(map.content.get_node("Points/N16/Sign").visible,"ordinary shop sign restored")
	check(Merchant.command(state,path,"accept").is_empty() and state.spirit_stones==coins+10,"repeat reward cannot pay twice")
	check(Merchant.arrival(state,RiverQuest.TOWN,Merchant.data.shop.point_id).is_empty(),"completed shop scene does not replay")
	map.set_task_open(true); map.task_screen.task_list.select_task(Merchant.ID)
	check(map.task_screen.detail_header.artwork.texture.resource_path=="res://assets/UI-task-right-zhi-shanglujinghun.webp","task detail uses supplied WebP")
	check(map.task_screen.task_list.cards[Merchant.ID].find_child("TaskThumbnail",true,false).texture.resource_path=="res://assets/UI-task-mid-zhi-shanglujinghun.webp","task middle card uses supplied WebP")
	if render: await shot("completed-task")
	map.set_task_open(false)
	var source:=state.snapshot(); source.quests[Merchant.ID].merge({"stage":"escorting","town_talk_done":true,"active":"","line":0,"location":{},"reward_pending":false},true)
	check(state.restore(source).is_empty(),"known-name return fixture")
	check(Merchant.command(state,path,"begin","shop_return").is_empty() and Merchant.command(state,path,"advance").is_empty() and Merchant.story(state).line==4,"known-name player skips repeated introduction")
	check(Merchant.command(state,path,"advance").is_empty(),"advance final thanks")
	check(MapLoadoutStore.load_into(state,path).is_empty() and Merchant.story(state).line==5,"final return dialogue resumes saved line")
	var result:={"checks":checks,"failures":failures,"directory":directory,"render":render}
	FileAccess.open(directory+"validation.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("MERCHANT ROAD "+JSON.stringify(result))
	map.deactivate_location(); map.free(); quit(1 if failures else 0)
