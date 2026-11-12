extends "res://tests/breakthrough_layout_sync_tests.gd"

func run() -> void:
	create_timer(58).timeout.connect(func(): quit(2))
	directory = "res://artifacts/breakthrough-circle-20261104/"
	DirAccess.make_dir_recursive_absolute(directory)
	Slots.auto_path = directory+"auto.json"
	Session.index_path = directory+"last.json"
	Session.clear_selection()
	root.get_node("SavePlaytime").set_process(false)
	root.get_node("GameSettings").apply_values({"background_pause":false,"background_mute":false})
	root.get_node("GameSettings").set_application_focus(true)
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(2560,1440)
	var map = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path = Slots.working_path()
	map.defer_map_music = true
	map.defer_optional_views = true
	root.add_child(map)
	current_scene = map
	await settle()
	map.set_process(false)
	check(map.startup_error.is_empty(),"isolated map starts")
	map.set_breakthrough_open(true)
	await settle()
	var screen: Control = map.breakthrough_screen
	var session: RefCounted = map.breakthrough_session
	check(screen.primary_start_art.visible and not screen.primary_running_art.visible and not screen.rotation_reference.visible,"ready state shows start only")
	check(preload("res://scripts/map/map_texture_metrics.gd").has_mipmaps(screen.circle_art.texture),"circle uses mipmaps")
	check(screen.rotation_reference.get_rect()==Rect2(1115.5,1292,64,64) and screen.rotation_reference.pivot_offset==Vector2(32,32),"circle keeps recorded slot and center pivot")
	for resolution in [Vector2i(2560,1440),Vector2i(1920,1080)]:
		root.size = resolution
		await settle()
		var scale_: float = float(resolution.x)/2560.0
		check(screen.primary_start_art.get_global_rect().get_center().distance_to(Vector2(1283,1331)*scale_)<0.1,"both main images shift left three design pixels")
		check(screen.primary_start_art.get_rect()==screen.primary_running_art.get_rect(),"both main images retain identical rects")
		if DisplayServer.get_name()!="headless": await capture("ready-%d" % resolution.x)
	root.size = Vector2i(2560,1440)
	# Use real owned items and each actual board, rather than a copied preview.
	for index in range(2,6):
		check(map.loadout.select_board("base.map_item.qinglan_board_%d" % index).is_empty(),"select calibrated actual board")
		if index==2: check(not equip_one(map).is_empty(),"equip a real owned item for calibration preview")
		await settle()
		board_matches(map,"calibrated board %d" % index)
		var profile: Dictionary = screen.board_layout_for(map.loadout.board.id)
		check(not profile.is_empty() and not screen.board_reference.get_meta("provisional_layout"),"requested reference has its own active profile")
		check(profile.texture==map.loadout.board.texture_path and profile.reference_artwork.ends_with(["lianqi.webp","zhuji.webp","jiedan.webp","yuanying.webp"][index-2]),"reference maps to correct board texture")
		if DisplayServer.get_name()!="headless": await capture("board-%d-2560" % index)
	check(map.loadout.select_board("base.map_item.qinglan_board_1").is_empty(),"restore Xiaolan display for circle checks")
	await settle()
	var before: Dictionary = map.loadout.snapshot()
	var reset_events := [0]
	session.reset_requested.connect(func(): reset_events[0]+=1)
	session.start()
	map._process(0.5)
	check(screen.primary_running_art.visible and not screen.primary_start_art.visible and screen.rotation_reference.visible,"starting shows running image and circle")
	check(absf(screen.rotation_reference.rotation_degrees-60.0)<0.001,"half second rotates sixty degrees")
	session.set_paused(true)
	map._process(2.0)
	check(session.elapsed_usec==500000 and absf(screen.rotation_reference.rotation_degrees-60.0)<0.001,"pause freezes angle and progress clock")
	if DisplayServer.get_name()!="headless": await capture("paused-circle-2560")
	session.set_paused(false)
	map._process(0.5)
	check(absf(screen.rotation_reference.rotation_degrees-120.0)<0.001,"continue resumes from retained angle at 120 degrees per second")
	map._process(2.0)
	check(session.elapsed_usec==3000000 and absf(screen.rotation_reference.rotation_degrees)<0.001,"three active seconds complete one turn")
	map._process(0.25)
	map.set_breakthrough_open(false)
	map.set_breakthrough_open(true)
	check(session.started and session.phase=="paused" and absf(screen.rotation_reference.rotation_degrees-30.0)<0.001,"temporary close retains paused session and angle")
	# Only the red exit's changed behavior is exercised with mouse input.
	await click(screen.exit_button)
	await click(map.breakthrough_exit_dialog.confirm_button)
	check(not map.is_breakthrough_open() and session.phase=="ready" and not session.started and session.elapsed_usec==0,"red exit closes and clears the session")
	check(reset_events[0]==1,"red exit sends one reset command for future authoritative progress")
	map.set_breakthrough_open(true)
	await settle()
	check(screen.primary_start_art.visible and not screen.primary_running_art.visible and not screen.rotation_reference.visible and screen.rotation_reference.rotation==0.0,"reopening after exit restores start and resets circle pose")
	session.start()
	map._process(0.5)
	check(absf(screen.rotation_reference.rotation_degrees-60.0)<0.001,"new breakthrough starts rotation from initial pose")
	root.size = Vector2i(1920,1080)
	await settle()
	await click(screen.exit_button)
	await click(map.breakthrough_exit_dialog.confirm_button)
	check(not session.started and session.elapsed_usec==0 and reset_events[0]==2,"1080p red exit also resets")
	check(map.loadout.snapshot()==before,"session operations do not alter authoritative gameplay")
	Meta.stop()
	map.deactivate_location()
	map.queue_free()
	await settle()
	print("BREAKTHROUGH_CIRCLE: %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)
