extends "res://tests/map_mining_tests.gd"

func animation_profile_path() -> String:
	return "res://data/ui/mining_options.json"

func animation_nodes() -> Array[String]:
	return ["n19", "n22"]

func animation_frame_counts() -> Array[int]:
	return [108, 142, 180]

func animation_label() -> String:
	return "MINING"

func check_no_shade(map: Node) -> void:
	check(map.gathering_animation.get_child_count() == 1 and map.gathering_animation.get_child(0) == map.gathering_animation.sprite, "playback contains only the actor, no full-screen shade")

func key(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		root.push_input(event, true)
	await settle()

func check_layout(map: Node) -> void:
	var view: MapGatheringAnimation = map.gathering_animation
	var sprite := view.sprite
	var source_feet := Vector2(view.character_rect.get_center().x, view.character_rect.end.y)
	var local_feet := source_feet - Vector2(180, 180)
	if sprite.flip_h: local_feet.x = -local_feet.x
	var feet := sprite.get_global_transform_with_canvas() * (sprite.offset + local_feet)
	var node_position: Vector2 = map.map_to_screen(map.travel.node_positions[map.travel.current_node_id])
	var expected: Vector2 = map.get_global_transform_with_canvas() * node_position
	check(feet.distance_to(expected) < 0.1, "mining feet stay on the actual path node")
	var actor_height := view.character_rect.size.y * sprite.get_global_transform_with_canvas().get_scale().y
	var walk_height: float = 266 * map.player.action_scale_in_canvas("walk").y
	check(absf(actor_height - walk_height) < 0.1, "visible height matches walking actor at current map zoom")

func run() -> void:
	create_timer(75).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0, true)
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(2560, 1440)
	MapEventState.session_completed.clear()
	save_path = "res://artifacts/" + animation_label().to_lower() + "-animation-%d.json" % Time.get_ticks_usec()
	var map := await new_map()
	if not map.startup_error.is_empty(): quit(1); return
	var options := MapGatheringOptions.new()
	check(options.load_options(animation_profile_path()).is_empty(), "mining options load")
	check((load(options.gathering_animation.texture) as Texture2D).get_image().has_mipmaps(), "mining sheet imported with mipmaps")
	var walk: Image = map.player.sprite_frames.get_frame_texture(&"walk", 0).get_image()
	var top := walk.get_height()
	var bottom := -1
	for y in walk.get_height():
		for x in walk.get_width():
			if walk.get_pixel(x, y).a >= 0.5:
				top = mini(top, y)
				bottom = maxi(bottom, y)
	check(bottom - top + 1 == int(options.gathering_animation.walk_visible_height), "height reference matches visible walking pixels")
	if DisplayServer.get_name() != "headless":
		await render_previews(map, options)
		await dispose_map(map)
		print("%s ANIMATION PREVIEW: %d checks, %d failures" % [animation_label(), checks, failures])
		quit(1 if failures else 0)
		return
	await dispose_map(map)
	for tier in 3:
		MapEventState.session_completed.clear()
		save_path = "res://artifacts/" + animation_label().to_lower() + "-animation-tier%d-%d.json" % [tier, Time.get_ticks_usec()]
		map = await new_map()
		await arrive(map, "base.map.qingshihewan.point." + animation_nodes()[tier % animation_nodes().size()])
		var event: Dictionary = map.event_state.active_event()
		var forecast := options.forecast(tier)
		var count: int = animation_frame_counts()[tier]
		check(forecast.days == [1, 2, 3][tier], "original day tier retained")
		var before: Dictionary = map.loadout.snapshot()
		var day := WorldCalendar.current_day(map.loadout.calendar)
		await click(map.gathering_dialog.action_buttons[tier])
		check(map.loadout.snapshot() == before and map.event_state.phase == "gathering", "selection alone does not commit")
		await click(map.gathering_dialog.action_buttons[tier])
		var started := Time.get_ticks_msec()
		var already_played: float = (map.gathering_animation.sprite.frame + map.gathering_animation.sprite.frame_progress) / 30.0
		check(map.event_state.phase == "gathering_animation" and map.travel.paused, "confirmed mine enters locked playback")
		check(not map.player.visible and not map.gathering_dialog.visible and not map.gathering_result.visible, "only mining actor shown at the node before reward")
		check_layout(map)
		check_no_shade(map)
		var view: MapGatheringAnimation = map.gathering_animation
		var frames := view.sprite.sprite_frames
		check(frames.get_frame_count(&"gathering") == count and frames.get_animation_speed(&"gathering") == 30.0 and not frames.get_animation_loop(&"gathering"), "correct exclusive playback length and rate")
		for i in count:
			var texture := frames.get_frame_texture(&"gathering", i) as AtlasTexture
			check(texture.region == Rect2((i % 15) * 360, (i / 15) * 360, 360, 360), "sequential atlas slice %d" % i)
		var committed: Dictionary = map.loadout.snapshot()
		var offer: Dictionary = MapGatheringRewards.pending(map.loadout, event)
		check(WorldCalendar.current_day(map.loadout.calendar) == day + forecast.days and not map.loadout.has_reward(offer.id), "time and pending result committed, inventory waits for claim")
		map._begin_gathering(forecast)
		map._accept_gathering()
		map._cancel_gathering()
		check(map.event_state.advance().is_empty(), "dialogue advance cannot finish mining")
		await key(KEY_ESCAPE)
		await key(KEY_SPACE)
		await key(KEY_I)
		await click(map, MOUSE_BUTTON_RIGHT)
		await click(map)
		await click(map, MOUSE_BUTTON_WHEEL_UP)
		check(map.event_state.phase == "gathering_animation" and map.loadout.snapshot() == committed and not map.is_inventory_open(), "playback input cannot skip, claim, move or charge twice")
		await wait_for_mining(map)
		var elapsed := already_played + (Time.get_ticks_msec() - started) / 1000.0
		check(absf(elapsed - count / 30.0) < 0.35, "real playback duration follows 30 FPS")
		check(view.sprite.frame == count - 1 and not view.visible and map.player.visible and map.gathering_result.visible, "inclusive last frame then result and original actor restored")
		check(map.loadout.snapshot() == committed, "animation completion makes no extra state change")
		print("%s TIMING: %d days, %d frames, %.3f seconds" % [animation_label(), forecast.days, count, elapsed])
		var invalid: Dictionary = committed.duplicate(true)
		invalid.gathering_offers[event.id].days = 99
		check(not map.loadout.restore(invalid).is_empty(), "unknown stored duration rejected")
		check(map.loadout.restore(committed).is_empty(), "original duration offer restores")
		map._accept_gathering()
		check(map.loadout.has_reward(offer.id), "result still claims through atomic inventory flow")
		await dispose_map(map)
	# Closing the app during playback leaves one persisted pending result, with no second charge/replay.
	MapEventState.session_completed.clear()
	save_path = "res://artifacts/" + animation_label().to_lower() + "-animation-interrupted-%d.json" % Time.get_ticks_usec()
	map = await new_map()
	await arrive(map, "base.map.qingshihewan.point." + animation_nodes()[0])
	map._begin_gathering(options.forecast(0))
	var saved: Dictionary = map.loadout.snapshot()
	await dispose_map(map)
	map = await new_map()
	await arrive(map, "base.map.qingshihewan.point." + animation_nodes()[0])
	check(map.event_state.phase == "gathering_reward" and not map.gathering_animation.visible and map.player.visible, "interrupted pending offer resumes directly at result")
	check(map.loadout.gathering_offers == saved.gathering_offers and map.loadout.calendar == saved.calendar, "restart preserves result and date")
	await dispose_map(map)
	stop_audio(root)
	print("%s ANIMATION FLOW: %d checks, %d failures" % [animation_label(), checks, failures])
	quit(1 if failures else 0)

