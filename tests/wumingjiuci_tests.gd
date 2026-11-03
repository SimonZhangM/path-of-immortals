extends SceneTree

const MAP := "base.map.wumingjiuci"
const DIR := "res://artifacts/wumingjiuci/"
const Session = preload("res://scripts/entry/game_save_session.gd")
const Catalog = preload("res://scripts/map/world_map_catalog.gd")
var checks := 0
var failures := 0
var render := false
var save_path := DIR + "test-%d.json" % Time.get_ticks_usec()

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
func place(map: Node, n: int) -> void:
	var id := MAP + ".point.n%02d" % n
	map.travel.stop_at_current_node()
	map.travel.current_node_id = id
	map.travel.map_position = map.travel.node_positions[id]
	map.travel.paused = false
	map.loadout.set_map_location(MAP,id)
	map._visit_exploration(id)
	map.player.present(map.travel)
func find_map(id: String) -> Node:
	for child in root.get_children():
		if child.has_method("_try_start_event") and child.definition.get("id")==id: return child
	return null
func run() -> void:
	create_timer(55).timeout.connect(func(): quit(2))
	render = DisplayServer.get_name() != "headless"
	AudioServer.set_bus_mute(0,true)
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(2560,1440)
	DirAccess.make_dir_recursive_absolute(DIR)
	Session.index_path = save_path + ".index.json"
	Session.clear_selection()
	MapEventState.session_completed.clear()
	var map = load("res://scenes/maps/wumingjiuci.tscn").instantiate()
	map.inventory_save_path = save_path
	map.defer_map_music = true
	map.defer_optional_views = true
	root.add_child(map)
	await settle()
	check(map.startup_error.is_empty(),"map startup: " + map.startup_error)
	if not map.startup_error.is_empty(): quit(1); return
	check(map.travel.current_node_id==MAP+".point.n01","bottom entry spawn")
	check(map.travel.node_positions.size()==32,"all 32 circles become nodes")
	check(map.content.get_node("Routes").get_child_count()==34,"34 marked route segments")
	check(map.event_registry.events.size()==16,"11 encounters, two rests, two chests, one herb")
	var seen := {MAP+".point.n01":true}
	var pending: Array = seen.keys()
	while not pending.is_empty():
		var id: String = pending.pop_back()
		for edge: Dictionary in map.travel.adjacency[id]:
			if not seen.has(edge.to): seen[edge.to]=true; pending.append(edge.to)
	check(seen.size()==32,"all branches reachable")
	for route: MapRoute in map.content.get_node("Routes").get_children():
		check(route.curve.get_point_position(0).is_equal_approx(route.get_node(route.start_point).position),"curve start " + route.name)
		check(route.curve.get_point_position(route.curve.point_count-1).is_equal_approx(route.get_node(route.end_point).position),"curve end " + route.name)
	for asset in ["map-wumingjiuci","map-title-wumingjiuci"]:
		check((load("res://assets/"+asset+".webp") as Texture2D).get_image().has_mipmaps(),"mipmaps " + asset)
	check(map.definition.title_image=="res://assets/map-title-wumingjiuci.webp","supplied hanging title")
	await capture("entry")
	for point: MapRoutePoint in map.content.get_node("Points").get_children(): point.present_exploration(true,true)
	for route: MapRoute in map.content.get_node("Routes").get_children(): route.present_exploration(true,false,false,72)
	map.zoom_factor=1.0
	map._fit_map()
	await settle()
	await capture("overview")
	var catalog := Catalog.new()
	check(catalog.location_for_map(MAP)=="base.world_location.wumingjiuci","world map current location")
	check(catalog.region_progress("base.world_region.qinglanshanlu",{}).total==144,"world denominator includes current shrine and village nodes")
	for n in [3,4,8,10,16,18,20,23,26,28,30]:
		place(map,n)
		check(map._try_start_event(map.travel.current_node_id,"arrival",true),"encounter arrival n%d" % n)
		var event: Dictionary = map.event_state.active_event()
		check(not event.get("pending_enemy",false) and event.has("enemy_id"),"assigned enemy n%d" % n)
		check(map.encounter_dialog.visible and not map.encounter_dialog.fight_button.disabled and not map.encounter_dialog.retreat_button.disabled,"ready actions n%d" % n)
		check(map.loadout.registry.enemy_battle_error(event.enemy_id).is_empty(),"enemy ready n%d" % n)
		check(map.encounter_dialog.enemy_name.text==map.loadout.registry.get_enemy(event.enemy_id).name,"enemy identity n%d" % n)
		if n==3: await capture("encounter")
		map.encounter_dialog.select_action(0)
		map.encounter_dialog.activate_action(0)
		check(not map.event_state.is_active() and not map.travel.paused,"retreat resumes map")
	var ready_event: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_events/qingshihewan_encounter_n01.json"))
	var ready_registry := MapEventRegistry.new()
	check(ready_registry.configure([ready_event],[ready_event.point_id]).is_empty(),"ordinary encounter still validates")
	var enemy := PartyMemberState.new(map.loadout.registry.get_enemy(ready_event.enemy_id),map.loadout.registry)
	enemy.equip_definition_loadout()
	map.encounter_dialog.present(ready_event,enemy)
	check(not map.encounter_dialog.fight_button.disabled and map.encounter_dialog.portrait.visible and map.encounter_dialog.loot_heading.visible,"ordinary encounter restores combat and enemy UI after pending")
	map.encounter_dialog.hide()
	# Validate pending-only constraints without weakening ordinary encounters.
	var pending_event: Dictionary = map.event_registry.events["base.map_event.wumingjiuci.encounter_n03"].duplicate(true)
	for field in ["enemy_id","enemy_sequence","battle_scene","respawn_days"]: pending_event.erase(field)
	pending_event.pending_enemy=true
	var registry := MapEventRegistry.new()
	for patch in [{"enemy_id":"base.enemy.fake"},{"battle_scene":"res://scenes/main/main.tscn"},{"pending_enemy":"yes"},{"pending_enemy":false}]:
		var broken := pending_event.duplicate(true)
		broken.merge(patch,true)
		check(not registry.configure([broken],[broken.point_id]).is_empty(),"invalid encounter rejected")
	for n in [15,24]:
		place(map,n)
		check(map._try_start_event(map.travel.current_node_id,"arrival",true),"rest arrival")
		check(map.rest_dialog.visible,"rest window")
		if n==15: await capture("rest")
		if not render:
			map.player_status.set_resource("hp",map.player_status.maxima.hp*0.1)
			var day := WorldCalendar.current_day(map.loadout.calendar)
			map._confirm_rest()
			check(WorldCalendar.current_day(map.loadout.calendar)==day+1,"rest advances one day")
			check(is_equal_approx(map.player_status.resources.hp,map.player_status.maxima.hp*0.4),"outdoor recovery")
		else: map._cancel_rest()
	for n in [11,27]:
		place(map,n)
		check(map._try_start_event(map.travel.current_node_id,"arrival",true),"chest arrival")
		var event: Dictionary = map.event_state.active_event()
		check(map.chest_observation_dialog.visible,"chest observation")
		if n==11: await capture("chest")
		if not render:
			map._open_chest()
			check(MapChestRewards.items(map.loadout,event).size()==2,"existing two-choice pool")
			check(MapChestRewards.claim(map.loadout,event,0,save_path).is_empty(),"claim chest")
			check(not MapChestRewards.claim(map.loadout,event,1,save_path).is_empty(),"no double claim")
		map._cancel_chest()
	place(map,31)
	check(map._try_start_event(map.travel.current_node_id,"arrival",true),"herb arrival")
	var herb: Dictionary = map.event_state.active_event()
	check(herb.item_id=="base.material.qingtenggen" and map.gathering_dialog.visible,"northeast qingtenggen")
	await capture("herb")
	if not render:
		var options := MapGatheringOptions.new()
		check(options.load_options().is_empty(),"herb options")
		var rng := RandomNumberGenerator.new()
		rng.seed=42
		var before: int = map.loadout.carried_owned().values().count(herb.item_id)
		check(MapGatheringRewards.prepare(map.loadout,herb,options.methods[0].id,save_path,rng).is_empty(),"prepare qingtenggen")
		var offer := MapGatheringRewards.pending(map.loadout,herb)
		check(MapGatheringRewards.claim(map.loadout,herb,save_path).is_empty(),"claim qingtenggen")
		check(map.loadout.carried_owned().values().count(herb.item_id)==before+int(offer.quantity),"qingtenggen reaches inventory")
	map._cancel_gathering()
	place(map,5)
	check(not map._try_start_event(map.travel.current_node_id,"arrival",true),"plain node has no event")
	check(map._save_loadout().is_empty(),"save shrine progress")
	map.queue_free()
	await settle()
	var router = load("res://scripts/map/map_session_start.gd").new()
	router.inventory_save_path=save_path
	router.defer_map_music=true
	root.add_child(router)
	await settle()
	map=find_map(MAP)
	check(map!=null and map.travel.current_node_id==MAP+".point.n05","resume registered map and point")
	if map!=null and not render:
		place(map,1)
		check(map._try_open_exit(MAP+".point.n01"),"exit confirmation")
		map.exit_dialog.confirm_button.pressed.emit()
		while is_instance_valid(map): await process_frame
		var river := find_map("base.map.qingshihewan")
		check(river!=null and river.travel.current_node_id=="base.map.qingshihewan.point.n02","arrive at marked river temple")
		if river!=null:
			check(river._try_open_exit("base.map.qingshihewan.point.n02"),"river return confirmation")
			river.exit_dialog.confirm_button.pressed.emit()
			while is_instance_valid(river): await process_frame
			map=find_map(MAP)
			check(map!=null and map.travel.current_node_id==MAP+".point.n01","return to shrine bottom")
	if is_instance_valid(map): map.queue_free()
	await settle()
	print("WUMINGJIUCI: %d checks, %d failures; render=%s" % [checks,failures,render])
	quit(1 if failures else 0)
