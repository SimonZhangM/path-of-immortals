extends "res://tests/item_selection_tooltip_tests.gd"
const WAREHOUSE := "base.warehouse.qingshizhen.home"

func solid_bounds(texture: Texture2D) -> Rect2:
	var source := texture.get_image()
	var minimum := source.get_size()
	var maximum := Vector2i.ZERO
	for y in source.get_height():
		for x in source.get_width():
			if source.get_pixel(x,y).a < 0.5: continue
			minimum = minimum.min(Vector2i(x,y))
			maximum = maximum.max(Vector2i(x,y)+Vector2i.ONE)
	return Rect2(minimum,maximum-minimum)

func rendered_solid(control: Control, texture: Texture2D) -> Rect2:
	var factor := minf(control.size.x/texture.get_width(),control.size.y/texture.get_height())
	var offset := (control.size-texture.get_size()*factor)*0.5
	var solid := solid_bounds(texture)
	return control.get_global_transform() * Rect2(offset+solid.position*factor,solid.size*factor)

func run() -> void:
	create_timer(40).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(2560,1440)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	var map = load("res://scenes/maps/qingshizhen.tscn").instantiate()
	map.inventory_save_path = ""
	map.defer_map_music = true
	root.add_child(map)
	map.set_process(false)
	await settle()
	check(map.startup_error.is_empty(),"map ready")
	var ui: MapInventoryScreen = map.inventory_screen
	ui.set_warehouse(WAREHOUSE)
	ui.show()
	await settle()
	var before: Dictionary = map.loadout.snapshot()
	var actions = ui.warehouse_actions
	# Static presentation fixture: make all four equally bright for comparison.
	actions.set_available(true,true,true,true)
	var buttons := [actions.withdraw_button,actions.withdraw_all_button,actions.deposit_button,actions.deposit_all_button]
	var rects: Array[Rect2] = []
	for button: TextureButton in buttons:
		check(button.stretch_mode==TextureButton.STRETCH_KEEP_ASPECT_CENTERED,"source aspect preserved")
		check((button.texture_normal as AtlasTexture).atlas.get_image().has_mipmaps(),"mipmap retained")
		rects.append(rendered_solid(button,button.texture_normal))
	for rect in rects:
		check(absf(rect.size.x-rects[1].size.x)<1.0 and absf(rect.size.y-rects[1].size.y)<1.0,"visible frame matches within one screen pixel")
	var left := ui.warehouse_pane.storage_panel.get_global_rect()
	var right := ui.storage_panel.get_global_rect()
	check(absf((rects[1].position.x-rects[0].end.x)-(rects[3].position.x-rects[2].end.x))<1.5,"visual pair gaps equal")
	check(absf((left.end.x-rects[1].end.x)-(rects[2].position.x-right.position.x))<1.5,"both inner visible edge gaps equal")
	var sign_rect := rendered_solid(actions.direction_art,actions.direction_art.texture)
	check(absf(sign_rect.get_center().x-(left.end.x+right.position.x)*0.5)<1.0,"visible sign centered between borders")
	check(sign_rect.position.x>left.end.x and sign_rect.end.x<right.position.x,"sign clears borders")
	check(absf(sign_rect.get_center().y-left.get_center().y)<1.0,"vertical centering retained")
	var original_size := Vector2((actions.direction_art.texture as AtlasTexture).atlas.get_image().get_used_rect().size)
	var prior_factor := minf((right.position.x-left.end.x-16*ui.stage.scale.x)/original_size.x,left.size.y*0.8/original_size.y)
	check(absf(sign_rect.size.x-solid_bounds((actions.direction_art.texture as AtlasTexture).atlas).size.x*prior_factor)<1.0,"sign visible size unchanged")
	check(map.loadout.snapshot()==before,"no gameplay mutation")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/warehouse-action-art.png")
	map.queue_free()
	await settle()
	print("WAREHOUSE ACTION ART: ",checks," checks, ",failures," failures; static only, no mouse")
	quit(1 if failures else 0)
