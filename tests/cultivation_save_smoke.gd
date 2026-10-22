extends "res://tests/map_shop_tests.gd"

func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var original:=FileAccess.get_file_as_string(MapLoadoutStore.DEFAULT_PATH)
	var isolated: String="res://artifacts/growth-save-smoke.json"
	var file:=FileAccess.open(isolated,FileAccess.WRITE)
	file.store_string(original); file.close()
	var map=load("res://scenes/maps/qingshizhen.tscn").instantiate()
	map.inventory_save_path=isolated
	map.defer_map_music=true
	root.add_child(map)
	map.set_process(false)
	await settle()
	check(map.startup_error.is_empty(),"real-save copy startup: "+map.startup_error)
	if not map.startup_error.is_empty(): quit(1); return
	check(map.player_status.rank_name.contains("化神") and map.loadout.growth.layer==1,"correct test realm")
	check(map.loadout.growth.roots.size()==7,"seven roots loaded")
	check(map.loadout.storage_used_slots()==96,"existing inventory retained")
	check(map.loadout.knowledge.learned.is_empty(),"existing zero mastery retained")
	var point: String="base.map.qingshizhen.point.n05"
	map.travel.current_node_id=point
	map.travel.map_position=map.travel.node_positions[point]
	map.travel.stop_at_current_node()
	check(map._try_start_event(point,"click",true),"town cultivation opens")
	map._request_cultivation("technique",5)
	check(map.cultivation_progress_dialog.visible and map.cultivation_session.site.slots==1,"town single slot runtime")
	check(map.cultivation_session.paused and map.cultivation_session.waiting_for_books,"book modes wait for selection before time advances")
	check(map.loadout.storage_used_slots()==97,"one guide gift in isolated copy")
	var book: String="base.cultivation_book.wood_04"
	check(map.cultivation_session.select_books([book]) and map.cultivation_session.paused,"selection still waits for start")
	check(not map.cultivation_session.select_books([book,"base.cultivation_book.fire_04"]),"town rejects excess books")
	map.cultivation_session.set_paused(true,0)
	map.cultivation_session.finish(0)
	var manager:=GameManager.new()
	manager.use_saved_loadout=true
	manager.loadout_save_path=isolated
	root.add_child(manager)
	manager.set_process(false)
	check(manager.startup_error.is_empty(),"battle entry with migrated save: "+manager.startup_error)
	check(manager.party[0].definition.max_hp==6400 and manager.party[0].definition.max_stamina==4000 and manager.party[0].definition.max_spirit==5000,"battle uses growth maxima")
	check(manager.party[0].test_spell_access,"previous test spell access retained")
	check(FileAccess.get_file_as_string(MapLoadoutStore.DEFAULT_PATH)==original,"real save unchanged by smoke test")
	manager.queue_free(); map.queue_free()
	await settle()
	print("CULTIVATION SAVE SMOKE: ",checks," checks; ",failures," failures")
	quit(1 if failures else 0)
