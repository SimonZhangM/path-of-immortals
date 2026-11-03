extends "res://tests/save_actions_tests.gd"
const Screen = preload("res://scripts/map/map_task_screen.gd")
const Memory = preload("res://scripts/map/map_task_view_memory.gd")

func run() -> void:
	create_timer(55).timeout.connect(func(): quit(2))
	directory = "res://artifacts/task-view-memory/run-%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	Slots.auto_path = directory+"auto.json"
	Session.index_path = directory+"session.json"
	Session.clear_selection()
	root.get_node("SavePlaytime").set_process(false)
	root.get_node("GameSettings").apply_values({"background_pause":false})
	root.get_node("GameSettings").set_application_focus(true)
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1920,1080)
	var map = load("res://scenes/maps/qingshizhen.tscn").instantiate()
	map.inventory_save_path = Slots.working_path()
	map.defer_map_music = true
	map.defer_optional_views = true
	root.add_child(map)
	current_scene = map
	await settle()
	map.set_process(false)
	check(map.startup_error.is_empty(),"isolated map starts")
	map.set_task_open(true)
	var screen = map.task_screen
	var before: Dictionary = map.loadout.snapshot()
	screen.sidebar.select_category("main")
	screen.task_list.select_task(QuestState.ID)
	check(Memory.read_selection(map.inventory_save_path)=={"id":QuestState.ID,"category":"main"},"task and its selected category remembered")
	map.set_task_open(false)
	map.set_task_open(true)
	await settle()
	check(screen.task_list.selected_task_id==QuestState.ID and screen.detail_body.visible and screen.task_list.cards[QuestState.ID].button_pressed,"close/reopen restores highlight and full details")
	screen.sidebar.select_category("side")
	check(not screen.detail_body.visible,"empty category shows no stale details")
	map.set_task_open(false)
	map.set_task_open(true)
	await settle()
	check(screen.sidebar.selected_category_id=="main" and screen.detail_body.visible,"reopen returns to last selected task after browsing an empty category")
	var rebuilt := Screen.new()
	root.add_child(rebuilt)
	rebuilt.bind_loadout(map.loadout)
	rebuilt.bind_memory(map.inventory_save_path)
	check(rebuilt.task_list.selected_task_id==QuestState.ID and rebuilt.detail_body.visible,"new map/screen restores persisted browsing preference")
	rebuilt.free()
	check(Memory.save_selection(directory+"missing-save",{"id":"quest.missing","category":"main"})==OK,"missing task preference fixture")
	rebuilt = Screen.new()
	root.add_child(rebuilt)
	rebuilt.bind_loadout(map.loadout)
	rebuilt.bind_memory(directory+"missing-save")
	check(rebuilt.task_list.selected_task_id.is_empty() and not rebuilt.detail_body.visible,"removed/unavailable task ignored safely")
	rebuilt.free()
	check(map.loadout.snapshot()==before,"browsing memory does not mutate quest/inventory gameplay state")
	map.set_task_open(false)
	var entry: Dictionary = QuestTracking.entries(map.loadout)[0]
	var tracker = map.quest_tracker_controller.tracker
	tracker.display([entry])
	for resolution in [Vector2i(1920,1080),Vector2i(2560,1440)]:
		root.size = resolution
		await settle()
		var card: Control = tracker.cards[0]
		var title: Control = card.find_child("TaskName",true,false)
		var tag: Control = card.find_child("CategoryTag",true,false)
		var icon: Control = card.find_child("ObjectiveLocation",true,false)
		check(title.get_global_rect().end.x<=tag.get_global_rect().position.x,"task name precedes category tag")
		check(absf(title.global_position.x-icon.global_position.x)<1,"location icon aligns below task name first character")
		check(tracker.close_button.text.is_empty() and tracker.close_button.get_node("CenteredChevron").get_script()!=null,"collapse arrow is drawn, not a font symbol")
		if DisplayServer.get_name()!="headless": await capture("tracker-layout-"+str(resolution.x))
	Meta.stop()
	map.deactivate_location()
	map.free()
	print("TASK_VIEW_MEMORY: %d checks; %d failures" % [checks,failures])
	print("OUTPUT: "+directory)
	quit(1 if failures else 0)
