extends "res://tests/save_actions_tests.gd"

func validate_versions() -> void:
	for version in [1,2]:
		for phase in ["running","paused","failed","succeeded"]:
			var growth := CultivationGrowth.initial(1 if phase=="succeeded" else 0)
			growth.breakthrough_attempt={"id":"base.breakthrough.first_qi","version":version,"phase":phase,
				"elapsed_usec":(1800000000 if version==1 else 300000000) if phase=="failed" else 12000000,
				"progress":(10000 if version==1 else 20000) if phase=="succeeded" else 0,"recent_gains":[]}
			check(CultivationGrowth.valid(growth),"integer version %d %s"%[version,phase])
			var decoded: Dictionary=JSON.parse_string(JSON.stringify(growth))
			check(CultivationGrowth.valid(decoded),"JSON round-trip version %d %s"%[version,phase])
			CultivationGrowth.migrate_breakthrough_attempt(decoded)
			check(CultivationGrowth.valid(decoded),"migrated JSON remains valid %d %s"%[version,phase])
	var invalid := CultivationGrowth.initial(0)
	invalid.breakthrough_attempt={"id":"base.breakthrough.first_qi","version":1,"phase":"paused","elapsed_usec":0,"progress":0}
	for version: Variant in [null,"1",true,0,1.5,2.5,3]:
		invalid.breakthrough_attempt.version=version
		check(not CultivationGrowth.valid(invalid),"reject invalid version "+str(version))

func shortcut(action: String) -> void:
	var event: InputEventKey=InputMap.action_get_events(action)[0].duplicate()
	event.pressed=true
	root.push_input(event,true)
	await settle()
	event.pressed=false
	root.push_input(event,true)

