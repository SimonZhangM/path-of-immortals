extends "res://tests/save_actions_tests.gd"
const Checkpoints = preload("res://scripts/entry/save_checkpoints.gd")

func run() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
	directory="res://artifacts/manual-quick-20261105/run-%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	Slots.auto_path=directory+"auto.json"
	Session.index_path=directory+"session.json"
	root.get_node("SavePlaytime").set_process(false)
	root.get_node("GameSettings").apply_values({"quick_save":false,"background_pause":false})
	var registry := ContentRegistry.new()
	check(registry.load_base_content(),"content loads")
	var made := MapLoadoutStore.create_state(registry,registry.get_board("base.board.bag"))
	check(made.error.is_empty(),"state created")
	var state: MapLoadoutState=made.state
	var catalog := Catalog.new()
	catalog.legacy_path=Slots.auto_path
	catalog.index_path=directory+"slots.json"
	catalog.manual_directory=directory
	var browser = preload("res://scripts/entry/save_browser.gd").new()
	browser.in_game=true; browser.catalog=catalog
	root.add_child(browser)
	var store_error := [""]
	browser.action_requested.connect(func(path: String):
		store_error[0]=Ops.store_manual(catalog,state,Slots.working_path(),path)
		browser.refresh())
	await settle()
	await click(browser.row_buttons[0])
	check(browser.selected_index==0 and not browser.back_button.disabled and browser.load_button.disabled,"empty quick can store but not load")
	state.spirit_stones=1234
	await click(browser.back_button)
	check(store_error[0].is_empty() and Session.has_save(Slots.quick_path()),"explicit save creates quick with automatic quick disabled")
	check(not browser.back_button.disabled and not browser.load_button.disabled,"created quick supports store and load")
	check(Files.read(Slots.quick_path()).save_info.save_kind=="quick","quick retains badge kind")
	Checkpoints.pending_quick=state.snapshot(); Checkpoints.pending_source=Slots.working_path(); Checkpoints.retry_seconds=5
	state.spirit_stones=5678
	var before := state.snapshot()
	await click(browser.back_button)
	await click(browser.overwrite_dialog.confirm_button)
	check(store_error[0].is_empty() and Files.read(Slots.quick_path()).spirit_stones==5678,"quick overwrite stores current state")
	check(Files.read(Slots.quick_path()+".bak").spirit_stones==1234,"overwrite preserves previous backup")
	check(Checkpoints.pending_quick.is_empty() and Checkpoints.pending_source.is_empty(),"new explicit save cancels stale retry")
	Checkpoints.retry_pending(10,Slots.working_path(),true)
	check(Files.read(Slots.quick_path()).spirit_stones==5678 and state.snapshot()==before,"retry cannot roll back explicit snapshot; live state unchanged")
	check(Session.resume_path(Slots.auto_path)==Slots.quick_path(),"continue finds new quick")
	check(catalog.next_manual_slot().slot==3 and not FileAccess.file_exists(catalog.index_path),"quick does not consume manual slot")
	await click(browser.row_buttons[1])
	check(browser.back_button.disabled and browser.load_button.disabled,"empty auto remains protected")
	check(not Ops.store_manual(catalog,state,Slots.working_path(),Slots.auto_path).is_empty(),"backend protects automatic slot")
	Files.write(Slots.auto_path,state.snapshot())
	var auto_hash := FileAccess.get_sha256(Slots.auto_path)
	browser.refresh(); browser.select(1)
	check(browser.back_button.disabled and not browser.load_button.disabled,"existing auto remains read only")
	check(not Ops.store_manual(catalog,state,Slots.working_path(),Slots.auto_path).is_empty() and FileAccess.get_sha256(Slots.auto_path)==auto_hash,"rejected overwrite preserves auto")
	browser.select(2)
	await click(browser.back_button)
	var manual: String=browser.entries[browser.selected_index].path
	check(store_error[0].is_empty() and Files.read(manual).save_info.save_kind=="manual","manual slot creation preserved")
	var manual_hash := FileAccess.get_sha256(manual)
	var quick_hash := FileAccess.get_sha256(Slots.quick_path())
	DirAccess.make_dir_absolute(Slots.quick_path()+".tmp")
	Checkpoints.pending_quick=state.snapshot(); Checkpoints.pending_source=Slots.working_path()
	check(not Ops.store_manual(catalog,state,Slots.working_path(),Slots.quick_path()).is_empty(),"failed write reports error")
	check(not Checkpoints.pending_quick.is_empty() and FileAccess.get_sha256(Slots.quick_path())==quick_hash,"failed write preserves retry and snapshot")
	check(FileAccess.get_sha256(manual)==manual_hash and state.snapshot()==before,"unrelated manual and live state preserved")
	DirAccess.remove_absolute(Slots.quick_path()+".tmp")
	Checkpoints.pending_quick.clear()
	browser.queue_free(); await settle()
	await create_timer(1.0).timeout
	print("MANUAL_QUICK: %d checks; %d failures; %s" % [checks,failures,directory])
	quit(1 if failures else 0)
