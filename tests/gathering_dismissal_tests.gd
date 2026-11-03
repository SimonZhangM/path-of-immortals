extends "res://tests/save_actions_tests.gd"

var map: Control
var path := ""

func load_map(point: String) -> void:
	if map!=null:
		Meta.stop()
		map.deactivate_location()
		map.free()
	MapEventState.session_completed.clear()
	map = load("res://scenes/maps/xiyuanyaopo.tscn").instantiate()
	map.inventory_save_path = path
	map.arrival_point_id = point
	map.defer_map_music = true
	map.defer_optional_views = true
	root.add_child(map)
	current_scene = map
	await settle()
	check(map.startup_error.is_empty(),"isolated slope map starts")
	map._try_start_event(point,"click",true)

func dismiss(kind: String) -> void:
	if kind=="button":
		await click(map.gathering_result.accept_button)
		return
	for pressed in [true,false]:
		var event: InputEvent
		if kind=="escape":
			var key := InputEventKey.new()
			key.keycode = KEY_ESCAPE
			key.pressed = pressed
			event = key
		else:
			var mouse := InputEventMouseButton.new()
			mouse.button_index = MOUSE_BUTTON_RIGHT
			mouse.position = map.gathering_result.accept_button.get_global_rect().get_center()
			mouse.pressed = pressed
			event = mouse
		root.push_input(event,true)
		await process_frame
	await settle()

func prepare(event: Dictionary) -> Dictionary:
	var options := MapGatheringOptions.new()
	check(options.load_options(MapGatheringOptions.path_for_record(MapGatheringRewards.record_for(map.loadout.records,event.item_id))).is_empty(),"gathering options load")
	check(MapGatheringRewards.prepare(map.loadout,event,options.methods[0].id,path,RandomNumberGenerator.new()).is_empty(),"prepare saved harvest result")
	map._show_gathering_result()
	await settle()
	check(map.gathering_result.visible and map.event_state.phase=="gathering_reward","finished harvest presents result")
	return map.loadout.gathering_offers[event.id].duplicate(true)

func run() -> void:
	create_timer(50).timeout.connect(func(): quit(2))
	directory = "res://artifacts/gathering-dismissal-20261102/run-%d/"%Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	Slots.auto_path = directory+"auto.json"
	Session.index_path = directory+"session.json"
	Session.clear_selection()
	path = Slots.working_path()
	root.get_node("SavePlaytime").set_process(false)
	root.get_node("GameSettings").apply_values({"background_pause":false,"background_mute":false,"quick_save":true})
	root.get_node("GameSettings").set_application_focus(true)
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1920,1080)
	var herb: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_events/xiyuanyaopo_gathering_n13.json"))
	for kind in ["button","right","escape"]:
		await load_map(herb.point_id)
		check(map.event_state.phase=="gathering" and not map.gathering_result.visible,"reloaded claimed result opens gathering menu only")
		var count_before: int = map.loadout.snapshot().owned_units.values().count(herb.item_id)
		var offer: Dictionary = await prepare(herb)
		var day_before := WorldCalendar.current_day(map.loadout.calendar)
		await dismiss(kind)
		check(map.loadout.has_reward(offer.id),kind+" acknowledges receipt")
		check(map.loadout.snapshot().owned_units.values().count(herb.item_id)==count_before+int(offer.quantity),kind+" receives exact herb quantity")
		check(not map.event_state.is_active() and not map.gathering_result.visible and not map.travel.paused,kind+" closes and resumes travel")
		check(MapGatheringRewards.pending(map.loadout,herb).is_empty(),kind+" leaves no pending old reward")
		check(Files.read(Slots.quick_path()).granted_rewards.has(offer.id),kind+" quick save includes receipt")
		var before: Dictionary = map.loadout.snapshot()
		map._accept_gathering()
		check(map.loadout.snapshot()==before,"duplicate acknowledgement changes nothing")
		var neighbor: String = map.travel.adjacency[herb.point_id][0].to
		map.travel.current_node_id = neighbor
		map._on_node_arrived(neighbor)
		map.travel.current_node_id = herb.point_id
		map._on_node_arrived(herb.point_id)
		check(not map.gathering_result.visible and not map.event_state.is_active(),kind+" leave and return does not reopen loot")
		check(WorldCalendar.current_day(map.loadout.calendar)==day_before,"revisit consumes no additional days")
	# Existing unacknowledged saves still deliver their exact pending roll once.
	await load_map(herb.point_id)
	var offer: Dictionary = await prepare(herb)
	await load_map(herb.point_id)
	check(map.event_state.phase=="gathering_reward" and map.loadout.gathering_offers[herb.id]==offer,"interrupted old pending result survives reload")
	var before: Dictionary = map.loadout.snapshot()
	map.inventory_save_path = directory+"missing/fail.json"
	await dismiss("escape")
	check(map.loadout.snapshot()==before and not map.loadout.has_reward(offer.id),"failed dismissal save changes no inventory or receipt")
	check(not map.event_state.is_active(),"failed settlement still permits leaving to resolve storage or save issue")
	map.inventory_save_path = path
	map._try_start_event(herb.point_id,"click",true)
	check(map.gathering_result.visible,"unsettled result can be retried")
	await dismiss("right")
	check(map.loadout.has_reward(offer.id),"retry settles same batch")
	# Shared mining results use the same acknowledgement path.
	var ore: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_events/xiyuanyaopo_mining_n15.json"))
	await load_map(ore.point_id)
	var count_before: int = map.loadout.snapshot().owned_units.values().count(ore.item_id)
	offer = await prepare(ore)
	await dismiss("escape")
	check(map.loadout.has_reward(offer.id),"mining dismissal settles receipt")
	check(map.loadout.snapshot().owned_units.values().count(ore.item_id)==count_before+int(offer.quantity),"mining credits once")
	await load_map(ore.point_id)
	check(not map.gathering_result.visible and map.event_state.phase=="gathering","mining reload does not replay old result")
	var snapshot: Dictionary = map.loadout.snapshot()
	map._cancel_gathering()
	check(map.loadout.snapshot()==snapshot and not map.event_state.is_active(),"pre-gather cancel still consumes nothing")
	Meta.stop()
	map.deactivate_location()
	map.free()
	await settle()
	print("GATHERING_DISMISSAL: %d checks; %d failures; %s"%[checks,failures,directory])
	quit(1 if failures else 0)
