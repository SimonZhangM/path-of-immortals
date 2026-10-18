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
			check(not record.has("icon"), "concrete effect artwork reserved for later")
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
			check(art.icons.is_empty() and art.status_icons.is_empty() and art.status_backplates.is_empty(), "no borrowed effect or status artwork")
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
	# Existing wooden content restores its own pictures when leaving a text-only book.
	screen.progress_art.show_book("base.cultivation_book.wood_05")
	check(screen.progress_art.icons.size() == 12 and screen.progress_art.reference.texture == "res://assets/UI-wood-middown-8.webp", "wood icons and frame restore intact")
	check(map.loadout.snapshot() == before, "presentation leaves player state unchanged")
	map.queue_free()
	await settle()
	print("%s PROGRESS: %d checks, %d failures" % [element.to_upper(),checks,failures])
	quit(1 if failures else 0)
