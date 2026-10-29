extends SceneTree

const TOWN := "base.map.qingshizhen"
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func settle() -> void:
	for i in 6: await process_frame
func run() -> void:
	create_timer(35).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1920,1080)
	for entrance in ["n25","n04"]:
		var map = load("res://scenes/maps/qingshizhen.tscn").instantiate()
		map.inventory_save_path = ""
		map.defer_map_music = true
		map.defer_location_save = true
		map.defer_optional_views = true
		map.arrival_point_id = TOWN+".point."+entrance
		root.add_child(map)
		map.set_process(false)
		await settle()
		check(map.startup_error.is_empty(),"town starts from "+entrance)
		check(map.travel.current_node_id == map.arrival_point_id,"entry point preserved")
		check(map.loadout.map_visited[TOWN] == [map.arrival_point_id],"old empty ledger records only actual entry")
		check(map.exploration != null and map.travel.exploration_enabled,"progressive mode enabled")
		check(map.exploration.revealed.size()<30,"only initial frontier revealed")
		for point: MapRoutePoint in map.content.get_node("Points").get_children():
			check(point.visible == map.exploration.revealed.has(point.point_id),"nodes outside frontier hidden")
			if point.visible: check((point.material==null)==map.exploration.visited.has(point.point_id),"visited color and frontier grayscale match ledger")
		for edge: Dictionary in map.travel.adjacency[map.arrival_point_id]:
			check(map.exploration.revealed.has(edge.to) and map.exploration.full_routes.has(edge.id),"adjacent frontier has known connecting path")
		var snapshot: Dictionary = map.loadout.snapshot().duplicate(true)
		map.player.present(map.travel)
		map.content.position = map.map_viewport.size*0.5-map.travel.map_position*map.content.scale
		map._clamp_position()
		await settle()
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/town-frontier-%s.png" % entrance)
		check(map.loadout.snapshot()==snapshot,"preview does not change visit state")
		map.queue_free()
		await settle()
	print("TOWN EXPLORATION: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
