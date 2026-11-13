extends SceneTree
## Current-region anchors, partial location metadata and static rendering.
const PEAK := "base.map.diecuifeng"
const ROAD := "base.map.qinglanshandao"
const EXPECTED := {PEAK: Vector2(2591, 1613), ROAD: Vector2(2748, 1628)}
var checks := 0
var failures := 0
var output := "res://artifacts/world-map-mountains-20261112/run-%d" % Time.get_ticks_usec()

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	for i in range(4): await process_frame

func run() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
	DirAccess.make_dir_recursive_absolute(output)
	preload("res://scripts/entry/game_save_session.gd").index_path = output + "/session.json"
	root.get_node("SavePlaytime").set_process(false)
	root.get_node("GameSettings").apply_values({"background_pause": false, "background_mute": false})
	AudioServer.set_bus_mute(0, true)
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var map = load("res://scenes/maps/diecuifeng.tscn").instantiate()
	map.inventory_save_path = ""
	map.defer_map_music = true
	map.defer_location_save = true
	map.defer_optional_views = true
	root.add_child(map)
	map.set_process(false)
	await settle()
	check(map.startup_error.is_empty(), "actual peak scene starts with the expanded world catalog")
	if not map.startup_error.is_empty():
		quit(1)
		return
	var before: Dictionary = map.loadout.snapshot().duplicate(true)
	map.set_world_map_open(true)
	await settle()
	var view: Control = map.world_map
	check(view.player_location_id == "base.world_location.diecuifeng", "normal world-map entry identifies the current peak")
	check(view.location_marker.visible, "current peak pointer is visible")
	var navigation := preload("res://scripts/quests/quest_navigation.gd").new()
	check(navigation.definitions.has(PEAK) and not navigation.definitions.has(ROAD), "routing reads available map definitions")
	check(MapEventRegistry.encounter_at(PEAK + ".point.n02").get("type") == "encounter", "encounter catalog accepts the pending road entry")
	for dimensions: Vector2i in [Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		root.size = dimensions
		await settle()
		for current: String in [PEAK, ROAD]:
			view.present(current, {})
			await settle()
			var id: String = current.replace("base.map.", "base.world_location.")
			var marker: TextureRect = view.landmark_markers[id]
			check(view.player_world_position == EXPECTED[current], "registered source anchor " + current)
			check(view.player_location_id == id and view.selected_location_id == id, "current region owns pointer and selected location")
			check(marker.visible and view.location_marker.visible, "current location is visible without a legacy visit ledger")
			var center: Vector2 = view.map_image.position + EXPECTED[current] * view.zoom_levels[view.zoom_index]
			check(marker.get_rect().get_center().is_equal_approx(center), "landmark follows world-image transform")
			check(is_equal_approx(view.location_marker.get_rect().get_center().x, center.x + 0.5), "current-position pointer aligns with landmark")
			check(view.map_window.get_rect().size.y > marker.get_rect().get_center().y, "current landmark stays within the viewport")
			check(view.sidebar.picture.visible == (current == PEAK), "available peak artwork and pending road artwork display correctly")
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				var path := output + "/%s-%d.png" % [current.get_slice(".", 2), dimensions.x]
				root.get_texture().get_image().save_png(path)
				print("WORLD_LOCATION_CAPTURE ", path)
	view.present("base.map.qingshizhen", {})
	for current: String in [PEAK, ROAD]:
		var id: String = current.replace("base.map.", "base.world_location.")
		check(not view.landmark_markers[id].visible, "unvisited mountain region stays hidden")
	view.present("base.map.qingshizhen", {PEAK: [PEAK + ".point.n01"]})
	check(view.landmark_markers["base.world_location.diecuifeng"].visible, "existing peak visits discover the new marker")
	check(map.loadout.snapshot() == before, "world-map presentation preserves the player's state")
	map.deactivate_location()
	map.queue_free()
	await settle()
	print("WORLD MAP MOUNTAINS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
