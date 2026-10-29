extends SceneTree

const RIVER := "base.map.qingshihewan"
const TOWN := "base.map.qingshizhen"
var path := "res://artifacts/location-resume-%d.json" % Time.get_ticks_usec()
var checks := 0

func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		push_error(label)
		quit(1)
func settle() -> void:
	for i in 5: await process_frame
func disk() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))
func boot() -> Node:
	var entry = load("res://scenes/maps/session_start.tscn").instantiate()
	entry.inventory_save_path = path
	entry.defer_map_music = true
	root.add_child(entry)
	await settle()
	var map := current_scene
	check(map != null and map.startup_error.is_empty(), "session starts from isolated save")
	map.set_process(false)
	return map
func dispose(node: Node) -> void:
	node.queue_free()
	await settle()

func run() -> void:
	create_timer(50).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/maps/session_start.tscn", "F5 uses location-aware entry")
	var map := await boot()
	check(map.travel.current_node_id == RIVER+".point.east_exit", "new game uses default")
	check(disk().map_location.point_id == map.travel.current_node_id, "first location saved")
	check(map.travel.request_destination(RIVER+".point.n15"), "frontier reachable")
	map.travel.advance(100)
	check(disk().map_location.point_id == RIVER+".point.n15", "arrival saved immediately")
	var preserved: Dictionary = disk()
	map.travel.request_destination(RIVER+".point.east_exit")
	map.travel.advance(0.01)
	check(map.travel.mode != "idle", "mid-edge fixture")
	await dispose(map)
	map = await boot()
	check(map.travel.current_node_id == RIVER+".point.n15" and map.travel.mode == "idle", "restart restores last reached node, not half edge")
	check(map.player.position == map.travel.node_positions[RIVER+".point.n15"], "sprite restored with travel")
	check(map.exploration.visited.has(RIVER+".point.n15") and not map.event_state.is_active(), "exploration retained without replaying arrival event")
	check(disk().owned_units == preserved.owned_units and disk().map_visited == preserved.map_visited, "inventory and exploration survive restart")
	map.travel.request_destination(RIVER+".point.east_exit")
	map.travel.advance(100)
	check(map.is_exit_open() and disk().map_location.point_id == RIVER+".point.east_exit", "revisited node also saves")
	await map._complete_exit()
	await settle()
	map = current_scene
	map.set_process(false)
	check(map.definition.id == TOWN and disk().map_location.map_id == TOWN, "actual cross-map commit saves town")
	check(disk().map_visited.get(TOWN, []) == [TOWN+".point.n25"], "town arrival records one visited node, not all visible nodes")
	check(disk().map_visited[RIVER] == preserved.map_visited[RIVER], "town arrival preserves river visits")
	check(map.exploration != null and map.travel.exploration_enabled, "town uses progressive exploration")
	for point: MapRoutePoint in map.content.get_node("Points").get_children():
		check(point.visible == map.exploration.revealed.has(point.point_id), "town visibility follows visited-node frontier")
	check(map.exploration.revealed.size()<31, "unexplored town is not fully open")
	check(not map.is_exit_open(), "transition arrival does not immediately reopen exit")
	await dispose(map)
	map = await boot()
	check(map.definition.id == TOWN and map.travel.current_node_id == TOWN+".point.n25", "startup selects saved town, not fixed river scene")
	var town_neighbor := TOWN+".point.n24"
	check(not map.travel.request_destination(town_neighbor), "hidden town node cannot be selected before frontier is reached")
	check(map.travel.request_destination(TOWN+".point.n31"), "town frontier is reachable")
	map.travel.advance(0.01)
	check(disk().map_visited[TOWN] == [TOWN+".point.n25"], "mid-edge travel does not mark future nodes visited")
	map.travel.advance(100)
	check(map.exploration.revealed.has(town_neighbor), "town arrival reveals next node")
	check(map.travel.request_destination(town_neighbor), "newly revealed town node becomes reachable")
	map.travel.advance(100)
	check(disk().map_location.point_id == town_neighbor, "town saves each arrival")
	check(disk().map_visited[TOWN] == [TOWN+".point.n25", TOWN+".point.n31", town_neighbor], "town records intermediate and destination nodes without completing events")
	var town_visits: Dictionary = disk().map_visited.duplicate(true)
	var town_revision: int = map.loadout.revision
	map._visit_exploration(town_neighbor)
	map._visit_exploration(TOWN+".point.removed")
	check(map.loadout.revision == town_revision and disk().map_visited == town_visits, "duplicate and invalid visits do not change progress")
	await dispose(map)
	map = await boot()
	check(map.travel.current_node_id == town_neighbor and disk().map_visited == town_visits, "town restart preserves all recorded visits")
	# A legacy town checkpoint supplies the current arrival, not invented history.
	var old_town: Dictionary = map.loadout.snapshot()
	old_town.map_visited.erase(TOWN)
	check(map.loadout.restore(old_town).is_empty(), "legacy town save has no visit ledger")
	check(MapLoadoutStore.save(map.loadout,path).is_empty(), "write isolated legacy town save")
	map.deactivate_location()
	await dispose(map)
	map = await boot()
	check(disk().map_visited[TOWN] == [town_neighbor], "legacy town records restored checkpoint without granting default spawn or all nodes")
	check(disk().map_visited[RIVER] == town_visits[RIVER], "legacy town migration preserves other maps")
	var raw: Dictionary = map.loadout.snapshot()
	var bad := raw.duplicate(true)
	bad.map_location = {"map_id":TOWN,"point_id":RIVER+".point.n15"}
	check(not map.loadout.restore(bad).is_empty() and map.loadout.snapshot() == raw, "invalid location rejected atomically")
	var reward: Dictionary = map.loadout.reward_candidate({"id":"base.map_reward.location_test","item_id":"base.material.zhixuecao","quantity":1})
	check(reward.error.is_empty() and reward.state.map_location == raw.map_location, "reward candidate preserves location")
	var before := FileAccess.get_file_as_string(path)
	var pending = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	pending.inventory_save_path = path
	pending.defer_map_music = true
	pending.defer_location_save = true
	pending.arrival_point_id = RIVER+".point.east_exit"
	root.add_child(pending)
	pending.set_process(false)
	check(pending.travel.current_node_id == pending.arrival_point_id, "explicit arrival beats saved location")
	check(FileAccess.get_file_as_string(path) == before, "preloaded destination does not overwrite saved location")
	await dispose(pending)
	check(FileAccess.get_file_as_string(path) == before, "discarding preload does not save")
	# Exercise the exact entry/return transition paths with an isolated battle view.
	var battle := Control.new()
	root.add_child(battle)
	var audio := GameAudio.new()
	battle.add_child(audio)
	audio.music = AudioStreamPlayer.new()
	audio.add_child(audio.music)
	var presentation = root.get_node("MapPresentation")
	await presentation.change_battle_scene(map,battle,map,battle,true,audio)
	check(not map._location_active and disk().map_location == raw.map_location, "entering battle retains last map checkpoint")
	await dispose(map)
	var returned = load("res://scenes/maps/qingshizhen.tscn").instantiate()
	returned.inventory_save_path = path
	returned.defer_map_music = true
	returned.defer_location_save = true
	returned.arrival_point_id = town_neighbor
	root.add_child(returned)
	await presentation.change_battle_scene(battle,returned,battle,returned,false,audio)
	check(returned._location_active and disk().map_location.point_id == town_neighbor, "battle return activates checkpoint")
	await dispose(battle)
	map = returned
	map.set_process(false)
	# A save failure leaves the previous file intact; retry writes the new checkpoint.
	map.inventory_save_path = "res://artifacts/no-such-location-dir/state.json"
	map.travel.request_destination(TOWN+".point.n31")
	map.travel.advance(100)
	map.travel.request_destination(TOWN+".point.n25")
	map.travel.advance(100)
	check(not map.location_save_error.is_empty() and disk().map_location.point_id == town_neighbor, "save failure keeps previous file")
	map.inventory_save_path = path
	map._save_location()
	check(map.location_save_error.is_empty() and disk().map_location.point_id == TOWN+".point.n25", "save retry persists location")
	# Legacy snapshots have no checkpoint and retain the original entry point.
	var legacy: Dictionary = map.loadout.snapshot()
	legacy.erase("map_location")
	check(map.loadout.restore(legacy).is_empty() and map.loadout.map_location.is_empty(), "old saves remain compatible")
	check(MapLoadoutStore.save(map.loadout,path).is_empty(), "write isolated old save")
	map.deactivate_location()
	await dispose(map)
	map = await boot()
	check(map.definition.id == RIVER and map.travel.current_node_id == RIVER+".point.east_exit", "old save starts at original default")
	var obsolete: Dictionary = map.loadout.snapshot()
	obsolete.map_location = {"map_id":RIVER,"point_id":RIVER+".point.removed"}
	check(map.loadout.restore(obsolete).is_empty(), "obsolete point is structurally valid")
	MapLoadoutStore.save(map.loadout,path)
	map.deactivate_location()
	await dispose(map)
	map = await boot()
	check(map.travel.current_node_id == RIVER+".point.east_exit", "obsolete point safely falls back")
	map.loadout.set_map_location("base.map.removed", "base.map.removed.point.start")
	MapLoadoutStore.save(map.loadout,path)
	map.deactivate_location()
	await dispose(map)
	map = await boot()
	check(map.definition.id == RIVER and disk().map_location.map_id == RIVER, "unknown map safely falls back and repairs checkpoint")
	map.travel.request_destination(RIVER+".point.n15")
	map.travel.advance(100)
	await dispose(map)
	# Simulate interrupted atomic rename using only this test's unique save.
	if FileAccess.file_exists(path+".bak"): DirAccess.remove_absolute(path+".bak")
	check(DirAccess.rename_absolute(path,path+".bak") == OK, "isolated backup fixture")
	map = await boot()
	check(map.travel.current_node_id == RIVER+".point.n15" and FileAccess.file_exists(path), "backup location restored and primary recovered")
	await dispose(map)
	presentation.music.stop()
	presentation.music.stream = null
	await settle()
	print("MAP LOCATION: ",checks," checks passed; isolated files only")
	quit()
