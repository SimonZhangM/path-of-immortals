extends SceneTree
## Only first-entry visibility, hidden-location input and isolated save/reload.
const TOWN := "base.map.qingshizhen"
const SLOPE := "base.map.xiyuanyaopo"
var checks := 0
var failures := 0
var output := "res://artifacts/world-map-discovery-20261101/run-%d" % Time.get_ticks_usec()
var save_path: String

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func settle() -> void:
	for i in 4: await process_frame
func boot(scene_name: String, point_id: String = "") -> Control:
	var map = load("res://scenes/maps/%s.tscn" % scene_name).instantiate()
	map.inventory_save_path = save_path
	map.defer_map_music = true
	map.defer_location_save = true
	map.defer_optional_views = true
	map.arrival_point_id = point_id
	root.add_child(map)
	map.set_process(false)
	if map.quest_story_controller != null: map.quest_story_controller.set_process(false)
	if map.river_story_controller != null: map.river_story_controller.set_process(false)
	check(map.startup_error.is_empty(), "actual scene starts: " + scene_name + " " + map.startup_error)
	await settle()
	return map
func location_id(map_id: String) -> String:
	return map_id.replace("base.map.", "base.world_location.")
func visible_count(view: Control) -> int:
	var count := 0
	for marker: TextureRect in view.landmark_markers.values():
		if marker.visible: count += 1
	return count
func disk() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(save_path))
func render_views() -> void:
	var view = load("res://scripts/map/map_world_map.gd").new()
	root.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fixtures := [
		{"name": "town-only", "current": TOWN, "visited": {TOWN: [TOWN + ".point.n03"]}, "count": 1},
		{"name": "slope-entered", "current": SLOPE, "visited": {TOWN: [TOWN + ".point.n03"], SLOPE: [SLOPE + ".point.n01"]}, "count": 2}
	]
	for dimensions: Vector2i in [Vector2i(1920,1080), Vector2i(2560,1440)]:
		root.size = dimensions
		await settle()
		for fixture: Dictionary in fixtures:
			view.present(fixture.current, fixture.visited)
			await settle()
			check(visible_count(view) == fixture.count, "render discovered marker count")
			check(view.selected_location_id == location_id(fixture.current) and view.location_marker.visible, "render current location")
			for id: String in view.locations:
				if id not in [location_id(TOWN), location_id(SLOPE)]:
					check(not view.landmark_markers[id].visible, "render undiscovered location hidden")
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output + "/%s-%d.png" % [fixture.name, dimensions.x])
	view.queue_free()
	await settle()
func check_hidden_input(view: Control, id: String) -> void:
	var marker: TextureRect = view.landmark_markers[id]
	var point := marker.get_rect().get_center()
	var selected: String = view.selected_location_id
	check(not marker.visible and not view.is_location_discovered(id), "unvisited marker hidden: " + id)
	check(view.location_at(point).is_empty(), "unvisited location has no hit target")
	view._hover_location(point)
	check(view.map_window.tooltip_text.is_empty() and view.map_window.mouse_default_cursor_shape == Control.CURSOR_ARROW, "unvisited location has no tooltip or hand cursor")
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		view._map_input(event)
	check(view.selected_location_id == selected, "unvisited marker click cannot change details")
	view.select_location(id)
	check(view.selected_location_id == selected, "direct selection cannot reveal unvisited details")

func run() -> void:
	create_timer(50).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0, true)
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(output)
	if "--visual-only" in OS.get_cmdline_user_args():
		await render_views()
		print("WORLD MAP DISCOVERY VISUAL: %d checks, %d failures" % [checks, failures])
		quit(1 if failures else 0)
		return
	save_path = output + "/live_session.json"
	MapLoadoutStore.GameSaveSession.index_path = output + "/index.json"
	MapLoadoutStore.GameSaveSession.active_path = ""
	var map := await boot("qingshizhen", TOWN + ".point.n03")
	if not map.startup_error.is_empty(): quit(1); return
	map.activate_location()
	map.quest_story_controller.set_process(false)
	map.river_story_controller.set_process(false)
	check(map.location_save_error.is_empty() and disk().map_visited.keys() == [TOWN], "initial entry persists town only")
	map.set_world_map_open(true)
	await settle()
	var view: Control = map.world_map
	var town := location_id(TOWN)
	var slope := location_id(SLOPE)
	var snapshot: Dictionary = map.loadout.snapshot().duplicate(true)
	var saved_text := FileAccess.get_file_as_string(save_path)
	check(visible_count(view) == 1 and view.landmark_markers[town].visible, "fresh game shows town only")
	check(view.selected_location_id == town and view.location_marker.visible and view.selection_ring.visible, "current town pointer and details retained")
	for dimensions: Vector2i in [Vector2i(1920,1080), Vector2i(2560,1440)]:
		root.size = dimensions
		await settle()
		view.present(TOWN, map.loadout.map_visited)
		for id: String in view.locations:
			if id != town: check_hidden_input(view, id)
		view.show_quest_targets([{"map_id": SLOPE}], true)
		check(view.quest_markers.is_empty() and view.selected_location_id == town, "quest hint cannot mark or select an unvisited scene")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output + "/town-only-%d.png" % dimensions.x)
	check(map.loadout.snapshot() == snapshot and FileAccess.get_file_as_string(save_path) == saved_text, "browsing never grants visits or writes save")
	map.set_world_map_open(false)
	map.deactivate_location()
	map.hide()
	var destination := await boot("xiyuanyaopo")
	if not destination.startup_error.is_empty(): quit(1); return
	check(not disk().map_visited.has(SLOPE), "prepared scene does not discover location in saved state")
	destination.activate_location()
	destination.quest_story_controller.set_process(false)
	destination.river_story_controller.set_process(false)
	check(destination.location_save_error.is_empty() and disk().map_visited.get(SLOPE, []).size() == 1, "first activation saves just one arrival node")
	destination.set_world_map_open(true)
	await settle()
	view = destination.world_map
	check(visible_count(view) == 2 and view.landmark_markers[town].visible and view.landmark_markers[slope].visible, "first entry discovers slope without walking onward")
	check(view.selected_location_id == slope and view.location_marker.visible, "pointer follows actual entered scene")
	view.select_location(town)
	check(view.selected_location_id == town, "previously entered town stays selectable")
	view.show_quest_targets([{"map_id": SLOPE}], false)
	check(view.quest_markers.has(slope) and view.quest_markers[slope].visible, "visited task target remains available")
	for dimensions: Vector2i in [Vector2i(1920,1080), Vector2i(2560,1440)]:
		root.size = dimensions
		await settle()
		view.present(SLOPE, destination.loadout.map_visited)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output + "/slope-entered-%d.png" % dimensions.x)
	destination.deactivate_location()
	destination.queue_free()
	map.queue_free()
	await settle()
	map = await boot("qingshizhen", TOWN + ".point.n03")
	map.set_world_map_open(true)
	await settle()
	view = map.world_map
	check(visible_count(view) == 2 and view.landmark_markers[slope].visible, "scene discovery persists after return and reload")
	view.present(TOWN, {})
	check(visible_count(view) == 1 and view.landmark_markers[town].visible, "legacy ledger-free save shows current scene only")
	view.present(TOWN, {SLOPE: []})
	check(not view.landmark_markers[slope].visible, "empty ledger key does not imply a visit")
	view.present("", {})
	check(visible_count(view) == 0 and not view.selection_ring.visible and not view.location_marker.visible and not view.sidebar.visible, "unknown current scene does not expose a fallback location")
	map.queue_free()
	await settle()
	print("WORLD MAP DISCOVERY: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
