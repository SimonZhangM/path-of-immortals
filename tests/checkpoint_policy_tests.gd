extends "res://tests/save_actions_tests.gd"
const Checkpoints = preload("res://scripts/entry/save_checkpoints.gd")
const Schedule = preload("res://scripts/entry/save_checkpoint_schedule.gd")

func place(map, point: String) -> void:
	map.travel.current_node_id = point
	map.travel.map_position = map.travel.node_positions[point]
	map.travel.stop_at_current_node()
	map.player.position = map.travel.map_position
	map.loadout.set_map_location(map.definition.id,point)

func run() -> void:
	create_timer(100).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1920,1080)
	directory = "res://artifacts/checkpoint-policy/run-%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	var real_paths := [Slots.AUTO_PATH,Slots.quick_path(),Slots.working_path(),"user://manual_save_02.json","user://save_slots.json",Session.INDEX_PATH]
	var before := []
	for path in real_paths: before.append(FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing")
	var raw := Files.read(Slots.AUTO_PATH)
	raw.map_location = {"map_id":"base.map.qingshizhen","point_id":"base.map.qingshizhen.point.n25"}
	raw.save_info.saved_at_unix = 1000
	raw.save_info.saved_at_unix_ms = 1000000
	Slots.auto_path = directory+"auto.json"
	Session.index_path = directory+"last.json"
	Session.clear_selection()
	Files.write(Slots.auto_path,raw)
	var manual := directory+"manual_save_02.json"
	var copy := raw.duplicate(true)
	copy.save_info.save_kind = "manual"
	Files.write(manual,copy)
	var manual_hash := FileAccess.get_sha256(manual)
	var catalog := Catalog.new()
	catalog.legacy_path = Slots.auto_path
	catalog.index_path = directory+"slots.json"
	catalog.manual_directory = directory
	Files.write(catalog.index_path,{"version":1,"paths":[Slots.auto_path,manual]})
	check(catalog.entries()[0].slot==2 and catalog.entries()[1].slot==3,"legacy auto becomes 02 and existing manual becomes 03 without rewriting")
	check(catalog.next_manual_slot().slot==4,"new manual starts after reserved system slots")
	var schedule := Schedule.new()
	check(not schedule.advance(599,false,true),"no auto before 600 seconds")
	check(not schedule.advance(30,true,true) and schedule.elapsed==599,"pause does not count time")
	check(not schedule.advance(1,false,false) and schedule.pending,"due during unsafe state waits")
	check(not schedule.advance(1200,false,false),"long unsafe period queues only one save")
	check(schedule.advance(0,false,true),"safe state releases pending save")
	schedule.complete(false)
	check(not schedule.advance(1,false,true) and schedule.advance(4,false,true),"failed write retries with backoff")
	schedule.complete(true)
	check(not schedule.advance(0,false,true) and schedule.elapsed==0,"successful save resets interval")
	var clock = root.get_node("SavePlaytime")
	clock.set_process(false)
	var auto_hash := FileAccess.get_sha256(Slots.auto_path)
	var map = load("res://scenes/maps/qingshizhen.tscn").instantiate()
	map.inventory_save_path = Slots.auto_path
	map.defer_map_music = true
	map.defer_optional_views = true
	root.add_child(map)
	current_scene = map
	await settle()
	check(map.startup_error.is_empty() and map.inventory_save_path==Slots.working_path(),"loaded snapshot adopted into private session")
	check(FileAccess.get_sha256(Slots.auto_path)==auto_hash and not Session.has_save(Slots.quick_path()),"loading creates no checkpoint and preserves loaded snapshot")
	check(map.can_save_timed_checkpoint(),"free map allows timed checkpoint")
	map.loadout.spirit_stones = 100000
	check(MapLoadoutStore.save(map.loadout,map.inventory_save_path).is_empty(),"transaction session writable")
	check(not MapLoadoutStore.save(map.loadout,Slots.auto_path).is_empty(),"ordinary writes cannot change auto snapshot")
	check(FileAccess.get_sha256(Slots.auto_path)==auto_hash,"movement/transaction working file does not alter auto")
	clock._process(599)
	for phase in ["dialogue","shop","clinic","cultivation","reward"]:
		map.event_state.active_id = "test.blocker"
		map.event_state.phase = phase
		clock._process(2)
		check(not map.can_save_timed_checkpoint() and FileAccess.get_sha256(Slots.auto_path)==auto_hash,"auto delayed during "+phase)
	map.event_state.active_id = ""
	map.event_state.phase = ""
	map._open_system_menu()
	clock._process(2)
	check(FileAccess.get_sha256(Slots.auto_path)==auto_hash,"pending auto waits while system menu open")
	map.system_menu_controller.close()
	clock._process(0)
	check(Files.read(Slots.auto_path).spirit_stones==100000 and not clock.schedule.pending,"pending auto saves final free-state snapshot once")
	auto_hash = FileAccess.get_sha256(Slots.auto_path)
	clock._process(0)
	check(FileAccess.get_sha256(Slots.auto_path)==auto_hash,"pending save not repeated")
	# Real purchase/sale completions update quick only, including exact currency.
	var shop: MapShop = map.shops.values()[0]
	var item_id: String = shop.products()[0].item_id
	check(shop.purchase(map.loadout,item_id,1,map.inventory_save_path).is_empty(),"real purchase succeeds")
	check(Files.read(Slots.quick_path()).spirit_stones==map.loadout.spirit_stones and Files.read(Slots.quick_path()).save_info.checkpoint_reason=="trade_buy","purchase commits quick after transaction")
	check(FileAccess.get_sha256(Slots.auto_path)==auto_hash,"trade does not overwrite timed auto")
	var quick_hash := FileAccess.get_sha256(Slots.quick_path())
	check(not shop.purchase(map.loadout,item_id,0,map.inventory_save_path).is_empty() and FileAccess.get_sha256(Slots.quick_path())==quick_hash,"failed transaction does not overwrite quick")
	check(shop.sell(map.loadout,item_id,1,map.inventory_save_path).is_empty(),"real sale succeeds")
	check(Files.read(Slots.quick_path()).save_info.checkpoint_reason=="trade_sell","sale saves quick")
	# Finish a real training session through its command boundary, not per tick.
	var practice := MapCultivationSession.new()
	practice.loadout = map.loadout
	practice.save_path = map.inventory_save_path
	practice.active = true
	practice.started = true
	practice.finish(WorldCalendar.current_day(map.loadout.calendar))
	check(Files.read(Slots.quick_path()).save_info.checkpoint_reason=="cultivation_complete","ending cultivation saves quick")
	quick_hash = FileAccess.get_sha256(Slots.quick_path())
	practice.finish(WorldCalendar.current_day(map.loadout.calendar))
	check(FileAccess.get_sha256(Slots.quick_path())==quick_hash,"training completion recorded once")
	var records := catalog.entries()
	check(records.size()==3 and records[0].slot==1 and records[0].save_kind=="quick" and records[1].slot==2 and records[1].save_kind=="auto" and records[2].path==manual,"fixed quick/auto/manual ordering")
	check(not catalog.paths().has(Slots.working_path()),"private session hidden from list")
	var controller = load("res://scripts/map/map_save_browser_controller.gd").new()
	controller.map = map
	controller.catalog_override = catalog
	map.add_child(controller)
	map.save_browser_controller = controller
	map._open_save_browser()
	await settle()
	var browser = controller.browser
	for index in [0,1]:
		await click(browser.row_buttons[index])
		check(browser.back_button.disabled and not browser.load_button.disabled,"system slot selectable and load-only "+str(index))
		check(not Ops.store_manual(catalog,map.loadout,map.inventory_save_path,browser.entries[index].path).is_empty(),"backend rejects system overwrite "+str(index))
	await click(browser.row_buttons[0])
	check(browser.row_buttons[0].get_node("SaveKindBadge").texture.atlas.resource_path.ends_with("UI-start-saveload-quick.webp"),"quick badge uses supplied texture")
	await capture("quick-auto-1920")
	root.size = Vector2i(2560,1440)
	await capture("quick-auto-2560")
	root.size = Vector2i(1920,1080)
	await click(browser.row_buttons[-1])
	check(not browser.back_button.disabled and browser.load_button.disabled,"empty manual slot remains store-only")
	await click(browser.back_button)
	check(catalog.entries().size()==4 and catalog.entries()[-1].slot==4,"new manual does not overwrite existing slots")
	controller.close()
	check(FileAccess.get_sha256(manual)==manual_hash,"legacy manual content unchanged")
	# Actual map transition produces a quick checkpoint at the destination node.
	place(map,"base.map.qingshizhen.point.n25")
	check(map._try_open_exit(map.travel.current_node_id),"map exit opens")
	var elapsed_before: float = clock.schedule.elapsed
	await map._complete_exit()
	await settle()
	map = current_scene
	check(map.definition.id=="base.map.qingshihewan","actual map transition completes")
	check(Files.read(Slots.quick_path()).map_location==map.loadout.map_location and Files.read(Slots.quick_path()).save_info.checkpoint_reason=="map_arrival","quick records destination after valid transition")
	check(clock.schedule.elapsed==elapsed_before,"map switch does not reset auto interval")
	check(FileAccess.get_sha256(Slots.auto_path)==auto_hash,"map switch preserves timed auto")
	check(Session.resume_path(Slots.auto_path)==Slots.quick_path(),"continue chooses newer quick")
	# An encounter checkpoint stays intact through battle consumption and return.
	place(map,"base.map.qingshihewan.point.n30")
	map.event_state.completed.erase("base.map_event.qingshihewan.cliff_encounter")
	map.loadout.encounter_cooldowns.erase("base.map_event.qingshihewan.cliff_encounter")
	check(map._try_start_event(map.travel.current_node_id,"click",true),"encounter opens")
	await map._start_encounter_battle()
	await settle()
	var battle = current_scene
	check(battle.has_node("GameManager"),"actual battle preparation entered")
	check(Files.read(Slots.quick_path()).save_info.checkpoint_reason=="before_battle","battle entry saves quick")
	quick_hash = FileAccess.get_sha256(Slots.quick_path())
	clock.schedule.elapsed = 599.0
	clock._process(2)
	check(clock.schedule.pending and FileAccess.get_sha256(Slots.auto_path)==auto_hash,"timer counts battle but defers auto")
	var manager = battle.get_node("GameManager")
	manager.set_process(false)
	manager.start_battle()
	manager.enemies[0].hp = 1
	for i in 180:
		if manager.simulation.state.is_finished(): break
		manager._process(1.0)
	check(manager.simulation.state.is_finished(),"battle reaches complete settlement")
	await battle.get_node("MapBattleReturn").return_to_map()
	await settle()
	map = current_scene
	check(map.has_method("can_save_timed_checkpoint"),"battle returns to map")
	check(FileAccess.get_sha256(Slots.quick_path())==quick_hash,"battle return does not overwrite prebattle quick")
	clock._process(0)
	check(not clock.schedule.pending and FileAccess.get_sha256(Slots.auto_path)!=auto_hash,"deferred timer saves settled state after battle return")
	# Load the older quick snapshot through the real UI router, preserving both.
	auto_hash = FileAccess.get_sha256(Slots.auto_path)
	map._open_save_browser()
	controller = map.save_browser_controller
	controller.browser.catalog = catalog
	controller.browser.refresh()
	await settle()
	await click(controller.browser.row_buttons[0])
	await click(controller.browser.load_button)
	while is_instance_valid(map) or root.has_node("GameLoadingOverlay"): await process_frame
	await settle()
	map = current_scene
	check(map.inventory_save_path==Slots.working_path() and map.loadout.map_location==Files.read(Slots.quick_path()).map_location,"quick read restores its location into session")
	check(FileAccess.get_sha256(Slots.quick_path())==quick_hash and FileAccess.get_sha256(Slots.auto_path)==auto_hash,"read neither quick nor auto rewrites snapshots")
	Meta.stop()
	map.deactivate_location()
	map.queue_free()
	current_scene = null
	Session.clear_selection()
	await settle()
	for index in real_paths.size():
		check((FileAccess.get_sha256(real_paths[index]) if FileAccess.file_exists(real_paths[index]) else "missing")==before[index],"real file unchanged "+real_paths[index])
	print("CHECKPOINT_POLICY: %d checks; %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
