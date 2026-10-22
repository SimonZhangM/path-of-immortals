extends "res://tests/map_shop_tests.gd"

# Static content/layout preview. No mouse injection or real save writes.
# Run one element per process with TECHNIQUE_PROGRESS_ELEMENT (default: metal).
func run() -> void:
	var element := OS.get_environment("TECHNIQUE_PROGRESS_ELEMENT")
	if element.is_empty(): element = "metal"
	assert(element in ["metal", "water", "fire", "earth", "wind", "thunder"])
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
	var screen: MapTechniqueScreen = map.technique_screen
	screen.category_buttons[["metal","wood","water","fire","earth","wind","thunder"].find(element)].button_pressed = true
	check(screen.progress_art.books.size() == 35, "all 35 books registered")
	for index in range(1,6):
		if OS.get_environment("TECHNIQUE_PROGRESS_STATUS_ONLY") == "1" and index != 3: continue
		var book_id := "base.cultivation_book.%s_%02d" % [element,index]
		for card in screen.book_cards:
			if card.book_id == book_id: card.button_pressed = true
		await settle()
		var art := screen.progress_art
		var kind: String = ["52a","52b","53","8","8"][index-1]
		var expected_count := 10 if index <= 2 else 15 if index == 3 else 12
		var records: Array = []
		for stage in art.content.stages:
			if stage.has("spell"): records.append(stage.spell)
			records.append_array(stage.choices)
		check(records.size() == expected_count, "all effects included for this book")
		var source_copy := FileAccess.get_file_as_string("res://" + String(art.content.source_document))
		for record in records:
			check(source_copy.contains("【%s】" % record.name) and source_copy.contains(record.description), "current name and complete numeric description match source")
			check(ResourceLoader.exists(record.icon), "concrete effect artwork available")
		for viewport_size in [Vector2i(1920,1080),Vector2i(2560,1080),Vector2i(2560,1440)]:
			root.size = viewport_size
			await settle()
			check(art.visible and art.content.book_id == book_id and screen.overview.selected_book_id == book_id, "correct upper/lower book content")
			check(art.texture.atlas.resource_path == "res://assets/UI-%s-middown-%s.webp" % [element,kind], "uses its own element and frame type")
			check(art.texture.atlas.get_size() == Vector2(1605,567) and art.texture.region == Rect2(14,79,1576,456), "shared source size and crop")
			check(art.texture.atlas.get_image().has_mipmaps(), "frame mipmaps enabled")
			check(FileAccess.get_sha256(art.reference.texture) == art.reference.baseline_sha256, "source matches saved element baseline")
			var panel := screen.middle_panel.get_global_rect()
			var divider_y := screen.progress_title.get_global_rect().get_center().y
			check(art.get_global_rect().get_center().is_equal_approx(Vector2(panel.get_center().x,(divider_y+panel.end.y)*0.5)), "same lower-container center as wood")
			check(panel.encloses(art.get_global_rect()), "whole frame inside middle panel")
			check(is_equal_approx(art.size.x/1576.0,art.size.y/456.0), "frame keeps aspect ratio")
			check(art.icons.size() == expected_count, "all skill and upgrade pictures shown")
			check_status_art(art, records, index == 3)
			for icon_index in art.icons.size():
				var icon: TextureRect = art.icons[icon_index]
				check(icon.texture.resource_path == records[icon_index].icon, "picture matches ordered effect record")
				var slug := String(art.books[book_id].content).get_file().trim_prefix("technique_progress_%s_" % element).trim_suffix(".json")
				check(icon.texture.resource_path.begins_with("res://assets/UI-%s-%s-effect-%02d-" % [element,slug,icon_index+1]), "picture belongs to correct element, book and sequence")
				check(icon.texture.get_size() == Vector2(376,376) and icon.texture.get_image().has_mipmaps(), "source size and mipmaps")
				check(icon.material.get_shader_parameter("line_width") == 1.0 and icon.material.get_shader_parameter("corner_radius") == 3.0 and icon.material.get_shader_parameter("line_color") == Color("d9bb72"), "wood border styling retained")
				var expected_rect: Rect2 = art.choice_icon_rect(icon.get_meta("group"),icon.get_meta("option")) if index <= 3 else art.icon_rect(icon.get_meta("group"),icon.get_meta("option"))
				expected_rect.position.y += float(art.reference.get("overlay_offset_screen_y",0)) / art.get_global_transform_with_canvas().get_scale().y
				check(icon.get_rect().is_equal_approx(expected_rect), "picture uses measured slot and screen offset")
				check(art.get_global_rect().encloses(icon.get_global_rect()), "picture inside frame")
				for label: Label in art.captions:
					check(not icon.get_global_rect().intersects(label.get_global_rect()), "picture does not cover text")
			var rank_count := 5 if index <= 3 else 8
			check(art.captions.size() == expected_count + rank_count + (8 if index >= 4 else 0), "all names, ranks and battle summaries shown")
			var names: Array[String] = []
			var ranks: Array[String] = []
			for label: Label in art.captions:
				var context := "%s %s at %s" % [book_id,label.text,viewport_size]
				check(art.get_global_rect().encloses(label.get_global_rect()), "caption inside frame: " + context)
				check(label.get_global_transform_with_canvas().get_scale().is_equal_approx(Vector2.ONE), "native-pixel text: " + context)
				var text_size: Vector2 = label.get_theme_font("font").get_multiline_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size"))
				check(text_size.x <= label.size.x + 0.1, "text fits allocated width: " + context)
				var source_rect: Rect2 = label.get_meta("source_rect")
				var label_kind := String(label.get_meta("kind"))
				if label_kind.begins_with("Rank"):
					ranks.append(label.text)
				else:
					check(label.get_theme_font("font").get_font_name() == ("KaiTi" if label_kind == "ChoiceEffect" else "HarmonyOS Sans SC"), "existing typography: " + context)
					check(source_rect.end.y <= (464 if index <= 3 else 411), "caption above card bottom: " + context)
					if label_kind != "ChoiceEffect": names.append(label.text.replace("\n",""))
			for rank in range(1,rank_count+1): check(str(rank) in ranks, "all circles numbered sequentially")
			for record in records: check(String(record.name) in names, "all names visible")
			for column in (4 if index >= 4 else 5):
				var options := [-1,0,1] if index >= 4 else [0,1,2] if index == 3 else [0,1]
				for option in options:
					var slot: Rect2 = art.icon_rect(column,option) if index >= 4 else art.choice_icon_rect(column,option)
					check(Rect2(Vector2.ZERO,art.size).encloses(slot), "reserved skill image slot stays in frame")
			if DisplayServer.get_name() != "headless" and viewport_size == Vector2i(2560,1440):
				await RenderingServer.frame_post_draw
				var shot := root.get_texture().get_image()
				shot.get_region(Rect2i(Vector2(panel.position.x,divider_y),Vector2(panel.size.x,panel.end.y-divider_y))).save_png("res://artifacts/technique-progress-%s-%02d.png" % [element,index])
	# Existing wooden content restores its own pictures after browsing other elements.
	screen.progress_art.show_book("base.cultivation_book.wood_05")
	check(screen.progress_art.icons.size() == 12 and screen.progress_art.reference.texture == "res://assets/UI-wood-middown-8.webp", "wood icons and frame restore intact")
	check(map.loadout.snapshot() == before, "presentation leaves player state unchanged")
	map.queue_free()
	await settle()
	print("%s PROGRESS: %d checks, %d failures" % [element.to_upper(),checks,failures])
	quit(1 if failures else 0)

