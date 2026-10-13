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
	check(map.startup_error.is_empty(),"town ready")
	if not map.startup_error.is_empty(): quit(1); return
	var before: Dictionary = map.loadout.snapshot()
	var dialog: MapShopDialog = map.shop_dialog
	dialog.present(JSON.parse_string(FileAccess.get_file_as_string("res://data/map_events/qingshizhen_shop.json")),map.shops[EVENT],map.loadout)
	var gathering := MapGatheringDialog.new()
	root.add_child(gathering)
	await settle()
	check(dialog.title_label.get_theme_font("font").font_names==gathering.heading.get_theme_font("font").font_names,"title font matches herb title blackface")
	check(dialog.title_label.get_theme_font_size("font_size")==gathering.heading.get_meta("source_font_size"),"title source size matches herb title 52")
	check(dialog.title_label.get_theme_color("font_color")==gathering.heading.get_theme_color("font_color"),"title color matches herb title fbf4bf")
	check(dialog.title_label.position.x==704-dialog.FRAME.position.x and is_equal_approx(dialog.title_label.position.y+dialog.title_label.size.y*0.5+dialog.FRAME.position.y,136.5),"title aligned to fixed shop logo")
	check(dialog.title_label.get_visible_line_count()==dialog.title_label.get_line_count(),"title fits")
	var page_style := dialog.next_button.get_theme_stylebox("hover") as StyleBoxFlat
	for button: TextureButton in [dialog.minus_button,dialog.plus_button]:
		var hover := button.get_node("QuantityHover") as Panel
		var style := hover.get_theme_stylebox("panel") as StyleBoxFlat
		check(style.bg_color==page_style.bg_color and style.border_color==page_style.border_color,"quantity tint and border match page hover")
		check(style.border_width_left==page_style.border_width_left and style.corner_radius_top_left==page_style.corner_radius_top_left,"quantity line width and radius match page hover")
		check(hover.mouse_filter==Control.MOUSE_FILTER_IGNORE,"visual overlay does not intercept input")
		check(hover.size==button.size and hover.position==Vector2.ZERO,"highlight fits existing button bounds")
		check(button.size==Vector2(28,28),"quantity button size unchanged")
		check(button.mouse_entered.has_connections() and button.mouse_exited.has_connections(),"quantity hover show/hide connected")
	check(not dialog.minus_button.get_node("QuantityHover").visible,"disabled minus has no highlight")
	check(dialog.leave_button.get_theme_stylebox("hover") is StyleBoxEmpty,"leave still has no hover effect")
	if DisplayServer.get_name()!="headless":
		# Static visual sample, no mouse input or quantity changes.
		dialog.plus_button.get_node("QuantityHover").show()
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/shop-title-quantity-hover.png")
	check(map.loadout.snapshot()==before,"money items and date unchanged")
	gathering.queue_free()
	map.queue_free()
	await settle()
	print("SHOP TITLE/QUANTITY STYLE: %d checks, %d failures; static only" % [checks,failures])
	quit(1 if failures else 0)
