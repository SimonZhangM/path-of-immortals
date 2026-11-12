extends "res://tests/river_quest_tests.gd"

func run() -> void:
	create_timer(55).timeout.connect(func(): quit(2))
	directory="res://artifacts/prologue-training-gifts-20261105/compat-%d/"%Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	Slots.auto_path=directory+"auto.json"
	Session.index_path=directory+"session.json"
	Session.clear_selection()
	path=Slots.working_path()
	root.get_node("SavePlaytime").set_process(false)
	root.get_node("GameSettings").apply_values({"background_pause":false,"dialogue_speed":"instant","dialogue_auto":false})
	root.content_scale_size=Vector2i.ZERO
	root.size=Vector2i(1920,1080)
	render=DisplayServer.get_name()!="headless"
	await switch_to("qingshizhen",31)
	var fixture := state.snapshot()
	for objective: Dictionary in QuestState.definition.objectives: fixture.quests[QuestState.ID].counts[objective.id]=objective.required
	fixture.quests[QuestState.ID].story=QuestStory.migrated({"counts":fixture.quests[QuestState.ID].counts})
	fixture.quests[RiverQuest.ID].done=["traces","injured","entrance","root","mirror","beasts_gone","medicine","return_jade","invite_doctor","pickup","clinic_arrival","gift_book"]
	fixture.quests[RiverQuest.ID].accepted_location=RiverQuest.RIVER
	check(state.restore(fixture).is_empty(),"legacy book-complete fixture")
	check(state.add_reward(RiverQuest.data.scenes.gift_book.reward).is_empty(),"legacy book receipt retained")
	var legacy := state.snapshot()
	arrive(32)
	finish_scene("gift_board")
	check(map.reward_dialog.visible,"book-complete save reaches board gift")
	for resolution: Vector2i in [Vector2i(1920,1080),Vector2i(2560,1440)]:
		root.size=resolution
		await settle()
		var tile: Control=map.reward_dialog.card
		var label: Label=tile.name_label
		check(label.get_theme_font("font").get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,27).x<=label.size.x,"full board name fits at "+str(resolution.x))
		check(tile.square.size==Vector2(152,152),"caption does not expand item art")
		await shot("xiaolan-name-"+str(resolution.x))
	var branch: MapLoadoutState=MapLoadoutStore.candidate(state).state
	# Capacity counts distinct kinds; remove the prototype's initial Xiaolan
	# so this receipt actually needs a new bag slot.
	var packed := branch.snapshot()
	packed.board_id="base.board.bag"
	packed.placements=[]
	for unit: String in packed.owned_units.keys():
		if packed.owned_units[unit]=="base.map_item.qinglan_board_1": packed.owned_units.erase(unit)
	check(branch.restore(packed).is_empty(),"full-bag fixture has no existing board stack")
	branch.storage_capacity_rules=state.storage_capacity_rules.duplicate(true)
	branch.storage_capacity_rules.test_capacity_override=branch.storage_used_slots()
	var before := branch.snapshot()
	check(not RiverQuest.command(branch,directory+"parcel.json","accept").is_empty() and branch.snapshot()==before,"full bag leaves pending board unchanged")
	check(RiverQuest.command(branch,directory+"parcel.json","reserve").is_empty(),"board can be reserved")
	check(RiverQuest.command(branch,directory+"parcel.json","advance").is_empty(),"reserved board continues final thanks")
	check(RiverQuest.arrival(branch,RiverQuest.TOWN,RiverQuest.data.scenes.closing.point_id).is_empty(),"reserved board cannot complete clinic")
	branch.storage_capacity_rules.test_capacity_override=999
	var count := branch.carried_owned().values().count("base.map_item.qinglan_board_1")
	check(RiverQuest.command(branch,directory+"parcel.json","claim_parcels").is_empty(),"board parcel claim succeeds")
	check(branch.carried_owned().values().count("base.map_item.qinglan_board_1")==count+1,"parcel grants exactly one board")
	check(RiverQuest.arrival(branch,RiverQuest.TOWN,RiverQuest.data.scenes.closing.point_id)=="closing","actual board receipt unlocks closing")
	check(RiverQuest.command(branch,directory+"parcel.json","claim_parcels").is_empty() and branch.carried_owned().values().count("base.map_item.qinglan_board_1")==count+1,"parcel claim is idempotent")
	var old_closing := legacy.duplicate(true)
	old_closing.quests[RiverQuest.ID].merge({"active":"closing","line":1,"location":{"map_id":RiverQuest.TOWN,"point_id":RiverQuest.data.scenes.closing.point_id}},true)
	check(branch.restore(old_closing).is_empty(),"legacy active closing restores without board receipt")
	check(RiverQuest.arrival(branch,RiverQuest.TOWN,RiverQuest.data.scenes.closing.point_id)=="closing","legacy closing keeps cursor")
	legacy.quests[RiverQuest.ID].done.append("closing")
	check(branch.restore(legacy).is_empty(),"legacy completed main two restores")
	check(RiverQuest.arrival(branch,RiverQuest.TOWN,RiverQuest.data.scenes.closing.point_id).is_empty(),"completed clinic never replays new gift")
	legacy.quests[HomecomingQuest.ID].merge({"accepted_location":RiverQuest.TOWN,"letter_received":true,"home_reunited":true,"guidance_completed":true},true)
	check(branch.restore(legacy).is_empty(),"legacy completed guidance restores")
	var expected_scene := "preparation" if int(branch.growth.realm)==0 else ""
	check(HomecomingQuest.ready_for_practice(branch) and HomecomingQuest.arrival(branch,HomecomingQuest.data.home.map_id,HomecomingQuest.data.home.point_id)==expected_scene,"completed guidance retained; only mortal saves receive supplementary teaching")
	var result := {"checks":checks,"failures":failures,"directory":directory,"render":render}
	FileAccess.open(directory+"validation.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("PROLOGUE_GIFT_COMPATIBILITY "+JSON.stringify(result))
	map.deactivate_location()
	map.free()
	quit(1 if failures else 0)
