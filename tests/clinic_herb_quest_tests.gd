extends "res://tests/river_quest_tests.gd"

func finish_herb_scene(id: String) -> void:
	check(HerbQuest.story(state).active==id,"errand scene active: "+id)
	var guard := 0
	while HerbQuest.story(state).active==id and not HerbQuest.story(state).reward_pending and guard<30:
		map._advance_dialogue()
		guard += 1
	check(guard<30,"errand scene terminates: "+id)

func entry() -> Dictionary:
	for row: Dictionary in QuestTracking.entries(state):
		if row.id==HerbQuest.ID:
			return row
	return {}

func open_clinic() -> void:
	# Inspect the ordinary clinic layer independently of the ready-to-deliver shortcut.
	check(map.event_state.try_start(map.travel.current_node_id,map.travel.current_node_id,true,"click"),"open ordinary clinic layer")
	map.travel.paused = true
	map._present_event_progress()
	check(map.event_state.phase=="clinic" and map.clinic_dialog.visible,"ordinary clinic accessible")
	check(map.clinic_dialog.herb_quest_button.visible,"explicit errand action available")
	await settle()

func run() -> void:
	create_timer(55).timeout.connect(func(): quit(2))
	directory = "res://artifacts/clinic-herbs-20261102/run-%d/"%Time.get_ticks_usec()
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
	await switch_to("qingshizhen",31)
	check(HerbQuest.configuration_error().is_empty(),"authored errand data valid")
	check(entry().is_empty(),"unaccepted side quest hidden from task list")
	var before := state.snapshot()
	check(not HerbQuest.command(state,path,"begin","intro").is_empty() and state.snapshot()==before,"cannot start away from clinic")
	check(HerbQuest.exit_blocked(state,RiverQuest.TOWN,HerbQuest.data.river_exit),"river exit initially locked")
	check(not HerbQuest.exit_blocked(state,RiverQuest.TOWN,"base.map.qingshizhen.point.n04"),"herb slope exit stays available")
	var fixture := state.snapshot()
	for id: String in fixture.quests[QuestState.ID].counts:
		fixture.quests[QuestState.ID].counts[id] = 1
	fixture.quests[QuestState.ID].story = QuestStory.migrated({"counts":fixture.quests[QuestState.ID].counts})
	for unit: String in fixture.owned_units.keys():
		if fixture.owned_units[unit]==HerbQuest.data.item_id:
			fixture.owned_units.erase(unit)
	check(state.restore(fixture).is_empty(),"isolated completed first-main fixture")
	check(MapLoadoutStore.save(state,path).is_empty(),"persist fixture")
	# Older saves without this side quest acquire an unaccepted, separate record.
	var legacy := state.snapshot()
	legacy.quests.erase(HerbQuest.ID)
	var candidate: MapLoadoutState = MapLoadoutStore.candidate(state).state
	check(candidate.restore(legacy).is_empty() and not HerbQuest.accepted(candidate),"legacy quest schema initializes without inventing acceptance")
	var legacy_reward := state.snapshot()
	legacy_reward.quests[QuestState.ID].counts.deliver = 0
	legacy_reward.quests[QuestState.ID].story = QuestStory.initial()
	legacy_reward.quests[QuestState.ID].story.merge({"active":"returning","line":12,"reward_pending":true,"location":QuestStory.data.shop.duplicate(true)},true)
	check(candidate.restore(legacy_reward).is_empty(),"old first-main reward cursor remains valid")
	check(QuestStory.story(candidate).line==QuestStory.data.scenes.returning.lines.size()-1,"legacy pending payment cursor migrates")
	check(candidate.restore(JSON.parse_string(JSON.stringify(legacy_reward))).is_empty(),"legacy reward cursor remains valid after JSON number conversion")
	arrive(25)
	if not map.is_exit_open(): map._try_open_exit(map.travel.current_node_id)
	check(map.is_exit_open() and map.exit_dialog.confirm_button.disabled,"actual town exit confirmation disabled")
	check(map.exit_dialog.error_label.text=="先去医馆找苏清禾。","completed main points player to clinic")
	await shot("locked-exit")
	map._cancel_exit()
	arrive(32)
	check(HerbQuest.story(state).active=="intro" and map.dialogue.visible,"clinic arrival starts authored introduction")
	check(entry().is_empty() and RiverQuest.story(state).accepted_location.is_empty(),"neither quest starts during the opening dialogue")
	map._advance_dialogue()
	before = state.snapshot()
	check(not HerbQuest.command(state,directory+"missing/fail.json","advance").is_empty() and state.snapshot()==before,"failed dialogue save preserves cursor and gate")
	await switch_to("qingshizhen",32)
	check(HerbQuest.story(state).line==1,"intro resumes at saved line")
	while HerbQuest.story(state).line<HerbQuest.data.scenes.intro.lines.size()-1:
		map._advance_dialogue()
	check(not HerbQuest.accepted(state) and HerbQuest.exit_blocked(state,RiverQuest.TOWN,HerbQuest.data.river_exit),"last displayed line still precedes acceptance")
	await shot("clinic-intro")
	map._advance_dialogue()
	check(HerbQuest.accepted(state) and not HerbQuest.exit_blocked(state,RiverQuest.TOWN,HerbQuest.data.river_exit),"final advance accepts side quest and opens river together")
	check(RiverQuest.story(state).accepted_location.is_empty(),"clinic does not accept main two")
	check(state.quest_tracking.ids==[HerbQuest.ID],"side quest tracked between main quests")
	check(entry().category=="side" and entry().objectives[0].current==0 and entry().has_locked_next,"side task shows inventory requirement and future delivery")
	check(Files.read(Slots.quick_path()).quests[HerbQuest.ID].accepted_location==HerbQuest.data.accepted_location,"quick save includes acceptance")
	map.set_task_open(true)
	map.task_screen.task_list.set_category("side")
	map.task_screen.task_list.select_task(HerbQuest.ID)
	await settle()
	var header = map.task_screen.detail_header
	check(header.title_label.text=="医馆备药" and header.category_tag.caption.text=="支线任务","new task name and side classification")
	check(header.artwork.texture.resource_path.ends_with("UI-task-right-main-yiguanbeiyao.webp"),"specified detail illustration bound")
	for image_path in [entry().image,entry().detail_image]:
		var texture: Texture2D = load(image_path)
		check(texture!=null and texture.get_image().has_mipmaps(),"specified image imported with mipmaps: "+image_path)
	for resolution in [Vector2i(1920,1080),Vector2i(2560,1440)]:
		root.size = resolution
		await settle()
		check(header.introduction.get_line_count()==header.introduction.get_visible_line_count(),"full introduction fits at "+str(resolution))
		await shot("side-detail-%d"%resolution.x)
	root.size = Vector2i(1920,1080)
	map.set_task_open(false)
	await open_clinic()
	await shot("clinic-errand-action")
	await click(map.clinic_dialog.herb_quest_button)
	finish_herb_scene("missing")
	check(not map.event_state.is_active() and not HerbQuest.story(state).completed,"missing herb reminder returns control")
	arrive(25)
	if not map.is_exit_open(): map._try_open_exit(map.travel.current_node_id)
	check(map.is_exit_open() and not map.exit_dialog.confirm_button.disabled,"river exit opens after side acceptance")
	map._cancel_exit()
	await switch_to("qingshihewan",37)
	arrive(40)
	check(RiverQuest.story(state).active=="traces" and not RiverQuest.story(state).accepted_location.is_empty(),"main two still starts at existing blood node")
	check(state.quest_tracking.ids==[RiverQuest.ID] and not HerbQuest.story(state).completed,"new main becomes default tracking; side remains pending")
	finish_scene("traces")
	# Rescue progress from before the side quest retains access and priority.
	legacy = state.snapshot()
	legacy.quests.erase(HerbQuest.ID)
	check(candidate.restore(legacy).is_empty() and not HerbQuest.exit_blocked(candidate,RiverQuest.TOWN,HerbQuest.data.river_exit),"existing rescue save keeps open route")
	var emergency := state.snapshot()
	emergency.quests[RiverQuest.ID].done = ["traces","injured","entrance","root","mirror","beasts_gone","medicine","return_jade"]
	emergency.map_location = HerbQuest.data.clinic.duplicate(true)
	check(candidate.restore(emergency).is_empty(),"rescue medical priority fixture")
	check(RiverQuest.arrival(candidate,RiverQuest.TOWN,HerbQuest.data.clinic.point_id)=="invite_doctor","main medical request retains priority")
	check(not HerbQuest.command(candidate,directory+"priority.json","begin","delivery").is_empty(),"errand cannot consume herbs during main medical request")
	emergency.quests[RiverQuest.ID].done.append("invite_doctor")
	check(candidate.restore(emergency).is_empty() and not HerbQuest.clinic_available(candidate),"doctor absence pauses errand delivery")
	check(state.add_reward({"id":"base.map_reward.test.clinic_herbs.stock","item_id":HerbQuest.data.item_id,"quantity":2}).is_empty(),"two herbs in carried inventory")
	check(entry().stage_id=="returning" and entry().objectives.size()==2,"stock unlocks delivery objective")
	var stocked := state.snapshot()
	var spent := stocked.duplicate(true)
	for unit: String in spent.owned_units.keys():
		if spent.owned_units[unit]==HerbQuest.data.item_id: spent.owned_units.erase(unit)
	check(state.restore(spent).is_empty(),"simulate herbs used for other purposes")
	check(entry().objectives[0].current==0 and entry().objectives.size()==2 and not entry().has_locked_next,"spent herbs require replenishment while known delivery stays visible")
	check(state.restore(stocked).is_empty(),"restore available stock")
	check(MapLoadoutStore.save(state,path).is_empty(),"save carried herbs")
	await switch_to("qingshizhen",32)
	check(not map.event_state.is_active(),"accepted intro does not replay or automatically deliver stock")
	await open_clinic()
	var normal_wallet := state.snapshot()
	var full_wallet := normal_wallet.duplicate(true)
	full_wallet.spirit_stones = 1000000000
	check(state.restore(full_wallet).is_empty(),"full wallet fixture")
	await click(map.clinic_dialog.herb_quest_button)
	check(map.event_state.phase=="clinic" and HerbQuest.story(state).active.is_empty() and HerbQuest.quantity(state)==2,"full wallet remains in dismissible clinic without consuming herbs")
	check(not HerbQuest.command(state,path,"begin","delivery").is_empty(),"transaction also rejects full wallet before opening delivery")
	check(state.restore(normal_wallet).is_empty(),"restore wallet after capacity check")
	await click(map.clinic_dialog.herb_quest_button)
	finish_herb_scene("delivery")
	check(map.reward_dialog.visible and HerbQuest.quantity(state)==2,"payment preview has not consumed herb")
	var stones := state.spirit_stones
	before = state.snapshot()
	check(not HerbQuest.command(state,directory+"missing/fail.json","accept").is_empty() and state.snapshot()==before,"failed settlement leaves herbs, stones and completion unchanged")
	await switch_to("qingshizhen",32)
	check(map.reward_dialog.visible and HerbQuest.story(state).reward_pending,"payment resumes after reload")
	await shot("side-payment")
	await click(map.reward_dialog.accept_button)
	check(state.spirit_stones==stones+3 and HerbQuest.quantity(state)==1 and HerbQuest.story(state).completed,"real receipt consumes exactly one herb, pays three stones and completes side")
	check(entry().objectives.all(func(row): return row.completed) and entry().stage_id=="completed","completed objectives survive consumed inventory")
	before = state.snapshot()
	check(HerbQuest.command(state,path,"accept").is_empty() and state.snapshot()==before,"repeated receipt cannot pay twice")
	check(not HerbQuest.exit_blocked(state,RiverQuest.TOWN,HerbQuest.data.river_exit),"side completion keeps river open")
	check(state.quest_tracking.ids==[RiverQuest.ID],"pending main remains tracked after side completes")
	check(Files.read(Slots.quick_path()).quests[HerbQuest.ID].completed,"visible checkpoint includes atomic side completion")
	map.set_task_open(true)
	map.task_screen.task_list.set_category("side")
	map.task_screen.task_list.select_task(HerbQuest.ID)
	await shot("side-completed")
	map.set_task_open(false)
	await switch_to("qingshizhen",32)
	check(HerbQuest.story(state).completed and HerbQuest.quantity(state)==1,"completed errand persists on reload")
	map._try_start_event(map.travel.current_node_id,"click",true)
	check(map.event_state.phase=="clinic" and not map.clinic_dialog.herb_quest_button.visible,"ordinary clinic remains; completed delivery action removed")
	Meta.stop()
	map.deactivate_location()
	map.free()
	print("Clinic herb quest checks: %d, failures: %d; artifacts: %s"%[checks,failures,directory])
	quit(1 if failures else 0)