func run() -> void:
	create_timer(55).timeout.connect(func(): quit(2))
	validate_versions()
	var fixture_dir := OS.get_environment("BAISHA_RELOAD_FIXTURE_DIR")
	if fixture_dir.is_empty():
		print("Breakthrough JSON versions: ",checks," checks, ",failures," failures")
		quit(1 if failures else 0)
		return
	directory="res://artifacts/baisha-startup-fix-20261106/run-%d/"%Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	Slots.auto_path=directory+"auto.json"
	Session.index_path=directory+"session.json"
	Session.clear_selection()
	root.get_node("SavePlaytime").set_process(false)
	var settings := root.get_node("GameSettings")
	settings.apply_values({"background_pause":false,"background_mute":false,"dialogue_speed":"instant","volume_master":1.0,"volume_music":1.0})
	settings.set_application_focus(true)
	# Keep playback inaudible without activating the mute/pause mechanism.
	settings._base_gain.volume_master=0.000001
	settings.apply_values({"volume_master":1.0})
	root.content_scale_size=Vector2i.ZERO
	root.size=Vector2i(1920,1080)
	var registry := ContentRegistry.new()
	check(registry.load_base_content(),"content registry loads")
	var made := MapLoadoutStore.create_state(registry,registry.get_board("base.board.bag"))
	check(made.error.is_empty(),"catalog loads")
	for filename in ["quick_save.json","live_session.json"]:
		var raw := Files.read(fixture_dir.path_join(filename))
		check(not raw.is_empty() and made.state.restore(raw).is_empty(),"actual copied save restores: "+filename)
		check(made.state.growth.breakthrough_attempt.progress==raw.growth.breakthrough_attempt.progress,"earned progress retained: "+filename)
		check(made.state.snapshot().owned_units==raw.owned_units,"owned items retained: "+filename)
		var same_resources := true
		for resource: String in raw.growth.resources:
			same_resources=same_resources and made.state.growth.resources[resource]==raw.growth.resources[resource]
		check(same_resources,"resources retained: "+filename)
	var original := Files.read(fixture_dir.path_join("live_session.json"))
	var path := directory+"working.json"
	check(Files.write(path,original)==OK,"isolated working save copied")
	var map = load("res://scenes/maps/baishacun.tscn").instantiate()
	map.inventory_save_path=path
	map.defer_optional_views=true
	root.add_child(map)
	current_scene=map
	await settle()
	check(map.startup_error.is_empty() and map.loadout!=null,"village startup fully initializes")
	if not map.startup_error.is_empty(): quit(1); return
	map.set_process(false)
	var presentation := root.get_node("MapPresentation")
	await create_timer(0.15).timeout
	var position: float=presentation.music.get_playback_position()
	await create_timer(0.2).timeout
	check(presentation.map_id=="base.map.baishacun" and presentation.playlist==["res://assets/bgm-baishacun.mp3"],"village track bound")
	check(presentation.music.playing and not presentation.music.stream_paused and presentation.music.get_playback_position()>position,"village audio playback advances")
	for pair in [["map_inventory","is_inventory_open"],["map_breakthrough","is_breakthrough_open"],["map_tasks","is_task_open"],["map_world_map","is_world_map_open"]]:
		await shortcut(pair[0])
		check(map.call(pair[1]),"shortcut opens "+pair[0])
		if pair[0]=="map_inventory": map.set_inventory_open(false)
		elif pair[0]=="map_breakthrough": map.set_breakthrough_open(false)
		elif pair[0]=="map_tasks": map.set_task_open(false)
		else: map.set_world_map_open(false)
		await settle()
	var home := "base.map.baishacun.point.n05"
	map.travel.current_node_id=home
	map.travel.stop_at_current_node()
	map.loadout.set_map_location("base.map.baishacun",home)
	check(map._start_registered_event(home,"click",true),"mother conversation opens")
	await settle()
	check(map.clinic_dialog.dialogue_rows.get_child_count()>0 and map.clinic_dialog._view.topics.size()==3,"mother text and three topics present")
	map._clinic_dialogue_command("select","chat")
	await settle()
	check(map.clinic_dialog._view.selected=="chat" and map.clinic_dialog.dialogue_rows.get_child_count()>0,"mother chat content opens")
	if DisplayServer.get_name()!="headless": await capture("mother-chat-restored")
	map._close_clinic()
	var exit_point := "base.map.baishacun.point.n01"
	map.travel.current_node_id=exit_point
	map.travel.stop_at_current_node()
	map.loadout.set_map_location("base.map.baishacun",exit_point)
	check(map._try_open_exit(exit_point),"village exit opens")
	map._confirm_exit()
	await create_timer(2.8).timeout
	var town = current_scene
	check(is_instance_valid(town) and town!=map and town.definition.id=="base.map.qingshizhen" and town.startup_error.is_empty(),"actual village-to-town transition succeeds")
	check(presentation.map_id=="base.map.qingshizhen" and presentation.music.playing,"destination music resumes")
	if is_instance_valid(town) and town.has_method("deactivate_location"): town.deactivate_location()
	Meta.stop()
	# Invalid direct-F5 input reports the error instead of retaining a partial map.
	var invalid := original.duplicate(true)
	invalid.growth.breakthrough_attempt.version=1.5
	var invalid_path := directory+"invalid.json"
	check(Files.write(invalid_path,invalid)==OK,"invalid fixture written")
	var invalid_hash := FileAccess.get_sha256(invalid_path)
	Session.clear_selection()
	# Load after autoload registration; the router refers to MapPresentation.
	var router = load("res://tests/fixtures/rejected_map_session.gd").new()
	router.inventory_save_path=invalid_path
	router.defer_map_music=true
	var before_children := root.get_child_count()
	Engine.print_error_messages=false # Expected bad-save diagnostic only.
	root.add_child(router)
	await settle()
	Engine.print_error_messages=true
	check(router.rejection.contains("修炼成长存档无效"),"direct startup reports invalid save")
	check(root.get_child_count()==before_children+1,"failed destination is released")
	check(FileAccess.get_sha256(invalid_path)==invalid_hash,"rejected save bytes preserved")
	router.queue_free()
	if is_instance_valid(town): town.queue_free()
	presentation.music.stop()
	presentation.music.stream=null
	await settle()
	await create_timer(0.2).timeout
	print("Breakthrough reload + village: ",checks," checks, ",failures," failures; ",directory)
	quit(1 if failures else 0)
