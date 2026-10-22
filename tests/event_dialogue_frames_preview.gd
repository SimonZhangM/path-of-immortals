extends SceneTree

func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for i in 6: await process_frame

func run() -> void:
	create_timer(40).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0, true)
	root.content_scale_size = Vector2i.ZERO
	var map = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path = ""
	map.defer_map_music = true
	map.defer_location_save = true
	root.add_child(map)
	await settle()
	assert(map.startup_error.is_empty(), map.startup_error)
	var dialogue: MapDialogue = map.dialogue
	var event: Dictionary = map.event_registry.events["base.map_event.qingshihewan.wounded_disciple"]
	var source_frame := Image.load_from_file("res://assets/map-event-picframe.webp")
	for dimensions in [Vector2i(1920,1080), Vector2i(2560,1440)]:
		root.size = dimensions
		await settle()
		for index in [0,8,15]:
			dialogue.present(event, event.lines[index], event.line_speakers[index])
			await settle()
			assert(dialogue.background.texture.atlas.resource_path.ends_with("map-event-chatframe.webp"))
			assert(dialogue.picture.frame.texture.atlas.resource_path.ends_with("map-event-picframe.webp"))
			assert(dialogue.picture.frame.texture.region == Rect2(101,17,1471,907))
			# Updated art shifts inside its canvas; keep the previous on-screen frame geometry.
			var reference := MapEventPicture.new()
			reference.configure(dialogue.picture.frame.texture, dialogue.picture.illustration.texture, [60,91,1350,759])
			var unshifted_chat := dialogue.background.get_rect()
			var shift: float = 20.0 * dimensions.y / 1080.0
			unshifted_chat.position.y -= shift
			reference.layout_for(Vector2(dimensions), unshifted_chat)
			reference.position.y += shift
			assert(reference.get_rect().is_equal_approx(dialogue.picture.get_rect()))
			reference.free()
			var picture_scale := dialogue.picture.size.x / 1471.0
			assert(dialogue.picture.window.get_rect().is_equal_approx(Rect2(Vector2(62,91) * picture_scale, Vector2(1349,758) * picture_scale)))
			# Imported texture must reflect the updated source, not stale cached artwork.
			var imported_frame: Image = dialogue.picture.frame.texture.atlas.get_image()
			for point in [Vector2i(500,85), Vector2i(125,300), Vector2i(500,880), Vector2i(836,470)]:
				assert(imported_frame.get_pixelv(point).is_equal_approx(source_frame.get_pixelv(point)))
			assert(dialogue.next_marker.texture.resource_path.ends_with("map-event-chatframe-next.webp"))
			assert(dialogue.next_marker.texture.get_image().has_mipmaps())
			assert(dialogue.background.texture.atlas.get_image().has_mipmaps())
			assert(dialogue.picture.frame.texture.atlas.get_image().has_mipmaps())
			assert(is_equal_approx(dialogue.background.get_rect().get_center().x, dialogue.picture.get_rect().get_center().x))
			assert(is_equal_approx(dialogue.background.get_rect().get_center().y, dimensions.y * 0.75 + 20.0 * dimensions.y / 1080.0))
			assert(dialogue.picture.get_rect().end.y < dialogue.background.position.y)
			var scaled := dialogue.background.size.x / dialogue.background.texture.get_width()
			assert(dialogue.text_label.size.y <= float(event.presentation.text_rect[3]) * scaled + 1)
			assert(not dialogue.text_label.get_rect().intersects(dialogue.next_marker.get_rect()))
			assert(dialogue.speaker_name.get_rect().end.y < dialogue.text_label.position.y)
			assert(dialogue.speaker_name.text == (map.player_status.display_name if index == 15 else "青岚宗弟子"))
			if index == 15:
				assert(dialogue.portrait.texture.atlas == map.status_header.portrait.texture.atlas)
				assert(dialogue.portrait.texture.region == map.status_header.portrait.texture.region)
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://artifacts/event-frames-%d-line%d.png" % [dimensions.x,index])
		# Illustration-only stage keeps the dialogue contents hidden.
		dialogue.present(event, "", "", "illustration")
		assert(dialogue.picture.visible and not dialogue.speaker_name.visible and not dialogue.next_marker.visible)
		var bridge: Dictionary = map.event_registry.events["base.map_event.qingshihewan.bridge_traces"]
		dialogue.present(bridge, bridge.lines[0], bridge.speaker_id)
		assert(not dialogue.picture.visible and dialogue.speaker_name.text == map.player_status.display_name)
	map.queue_free()
	await settle()
	print("PASS: new picture/chat/next art, two resolutions, same horizontal center and +20 design px, player/NPC names, longest copy, illustration-only and bridge states. No mouse or save.")
	quit()
