extends "res://tests/clinic_dialog_tests.gd"

func run() -> void:
	create_timer(40).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(2560,1440)
	var map = load("res://scenes/maps/qingshizhen.tscn").instantiate()
	map.inventory_save_path = ""
	map.defer_map_music = true
	root.add_child(map)
	map.set_process(false)
	await settle()
	check(map.startup_error.is_empty(),"town loads updated clinic art")
	if not map.startup_error.is_empty(): quit(1); return
	map.travel.current_node_id = CLINIC_POINT
	map.travel.mode = "idle"
	map._try_start_event(CLINIC_POINT,"click",true)
	await settle()
	var dialog: MapClinicDialog = map.clinic_dialog
	check(dialog.illustration.texture.resource_path=="res://assets/tanchuang-qingshizhen-yiguan-boss.webp","new scene art")
	check(dialog.library.definition.portrait=="res://assets/UI-portrait-suqinghe.webp","same updated portrait path")
	var portrait: Texture2D = load(dialog.library.definition.portrait)
	check(portrait.get_image().has_mipmaps() and dialog.illustration.texture.get_image().has_mipmaps(),"both images have mipmaps")
	var bubble: DialogueBubble = dialog.dialogue_rows.get_child(0)
	check(bubble.portrait.texture==portrait,"actual welcome bubble uses updated portrait")
	var before: Dictionary = map.loadout.snapshot()
	var scene_rect: Rect2 = dialog.illustration.get_rect()
	for mode in ["conversation","treatment"]:
		dialog.set_mode(mode)
		await settle()
		check(dialog.illustration.get_rect()==scene_rect,"scene placement unchanged in "+mode)
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/clinic-art-"+mode+".png")
	check(map.loadout.snapshot()==before,"static views preserve state")
	map.queue_free()
	await settle()
	print("CLINIC ART: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
