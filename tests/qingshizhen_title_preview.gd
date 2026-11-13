extends SceneTree

func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for i in 5: await process_frame
func run() -> void:
	create_timer(50).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0, true)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	for map_name: String in ["qingshihewan", "qingshizhen", "xiyuanyaopo", "wumingjiuci", "baishacun", "diecuifeng"]:
		var key := "qshw" if map_name == "qingshihewan" else map_name
		var expected := "res://assets/map-title-" + key + "-complete.webp"
		var map = load("res://scenes/maps/" + map_name + ".tscn").instantiate()
		map.inventory_save_path = ""
		map.defer_map_music = true
		root.add_child(map)
		map.set_process(false)
		await settle()
		assert(map.startup_error.is_empty(), map.startup_error)
		var title: TextureRect = map.status_header.map_title
		var atlas := title.texture as AtlasTexture
		assert(title.is_visible_in_tree())
		assert(title.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS)
		assert(atlas.atlas.resource_path == expected)
		assert(atlas.atlas.get_size() == Vector2(384, 1024))
		assert(atlas.atlas.get_image().has_mipmaps())
		assert(atlas.region == Rect2(atlas.atlas.get_image().get_used_rect()))
		assert(is_equal_approx(title.size.y, 371.16))
		assert(is_equal_approx(title.position.x + title.size.x * 0.5, 60.48))
		assert(is_equal_approx(title.position.y, 126.0 if map_name == "qingshizhen" else 128.0))
		assert(is_equal_approx(title.size.aspect(), atlas.region.size.aspect()))
		for dimensions: Vector2i in [Vector2i(1920, 1080), Vector2i(2560, 1440)]:
			root.size = dimensions
			await settle()
			var rect := title.get_global_rect()
			var factor := float(dimensions.x) / 1920.0
			assert(is_equal_approx(rect.size.y, 371.16 * factor))
			assert(is_equal_approx(rect.get_center().x, 60.48 * factor))
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://artifacts/plaque-v2-integration-20261113/%s-%d.png" % [map_name, dimensions.x])
			print("PLAQUE PASS: ", map_name, " ", dimensions, " ", rect)
		map.queue_free()
		await settle()
	for node in root.find_children("*", "AudioStreamPlayer", true, false):
		node.stop()
		node.stream = null
	await settle()
	print("PLAQUE V2: six maps, two resolutions; complete alpha crop, shared axis/height, mipmaps; no interaction or real saves")
	quit()