func render_previews(map: Node, options: MapGatheringOptions) -> void:
	map.player.hide()
	var cases: Array = []
	for node in animation_nodes():
		cases.append([Vector2i(2560, 1440), 1.25, node])
		cases.append([Vector2i(1920, 1080), 1.75, node])
	for entry: Array in cases:
		root.size = entry[0]
		await settle()
		var point_id: String = "base.map.qingshihewan.point." + entry[2]
		map.travel.current_node_id = point_id
		map.travel.map_position = map.travel.node_positions[point_id]
		map._visit_exploration(point_id)
		map.player.present(map.travel)
		map._zoom_at(entry[1], map.size * 0.5)
		# Keep the event node visibly off-center to catch screen-center anchoring.
		map.content.position = map.map_viewport.size * Vector2(0.66, 0.6) - map.player.position * map.content.scale
		map._clamp_position()
		var camera_position: Vector2 = map.content.position
		var player_position: Vector2 = map.player.position
		check(map.gathering_animation.prepare(options, options.methods[2].id, map.player).is_empty(), "render animation prepared")
		map.gathering_animation.play_prepared()
		map.gathering_animation.sprite.pause()
		map.gathering_animation.sprite.frame = 80
		await settle()
		check_layout(map)
		check_no_shade(map)
		check(map.content.position == camera_position and map.player.position == player_position, "animation does not move camera or map player")
		check(map.map_to_screen(player_position).distance_to(map.size * 0.5) > 50, "preview node is not the viewport center")
		# Presentation-only pan, no mouse path or gameplay transaction is exercised.
		map.content.position += Vector2(-74, 23)
		await settle()
		check_layout(map)
		check_no_shade(map)
		await capture("res://artifacts/" + animation_label().to_lower() + "-node-%s-%d.png" % [entry[2], root.size.x])
	# Resize while visible must preserve the node anchor and map-relative scale.
	root.size = Vector2i(2560, 1440)
	await settle()
	check_layout(map)
