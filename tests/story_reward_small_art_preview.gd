extends SceneTree

func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for i in 6: await process_frame

func run() -> void:
	create_timer(35).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0, true)
	root.content_scale_size = Vector2i.ZERO
	var map = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path = ""
	map.defer_map_music = true
	map.defer_location_save = true
	root.add_child(map)
	await settle()
	assert(map.startup_error.is_empty(), map.startup_error)
	var modal: MapRewardDialog = map.reward_dialog
	var record: Dictionary = map.loadout.records["base.map_item.warm_jade"].duplicate(true)
	record.quantity = 1
	modal.present(record, "法器")
	var medium: MapExitDialog = map.exit_dialog
	for dimensions in [Vector2i(1920,1080), Vector2i(2560,1440)]:
		root.size = dimensions
		await settle()
		var art := modal.backing.texture as AtlasTexture
		assert(art.atlas.resource_path.ends_with("UI-jiaohu-size-s.webp"))
		assert(art.atlas.get_image().has_mipmaps())
		assert(is_equal_approx(modal.backing.get_global_rect().size.y, medium.backing.get_global_rect().size.y))
		assert(is_equal_approx(modal.backing.size.aspect(), art.get_size().aspect()))
		assert(modal.heading.text == "获得物品" and modal.heading.get_theme_font_size("font_size") == 32)
		assert(is_equal_approx(modal.card.size.x, 152.0))
		assert(modal.accept_button.size.is_equal_approx(MapRewardDialog.ACTION_SIZE))
		assert(modal.accept_button.texture_normal.resource_path.ends_with("button-queren.webp"))
		assert(modal.accept_button.get_node("AcceptCaption").text == "收下")
		assert(modal.heading.get_rect().end.y < modal.card.position.y)
		assert(modal.card.get_rect().end.y + modal.card.quality_badge.size.y * 0.5 < modal.accept_button.position.y)
		assert(modal.backing.get_global_rect().encloses(modal.accept_button.get_global_rect()))
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/story-reward-small-%d.png" % dimensions.x)
	for path in ["res://scripts/map/map_gathering_result_dialog.gd"]:
		var other = load(path).new()
		assert(other.backing.texture.atlas.resource_path.ends_with("UI-jiaohu-size1.webp"))
		assert(other._display_height == 540.0)
		other.free()
	map.queue_free()
	await settle()
	print("PASS: story reward small art matches medium visible height at 1080p/1440p, keeps aspect and components, no overlaps; gathering unchanged. No mouse or save.")
	quit()
