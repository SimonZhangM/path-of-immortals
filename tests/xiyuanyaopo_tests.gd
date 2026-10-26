extends SceneTree

const Session = preload("res://scripts/entry/game_save_session.gd")
const MAP := "base.map.xiyuanyaopo"
const DIR := "res://artifacts/xiyuanyaopo/"
var checks := 0
var failures := 0
var save_path := DIR + "test-%d.json" % Time.get_ticks_usec()
var render := false

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
func settle() -> void:
	for i in 5: await process_frame
func capture(file: String) -> void:
	if not render: return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(DIR + file + ".png")
func hash_file(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
func event_at(map: Node, n: int) -> Dictionary:
	return map.event_registry.events[map.event_registry.by_point[MAP+".point.n%02d" % n]]
func place(map: Node, id: String) -> void:
	map.travel.stop_at_current_node()
	map.travel.current_node_id = id
	map.travel.map_position = map.travel.node_positions[id]
	map.travel.paused = false
	map.loadout.set_map_location(map.definition.id,id)
	map._visit_exploration(id)
	map.player.present(map.travel)
func new_map(staged := false) -> Node:
	var map = load("res://scenes/maps/xiyuanyaopo.tscn").instantiate()
	map.inventory_save_path = save_path
	map.defer_map_music = true
	map.defer_optional_views = true
	map.staged_startup = staged
	root.add_child(map)
	if staged: await map.initialize_staged()
	await settle()
	check(map.startup_error.is_empty(), "new map startup: " + map.startup_error)
	return map
func run() -> void:
	create_timer(100).timeout.connect(func(): quit(2))
	render = DisplayServer.get_name() != "headless"
	AudioServer.set_bus_mute(0,true)
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1920,1080)
	DirAccess.make_dir_recursive_absolute(DIR)
	var original_save := hash_file(MapLoadoutStore.DEFAULT_PATH)
	var original_index := hash_file(Session.INDEX_PATH)
	Session.index_path = save_path + ".index.json"
	Session.clear_selection()
	MapEventState.session_completed.clear()
	var map := await new_map()
	if not map.startup_error.is_empty(): quit(1); return
	check(map.travel.node_positions.size()==19 and map.content.get_node("Routes").get_child_count()==18, "19 nodes and 18 routes")
	check(map.event_registry.events.size()==9, "seven gathering and two chest events")
	check(map.travel.current_node_id==MAP+".point.n01", "southwest spawn")
	check(map.exits_by_point[MAP+".point.n01"].target_point=="base.map.qingshizhen.point.n04", "exit targets town northeast")
	var seen := {MAP+".point.n01":true}
	var pending: Array = seen.keys()
	while not pending.is_empty():
		var id: String = pending.pop_back()
		for edge: Dictionary in map.travel.adjacency[id]:
			if not seen.has(edge.to): seen[edge.to]=true; pending.append(edge.to)
	check(seen.size()==19, "every node reachable from exit")
	for route: MapRoute in map.content.get_node("Routes").get_children():
		check(route.curve.get_point_position(0).is_equal_approx(route.get_node(route.start_point).position), "curve start " + route.name)
		check(route.curve.get_point_position(route.curve.point_count-1).is_equal_approx(route.get_node(route.end_point).position), "curve end " + route.name)
	check((load("res://assets/map-xiyuanyaopo.webp") as Texture2D).get_image().has_mipmaps(), "map mipmaps")
	await capture("entry")
	# Review the complete authored geometry without granting exploration progress.
	for point: MapRoutePoint in map.content.get_node("Points").get_children(): point.present_exploration(true,true)
	for route: MapRoute in map.content.get_node("Routes").get_children(): route.present_exploration(true,false,false,72)
	map.zoom_factor=1.0
	map._fit_map()
	await settle()
	await capture("overview")
	var expected := {7:"base.material.kuaiye",12:"base.material.kuaiye",13:"base.material.xilutai",18:"base.material.xilutai",10:MapGatheringRewards.SPIRIT_STONE_ID,17:MapGatheringRewards.SPIRIT_STONE_ID,15:"base.material.cutiekuang"}
	for n: int in expected:
		var event := event_at(map,n)
		check(event.item_id==expected[n], "resource mapping n%d" % n)
		place(map,event.point_id)
		check(map._try_start_event(event.point_id,"click",true), "open gathering n%d" % n)
		check(map.gathering_dialog.location_illustration.visible and map.gathering_dialog.location_illustration.texture.resource_path==event.presentation.illustration, "location picture n%d" % n)
		check(map.gathering_dialog.location_description.text==event.presentation.description, "local description n%d" % n)
		map.gathering_dialog.select_method(0)
		check(not map.gathering_dialog.method_note.text.is_empty(), "method note n%d" % n)
		if n in [7,10,15]: await capture("gathering-%d" % n)
		map._cancel_gathering()
	if render:
		var currency := MapGatheringRewards.record_for(map.loadout.records,MapGatheringRewards.SPIRIT_STONE_ID)
		currency.quantity=3
		map.gathering_result.present_herb(currency,map.loadout)
		await capture("currency-result")
		map.gathering_result.hide()
	if not render:
		await exercise_rewards(map)
		await exercise_interaction(map)
	for n in [5,16]:
		var event := event_at(map,n)
		place(map,event.point_id)
		check(map._try_start_event(event.point_id,"click",true), "open chest observation")
		check(map.chest_observation_dialog.visible and map.chest_observation_dialog.location_illustration.texture.resource_path==event.presentation.illustration and map.chest_observation_dialog.chest_image.texture.resource_path==event.presentation.chest_image, "chest location illustration and matching separate icon")
		await capture("chest-observation")
		map._open_chest()
		check(map.chest_dialog.visible and MapChestRewards.items(map.loadout,event).size()==2, "two choices shown")
		await capture("chest-choices")
		if not render:
			check(MapChestRewards.claim(map.loadout,event,0,save_path).is_empty(), "chest claim")
			check(map.loadout.chest_cooldowns[event.reward_id].ready_day==WorldCalendar.current_day(map.loadout.calendar)+40, "40 days after claim")
			check(not MapChestRewards.claim(map.loadout,event,1,save_path).is_empty(), "reject second chest choice")
			check(map.loadout.advance_days(40,"test.chest.%d" % n).is_empty(), "advance chest clock")
			check(MapChestRewards.current_event(map.loadout,event).reward_id.ends_with(".cycle.2"), "chest reopens in new cycle")
		map._cancel_chest()
	# Persist a real new-map location, then exercise the registered startup router.
	place(map,MAP+".point.n08")
	check(map._save_loadout().is_empty(), "save new map location")
	map.queue_free()
	await settle()
	var router = load("res://scripts/map/map_session_start.gd").new()
	router.inventory_save_path=save_path
	router.defer_map_music=true
	root.add_child(router)
	await settle()
	map = find_map(MAP)
	check(map!=null and map.travel.current_node_id==MAP+".point.n08", "session catalog resumes new-map point")
	if map!=null:
		if not render: await exercise_exits(map)
		else: map.queue_free(); await settle()
	# New map also supports the menu's staged initialization path.
	var staged := await new_map(true)
	check(staged.travel.current_node_id==MAP+".point.n01" or staged.travel.current_node_id==MAP+".point.n08", "staged startup has valid point")
	staged.queue_free()
	await settle()
	check(hash_file(MapLoadoutStore.DEFAULT_PATH)==original_save and hash_file(Session.INDEX_PATH)==original_index, "actual save and index untouched")
	print("XIYUANYAOPO ", "RENDER" if render else "LOGIC", ": ",checks," checks, ",failures," failures")
	quit(0 if failures==0 else 1)

