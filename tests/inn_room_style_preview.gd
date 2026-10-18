extends "res://tests/map_shop_tests.gd"

func run() -> void:
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(2560,1440)
	var map = load("res://scenes/maps/qingshizhen.tscn").instantiate()
	map.inventory_save_path = ""
	map.defer_map_music = true
	root.add_child(map)
	map.set_process(false)
	await settle()
	check(map.startup_error.is_empty(),"startup")
	if not map.startup_error.is_empty(): quit(1); return
	var before: Dictionary = map.loadout.snapshot()
	var event: Dictionary = map.event_registry.events["base.map_event.qingshizhen.inn"]
	var dialog: MapInnDialog = map.inn_dialog
	dialog.present(event,map.loadout,map.player_status)
	dialog.set_mode("lodging")
	var view := dialog.lodging_content
	for index in 2:
		view.select_room(event.lodging.rooms[index].id)
		await settle()
		for button in view.room_buttons:
			var rim := button.get_theme_stylebox("normal") as StyleBoxFlat
			check(rim!=null and rim.border_width_left>0,"both rooms have borders")
			check(button.get_theme_color("font_color")==button.get_theme_color("font_hover_color"),"hover font stays unchanged")
			check(button.get_theme_stylebox("normal")==button.get_theme_stylebox("hover"),"hover retains the room border")
			check(absf(button.get_global_rect().get_center().y-view.room_title.get_global_rect().get_center().y)<0.1,"room title shares horizontal centerline")
		var selected: StyleBoxFlat = view.room_buttons[index].get_theme_stylebox("normal")
		var category: StyleBoxFlat = dialog.lodging_tab.get_theme_stylebox("normal")
		check(selected.bg_color==category.bg_color and selected.border_color==category.border_color and selected.shadow_size==category.shadow_size and selected.shadow_color==category.shadow_color and selected.border_width_left==category.border_width_left,"selected highlight matches main category")
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/inn-room-style-%d.png" % index)
	check(before==map.loadout.snapshot(),"static preview does not alter state")
	map.queue_free()
	await settle()
	print("INN ROOM STYLE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
