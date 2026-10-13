extends SceneTree

func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for i in 5: await process_frame
func run() -> void:
	create_timer(20).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(2560,1440)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	var river_rect := Rect2()
	for name_suffix in ["qingshihewan","qingshizhen"]:
		var map = load("res://scenes/maps/"+name_suffix+".tscn").instantiate()
		map.inventory_save_path = "res://artifacts/title-preview-%s-%d.json" % [name_suffix,Time.get_ticks_usec()]
		map.defer_map_music = true
		root.add_child(map)
		map.set_process(false)
		await settle()
		assert(map.startup_error.is_empty())
		var title: TextureRect = map.status_header.map_title
		assert(title.is_visible_in_tree())
		assert(title.mouse_filter==Control.MOUSE_FILTER_IGNORE)
		assert(title.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS)
		var atlas := title.texture as AtlasTexture
		assert(atlas.atlas.get_image().has_mipmaps())
		if name_suffix=="qingshihewan":
			river_rect = title.get_global_rect()
			assert(atlas.atlas.resource_path=="res://assets/map-title-qshw.webp")
			assert(title.position==Vector2(18,128) and title.size.is_equal_approx(Vector2(84.96,371.16)))
		else:
			assert(atlas.atlas.resource_path=="res://assets/map-title-qingshizhen.webp")
			assert(is_equal_approx(title.position.y,126.0))
			assert(is_equal_approx(title.get_global_rect().get_center().x,river_rect.get_center().x))
			assert(is_equal_approx(title.get_global_rect().size.y,river_rect.size.y))
			assert(absf(title.size.x/84.96-1.0)<0.15)
			assert(is_equal_approx(title.size.aspect(),atlas.region.size.aspect()))
			print("TITLE: river design 84.96x371.16; town ",title.size,"; source crop ",atlas.region)
			if DisplayServer.get_name()!="headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://artifacts/qingshizhen-title.png")
		map.queue_free()
		await settle()
	for node in root.find_children("*","AudioStreamPlayer",true,false):
		node.stop()
		node.stream=null
	await settle()
	print("MAP TITLE: matching height/axis; town up 2 design px; source aspect and mipmaps passed; no mouse or real save")
	quit()
