extends "res://tests/river_quest_tests.gd"

const LETTER := "base.map_item.yesongnian_letter"

func run() -> void:
	create_timer(55).timeout.connect(func(): quit(2))
	directory = "res://artifacts/letter-receipt-20261103/run-%d/"%Time.get_ticks_usec()
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
	await switch_to("qingshizhen",30)
	var original_player := MapPlayer.new()
	var player_config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/player.json"))
	check(original_player.configure(player_config).is_empty(),"baseline map player configured")
	check(map.player._action_scales==original_player._action_scales,"town retains its original actor scale")
	var fixture := state.snapshot()
	for target: Dictionary in QuestState.definition.objectives: fixture.quests[QuestState.ID].counts[target.id] = target.required
	fixture.quests[QuestState.ID].story = QuestStory.migrated({"counts":fixture.quests[QuestState.ID].counts})
	fixture.quests[RiverQuest.ID].done = ["traces","injured","entrance","root","mirror","beasts_gone","medicine","return_jade","invite_doctor","pickup","clinic_arrival","gift_book","closing"]
	fixture.quests[RiverQuest.ID].accepted_location = RiverQuest.RIVER
	check(state.restore(fixture).is_empty(),"ready for letter fixture")
	arrive(14)
	check(HomecomingQuest.story(state).active=="intro" and HomecomingQuest.story(state).line==0,"opening observation begins")
	check(map.quest_tracker_controller.markers.get_child_count()==0,"opening has no target location marker")
	check(state.carried_owned().values().count(LETTER)==0,"letter not granted on opening")
	map._advance_dialogue()
	check(HomecomingQuest.story(state).reward_pending and HomecomingQuest.story(state).line==0,"receipt opens immediately after observation")
	check(map.reward_dialog.visible and map.dialogue.visible and map.dialogue._phase=="dialogue_paused","receipt overlays paused dialogue")
	check(not map.reward_dialog.shade.visible,"receipt retains undimmed dialogue")
	check(map.reward_dialog.card.entry.id==LETTER and map.reward_dialog.card.entry.quantity==1,"one letter on receipt")
	check(map.reward_dialog.card.entry.icon=="res://assets/UI-other-letter from yesongnian.webp","requested letter art")
	check(map.reward_dialog.close_button.visible,"receipt has close action")
	check(state.records[LETTER].quest_item and "任务物品" in state.registry.get_item(LETTER).tags,"letter marked as quest item")
	check(not state.inventory.equipment_allowed(state.registry.get_item(LETTER)),"letter cannot be equipped")
	check(not MapShop.new()._sale_allowed(state,LETTER),"letter cannot be sold")
	check(ItemTooltip.effect_text(state.registry.get_item(LETTER)).contains("叶松年"),"letter tooltip has task description")
	await shot("letter-receipt")
	await switch_to("qingshizhen",14)
	check(HomecomingQuest.story(state).reward_pending and map.reward_dialog.visible,"pending receipt resumes on reload")
	var pending := state.snapshot()
	map.inventory_save_path = directory+"missing/fail.json"
	await click(map.reward_dialog.close_button)
	check(state.snapshot()==pending and map.reward_dialog.visible,"failed close-save retains reward and dialogue cursor")
	map.inventory_save_path = path
	for method in ["close","accept","escape","right"]:
		check(state.restore(pending).is_empty(),"reset receipt fixture "+method)
		map.homecoming_story_controller.present()
		if method=="close": await click(map.reward_dialog.close_button)
		elif method=="accept": await click(map.reward_dialog.accept_button)
		elif method=="escape":
			var key := InputEventKey.new()
			key.keycode = KEY_ESCAPE
			key.pressed = true
			map._input(key)
		else:
			var mouse := InputEventMouseButton.new()
			mouse.button_index = MOUSE_BUTTON_RIGHT
			mouse.pressed = true
			map._input(mouse)
		check(state.carried_owned().values().count(LETTER)==1,"one letter received via "+method)
		check(HomecomingQuest.story(state).line==1 and not HomecomingQuest.story(state).reward_pending,"next dialogue resumes via "+method)
		check(not map.reward_dialog.visible and map.dialogue._phase=="dialogue","receipt closes and dialogue continues")
		check(HomecomingQuest.command(state,path,"accept").is_empty() and state.carried_owned().values().count(LETTER)==1,"duplicate acceptance grants nothing twice")
	check(map.quest_tracker_controller.markers.get_child_count()==0,"location marker remains hidden during opening")
	while not HomecomingQuest.story(state).active.is_empty(): map._advance_dialogue()
	check(HomecomingQuest.story(state).letter_received,"opening ends normally")
	check(map.quest_tracker_controller.markers.get_child_count()==1 and map.quest_tracker_controller.markers.get_child(0).get_meta("point_id")==RiverQuest.TOWN+".point.n30","opening end activates village route marker")
	check(MapLoadoutStore.save(state,path).is_empty(),"save letter inventory")
	await switch_to("baishacun",6)
	check(state.carried_owned().values().count(LETTER)==1,"letter persists across maps")
	for action: String in original_player._action_scales:
		check(is_equal_approx(map.player._action_scales[action],original_player._action_scales[action]*2.0/3.0),"village actor reduced by one third "+action)
		check(map.player._action_offsets[action]==original_player._action_offsets[action],"same source foot anchor "+action)
		map.player.play(action)
		check(is_equal_approx(map.player.scale.x,map.player._action_scales[action]),"animation change retains village scale "+action)
	map.player.play("idle")
	check(map.travel.walk_speed==player_config.walk_speed and map.travel.run_speed==player_config.run_speed,"movement speed preserved")
	await shot("baisha-smaller-player")
	original_player.free()
	var result := {"checks":checks,"failures":failures,"render":render,"directory":directory}
	FileAccess.open(directory+"validation.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("HOMECOMING_LETTER "+JSON.stringify(result))
	map.deactivate_location()
	map.free()
	quit(1 if failures else 0)
