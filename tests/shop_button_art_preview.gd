extends "res://tests/map_shop_tests.gd"

func alpha_bounds(texture: Texture2D, threshold: float) -> Rect2:
	var image := texture.get_image()
	var minimum := image.get_size()
	var maximum := Vector2i.ZERO
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x,y).a <= threshold: continue
			minimum = minimum.min(Vector2i(x,y))
			maximum = maximum.max(Vector2i(x+1,y+1))
	return Rect2(minimum,maximum-minimum)

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
	check(map.startup_error.is_empty(),"map ready")
	if not map.startup_error.is_empty(): quit(1); return
	var before: Dictionary = map.loadout.snapshot()
	var dialog: MapShopDialog = map.shop_dialog
	dialog.present(JSON.parse_string(FileAccess.get_file_as_string("res://data/map_events/qingshizhen_shop.json")),map.shops[EVENT],map.loadout)
	await settle()
	var gathering := MapGatheringDialog.new()
	root.add_child(gathering)
	gathering.size = root.size
	gathering._layout()
	var reference_caption: Label
	for label in gathering.find_children("*","Label",true,false):
		if label.text=="稍后再说": reference_caption = label
	check(reference_caption!=null,"gathering exit caption found")
	check(dialog.leave_button.get_theme_font("font").font_names==reference_caption.get_theme_font("font").font_names,"leave uses same blackface as gathering")
	check(dialog.leave_button.get_theme_font_size("font_size")==reference_caption.get_meta("source_font_size"),"same twenty-seven source font size")
	for style in ["normal","hover","pressed","disabled","focus"]:
		check(dialog.leave_button.get_theme_stylebox(style) is StyleBoxEmpty,"no leave highlight: "+style)
	for color in ["font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color"]:
		check(dialog.leave_button.get_theme_color(color)==dialog.leave_button.get_theme_color("font_color"),"leave text color unchanged: "+color)
	var button := dialog.buy_button
	var idle := button.texture_normal as AtlasTexture
	var hover := button.texture_hover as AtlasTexture
	var measured: Array[Rect2] = []
	for texture: AtlasTexture in [idle,hover]:
		var body := alpha_bounds(texture.atlas,0.5)
		var ratio := button.size/texture.region.size
		measured.append(Rect2(button.position+(body.position-texture.region.position)*ratio,body.size*ratio))
		check(texture.atlas.get_image().has_mipmaps(),"button source mipmaps preserved")
	check(measured[0].is_equal_approx(measured[1]),"normal and hover solid body size/position identical")
	var original_hover := dialog._trimmed("res://assets/tanchuang-baoxiang-dakai2.webp")
	var old_size := Vector2(200,58)
	var old_factor := minf(old_size.x/original_hover.get_width(),old_size.y/original_hover.get_height())
	var old_draw := original_hover.get_size()*old_factor
	var original_body := alpha_bounds(hover.atlas,0.5)
	var old_rect := Rect2(Vector2(1206,722)-dialog.FRAME.position+(old_size-old_draw)*0.5+(original_body.position-original_hover.region.position)*old_factor,original_body.size*old_factor)
	check(measured[1].is_equal_approx(old_rect),"hover body retains previous exact visual bounds")
	check(button.get_rect().get_center().is_equal_approx(dialog.buy_label.get_rect().get_center()),"purchase text remains centered")
	check(button.texture_pressed==hover and button.texture_disabled==idle,"pressed/disabled share respective body geometry")
	print("NORMAL/HOVER SOLID RECT ",measured)
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/shop-button-normal.png")
		# Static hover-art fixture only: no pointer events or purchase callbacks.
		button.texture_normal = hover
		dialog.buy_label.add_theme_color_override("font_color",Color.BLACK)
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/shop-button-hover.png")
	check(map.loadout.snapshot()==before,"no inventory, funds or date changes")
	gathering.queue_free()
	map.queue_free()
	await settle()
	print("SHOP BUTTON ART: %d checks, %d failures; static only" % [checks,failures])
	quit(1 if failures else 0)
