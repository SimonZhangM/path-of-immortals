extends "res://tests/river_quest_tests.gd"

const JADE := "base.map_item.warm_jade"
const BOOK := "base.book.yinqijue"
const HERB := "base.material.zhixuecao"
const ROOT_HERB := "base.material.qingtenggen"
const RESCUED := "base.story.qingshihewan.cultivator_rescued"

func run() -> void:
	create_timer(55).timeout.connect(func(): quit(2))
	directory = "res://artifacts/river-clinic-20261101/run-%d/"%Time.get_ticks_usec()
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
	await switch_to("qingshihewan",21)
	var fixture := state.snapshot()
	for id: String in fixture.quests[QuestState.ID].counts: fixture.quests[QuestState.ID].counts[id] = 1
	fixture.quests[QuestState.ID].story = QuestStory.migrated({"counts":fixture.quests[QuestState.ID].counts})
	fixture.quests[RiverQuest.ID].done = ["traces","injured","entrance","root","mirror","beasts_gone"]
	fixture.quests[RiverQuest.ID].accepted_location = RiverQuest.RIVER
	fixture.quest_tracking.ids = [RiverQuest.ID]
	for unit: String in fixture.owned_units.keys():
		if fixture.owned_units[unit] in [HERB,ROOT_HERB,JADE,BOOK]: fixture.owned_units.erase(unit)
	check(state.restore(fixture).is_empty(),"isolated post-shrine fixture")
	check(MapLoadoutStore.save(state,path).is_empty(),"save fixture")
	check(state.records[JADE].quest_item and state.records[BOOK].quest_item,"both items are quest items")
	check(not state.ordinary_acquisition_allowed(JADE),"jade ordinary acquisition locked before completion")
	var shop := MapShop.new()
	check(shop.load_catalog("res://data/shops/qingshizhen_sect.json",state).is_empty(),"sect shop loads")
	check(not shop.products("all",state).any(func(row): return row.item_id==JADE),"jade hidden from shop products")
	var before := state.snapshot()
	check(not shop.purchase(state,JADE,1,path).is_empty() and state.snapshot()==before,"direct purchase cannot bypass quest gate")
	var chest := {"quality":"下品","reward_id":"base.map_reward.test.river_clinic_chest"}
	check(MapChestRewards.load_rules().is_empty(),"chest rules load")
	var selected_pool := {}
	for pool: Dictionary in MapChestRewards._rules.pools:
		var slots := MapChestRewards.candidates(state,chest,pool)
		for slot: Array in slots: check(JADE not in slot,"jade excluded from chest pool")
		if "artifact" in pool.slots[1]: selected_pool = pool
	var other: String = MapChestRewards.candidates(state,chest,selected_pool)[0][0]
	state.chest_offers[chest.reward_id] = {"version":2,"pool_id":selected_pool.id,"items":[other,JADE]}
	before = state.snapshot()
	check(not MapChestRewards.claim(state,chest,1,path).is_empty() and state.snapshot()==before,"old pending jade chest cannot be claimed")
	check(MapChestRewards.ensure_offer(state,chest,path,RandomNumberGenerator.new()).is_empty(),"old pending offer migrated on open")
	check(JADE not in MapChestRewards.items(state,chest) and MapChestRewards.items(state,chest)[0]==other,"replace restricted choice and retain other choice")
	arrive(20)
	finish_scene("medicine_missing")
	check(not map.event_state.is_active() and not RiverQuest.done(state,"medicine"),"missing medicine releases modal without advancing")
	for id in [JADE,HERB,ROOT_HERB]:
		check(state.add_reward({"id":"base.map_reward.test.clinic."+id.get_slice(".",2),"item_id":id,"quantity":2}).is_empty(),"supply two units "+id)
	check(not shop.sell(state,JADE,1,path).is_empty(),"quest jade cannot be sold")
	var growth_before := state.growth.duplicate(true)
	var calendar_before := state.calendar.duplicate(true)
	before = state.snapshot()
	check(not RiverQuest.command(state,directory+"missing/fail.json","begin","medicine").is_empty(),"medicine save failure reported")
	check(state.snapshot()==before,"medicine save failure preserves both materials and cursor")
	var parcel_case: MapLoadoutState = MapLoadoutStore.candidate(state).state
	var parcel_snapshot := parcel_case.snapshot()
	for unit: String in parcel_snapshot.owned_units.keys():
		if parcel_snapshot.owned_units[unit]==ROOT_HERB: parcel_snapshot.owned_units.erase(unit)
	parcel_snapshot.erase("granted_rewards")
	parcel_snapshot.quests[RiverQuest.ID].parcels.root = RiverQuest.data.scenes.root.reward.duplicate(true)
	check(parcel_case.restore(parcel_snapshot).is_empty(),"unclaimed root parcel with no grant receipts fixture")
	check(RiverQuest.command(parcel_case,directory+"parcel-medicine.json","begin","medicine").is_empty(),"medicine consumes reserved root without needing bag space")
	check(RiverQuest.item_count(parcel_case,ROOT_HERB)==0 and parcel_case.has_reward(RiverQuest.data.scenes.root.reward.id),"consumed root parcel closed and receipted once")
	map._try_start_event(map.travel.current_node_id,"click",true)
	check(RiverQuest.bag_count(state,HERB)==1 and RiverQuest.bag_count(state,ROOT_HERB)==1,"exactly one of each medicine consumed")
	check(RiverQuest.bag_count(state,JADE)==2,"medicine delivery does not return jade")
	map._advance_dialogue()
	await switch_to("qingshihewan",20)
	check(RiverQuest.story(state).active=="medicine" and RiverQuest.story(state).line==1,"medicine cursor restored without repeat consumption")
	check(RiverQuest.bag_count(state,HERB)==1,"reload does not consume again")
	var with_jade := state.snapshot()
	var absent := state.snapshot()
	for unit: String in absent.owned_units.keys():
		if absent.owned_units[unit]==JADE: absent.owned_units.erase(unit)
	check(state.restore(absent).is_empty(),"missing carried jade fixture")
	finish_scene("medicine")
	finish_scene("jade_missing")
	check(not RiverQuest.doctor_away(state) and not map.event_state.is_active(),"river return waits for carried jade while bag remains accessible")
	check(RiverQuest.arrival(state,RiverQuest.TOWN,RiverQuest.data.scenes.invite_doctor.point_id).is_empty(),"new flow returns jade before inviting doctor")
	var waiting: Dictionary = RiverQuest.display_entry(state,QuestTracking.presentation.display_entries[1])
	check(waiting.stage_id=="return_jade" and waiting.objectives.back().targets[0].map_id==RiverQuest.RIVER,"pending handover objective remains at the river")
	var restored := state.snapshot()
	for unit: String in with_jade.owned_units:
		if with_jade.owned_units[unit]==JADE: restored.owned_units[unit] = JADE
	check(state.restore(restored).is_empty(),"jade returned to backpack")
	map._try_start_event(map.travel.current_node_id,"click",true)
	finish_scene("return_jade")
	check(map.reward_dialog.heading.text=="交出","handover title exact")
	check(map.reward_dialog.shade.visible,"handover restores ordinary shade after earlier inline rewards")
	check(map.reward_dialog.accept_button.get_node("AcceptCaption").text=="确认","handover button exact")
	check(not map.river_story_controller.choices.visible,"handover has no reserve or cancel action")
	check(RiverQuest.bag_count(state,JADE)==2,"opening popup removes nothing")
	await shot("handover-1080p")
	root.size = Vector2i(2560,1440)
	await shot("handover-1440p")
	root.size = Vector2i(1920,1080)
	await switch_to("qingshihewan",20)
	check(map.reward_dialog.visible and map.reward_dialog.heading.text=="交出" and RiverQuest.bag_count(state,JADE)==2,"handover reload keeps title and inventory")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape,true)
	await settle()
	check(map.reward_dialog.visible and RiverQuest.story(state).reward_pending,"Escape cannot cancel handover")
	before = state.snapshot()
	check(not RiverQuest.command(state,directory+"missing/fail.json","accept").is_empty() and state.snapshot()==before,"handover failed save does not remove jade")
	check(not RiverQuest.command(state,path,"reserve").is_empty() and state.snapshot()==before,"handover cannot be reserved")
	await click(map.reward_dialog.accept_button)
	check(RiverQuest.bag_count(state,JADE)==1 and RiverQuest.done(state,"return_jade"),"real confirm click removes exactly one jade")
	check(RiverQuest.command(state,path,"accept").is_empty() and RiverQuest.bag_count(state,JADE)==1,"duplicate confirm cannot remove second jade")
	check(RiverQuest.arrival(state,RiverQuest.TOWN,RiverQuest.data.scenes.invite_doctor.point_id)=="invite_doctor","doctor invitation opens after river handover")
	check(RiverQuest.display_entry(state,QuestTracking.presentation.display_entries[1]).rewards.is_empty(),"returning jade at river does not reveal clinic gift early")
	await switch_to("qingshizhen",32)
	await shot("invite-doctor")
	finish_scene("invite_doctor")
	check(RiverQuest.doctor_away(state),"doctor absent after invitation")
	map._try_start_event(map.travel.current_node_id,"click",true)
	finish_scene("doctor_away")
	check(map.clinic_dialog==null or not map.clinic_dialog.visible,"absent doctor does not open normal clinic")
	var library := NpcDialogueLibrary.new()
	check(library.load_file("res://data/dialogues/suqinghe.json").is_empty(),"doctor dialogue library loads")
	before = state.snapshot()
	check(not NpcDialogueActions.command(state,library,"visit",path).is_empty() and state.snapshot()==before,"personal dialogue transaction blocked while away")
	var clinic: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_events/qingshizhen_clinic.json"))
	check(not MapClinicTreatment.treat(state,map.player_status,clinic.treatment,path,library).error.is_empty(),"absent doctor cannot treat player")
	await switch_to("qingshihewan",20)
	finish_scene("pickup")
	check(not map.content.get_node("Points/N20/QuestSign").visible,"injured sign removed when patient leaves river")
	check(not state.narrative.flags.get(RESCUED,false),"pickup is not completion")
	await switch_to("qingshizhen",30)
	check(not state.narrative.flags.get(RESCUED,false),"arriving in town is not completion")
	arrive(32)
	finish_scene("clinic_arrival")
	check(RiverQuest.story(state).active=="gift_book" and RiverQuest.bag_count(state,JADE)==1,"clinic proceeds directly to gift without a second handover")
	# Preserve advanced legacy story saves and discard an obsolete clinic prompt.
	var advanced := state.snapshot()
	advanced.quests[RiverQuest.ID].done.erase("return_jade")
	advanced.quests[RiverQuest.ID].merge({"active":"","line":0,"location":{},"reward_pending":false},true)
	var migrated: MapLoadoutState = MapLoadoutStore.candidate(state).state
	for old_scene in ["", "return_jade", "jade_missing"]:
		var old := advanced.duplicate(true)
		if not old_scene.is_empty():
			old.quests[RiverQuest.ID].active = old_scene
			old.quests[RiverQuest.ID].line = 1 if old_scene=="return_jade" else 0
			old.quests[RiverQuest.ID].location = {"map_id":RiverQuest.TOWN,"point_id":clinic.point_id}
			old.quests[RiverQuest.ID].reward_pending = old_scene=="return_jade"
		check(migrated.restore(JSON.parse_string(JSON.stringify(old))).is_empty(),"legacy clinic stage loads: "+old_scene)
		check(RiverQuest.arrival(migrated,RiverQuest.TOWN,clinic.point_id)=="gift_book","legacy clinic proceeds to book: "+old_scene)
		check(migrated.snapshot().owned_units==old.owned_units and not RiverQuest.done(migrated,"return_jade"),"legacy transition preserves inventory and actual return facts: "+old_scene)
		var once := migrated.snapshot()
		check(migrated.restore(once).is_empty() and migrated.snapshot()==once,"legacy transition is idempotent: "+old_scene)
	finish_scene("gift_book")
	check(map.reward_dialog.heading.text=="获得物品" and map.reward_dialog.accept_button.get_node("AcceptCaption").text=="收下","gift resets ordinary receipt labels")
	check(RiverQuest.bag_count(state,BOOK)==0,"gift dialogue alone grants no book")
	await shot("book-receipt")
	var branch: MapLoadoutState = MapLoadoutStore.candidate(state).state
	branch.storage_capacity_rules = state.storage_capacity_rules.duplicate(true)
	branch.storage_capacity_rules.test_capacity_override = branch.storage_used_slots()
	check(not RiverQuest.command(branch,directory+"full.json","accept").is_empty(),"full bag cannot silently overflow")
	check(RiverQuest.command(branch,directory+"full.json","reserve").is_empty(),"book can be packed for later")
	check(RiverQuest.story(branch).active=="gift_book" and RiverQuest.command(branch,directory+"full.json","advance").is_empty(),"packed book continues its remaining dialogue")
	check(RiverQuest.arrival(branch,RiverQuest.TOWN,clinic.point_id).is_empty() and not branch.narrative.flags.get(RESCUED,false),"reserved but unreceived book cannot finish quest")
	branch.storage_capacity_rules.test_capacity_override = 999
	check(RiverQuest.command(branch,directory+"full.json","claim_parcels").is_empty(),"claim book parcel when capacity permits")
	check(RiverQuest.bag_count(branch,BOOK)==1 and RiverQuest.arrival(branch,RiverQuest.TOWN,clinic.point_id)=="closing","actual receipt unlocks closing")
	check(RiverQuest.command(branch,directory+"full.json","claim_parcels").is_empty() and RiverQuest.bag_count(branch,BOOK)==1,"parcel grants book once")
	await switch_to("qingshizhen",32)
	check(map.reward_dialog.visible and map.reward_dialog.heading.text=="获得物品","book pending receipt restores")
	check(map.dialogue.visible and not map.reward_dialog.shade.visible,"gift receipt retains dialogue without screen dimming")
	check(map.dialogue.text_label.visible and map.dialogue.background.visible,"gift receipt retains visible dialogue contents")
	await click(map.reward_dialog.accept_button)
	check(RiverQuest.bag_count(state,BOOK)==1 and not state.narrative.flags.get(RESCUED,false),"book received once before final dialogue completes")
	check(RiverQuest.story(state).active=="gift_book" and RiverQuest.story(state).line==4,"received book continues player response")
	finish_scene("gift_book")
	map._advance_dialogue()
	await switch_to("qingshizhen",32)
	check(RiverQuest.story(state).active=="closing" and RiverQuest.story(state).line==1,"closing cursor restored")
	finish_scene("closing")
	check(state.narrative.flags.get(RESCUED,false) and RiverQuest.ID not in state.quest_tracking.ids,"final dialogue completes quest and untracks")
	check(state.growth==growth_before and state.calendar==calendar_before,"quest does not heal, cultivate, grant growth or consume time")
	var entry: Dictionary = QuestTracking.entries(state).filter(func(e): return e.id==RiverQuest.ID)[0]
	check(entry.stage_id=="completed" and not entry.has_locked_next,"completed quest detail and no next lock")
	check(entry.objectives.all(func(row): return row.completed),"consumed herbs remain completed objectives")
	check(state.ordinary_acquisition_allowed(JADE) and shop.products("all",state).any(func(row): return row.item_id==JADE),"jade ordinary acquisition unlocks only on completion")
	var unlocked: MapLoadoutState = MapLoadoutStore.candidate(state).state
	unlocked.spirit_stones = 1000
	check(shop.purchase(unlocked,JADE,1,directory+"unlocked.json").is_empty() and RiverQuest.bag_count(unlocked,JADE)==2,"post-completion purchase uses normal transaction")
	check(JADE in MapChestRewards.candidates(state,chest,selected_pool)[1],"post-completion chest pool restores jade")
	check(not state.registry.library.books.has(BOOK),"reading book has no invented cultivation definition")
	var item: ItemData = state.registry.get_item(BOOK)
	check(item.category=="book" and item.icon_path=="res://assets/UI-otherbook-yinqijue.webp" and "任务物品" in item.tags,"quest cultivation book registered with designated art")
	var catalog := MapInventoryCatalog.new()
	catalog.configure(JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/map_inventory.json")))
	check(catalog.replace_entries(state.storage_records()).is_empty(),"book included in ordinary inventory catalog")
	catalog.collection = "key"
	check(catalog.visible_entries().any(func(row): return row.id==JADE) and catalog.visible_entries().any(func(row): return row.id==BOOK),"both quest items visible in key-item collection")
	map.set_task_open(true)
	map.task_screen.task_list.select_task(RiverQuest.ID)
	await shot("quest-complete")
	map.set_task_open(false)
	var tooltip := ItemTooltip.new()
	tooltip.configure(item,CultivationDescription.tooltip_context(state.knowledge,BOOK,item))
	root.add_child(tooltip)
	tooltip.z_index = 100
	tooltip.position = Vector2(650,250)
	await shot("book-tooltip")
	check(tooltip.details_button==null,"reading-only book has no inactive cultivation details control")
	tooltip.free()
	await switch_to("qingshizhen",32)
	check(RiverQuest.bag_count(state,BOOK)==1 and RiverQuest.bag_count(state,JADE)==1,"completion reload retains exactly one book and unreturned duplicate jade")
	check(RiverQuest.arrival(state,RiverQuest.TOWN,clinic.point_id,true).is_empty(),"completed story does not replay")
	check(NpcDialogueActions.command(state,library,"visit",path).is_empty(),"normal clinic personal dialogue restored")
	Meta.stop()
	map.deactivate_location()
	map.free()
	print("River clinic checks: %d, failures: %d; artifacts: %s"%[checks,failures,directory])
	quit(1 if failures else 0)
