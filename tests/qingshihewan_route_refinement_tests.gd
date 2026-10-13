extends SceneTree
const PREFIX := "base.map.qingshihewan.point."
var checks:=0
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)
func settle() -> void:
	for i in 6: await process_frame
func run() -> void:
	create_timer(40).timeout.connect(func():quit(2))
	AudioServer.set_bus_mute(0,true)
	root.size=Vector2i(2560,1440)
	var map=load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path=""
	map.defer_map_music=true
	root.add_child(map);map.set_process(false)
	await settle()
	check(map.startup_error.is_empty(), "actual map starts")
	check(map.travel.node_positions.size()==40,"40 unique nodes including new junction")
	check(map.content.get_node("Routes").get_child_count()==44,"44 route segments")
	check(map.travel.node_positions[PREFIX+"n08"].is_equal_approx(Vector2(1625,105)),"upper chest shifted")
	check(map.travel.node_positions[PREFIX+"n14"].is_equal_approx(Vector2(2851,503)),"road junction restored")
	for route: MapRoute in map.content.get_node("Routes").get_children():
		check(route._get_configuration_warnings().is_empty(),"valid route "+route.route_id)
		check(route.curve.get_point_position(0).is_equal_approx(route.get_node(route.start_point).position),"start matches "+route.route_id)
		check(route.curve.get_point_position(route.curve.point_count-1).is_equal_approx(route.get_node(route.end_point).position),"end matches "+route.route_id)
	for suffix in ["n08","n39"]:
		check(map.event_registry.events[map.event_registry.by_point[PREFIX+suffix]].type=="chest","chest keeps event")
	check(not map.event_registry.by_point.has(PREFIX+"n38"),"junction has no new event")
	check(map.event_registry.events[map.event_registry.by_point[PREFIX+"n28"]].title=="临溪石坡","branch reaches intended encounter")
	map.travel.current_node_id=PREFIX+"n36";map.travel.map_position=map.travel.node_positions[PREFIX+"n36"]
	map.travel.stop_at_current_node();map.player.position=map.travel.map_position
	map._visit_exploration(PREFIX+"n36")
	check(map.exploration.revealed.has(PREFIX+"n38"),"old herb visit discovers new fork")
	check(map.travel.request_destination(PREFIX+"n38"),"walk from herb to fork")
	map.travel.advance(100);await settle()
	check(map.travel.current_node_id==PREFIX+"n38" and not map.event_state.is_active(),"fork arrival has no event")
	check(map.exploration.revealed.has(PREFIX+"n28"),"fork reveals encounter")
	var path: Array=map.travel.shortest_path(PREFIX+"n36",PREFIX+"n28")
	check(path.size()==2 and path[0].id.ends_with("r42") and path[1].id.ends_with("r43"),"shortcut uses new branch instead of N29 detour")
	check(map.travel.request_destination(PREFIX+"n28"),"continue directly to encounter")
	map.travel.advance(100);await settle()
	check(map.travel.current_node_id==PREFIX+"n28" and map.encounter_dialog.visible,"arrival opens encounter")
	map._retreat_encounter()
	map.queue_free();await settle()
	# Static editor-style full-map preview only; no mouse interaction or saved exploration edits.
	var layout: Node2D=load("res://scenes/maps/qingshihewan_layout.tscn").instantiate()
	root.add_child(layout);layout.scale=Vector2.ONE*0.775;layout.position=Vector2(20,8)
	await settle()
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/qshw-route-refinement.png")
	layout.queue_free();await settle()
	for audio_node in root.find_children("*","AudioStreamPlayer",true,false): audio_node.stop();audio_node.stream=null
	await settle()
	print("ROUTE REFINEMENT: %d checks, %d failures; map startup, endpoints, chest identity, shortcut travel/exploration/encounter and static map. No mouse or player save."%[checks,failures])
	quit(1 if failures else 0)
