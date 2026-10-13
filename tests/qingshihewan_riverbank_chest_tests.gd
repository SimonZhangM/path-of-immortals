extends SceneTree
const PREFIX := "base.map.qingshihewan.point."
var checks:=0
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func settle() -> void:
	for i in 6: await process_frame
func run() -> void:
	create_timer(40).timeout.connect(func():quit(2))
	AudioServer.set_bus_mute(0,true)
	root.size=Vector2i(1600,1400)
	var map=load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path="";map.defer_map_music=true
	root.add_child(map);map.set_process(false);await settle()
	check(map.startup_error.is_empty(),"map startup")
	check(map.travel.node_positions.size()==40 and map.content.get_node("Routes").get_child_count()==44,"40 nodes / 44 routes")
	check(map.travel.node_positions[PREFIX+"n14"].is_equal_approx(Vector2(2851,503)),"road node restored")
	check(map.travel.node_positions[PREFIX+"n39"].is_equal_approx(Vector2(2660,682)),"chest moved to riverbank")
	check(not map.event_registry.by_point.has(PREFIX+"n14") and not map.content.get_node("Points/N14").has_node("Sign"),"road has no event or chest sign")
	check(map.travel.adjacency[PREFIX+"n39"].size()==1 and map.travel.adjacency[PREFIX+"n39"][0].to==PREFIX+"n14","only connection leads to old road node")
	check(map.travel.adjacency[PREFIX+"n14"].size()==4,"all three original roads plus chest branch")
	var event: Dictionary=map.event_registry.events[map.event_registry.by_point[PREFIX+"n39"]]
	check(event.id=="base.map_event.qingshihewan.chest_n14" and event.reward_id=="base.map_reward.qingshihewan.chest_n14" and event.quality=="下品","stable chest/reward identity and quality")
	for route: MapRoute in map.content.get_node("Routes").get_children():
		check(route.curve.get_point_position(0).is_equal_approx(route.get_node(route.start_point).position) and route.curve.get_point_position(route.curve.point_count-1).is_equal_approx(route.get_node(route.end_point).position),"route endpoints "+route.route_id)
	map.travel.current_node_id=PREFIX+"n15";map.travel.map_position=map.travel.node_positions[PREFIX+"n15"];map.travel.stop_at_current_node()
	map._visit_exploration(PREFIX+"n15")
	check(map.travel.request_destination(PREFIX+"n14"),"walk to road junction")
	map.travel.advance(100);await settle()
	check(map.travel.current_node_id==PREFIX+"n14" and not map.event_state.is_active() and not map.chest_dialog.visible,"road arrival does not trigger chest")
	check(map.exploration.revealed.has(PREFIX+"n39"),"road reveals new dead-end chest")
	check(map.travel.request_destination(PREFIX+"n39"),"walk down single chest branch")
	map.travel.advance(100);await settle()
	check(map.chest_observation_dialog.visible and map.event_state.active_id==event.id,"new chest arrival triggers observation")
	map._open_chest()
	var offer: Array=MapChestRewards.items(map.loadout,event)
	map._cancel_chest()
	check(map._try_start_event(PREFIX+"n39","click",true),"reopen at relocated chest")
	map._open_chest()
	check(MapChestRewards.items(map.loadout,event)==offer,"same reward id preserves rolled choices")
	map._cancel_chest()
	map.loadout.granted_rewards[event.reward_id]=true
	check(not map._try_start_event(PREFIX+"n39","click",true),"old claim receipt blocks duplicate reward at new position")
	check(map.travel.request_destination(PREFIX+"n14"),"branch permits return to road")
	map.travel.advance(100);await settle()
	check(map.travel.current_node_id==PREFIX+"n14" and not map.event_state.is_active(),"return road remains ordinary")
	map.queue_free();await settle()
	var layout: Node2D=load("res://scenes/maps/qingshihewan_layout.tscn").instantiate()
	root.add_child(layout);layout.scale=Vector2.ONE*1.7;layout.position=Vector2(-4000,-250)
	await settle()
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/qshw-riverbank-chest.png")
	layout.queue_free();await settle()
	for a in root.find_children("*","AudioStreamPlayer",true,false): a.stop();a.stream=null
	await settle()
	print("RIVERBANK CHEST: %d checks, %d failures; route/arrival/offer/receipt and static render; no mouse or real save."%[checks,failures])
	quit(1 if failures else 0)
