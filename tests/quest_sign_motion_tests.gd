extends SceneTree
## Presentation-only checks: real layouts and runtime quest signs, without input or saves.
var checks := 0
var failures := 0
var output := "res://artifacts/quest-sign-motion-20261101"

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	AudioServer.set_bus_mute(0, true)
	DirAccess.make_dir_recursive_absolute(output)
	for path: String in ["res://scripts/map/map_quest_story_controller.gd", "res://scripts/map/map_river_story_controller.gd"]:
		check(load(path).can_instantiate(), "controller loads: " + path)
	var cases := {"qingshizhen": "n14", "qingshihewan": "n20", "wumingjiuci": "n31"}
	for dimensions: Vector2i in [Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		root.size = dimensions
		for map_name: String in cases:
			var viewport := Control.new()
			root.add_child(viewport)
			viewport.size = Vector2(dimensions)
			var layout = load("res://scenes/maps/%s_layout.tscn" % map_name).instantiate()
			viewport.add_child(layout)
			var points: Node = layout.get_node("Points")
			var motion := MapSignMotion.new()
			viewport.add_child(motion)
			check(motion.configure(points, viewport, "res://data/ui/map_sign_motion.json").is_empty(), "layout motion: " + map_name)
			motion.set_process(false)
			var count := motion.signs.size()
			var overlays = preload("res://scripts/map/map_quest_signs.gd").new()
			overlays.configure(points, motion)
			var id := "base.map.%s.point.%s" % [map_name, cases[map_name]]
			var wanted: Array[String] = [id]
			overlays.show_at(wanted)
			var overlay: Sprite2D = overlays.entries[id].overlay
			var entry: Dictionary = {}
			for candidate: Dictionary in motion.signs.values():
				if candidate.sign == overlay: entry = candidate
			check(not entry.is_empty() and motion.signs.size() == count + 1, "runtime sign registered: " + map_name)
			if entry.is_empty():
				viewport.free()
				continue
			check(entry.profile.period == 4.8 and entry.profile.sway_seconds == 1.1 and entry.profile.degrees == 10.0, "faster shared timing")
			layout.scale = Vector2.ONE * (float(dimensions.y) / 1080.0) * 1.5
			layout.position += viewport.size * 0.5 - overlay.global_position
			var point: Node2D = overlay.get_parent()
			var point_transform := point.global_transform
			var frame_transform := overlay.global_transform
			var dot_transform: Transform2D = entry.icon.global_transform
			var peak := acos(1.0 / sqrt(3.0)) / PI
			for fraction: float in [0.0, peak, 1.0 - peak, 1.0]:
				motion.elapsed = entry.profile.period - entry.profile.sway_seconds + entry.profile.sway_seconds * fraction - entry.phase
				motion.advance_visuals(0.0)
				check(point.global_transform == point_transform and overlay.global_transform == frame_transform, "node and frame stay fixed")
				check(entry.icon.global_transform == dot_transform, "red pivot dot stays fixed")
				if fraction == peak or fraction == 1.0 - peak:
					check(is_equal_approx(entry.symbol.rotation_degrees, 10.0 if fraction == peak else -10.0), "both sway extrema")
				else:
					check(is_zero_approx(entry.symbol.rotation), "returns to rest")
			motion.elapsed = entry.profile.period - entry.profile.sway_seconds + entry.profile.sway_seconds * peak - entry.phase
			motion.advance_visuals(0.0)
			var rotation: float = entry.symbol.rotation
			motion.set_suspended(true)
			motion.advance_visuals(0.2)
			check(entry.symbol.rotation == rotation, "shared suspension freezes overlay")
			motion.set_suspended(false)
			overlays.show_at(wanted)
			check(motion.signs.size() == count + 1 and overlays.entries[id].overlay == overlay, "refresh reuses registered split")
			if overlays.entries[id].original != null:
				check(not overlays.entries[id].original.visible, "authored sign hidden under quest overlay")
				motion.complete(id, false)
				check(overlay.visible and not entry.finished, "authored sign retirement leaves overlay intact")
			if DisplayServer.get_name() != "headless":
				await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(output + "/%s-%dx%d.png" % [map_name, dimensions.x, dimensions.y])
			overlays.show_at([])
			check(not overlay.visible, "task refresh hides overlay")
			overlays.show_at(wanted)
			check(overlay.visible and motion.signs.size() == count + 1, "restored overlay retains animation")
			viewport.free()
			await process_frame
	print("QUEST SIGN MOTION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