func exercise_rewards(map: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed=20261025
	for n in [10,17,15,7,13]:
		var event := event_at(map,n)
		var record := MapGatheringRewards.record_for(map.loadout.records,event.item_id)
		var options := MapGatheringOptions.new()
		check(options.load_options(MapGatheringOptions.path_for_record(record)).is_empty(),"profile")
		for index in 3:
			var before: Dictionary = map.loadout.snapshot()
			var day := WorldCalendar.current_day(map.loadout.calendar)
			var method: String = options.methods[index].id
			check(not MapGatheringRewards.prepare(map.loadout,event,method,DIR+"missing/save.json",rng).is_empty() and map.loadout.snapshot()==before,"failed roll atomic")
			check(MapGatheringRewards.prepare(map.loadout,event,method,save_path,rng).is_empty(),"prepare result")
			var offer := MapGatheringRewards.pending(map.loadout,event)
			check(offer.quantity>=index+1 and offer.quantity<=index+2 and WorldCalendar.current_day(map.loadout.calendar)==day+index+1,"three yield/day tiers")
			check(MapGatheringRewards.prepare(map.loadout,event,method,save_path,rng).is_empty() and MapGatheringRewards.pending(map.loadout,event)==offer and WorldCalendar.current_day(map.loadout.calendar)==day+index+1,"pending no reroll or double days")
			var registry := ContentRegistry.new()
			check(registry.load_base_content(), "fresh registry for reload")
			var copy := MapLoadoutStore.create_state(registry,registry.get_board(map.loadout.board.id))
			var reload_error := MapLoadoutStore.load_into(copy.state,save_path)
			check(copy.error.is_empty() and reload_error.is_empty() and MapGatheringRewards.pending(copy.state,event)==offer,"pending survives reload: " + copy.error + reload_error)
			var pending_snapshot: Dictionary = map.loadout.snapshot()
			check(not MapGatheringRewards.claim(map.loadout,event,DIR+"missing/save.json").is_empty() and map.loadout.snapshot()==pending_snapshot,"failed claim atomic")
			check(MapGatheringRewards.claim(map.loadout,event,save_path).is_empty(),"claim succeeds")
			var after: Dictionary = map.loadout.snapshot()
			if event.item_id==MapGatheringRewards.SPIRIT_STONE_ID:
				check(after.spirit_stones==before.spirit_stones+offer.quantity and after.owned_units==before.owned_units,"currency only, no bag occupancy")
			else:
				check(after.spirit_stones==before.spirit_stones and after.owned_units.size()==before.owned_units.size()+offer.quantity,"ordinary materials enter bag")
			check(MapGatheringRewards.claim(map.loadout,event,save_path).is_empty() and map.loadout.snapshot()==after,"duplicate claim no-op")
			reload_error = MapLoadoutStore.load_into(copy.state,save_path)
			check(reload_error.is_empty() and copy.state.spirit_stones==map.loadout.spirit_stones and copy.state.has_reward(offer.id),"claimed balance and receipt survive reload: " + reload_error)
	var malformed := {"base.map_event.test.bad":{"id":"base.map_reward.test.bad.1","item_id":"base.currency.fake","quantity":1,"method_id":"base.gathering.mining_shallow","days":1}}
	check(not MapGatheringRewards.validate_offers(malformed,map.loadout.records),"reject unknown currency")

func exercise_interaction(map: Node) -> void:
	var event := event_at(map,10)
	place(map,event.point_id)
	check(map._try_start_event(event.point_id,"click",true),"mining interaction reopens")
	map.gathering_dialog.action_buttons[0].pressed.emit()
	check(map.event_state.phase=="gathering", "first action click selects")
	map.gathering_dialog.action_buttons[0].pressed.emit()
	check(map.event_state.phase=="gathering_animation", "second action click starts animation")
	while map.event_state.phase=="gathering_animation": await process_frame
	check(map.gathering_result.visible and map.gathering_result.heading.text=="获得灵石", "animation shows currency result")
	var before: int = map.loadout.spirit_stones
	var quantity: int = MapGatheringRewards.pending(map.loadout,event).quantity
	map.gathering_result.accept_button.pressed.emit()
	check(not map.event_state.is_active() and map.loadout.spirit_stones==before+quantity,"result button closes and credits balance")
	await create_timer(0.4).timeout
	check(not map.content.get_node("Points/N10/Sign").visible,"completed mine sign hidden")

func find_map(id: String) -> Node:
	for child: Node in root.get_children():
		if child.get_script()==load("res://scripts/map/map_screen.gd") and child.definition.get("id")==id: return child
	return null
func exercise_exits(map: Node) -> void:
	place(map,MAP+".point.n01")
	check(map._try_open_exit(MAP+".point.n01"),"exit confirmation")
	map.exit_dialog.confirm_button.pressed.emit()
	while is_instance_valid(map): await process_frame
	var town := find_map("base.map.qingshizhen")
	check(town!=null and town.travel.current_node_id=="base.map.qingshizhen.point.n04","arrive at town northeast")
	if town==null: return
	check(town._try_open_exit("base.map.qingshizhen.point.n04"),"town northeast return link")
	town.exit_dialog.confirm_button.pressed.emit()
	while is_instance_valid(town): await process_frame
	var returned := find_map(MAP)
	check(returned!=null and returned.travel.current_node_id==MAP+".point.n01","return to southwest entry")
	if returned!=null: returned.queue_free(); await settle()
