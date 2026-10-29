extends "res://tests/save_actions_tests.gd"
const Checkpoints = preload("res://scripts/entry/save_checkpoints.gd")

func prepare(state: MapLoadoutState, event: Dictionary) -> Dictionary:
	var options := MapGatheringOptions.new()
	options.load_options(MapGatheringOptions.path_for_record(MapGatheringRewards.record_for(state.records,event.item_id)))
	var rng := RandomNumberGenerator.new()
	rng.seed = 47
	check(MapGatheringRewards.prepare(state,event,options.methods[0].id,Slots.working_path(),rng).is_empty(),"prepare gathering")
	return state.gathering_offers[event.id].duplicate(true)

func run() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	root.get_node("SavePlaytime").set_process(false)
	root.get_node("GameSettings").apply_values({"background_pause":false,"quick_save":true})
	directory = "res://artifacts/gathering-checkpoint/run-%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	Slots.auto_path = directory+"auto.json"
	Session.index_path = directory+"last.json"
	Session.clear_selection()
	var map = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path = Slots.working_path()
	map.defer_map_music = true
	map.defer_optional_views = true
	root.add_child(map)
	current_scene = map
	await settle()
	map.set_process(false)
	check(map.startup_error.is_empty(),"isolated fresh map initializes")
	var state: MapLoadoutState = map.loadout
	for filename: String in ["qingshihewan_gathering_n04","qingshihewan_mining_n19","xiyuanyaopo_mining_n17"]:
		var event: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_events/"+filename+".json"))
		var before_hash := FileAccess.get_sha256(Slots.quick_path()) if FileAccess.file_exists(Slots.quick_path()) else ""
		var offer := prepare(state,event)
		check((FileAccess.get_sha256(Slots.quick_path()) if FileAccess.file_exists(Slots.quick_path()) else "")==before_hash,"pending loot never overwrites quick")
		var units_before: int = state.snapshot().owned_units.size()
		var stones_before := state.spirit_stones
		if filename=="qingshihewan_gathering_n04":
			map.travel.current_node_id = event.point_id
			map.travel.map_position = map.travel.node_positions[event.point_id]
			map.travel.mode = "idle"
			map._visit_exploration(event.point_id)
			check(map._try_start_event(event.point_id,"click",true),"pending herb opens through map flow")
			check(map.event_state.phase=="gathering_reward","map shows pending herb reward")
			map._accept_gathering()
			check(not map.event_state.is_active(),"map receive completes gathering")
		else:
			check(MapGatheringRewards.claim(state,event,Slots.working_path()).is_empty(),"claim mineral reward")
		check(state.has_reward(offer.id),"committed reward receipt")
		if event.item_id==MapGatheringRewards.SPIRIT_STONE_ID:
			check(state.spirit_stones==stones_before+int(offer.quantity),"mined spirit stones enter balance")
		else:
			check(state.snapshot().owned_units.size()==units_before+int(offer.quantity),"gathered items enter bag")
		var saved := Files.read(Slots.quick_path())
		check(saved.get("save_info",{}).get("checkpoint_reason")=="gathering_complete","quick checkpoint written after receipt")
		for field: String in ["owned_units","spirit_stones","calendar","gathering_offers","granted_rewards"]:
			check(saved.get(field)==JSON.parse_string(JSON.stringify(state.snapshot().get(field))),"quick contains committed "+field)
		var quick_hash := FileAccess.get_sha256(Slots.quick_path())
		var committed := state.snapshot()
		check(MapGatheringRewards.claim(state,event,Slots.working_path()).is_empty() and state.snapshot()==committed,"duplicate receipt gives nothing")
		check(FileAccess.get_sha256(Slots.quick_path())==quick_hash,"duplicate receipt does not rewrite quick")
	var herb: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_events/qingshihewan_gathering_n04.json"))
	var offer := prepare(state,herb)
	var quick_hash := FileAccess.get_sha256(Slots.quick_path())
	DirAccess.make_dir_recursive_absolute(Slots.working_path()+".tmp")
	check(not MapGatheringRewards.claim(state,herb,Slots.working_path()).is_empty() and not state.has_reward(offer.id),"failed transaction leaves loot pending")
	check(FileAccess.get_sha256(Slots.quick_path())==quick_hash,"failed transaction preserves quick")
	DirAccess.remove_absolute(Slots.working_path()+".tmp")
	root.get_node("GameSettings").apply_values({"quick_save":false})
	check(MapGatheringRewards.claim(state,herb,Slots.working_path()).is_empty() and state.has_reward(offer.id),"quick disabled still grants loot")
	check(FileAccess.get_sha256(Slots.quick_path())==quick_hash,"quick disabled preserves previous checkpoint")
	root.get_node("GameSettings").apply_values({"quick_save":true})
	offer = prepare(state,herb)
	DirAccess.make_dir_recursive_absolute(Slots.quick_path()+".tmp")
	check(MapGatheringRewards.claim(state,herb,Slots.working_path()).is_empty() and state.has_reward(offer.id),"quick write failure does not undo receipt")
	check(not Checkpoints.pending_quick.is_empty() and FileAccess.get_sha256(Slots.quick_path())==quick_hash,"failed quick queues committed state")
	var committed := state.snapshot()
	MapGatheringRewards.claim(state,herb,Slots.working_path())
	check(state.snapshot()==committed,"retrying receipt after quick failure gives no duplicate loot")
	DirAccess.remove_absolute(Slots.quick_path()+".tmp")
	Checkpoints.retry_pending(6,Slots.working_path(),true)
	check(Checkpoints.pending_quick.is_empty() and Files.read(Slots.quick_path()).owned_units==committed.owned_units,"quick retry saves committed loot")
	check(not FileAccess.file_exists(Slots.auto_path),"gathering never writes timed snapshot")
	Meta.stop()
	map.deactivate_location()
	map.queue_free()
	await settle()
	print("GATHERING_CHECKPOINT: %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)
