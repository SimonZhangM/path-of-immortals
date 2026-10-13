extends "res://tests/map_shop_tests.gd"

func run() -> void:
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(2560,1440)
	var original := MapExitDialog.new()
	for scene in ["qingshihewan","qingshizhen"]:
		var map = load("res://scenes/maps/%s.tscn" % scene).instantiate()
		map.inventory_save_path = ""
		map.defer_map_music = true
		root.add_child(map)
		map.set_process(false)
		await settle()
		check(map.startup_error.is_empty(),"map ready: "+scene)
		if not map.startup_error.is_empty(): map.queue_free(); continue
		var before: Dictionary = map.loadout.snapshot()
		var modal: MapExitDialog = map.exit_dialog
		modal.present("前往 青石镇" if scene=="qingshihewan" else "前往 青石河湾")
		await settle()
		var atlas := modal.backing.texture as AtlasTexture
		check(atlas.atlas.resource_path.ends_with("UI-jiaohu-size-m.webp"),"map exit uses medium artwork")
		check(atlas.atlas.get_image().has_mipmaps(),"new background mipmaps")
		check(is_equal_approx(modal.backing.size.y,original.backing.size.y),"new and old backgrounds same height")
		check(is_equal_approx(modal.backing.size.x/modal.backing.size.y,atlas.get_width()/float(atlas.get_height())),"new artwork keeps aspect ratio")
		check(modal.backing.get_rect().get_center().is_equal_approx(MapExitDialog.DESIGN_SIZE*0.5),"expanded art centered on original dialog")
		check(modal.backing.get_global_rect().get_center().distance_to(Vector2(root.size)*0.5)<0.01,"visible dialog remains screen centered")
		var divider_y: float = (185-atlas.region.position.y)*modal.backing.size.y/atlas.get_height()
		check(modal.heading.get_rect().end.y<divider_y,"title clears new upper divider")
		for pair in [[modal.confirm_button,original.confirm_button],[modal.cancel_button,original.cancel_button]]:
			check(pair[0].get_rect()==pair[1].get_rect(),"action size and position unchanged")
			check(pair[0].texture_normal.resource_path==pair[1].texture_normal.resource_path,"original action artwork retained")
			check(pair[0].get_node("Caption").text==pair[1].get_node("Caption").text,"original action caption retained")
		check(modal.confirm_button.position.x<modal.cancel_button.position.x,"left confirm right cancel")
		check(modal.confirm_button.pressed.has_connections() and modal.cancel_button.pressed.has_connections(),"existing action callbacks remain connected")
		check(map.inventory_screen.board_change_dialog.backing.texture.atlas.resource_path.ends_with("UI-jiaohu-size0.webp"),"board confirmation retains old artwork")
		check(modal.message.position.y==original.message.position.y,"message vertical layout unchanged")
		check(map.loadout.snapshot()==before,"visual preview does not change save data")
		print("EXIT ART ",scene," region ",atlas.region," design size ",modal.backing.size)
		if scene=="qingshihewan" and DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/map-exit-medium.png")
		map.queue_free()
		await settle()
	original.free()
	print("MAP EXIT ART: %d checks, %d failures; static only" % [checks,failures])
	quit(1 if failures else 0)
