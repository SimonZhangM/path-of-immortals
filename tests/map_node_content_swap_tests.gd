extends SceneTree

func _initialize() -> void: run.call_deferred()
func run() -> void:
	create_timer(30).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0, true)
	var map = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path = "res://artifacts/node-swap-%d.json" % Time.get_ticks_usec()
	map.defer_map_music = true
	root.add_child(map)
	map.set_process(false)
	for i in 8: await process_frame
	assert(map.startup_error.is_empty(), map.startup_error)
	var north: Node2D = map.content.get_node("Points/N08")
	var south: Node2D = map.content.get_node("Points/N22")
	assert(north.position == Vector2(1735, 117) and south.position == Vector2(1847, 833))
	assert(north.get_node("Sign/EventIcon").texture.atlas.resource_path == "res://assets/map-baoxiang.webp")
	assert(south.get_node("Sign/EventIcon").texture.atlas.resource_path == "res://assets/map-kuangshi.webp")
	assert(north.get_node("Sign/EventIcon").scale.is_equal_approx(Vector2.ONE * 0.695492023))
	assert(south.get_node("Sign/EventIcon").scale.is_equal_approx(Vector2.ONE * 0.628771324))
	var event_id := "base.map_event.qingshihewan.chest_n22"
	var reward_id := "base.map_reward.qingshihewan.chest_n22"
	assert(map.event_registry.by_point[north.point_id] == event_id)
	assert(not map.event_registry.by_point.has(south.point_id))
	var event: Dictionary = map.event_registry.events[event_id]
	assert(event.quality == "下品" and event.reward_id == reward_id)
	var state := MapEventState.new(map.event_registry, {})
	assert(state.try_start(north.point_id, north.point_id, true, "arrival"))
	assert(state.phase == "chest" and state.active_id == event_id)
	var claimed := MapEventState.new(map.event_registry, {})
	claimed.reward_claimed = func(id): return id == reward_id
	assert(not claimed.try_start(north.point_id, north.point_id, true, "arrival"))
	assert(not claimed.try_start(south.point_id, south.point_id, true, "arrival"))
	assert(map.content.get_node("Points").get_child_count() == 38)
	assert(map.content.get_node("Routes").get_child_count() == 41)
	map.queue_free()
	for i in 8: await process_frame
	print("NODE SWAP: actual map startup, icons/scales, unchanged positions/topology, N08 chest trigger and preserved reward identity passed")
	quit()
