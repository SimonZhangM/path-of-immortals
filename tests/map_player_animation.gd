extends SceneTree

var checks := 0
var failures := 0
const SPECS := {
	"idle": {"count": 16, "columns": 4, "file": "stand16-spritesheet-4x4.webp", "cycle": 4.0 / 3.0, "ground": 316},
	"walk": {"count": 26, "columns": 6, "file": "walk26-spritesheet-6x5.webp", "cycle": 1.0, "ground": 314},
	"run": {"count": 16, "columns": 4, "file": "run16-spritesheet-4x4.webp", "cycle": 0.75, "ground": 315},
}

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var map = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path = ""
	root.add_child(map)
	for i in 8:
		await process_frame
	map.set_process(false)
	_check(map.startup_error.is_empty(), "map starts with replacement sheets")
	var player: MapPlayer = map.player
	_check(player.flip_h, "preserve initial facing left")
	_check(map.travel.walk_speed == 200 and map.travel.run_speed == 360, "world movement speeds unchanged")
	for action: String in SPECS:
		var spec: Dictionary = SPECS[action]
		var frames := player.sprite_frames
		_check(frames.get_frame_count(action) == spec.count, "exact frame count " + action)
		_check(frames.get_animation_loop(action), "loop enabled " + action)
		_check(is_equal_approx(spec.count / frames.get_animation_speed(action), spec.cycle), "preserve complete-cycle duration " + action)
		var sheet: Texture2D = load("res://assets/" + spec.file)
		var source := sheet.get_image()
		_check(source.has_mipmaps(), "mipmaps enabled " + action)
		for i in spec.count:
			var atlas: AtlasTexture = frames.get_frame_texture(action, i)
			var expected := Rect2((i % int(spec.columns)) * 360, (i / int(spec.columns)) * 360, 360, 360)
			_check(atlas.atlas == sheet and atlas.region == expected, "row-major source cell %s:%d" % [action, i + 1])
			_check(source.get_region(Rect2i(expected)).get_used_rect().has_area(), "no blank source frame %s:%d" % [action, i + 1])
		if action == "walk":
			for blank in range(26, 30):
				var region := Rect2i((blank % 6) * 360, (blank / 6) * 360, 360, 360)
				_check(not source.get_region(region).get_used_rect().has_area(), "last four walk slots are excluded transparent padding")
		player.play(action)
		player.set_frame_and_progress(0, 0)
		_check(is_equal_approx(player.scale.x, 0.4) and player.scale.is_equal_approx(Vector2.ONE * 0.4), "common actor scale " + action)
		_check(is_zero_approx((spec.ground - 180 + player.offset.y) * player.scale.y), "feet on node ground " + action)
		var observed := {0: true}
		var loops := [0]
		var changed := func(): observed[player.frame] = true
		var looped := func(): loops[0] += 1
		player.frame_changed.connect(changed)
		player.animation_looped.connect(looped)
		await create_timer(spec.cycle + 0.2).timeout
		player.frame_changed.disconnect(changed)
		player.animation_looped.disconnect(looped)
		_check(observed.size() == spec.count and loops[0] > 0, "actual playback visits every frame and loops " + action)
		player.pause()
		player.frame = 0
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/map_player_new_%s.png" % action)
	var points: Node2D = map.content.get_node("Points")
	map.travel.request_destination(points.get_node("N15").point_id)
	map.travel.advance(0.1)
	player.present(map.travel)
	_check(player.animation == &"walk", "adjacent destination selects new walk")
	map.travel.advance(1000)
	player.present(map.travel)
	_check(player.animation == &"idle", "arrival selects new stand")
	map.travel.request_destination(points.get_node("N01").point_id)
	map.travel.advance(0.1)
	player.present(map.travel)
	_check(player.animation == &"run", "long route selects new run")
	map.travel.advance(1000)
	player.present(map.travel)
	_check(player.animation == &"idle", "run arrival returns to new stand")
	map.queue_free()
	for i in 3:
		await process_frame
	print("MAP PLAYER ANIMATION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
