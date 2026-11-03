extends "res://tests/save_actions_tests.gd"

func run() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	directory = "res://artifacts/quest-story-startup/run-%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	var source := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--opening-source="): source = argument.trim_prefix("--opening-source=")
	if source.is_empty():
		var registry := ContentRegistry.new()
		check(registry.load_base_content(),"load default isolated fixture content")
		var made := MapLoadoutStore.create_state(registry,registry.get_board("base.board.bag"))
		check(made.error.is_empty() and QuestStory.prepare_start(made.state).is_empty(),"prepare default isolated opening")
		source = directory+"source.json"
		check(Files.write(source,made.state.snapshot())==OK,"save default isolated source")
	var source_hash := FileAccess.get_sha256(source)
	Slots.auto_path = directory+"auto.json"
	Session.index_path = directory+"last.json"
	Session.clear_selection()
	check(Files.write(Slots.quick_path(),Files.read(source))==OK,"copy prepared current character into isolated checkpoint")
	root.get_node("SavePlaytime").set_process(false)
	root.get_node("GameSettings").apply_values({"background_pause":false,"background_mute":false,"dialogue_speed":"instant","dialogue_auto":false})
	root.get_node("GameSettings").set_application_focus(true)
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(2560,1440)
	check(Session.begin_resume(Slots.quick_path()),"resume isolated checkpoint through real loading router")
	var router = load("res://scripts/map/map_session_start.gd").new()
	root.add_child(router)
	while current_scene==null: await process_frame
	var map = current_scene
	check(map.startup_error.is_empty(),"staged map initialization succeeds: "+map.startup_error)
	check(map.travel.current_node_id==QuestStory.data.home.point_id,"continue routes saved character to home")
	check(QuestStory.story(map.loadout).wake_pending and not map.dialogue.visible,"loading cover consumes none of the opening")
	check(not map.loadout.quest_tracking.shown and not map.quest_tracker_controller.tracker.visible and map.loadout.quest_tracking.ids==[QuestStory.ID],"main quest selected by default while tracker stays closed before monologue")
	await process_frame
	await process_frame
	check(map.quest_story_controller.waiting_idle,"idle starts after loading cover is gone")
	await map.player.animation_looped
	await settle()
	check(QuestStory.story(map.loadout).active=="wake" and map.dialogue.visible,"actual saved character reaches opening dialogue")
	check(map.player_status.display_name==DialogueJournal.full_name(Files.read(source).narrative),"saved player identity is displayed")
	await capture("current-character-wake-2560x1440")
	map._advance_dialogue()
	check(not map.loadout.quest_tracking.shown and map.loadout.quest_tracking.ids==[QuestStory.ID],"first wake line does not open tracker")
	var before_final: Dictionary = map.loadout.snapshot().duplicate(true)
	var failed := QuestStory.command(map.loadout,directory+"missing-parent/save.json","advance")
	check(not failed.is_empty() and map.loadout.snapshot()==before_final,"failed final-line save publishes neither completion nor tracking")
	map._advance_dialogue()
	check(QuestStory.story(map.loadout).active.is_empty() and "wake" in QuestStory.story(map.loadout).done,"last wake line completes opening")
	check(map.loadout.quest_tracking.ids==[QuestStory.ID] and map.loadout.quest_tracking.shown and map.quest_tracker_controller.tracker.visible,"completed monologue tracks first main quest and opens tracker")
	var persisted: Dictionary = Files.read(Slots.working_path())
	check(persisted.quest_tracking==map.loadout.quest_tracking and "wake" in persisted.quests[QuestStory.ID].story.done,"wake completion and tracking saved together")
	check(Files.read(Slots.quick_path()).quest_tracking==map.loadout.quest_tracking,"continue checkpoint retains automatic tracking")
	var reload := MapLoadoutStore.candidate(map.loadout)
	check(reload.error.is_empty() and reload.state.quest_tracking==map.loadout.quest_tracking,"tracking survives snapshot restore")
	var closed: Dictionary = map.loadout.quest_tracking.duplicate(true)
	closed.shown = false
	check(QuestTracking.commit(map.loadout,closed,Slots.working_path()).is_empty(),"player can close tracker after automatic opening")
	check(QuestStory.command(map.loadout,Slots.working_path(),"advance").is_empty() and not map.loadout.quest_tracking.shown and map.loadout.quest_tracking.ids==[QuestStory.ID],"repeated completion neither duplicates task nor reopens tracker")
	map.travel.current_node_id = QuestStory.data.shop.point_id
	map.travel.map_position = map.travel.node_positions[map.travel.current_node_id]
	map.travel.stop_at_current_node()
	map.player.position = map.travel.map_position
	map._on_node_arrived(map.travel.current_node_id)
	check(QuestStory.story(map.loadout).active=="morning","shop dialogue follows opening")
	await capture("current-character-morning-2560x1440")
	Meta.stop()
	map.deactivate_location()
	map.queue_free()
	await settle()
	check(FileAccess.get_sha256(source)==source_hash,"prepared source remains unchanged")
	print("QUEST_STORY_STARTUP: %d checks; %d failures" % [checks,failures])
	print("OUTPUT: "+directory)
	quit(1 if failures else 0)
