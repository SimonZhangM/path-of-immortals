extends SceneTree

const Capacity = preload("res://scripts/map/map_board_capacity.gd")

func _initialize() -> void: run.call_deferred()

func run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(640, 240)
	var backdrop := ColorRect.new()
	backdrop.color = Color("11212a")
	backdrop.size = Vector2(640, 240)
	root.add_child(backdrop)
	var capacity := Capacity.new()
	root.add_child(capacity)
	capacity.size = Vector2(capacity.texture.get_width() * 50.0 / capacity.texture.get_height(), 50)
	capacity.position = Vector2(40, 70)
	capacity.set_capacity(9, 30)
	assert(capacity.USED_COLOR == Color("b18b43"))
	assert(capacity.number_font.antialiasing == TextServer.FONT_ANTIALIASING_GRAY)
	assert(capacity.TOTAL_COLOR == Color("1f3f3b"))
	assert(capacity.texture.atlas.get_image().has_mipmaps())
	var center := capacity.number_center()
	capacity.set_capacity(30, 30)
	assert(capacity.number_center() == center)
	capacity.set_capacity(9, 30)
	for i in 8: await process_frame
	print("CAPACITY GEOMETRY: ", capacity.size, " source=", capacity.texture.atlas.get_size(), " region=", capacity.texture.region)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/map-capacity-outline.png")
	capacity.queue_free()
	backdrop.queue_free()
	for i in 3: await process_frame
	print("CAPACITY ART: native antialiased text, darker used number without outline, mipmaps and fixed slash passed")
	quit()
