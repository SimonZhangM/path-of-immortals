extends SceneTree

var checks := 0
var failures := 0
var save_path := "res://artifacts/sign-restore-%d.json" % Time.get_ticks_usec()
var completed_events: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func new_map() -> Node:
	var map: Node = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path = save_path
	map.defer_map_music = true
	map.defer_location_save = true
	root.add_child(map)
	map.set_process(false)
	check(map.startup_error.is_empty(), "map startup: " + map.startup_error)
	map.sign_motion.set_process(false)
	return map

func check_hidden(map: Node, stage: String) -> void:
	for event: Dictionary in completed_events:
		var entry: Dictionary = map.sign_motion.signs[event.point_id]
		check(map.event_state.completed.has(event.id) and entry.finished and not entry.fading and not entry.sign.visible, stage + ": " + event.id)

func _run() -> void:
	create_timer(55).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(2560, 1440)
	MapEventState.session_completed.clear()
	MapEventState.session_encounters.clear()
	var map := new_map()
	var raw: Dictionary = map.loadout.snapshot()
	var today := WorldCalendar.current_day(raw.calendar)
	raw.encounter_cooldowns = {}
	raw.chest_cooldowns = {}
	raw.granted_rewards = {}
	var chest_count := 0
	for event: Dictionary in map.event_registry.events.values():
		if event.type == "encounter":
			raw.encounter_cooldowns[event.id] = today + 20
			completed_events.append(event)
		elif event.type == "chest":
			chest_count += 1
			var cycle := 1 if chest_count % 2 else 2
			var grant := {"item_id": "base.map_item.qingshi_short_sword", "quantity": 1}
			raw.granted_rewards[event.reward_id] = grant
			if cycle == 2:
				raw.granted_rewards[event.reward_id + ".cycle.2"] = grant
			raw.chest_cooldowns[event.reward_id] = {"delay_days": 40, "remaining_days": 40, "ready_day": today + 40, "cycle": cycle}
			completed_events.append(event)
	check(completed_events.size() == 16, "eleven enemies and five chests covered")
	check(map.loadout.restore(raw).is_empty(), "isolated cooldown fixture valid")
	check(MapLoadoutStore.save(map.loadout, save_path).is_empty(), "save isolated restart fixture")
	map.queue_free()
	await process_frame
	# A real process restart has no shared in-memory completion flags.
	MapEventState.session_completed.clear()
	MapEventState.session_encounters.clear()
	map = new_map()
	check_hidden(map, "before first frame after fresh restart")
	for frame in 3:
		await process_frame
		map.sign_motion.advance_visuals(0.016)
		check_hidden(map, "startup frame %d" % frame)
	for event: Dictionary in map.event_registry.events.values():
		if event.type in ["rest", "gathering"]:
			check(map.sign_motion.signs[event.point_id].sign.visible, "uncompleted rest/gathering still available")
	map.queue_free()
	await process_frame
	map = new_map()
	check_hidden(map, "same-session reentry before first frame")
	check(map.loadout.advance_days(20, "base.test.sign_restore").is_empty(), "advance to enemy respawn")
	map._sync_calendar()
	for event: Dictionary in completed_events:
		var entry: Dictionary = map.sign_motion.signs[event.point_id]
		check(entry.sign.visible == (event.type == "encounter"), "day twenty visibility: " + event.id)
	check(map.loadout.advance_days(20, "base.test.sign_restore").is_empty(), "advance to chest reopening")
	map._sync_calendar()
	for event: Dictionary in completed_events:
		check(map.sign_motion.signs[event.point_id].sign.visible, "day forty restored: " + event.id)
	# An immediate state sync must also finish an already-started fade.
	var entry: Dictionary = map.sign_motion.signs[completed_events[0].point_id]
	entry.sign.get_parent().show()
	map.content.position += map.map_viewport.size * 0.5 - map.map_viewport.get_global_transform().affine_inverse() * entry.sign.global_position
	map.sign_motion.complete(completed_events[0].point_id, true)
	check(entry.fading and entry.sign.visible, "live completion still animates")
	map.sign_motion.advance_visuals(0.15)
	check(is_equal_approx(entry.sign.modulate.a, 0.5), "live fade reaches half opacity")
	map.sign_motion.complete(completed_events[0].point_id, false)
	check(not entry.fading and not entry.sign.visible and entry.sign.get_parent().visible, "immediate sync finishes fade without hiding route point")
	map.queue_free()
	await process_frame
	# Persisted expired deadlines must also restore correctly in a fresh process.
	check(WorldCalendar.advance(raw.calendar, 40, "base.test.sign_restore").is_empty(), "expired saved calendar")
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(raw))
	file.close()
	MapEventState.session_completed.clear()
	MapEventState.session_encounters.clear()
	map = new_map()
	for event: Dictionary in completed_events:
		check(map.sign_motion.signs[event.point_id].sign.visible and not map.event_state.completed.has(event.id), "expired restart visible: " + event.id)
	map.queue_free()
	await process_frame
	MapEventState.session_completed.clear()
	MapEventState.session_encounters.clear()
	print("Map sign restore: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
