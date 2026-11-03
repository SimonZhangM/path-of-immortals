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
		assert(modal.card.get_rect().end.y < modal.accept_button.position.y)
		var factor := MapRewardDialog.DESIGN_SIZE.y / art.get_height()
		var old_title_y := modal.backing.position.y + (105.0-art.region.position.y)*factor-modal.heading.size.y*0.5
		assert(is_equal_approx(modal.heading.position.y,old_title_y+5.0))
		assert(is_equal_approx(modal.card.name_label.position.y-modal.card.square.get_rect().end.y,17.0))
		assert(modal.backing.get_global_rect().encloses(modal.accept_button.get_global_rect()))
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/story-reward-small-%d.png" % dimensions.x)
		modal.present(record,"法器",true)
		await settle()
		assert(modal.heading.text=="交出" and modal.accept_button.get_node("AcceptCaption").text=="确认")
		assert(is_equal_approx(modal.heading.position.y,old_title_y+5.0))
		assert(is_equal_approx(modal.card.name_label.position.y-modal.card.square.get_rect().end.y,17.0))
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/handover-shared-offset-%d.png"%dimensions.x)
		modal.hide()
		for script in ["res://scripts/map/map_gathering_result_dialog.gd","res://scripts/ui/battle_reward_dialog.gd"]:
			var variant = load(script).new()
			root.add_child(variant)
			variant.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			if variant.has_method("present_loot"):
				var loot: Array[Dictionary] = [record]
				variant.present_loot(loot,{})
			else:
				variant.present_herb(map.loadout.records["base.material.zhixuecao"],map.loadout)
			await settle()
			assert(is_equal_approx(variant.heading.position.y,modal.heading.position.y))
			var tile: Control = variant.grid.get_child(0) if variant.has_method("present_loot") else variant.card
			assert(is_equal_approx(tile.name_label.position.y-tile.square.get_rect().end.y,17.0))
			assert(tile.name_label.get_global_rect().end.y<variant.accept_button.get_global_rect().position.y)
			if DisplayServer.get_name()!="headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://artifacts/%s-shared-offset-%d.png"%[variant.name,dimensions.x])
			variant.free()
		modal.present(record,"法器")
	for path in ["res://scripts/map/map_gathering_result_dialog.gd"]:
		var other = load(path).new()
		assert(other.backing.texture.atlas.resource_path.ends_with("UI-jiaohu-size-s.webp"))
		assert(other._display_height == MapExitDialog.DESIGN_SIZE.y)
		other.free()
	map.queue_free()
	await settle()
	print("PASS: shared reward/handover/gathering/battle heading +5 and item name +10 at 1080p/1440p; no doubled battle offsets or overlaps. No mouse or save.")
	quit()
