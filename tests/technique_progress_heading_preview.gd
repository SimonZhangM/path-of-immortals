extends "res://tests/map_shop_tests.gd"

# Static geometry and render verification only; no mouse or input injection.
func run() -> void:
	AudioServer.set_bus_mute(0, true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(2560,1440)
	var map = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path = ""
	map.defer_map_music = true
	root.add_child(map)
	map.set_process(false)
	await settle()
	check(map.startup_error.is_empty(), "map starts")
	if not map.startup_error.is_empty(): quit(1); return
	var before: Dictionary = map.loadout.snapshot().duplicate(true)
	map.set_technique_open(true)
	await settle()
	var screen: MapTechniqueScreen = map.technique_screen
	screen.category_buttons[1].button_pressed = true
	check(screen.progress_art.content.book_id.begins_with("base.cultivation_book.metal_") and screen.overview.selected_book_id.begins_with("base.cultivation_book.metal_"), "metal selection keeps its own upper and lower content")
	for card in screen.book_cards:
		if card.book_id == "base.cultivation_book.wood_05": card.button_pressed = true
	await settle()
	check(screen.progress_art.visible, "Qingluo selection displays its own chart")
	for book_id in ["base.cultivation_book.wood_05", "base.cultivation_book.wood_04"]:
		for card in screen.book_cards:
			if card.book_id == book_id: card.button_pressed = true
		await settle()
		var is_wanmu: bool = book_id.ends_with("wood_04")
		var book_slug := "wanmushengshajue" if is_wanmu else "qingluohuashengjue"
		var short_name := "wanmu" if is_wanmu else "qingluo"
		var suffix := "-wanmu" if is_wanmu else ""
		var expected_names := ["锐刺","毒芽","连刃","缚刃","穿林","毒翎","森罗尽发","枯荣夺生"] if is_wanmu else ["盘根","疾藤","入骨","蔓生","急生","长养","天罗固缚","引火召雷"]
		for viewport_size in [Vector2i(1920,1080),Vector2i(2560,1080),Vector2i(2560,1440)]:
			root.size = viewport_size
			await settle()
			var panel := screen.middle_panel.get_global_rect()
			var title := screen.progress_title.get_global_rect()
			var factor := screen.stage.scale.x
			var rim: ColorRect = screen.middle_panel.find_child("Border",true,false)
			var paint := screen.progress_divider.material as ShaderMaterial
			check(absf((title.get_center().y-panel.get_center().y)/factor-30.0)<0.01, "title moves thirty design pixels below side midpoint")
			check(absf(screen.progress_divider.get_global_rect().position.y+2.0*factor-title.get_center().y)<0.01, "title and full divider move together")
			check(absf((title.position.x-panel.position.x)/factor-16.0)<0.01, "sixteen-pixel visible clearance to side")
			check(absf(title.size.x/factor-240.0)<0.01, "reference title width retained")
			check(is_equal_approx(title.size.x/title.size.y,float(screen.progress_title.texture.get_width())/screen.progress_title.texture.get_height()), "title preserves original aspect ratio")
			check(screen.progress_title.texture.atlas.get_image().has_mipmaps(), "title uses mipmaps")
			check(paint.get_shader_parameter("line_color")==rim.material.get_shader_parameter("line_color") and paint.get_shader_parameter("line_width")==rim.material.get_shader_parameter("line_width"), "same gold and stroke as existing rim")
			check(paint.get_shader_parameter("corner_radius")==rim.material.get_shader_parameter("corner_radius"), "same two upper corner radii")
			check(paint.get_shader_parameter("panel_size").is_equal_approx(Vector2(screen.middle_panel.size.x,screen.middle_panel.size.y*0.5-30.0)), "divider follows full width and shifted lower section")
			check(paint.get_shader_parameter("title_gap")==Vector2(20,252), "line overlaps both opaque tips by four pixels without crossing title body")
			check(screen.progress_title.mouse_filter==Control.MOUSE_FILTER_IGNORE and screen.progress_divider.mouse_filter==Control.MOUSE_FILTER_IGNORE, "decorations do not intercept input")
			var art := screen.progress_art
			var overview := screen.overview
			check(art.content.book_id==book_id and overview.selected_book_id==book_id, "upper and lower content match selected book")
			check(overview.visible and overview.get_global_rect().end.y<title.get_center().y, "selected overview stays above progress divider")
			for piece: TextureRect in overview.artwork.values():
				check(piece.texture.atlas.resource_path.contains(book_slug), "overview art belongs to selected book")
				check(overview.get_global_rect().encloses(piece.get_global_rect()), "overview artwork inside upper region")
				check(piece.texture.atlas.get_image().has_mipmaps() and is_equal_approx(piece.size.x/piece.size.y,piece.texture.get_width()/float(piece.texture.get_height())), "overview artwork preserves proportions with mipmaps")
			for copy: Label in [overview.poem, overview.origin]:
				check(overview.get_global_rect().encloses(copy.get_global_rect()), "complete overview text fits above progress")
				check(copy.get_global_transform_with_canvas().get_scale().is_equal_approx(Vector2.ONE), "overview text renders in native pixels")
			check(not overview.copy_box.get_global_rect().intersects(overview.artwork.book.get_global_rect()), "book does not cover poem or origin")
			var solid_source := preload("res://scripts/map/map_texture_metrics.gd").solid_rect(art.texture.atlas)
			var visible_top: Vector2 = art.get_global_transform_with_canvas() * Vector2(0, (solid_source.position.y - 79) * art.size.y / 456)
			check(panel.encloses(art.get_global_rect()) and visible_top.y>title.end.y, "visible artwork clears heading inside middle panel, excluding transparent crop padding")
			check(absf(art.get_global_rect().get_center().x-panel.get_center().x)<0.01, "progress artwork horizontally centered")
			var lower_center := Vector2(panel.get_center().x, (title.get_center().y + panel.end.y) * 0.5)
			check(art.get_global_rect().get_center().is_equal_approx(lower_center), "eight-rank artwork centered in the lower bordered container")
			for layout_path in ["res://data/ui/technique_progress_art_52a.json", "res://data/ui/technique_progress_art_52b.json", "res://data/ui/technique_progress_art_53.json"]:
				var shared: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(layout_path))
				check(art.reference.display_crop == shared.display_crop and art.reference.placement_crop == shared.placement_crop and art.reference.center_in_lower_panel == shared.center_in_lower_panel, "eight-rank, 52 and 53 use identical dimensions, scale and center")
			check(is_equal_approx(art.size.x/art.texture.get_width(),art.size.y/art.texture.get_height()), "full chart scales uniformly")
			check(art.texture.atlas.get_image().has_mipmaps() and art.mouse_filter==Control.MOUSE_FILTER_IGNORE, "chart uses mipmaps without input handling")
			check(art.texture.atlas.get_size()==Vector2(1605,567) and art.texture.region==Rect2(14,79,1576,456), "updated canvas and shared display crop match saved baseline")
			check(FileAccess.get_sha256(art.reference.texture)==art.reference.baseline_sha256, "updated source matches recorded baseline")
			for group_index in 4:
				for option_index in [-1,0,1]:
					var slot: Rect2 = art.icon_rect(group_index,option_index)
					check(Rect2(Vector2.ZERO,art.size).encloses(slot), "all twelve future icon slots inside chart")
					var first: Rect2 = art.icon_rect(0,option_index)
					var column_index := group_index * 2 + (0 if option_index == -1 else 1)
					var measured_offsets := [0,4,-3,0,-4,1,-6,0]
					var source_shift: float = group_index * 394.0 + measured_offsets[column_index] - measured_offsets[0 if option_index == -1 else 1]
					check(slot.size.is_equal_approx(first.size) and absf((slot.position.x-first.position.x)/art.size.x*1576.0-source_shift)<0.01, "icons retain dimensions and follow measured updated card positions")
					var source_slot := Rect2(slot.position / art.size * Vector2(1576,456) + Vector2(14,79), slot.size / art.size * Vector2(1576,456))
					var first_source := Rect2(45,243,98,97) if option_index == -1 else Rect2(197 + option_index * 100,250,84,84)
					check(source_slot.is_equal_approx(Rect2(first_source.position + Vector2(source_shift,0),first_source.size)), "icons match translated original slots in the new source")
			check(art.icons.size()==12 and art.captions.size()==28, "twelve independent icons with circle ranks, spell names and enhancement captions")
			check(screen.progress_shade.get_global_rect().position.y>title.get_center().y and screen.progress_shade.get_index()<art.get_index(), "shade only below divider and behind artwork")
			check(screen.progress_shade.material.shader.resource_path=="res://scripts/map/map_technique_progress_shade.gdshader", "lower shade uses downward fade and feathered sides")
			var names: Array[String] = []
			for icon in art.icons:
				check(icon.texture.resource_path.contains(book_slug), "effect belongs to selected book")
				check(icon.texture.get_image().has_mipmaps(), "effect texture has mipmaps")
				check(icon.get_rect().is_equal_approx(art.icon_rect(icon.get_meta("group"),icon.get_meta("option"))), "icon follows recorded slot")
				check(icon.material.get_shader_parameter("line_width")==1.0 and icon.material.get_shader_parameter("corner_radius")==3.0, "one-pixel gold edge and three-pixel rounded clipping")
			for label in art.captions:
				check(art.get_global_rect().encloses(label.get_global_rect()), "caption stays within chart: %s %s in %s at %s" % [label.text,label.get_global_rect(),art.get_global_rect(),viewport_size])
				var text_transform: Transform2D = label.get_global_transform_with_canvas()
				check(text_transform.get_scale().is_equal_approx(Vector2.ONE) and text_transform.origin.distance_to(text_transform.origin.round())<0.001, "text renders at native scale on integer pixels")
				check(label.get_theme_font("font").get_multiline_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x<=label.size.x+0.1, "caption fits available column")
				if String(label.get_meta("kind")).begins_with("Rank"):
					check(label.text in ["1","2","3","4","5","6","7","8"], "circle numbers are integers")
					var ring_centers := [Vector2(94,140),Vector2(290,141),Vector2(485,141),Vector2(680,140),Vector2(878,140),Vector2(1074,140),Vector2(1269,140),Vector2(1468,140)]
					var ring_center: Vector2 = art.get_global_transform_with_canvas() * ((ring_centers[int(label.text)-1]-Vector2(14,79))*art.size/Vector2(1576,456))
					check(label.get_global_rect().get_center().distance_to(ring_center) < 1.2, "number centered on measured updated ring")
				if label.get_meta("kind")=="ChoiceEffect":
					var source_bottom: float = (label.get_global_rect().end.y-art.get_global_rect().position.y) / art.get_global_rect().size.y * 456 + 79
					check(source_bottom <= 399, "effect stays clear of bottom card border: %s %s" % [label.text,source_bottom])
				if label.get_meta("kind")=="ChoiceName": names.append(label.text)
			check(names==expected_names, "enhancement names match selected book in supplied sequence")
			if DisplayServer.get_name()!="headless" and viewport_size==Vector2i(2560,1440):
				await RenderingServer.frame_post_draw
				var shot := root.get_texture().get_image()
				shot.save_png("res://artifacts/technique-progress-heading%s.png" % suffix)
				shot.get_region(Rect2i(overview.get_global_rect())).save_png("res://artifacts/technique-overview-%s.png" % short_name)
				shot.get_region(Rect2i(panel.position+Vector2(0,485)*factor,Vector2(panel.size.x,425*factor))).save_png("res://artifacts/technique-progress-middown%s.png" % suffix)
				shot.get_region(Rect2i(panel)).save_png("res://artifacts/technique-progress-heading-middle%s.png" % suffix)
				shot.get_region(Rect2i(Vector2(panel.position.x,title.position.y-12),Vector2(panel.size.x,title.size.y+40))).save_png("res://artifacts/technique-progress-heading-detail%s.png" % suffix)
	check(map.loadout.snapshot()==before,"layout leaves player state unchanged")
	for book_id in ["base.cultivation_book.metal_01", "base.cultivation_book.wood_03", "base.cultivation_book.wood_04", "base.cultivation_book.wood_05"]:
		var card
		for candidate in screen.book_cards:
			if candidate.book_id == book_id: card = candidate
		card.button_pressed = true
		check(screen.progress_art.visible==screen.progress_art.books.has(card.book_id) and screen.overview.visible==screen.overview.records.has(card.book_id), "upper and lower content follow their independent registries")
		if screen.progress_art.visible:
			check(screen.progress_art.content.book_id==card.book_id and screen.overview.selected_book_id==card.book_id, "switching back restores the matching content")
	for card in screen.book_cards:
		if card.book_id=="base.cultivation_book.wood_05": card.button_pressed = true
	screen.category_buttons[0].button_pressed = true
	check(screen.progress_art.visible and screen.selected_book_id=="base.cultivation_book.wood_05", "category filtering does not replace the globally selected book")
	map.queue_free()
	await settle()
	print("TECHNIQUE PROGRESS HEADING: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
