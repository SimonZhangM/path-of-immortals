extends SceneTree

const N37 := "base.map.qingshihewan.point.n37"
const BRIDGE := "base.map_event.qingshihewan.bridge_traces"
var checks := 0
var failures := 0
var map: Control

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func settle() -> void:
	for frame in 5:
		await process_frame

func load_map() -> void:
	map = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path = ""
	root.add_child(map)
	current_scene = map
	map.set_process(false)
	await settle()
	check(map.startup_error.is_empty(), "river initializes with motion")
	map.sign_motion.set_process(false)

func focus(sign: Sprite2D) -> void:
	map.content.position += map.map_viewport.size * 0.5 - map.map_viewport.get_global_transform().affine_inverse() * sign.global_position

func _run() -> void:
	MapEventState.session_completed.clear()
	root.size = Vector2i(1920, 1080)
	await load_map()
	var motion: MapSignMotion = map.sign_motion
	check(motion.signs.size() == 30, "all 30 signs registered")
	var counts := {}
	var phases := {}
	for id: String in motion.signs:
		var entry: Dictionary = motion.signs[id]
		counts[entry.category] = int(counts.get(entry.category, 0)) + 1
		phases[id] = entry.phase
		var sign: Sprite2D = entry.sign
		var point: Sprite2D = sign.get_parent()
		var point_position := point.position
		var point_scale := point.scale
		var point_tint := point.modulate
		var sign_scale: Vector2 = entry.scale
		var child_position: Vector2 = entry.icon.position
		var dot_transform: Transform2D = entry.icon.global_transform
		focus(sign)
		dot_transform = entry.icon.global_transform
		for fraction in [0.0, 0.25, 0.5, 0.75]:
			motion.elapsed = entry.profile.period * fraction - entry.phase
			motion.advance_visuals(0)
			check(point.position == point_position and point.scale == point_scale and point.modulate == point_tint, "route point stable " + id)
			check(entry.icon.position == child_position, "authored child alignment stable " + id)
			check(is_equal_approx(entry.icon.self_modulate.a, entry.tint.a), "icon alpha preserved " + id)
			if entry.profile.mode == "scale":
				var ratio := sign.scale.x / sign_scale.x
				check(ratio >= 1.0 - 0.00001 and ratio <= entry.profile.maximum_scale + 0.00001 and sign.scale.is_equal_approx(sign_scale * ratio) and sign.position == entry.position, "battle scales uniformly around fixed center " + id)
			else:
				check(sign.scale == sign_scale, "non-battle frame size fixed " + id)
			if entry.profile.mode in ["breathe", "frame_breathe"]:
				var tint: Color = sign.self_modulate if entry.profile.mode == "frame_breathe" else entry.icon.self_modulate
				check(sign.position == entry.position and tint.r >= entry.profile.minimum - 0.00001 and tint.r <= 1.0 and is_equal_approx(tint.a, 1.0), "RGB breathing preserves geometry/alpha " + id)
			if entry.profile.mode != "breathe":
				check(entry.icon.self_modulate == entry.tint, "icon brightness unchanged " + id)
			if entry.profile.mode != "frame_breathe":
				check(sign.self_modulate == entry.frame_tint, "frame brightness unchanged " + id)
		if entry.profile.mode == "sway":
			motion.elapsed = 3.0 - entry.phase
			motion.advance_visuals(0)
			check(is_zero_approx(entry.symbol.rotation), "story quiet interval")
			var peak := acos(1.0 / sqrt(3.0)) / PI
			for swing_fraction in [peak, 1.0 - peak]:
				motion.elapsed = entry.profile.period - entry.profile.sway_seconds + entry.profile.sway_seconds * swing_fraction - entry.phase
				motion.advance_visuals(0)
				check(absf(entry.symbol.rotation_degrees) > 9.9 and signf(entry.symbol.rotation) == (1.0 if swing_fraction < 0.5 else -1.0), "story swings in both directions")
				check(entry.icon.global_transform == dot_transform, "story dot remains stationary during swing")
	check(counts == {"battle":11, "opportunity":10, "rest":3, "story":4, "location":2}, "five authored categories")
	check(phases.values()[0] != phases.values()[1], "stable phases are staggered")
	var floating: Dictionary = motion.signs["base.map.qingshihewan.point.n04"]
	for dimensions in [Vector2i(1920,1080), Vector2i(1280,720)]:
		root.size = dimensions
		await settle()
		for zoom in [1.0, 1.75]:
			map.zoom_factor = zoom
			map._fit_map()
			focus(floating.sign)
			for fraction in [0.25, 0.75]:
				motion.elapsed = floating.profile.period * fraction - floating.phase
				motion.advance_visuals(0)
				var offset: Vector2 = floating.sign.get_parent().get_screen_transform().basis_xform(floating.sign.position - floating.position)
				check(is_equal_approx(absf(offset.y), 1.2) and absf(offset.x) < 0.001, "float stays 1.2 physical pixels across zoom/viewport: %s" % str(offset))
	var before := motion.elapsed
	map.inventory_screen.show()
	motion.advance_visuals(2)
	check(motion.suspended and motion.elapsed == before, "inventory cover pauses idle")
	map.inventory_screen.hide()
	check(not motion.suspended, "closing cover resumes idle")
	Engine.time_scale = 8
	motion._last_tick_usec = Time.get_ticks_usec() - 50000
	motion._process(999.0)
	check(motion.elapsed - before > 0.045 and motion.elapsed - before < 0.09, "visual time ignores supplied/scaled delta")
	Engine.time_scale = 1
	var story: Dictionary = motion.signs[N37]
	focus(story.sign)
	map.travel.request_destination(N37)
	map.travel.advance(1000)
	check(map.event_state.active_id == BRIDGE, "arrival still starts existing story")
	while map.event_state.is_active():
		map._advance_dialogue()
	check(map.event_state.completed.has(BRIDGE) and story.finished and story.fading, "authoritative completion precedes fade")
	check(not map.event_state.try_start(N37, N37, true, "arrival"), "completed event cannot restart during fade")
	var pose: Vector2 = story.sign.position
	var icon_color: Color = story.icon.self_modulate
	motion.advance_visuals(0.15)
	check(story.sign.visible and is_equal_approx(story.sign.modulate.a, 0.5), "halfway fade alpha")
	check(story.sign.position == pose and story.icon.self_modulate == icon_color, "fade freezes idle")
	motion.advance_visuals(0.15)
	check(not story.sign.visible and story.sign.get_parent().visible, "only sign disappears at 0.3 seconds")
	map.queue_free()
	await settle()
	await load_map()
	check(not map.sign_motion.signs[N37].sign.visible, "map reentry restores completed sign hidden")
	check(map.sign_motion.signs[N37].phase == phases[N37], "phase stable on reentry")
	map.queue_free()
	await settle()
	var town = load("res://scenes/maps/qingshizhen.tscn").instantiate()
	town.inventory_save_path = ""
	root.add_child(town)
	check(town.startup_error.is_empty() and town.sign_motion != null, "town initializes with shared motion")
	if town.sign_motion != null:
		check(town.sign_motion.signs.size() == 20, "all 20 town signs registered")
	town.queue_free()
	await settle()
	MapEventState.session_completed.clear()
	print("Map sign motion: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