func check_status_art(art, records: Array, has_statuses: bool) -> void:
	check(art.status_icons.size() == (18 if has_statuses else 0), "status book has eighteen symbols; other books have none")
	check(art.status_backplates.size() == (15 if has_statuses else 0), "one backing per status group; no leakage to other books")
	if not has_statuses: return
	var expected: Array = []
	for record in records: expected.append_array(record.status_icons)
	for i in expected.size():
		var symbol: TextureRect = art.status_icons[i]
		check(symbol.get_meta("status_name") == expected[i].name and symbol.texture.atlas.resource_path == expected[i].icon, "correct buff/debuff symbol and order")
		check(symbol.texture.atlas.get_image().has_mipmaps(), "state symbol mipmaps enabled")
		check(art.get_global_rect().encloses(symbol.get_global_rect()), "state symbol inside frame")
		for label in art.captions:
			check(not symbol.get_global_rect().intersects(label.get_global_rect()), "state symbol does not cover a caption")
		for icon in art.icons:
			check(not symbol.get_global_rect().intersects(icon.get_global_rect()), "state symbol stays below skill artwork")
	for plate in art.status_backplates:
		var paired: bool = plate.get_meta("column") == 2
		check(plate.texture.resource_path == "res://assets/UI-wood-middown-53-button.webp" and plate.texture.get_image().has_mipmaps(), "shared wood backing texture")
		var source_rect: Rect2 = plate.get_meta("source_rect")
		check(source_rect.size.is_equal_approx(Vector2(100 if paired else 70,69)), "wood single/paired backing dimensions")
		var center := source_rect.position + Vector2(50 if paired else 35,34)
		var matching: Array[Rect2] = []
		for symbol in art.status_icons:
			var rect: Rect2 = symbol.get_meta("source_rect")
			if absf(rect.get_center().y-center.y) < 0.01 and absf(rect.get_center().x-center.x) < (30 if paired else 0.01):
				matching.append(rect)
				check(plate.get_index() < symbol.get_index(), "background draws behind symbol")
				check(rect.size.is_equal_approx(Vector2.ONE * (28.8 if paired else 32)), "wood symbol size and paired ten-percent reduction")
		check(matching.size() == (2 if paired else 1), "symbols aligned to backing circle center")
		if paired and matching.size() == 2:
			check(absf(matching[1].position.x-matching[0].end.x) < 0.01, "paired symbols use zero gap")
			check(((matching[0].get_center()+matching[1].get_center())*0.5).is_equal_approx(center), "pair centered as a whole")
		var crop: Array = art.reference.display_crop
		var factor: Vector2 = art.size / Vector2(crop[2],crop[3])
		var original: Vector2 = art.get_global_transform_with_canvas() * ((source_rect.position-Vector2(crop[0],crop[1]))*factor)
		check((plate.get_global_rect().position-original).is_equal_approx(Vector2(0,-2)), "backing retains wood two-screen-pixel upward offset")
