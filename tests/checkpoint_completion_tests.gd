extends "res://tests/save_actions_tests.gd"
const Checkpoints = preload("res://scripts/entry/save_checkpoints.gd")

func run() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	root.get_node("SavePlaytime").set_process(false)
	directory = "res://artifacts/checkpoint-completion/run-%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	var raw := Files.read(Slots.AUTO_PATH)
	Slots.auto_path = directory+"auto.json"
	Session.index_path = directory+"last.json"
	Session.clear_selection()
	raw.growth.day_usec = 0
	Files.write(Slots.auto_path,raw)
	var map = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path = Slots.auto_path
	map.defer_map_music = true
	map.defer_optional_views = true
	root.add_child(map)
	current_scene = map
	await settle()
	check(map.startup_error.is_empty(),"isolated map initialized")
	map.set_process(false)
	var state: MapLoadoutState = map.loadout
	var prepared := state.snapshot()
	prepared.placements=[]
	prepared.owned_units["test.guide"]="base.map_item.training_guide_stone"
	check(state.restore(prepared).is_empty(),"guide fixture restored")
	check(state.inventory.add_item("test.guide","base.map_item.training_guide_stone",Vector2i.ZERO),"guide equipped")
	state.storage.take_one("test.guide")
	Checkpoints.write(state,map.inventory_save_path,"quick","test_baseline")
	var quick_hash := FileAccess.get_sha256(Slots.quick_path())
	var auto_hash := FileAccess.get_sha256(Slots.auto_path)
	var event: Dictionary = map.event_registry.events["base.map_event.qingshihewan.cultivation_n32"].duplicate(true)
	event.durations=[1]
	var practice := MapCultivationSession.new()
	check(practice.begin(event,"cultivation",1,WorldCalendar.current_day(state.calendar)) and practice.bind(state,map.player_status,map.inventory_save_path),"training session bound")
	practice.set_paused(false,WorldCalendar.current_day(state.calendar))
	practice.advance(1)
	check(practice.error.is_empty() and state.growth.day_usec==1000000,"actual one-second training settled")
	check(FileAccess.get_sha256(Slots.quick_path())==quick_hash,"per-second cultivation does not overwrite quick")
	practice.advance(59)
	check(practice.error.is_empty() and practice.elapsed_days==1,"actual training reaches duration")
	# JSON numbers deserialize as floats, including the nested birthday array.
	var saved_calendar: Dictionary = JSON.parse_string(JSON.stringify(state.calendar))
	check(Files.read(Slots.quick_path()).save_info.checkpoint_reason=="cultivation_complete" and Files.read(Slots.quick_path()).calendar==saved_calendar,"duration completion saves full result")
	quick_hash = FileAccess.get_sha256(Slots.quick_path())
	practice.finish(WorldCalendar.current_day(state.calendar))
	check(FileAccess.get_sha256(Slots.quick_path())==quick_hash,"closing completed training does not repeat snapshot")
	check(practice.begin(event,"cultivation",1,WorldCalendar.current_day(state.calendar)) and practice.bind(state,map.player_status,map.inventory_save_path),"session reuse resets completion guard")
	practice.set_paused(false,WorldCalendar.current_day(state.calendar))
	practice.advance(3)
	practice.set_paused(true,WorldCalendar.current_day(state.calendar))
	check(FileAccess.get_sha256(Slots.quick_path())==quick_hash,"pausing is not completing training")
	practice.finish(WorldCalendar.current_day(state.calendar))
	check(FileAccess.get_sha256(Slots.quick_path())!=quick_hash and Files.read(Slots.quick_path()).growth.day_usec==3000000,"manual finish saves settled partial session")
	check(FileAccess.get_sha256(Slots.auto_path)==auto_hash,"all training commits preserve timed snapshot")
	# Fail the quick-write boundary after a successfully committed transaction.
	quick_hash = FileAccess.get_sha256(Slots.quick_path())
	DirAccess.make_dir_recursive_absolute(Slots.quick_path()+".tmp")
	state.spirit_stones = 2345
	check(MapLoadoutStore.save(state,map.inventory_save_path).is_empty(),"completed action commits despite separate quick target failure")
	Checkpoints.after_action(state,map.inventory_save_path,"craft_complete")
	check(not Checkpoints.pending_quick.is_empty() and FileAccess.get_sha256(Slots.quick_path())==quick_hash,"failed quick preserves old file and queues completed snapshot")
	DirAccess.remove_absolute(Slots.quick_path()+".tmp")
	state.spirit_stones = 3456
	Checkpoints.retry_pending(6,map.inventory_save_path,true)
	check(Checkpoints.pending_quick.is_empty() and Files.read(Slots.quick_path()).spirit_stones==2345,"retry writes completed snapshot without repeating action")
	Checkpoints.after_action(state,map.inventory_save_path,"alchemy_complete")
	check(Files.read(Slots.quick_path()).spirit_stones==3456 and Files.read(Slots.quick_path()).save_info.checkpoint_reason=="alchemy_complete","future alchemy can use same completion interface")
	# A newer success invalidates an older pending record.
	Checkpoints.pending_quick = Files.read(Slots.quick_path())
	state.spirit_stones=4567
	check(Checkpoints.write(state,map.inventory_save_path,"quick","before_battle").is_empty() and Checkpoints.pending_quick.is_empty(),"newer quick supersedes old retry")
	check(FileAccess.get_sha256(Slots.auto_path)==auto_hash,"failed/retried quick never changes auto")
	Meta.stop()
	map.deactivate_location()
	map.queue_free()
	await settle()
	print("CHECKPOINT_COMPLETION: %d checks; %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
