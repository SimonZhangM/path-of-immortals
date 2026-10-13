extends SceneTree

func _initialize() -> void: run.call_deferred()

func run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(800,600)
	var layout = load("res://scenes/maps/qingshihewan_layout.tscn").instantiate()
	root.add_child(layout)
	var point: Node2D = layout.get_node("Points/N36")
	assert(point.position == Vector2(1193,1371))
	assert(point.point_id == "base.map.qingshihewan.point.n36")
	var icon: Sprite2D = point.get_node("Sign/EventIcon")
	var reference: Sprite2D = layout.get_node("Points/N31/Sign/EventIcon")
	assert(icon.texture == reference.texture)
	assert(icon.scale.is_equal_approx(reference.scale))
	assert(icon.texture.atlas.resource_path == "res://assets/map-zhiwu.webp")
	for name in ["N22", "N19"]:
		assert(layout.get_node("Points/%s/Sign/EventIcon" % name).texture.atlas.resource_path == "res://assets/map-kuangshi.webp")
	assert(layout.get_node("Points").get_child_count() == 38)
	assert(layout.get_node("Routes").get_child_count() == 41)
	layout.position = Vector2(400,360) - point.position
	for i in 5: await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/map-n36-herb.png")
	layout.queue_free()
	for i in 3: await process_frame
	print("N36 HERB: shared plant art/scale, unchanged point and remaining ore signs, topology passed")
	quit()
