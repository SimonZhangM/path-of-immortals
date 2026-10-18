extends "res://tests/map_shop_tests.gd"

# Static wood skill artwork and frame placement; no mouse injection or real saves.
func run() -> void:
	AudioServer.set_bus_mute(0, true)
	root.content_scale_size = Vector2i.ZERO
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
	screen.category_buttons[1].button_pressed = true
	var art = screen.progress_art
	for viewport_size in [Vector2i(1920,1080),Vector2i(2560,1080),Vector2i(2560,1440)]:
		root.size = viewport_size
		await settle()
		for card in screen.book_cards:
			if card.book_id == "base.cultivation_book.wood_05": card.button_pressed = true
		await settle()
		var baseline_scale: Vector2 = art.size / Vector2(1576,456)
		var spell_name: Label = art.captions[2]
		var name_size := spell_name.get_theme_font_size("font_size")
		var name_color := spell_name.get_theme_color("font_color")
		var name_font := spell_name.get_theme_font("font").get_font_name()
		var reference_rank: Label = art.captions[0]
		var rank_size := reference_rank.get_theme_font_size("font_size")
		var rank_font := reference_rank.get_theme_font("font").get_font_name()
		var rank_color := reference_rank.get_theme_color("font_color")
		var common_five_column_rect := Rect2()
		for book_suffix in ["01", "02", "03", "04", "05", "03", "01"]:
			var book_id: String = "base.cultivation_book.wood_" + book_suffix
			for card in screen.book_cards:
				if card.book_id == book_id: card.button_pressed = true
			await settle()
			var crop: Array = art.reference.display_crop
			var factor: Vector2 = art.size / Vector2(crop[2],crop[3])
			check(art.visible and art.content.book_id == book_id, "selected frame follows selected book")
			check(screen.overview.visible and screen.overview.selected_book_id == book_id, "upper overview remains independent and correct")
			var lower_center := Vector2(screen.middle_panel.size.x * 0.5, (screen.middle_panel.size.y * 0.5 + 30 + screen.middle_panel.size.y) * 0.5)
			var expected_source_origin: Vector2 = lower_center - Vector2(802,307) * baseline_scale
			check(factor.is_equal_approx(baseline_scale) and (art.position - Vector2(crop[0],crop[1]) * factor).is_equal_approx(expected_source_origin), "all five- and eight-rank frames share lower-panel center and original scale")
			check(screen.middle_panel.get_global_rect().encloses(art.get_global_rect()), "entire crop inside middle panel")
			var solid_source := preload("res://scripts/map/map_texture_metrics.gd").solid_rect(art.texture.atlas)
			var visible_top: Vector2 = art.get_global_transform_with_canvas() * Vector2(0, (solid_source.position.y - crop[1]) * factor.y)
			check(visible_top.y > screen.progress_title.get_global_rect().end.y, "visible frame clears title; transparent crop padding is ignored")
			check(art.texture.atlas.get_image().has_mipmaps(), "frame uses mipmaps")
			_check_skill_icons(art)
			if DisplayServer.get_name() != "headless" and viewport_size == Vector2i(2560,1440):
				await RenderingServer.frame_post_draw
				var shot := root.get_texture().get_image()
				shot.get_region(Rect2i(screen.middle_panel.get_global_rect())).save_png("res://artifacts/technique-frame-wood-%s.png" % book_suffix)
			if book_suffix in ["04", "05"]:
				check(art.icons.size() == 12 and art.captions.size() == 28, "switching back restores original skill overlays")
				continue
			if common_five_column_rect == Rect2(): common_five_column_rect = art.get_rect()
			check(art.get_rect().is_equal_approx(common_five_column_rect), "52 and 53 share identical display size and center")
			var suffix := "53" if book_suffix == "03" else "52a" if book_suffix == "01" else "52b"
			var expected_slots := [Rect2(31,265,88,88),Rect2(128,265,88,88),Rect2(225,265,88,88)] if suffix == "53" else [Rect2(96,265,98,97),Rect2(210,265,98,97)]
			check(art.texture.atlas.resource_path == "res://assets/UI-wood-middown-%s.webp" % suffix, "correct five-by-two or five-by-three frame")
			var count := 15 if suffix == "53" else 10
			check(art.icons.size() == count and art.captions.size() == count + 5, "all five ranks have icons, names and numbered markers")
			for column in 5:
				var rank: Label = art.captions[count + column]
				check(rank.text == str(column + 1), "rank markers run from one through five")
				check(rank.get_theme_font_size("font_size") == rank_size and rank.get_theme_font("font").get_font_name() == rank_font and rank.get_theme_color("font_color") == rank_color, "rank style matches Qingluo green rings")
				var center: Vector2 = Vector2(172 if suffix == "53" else 202,132) + art.source_column_offset(column)
				var expected_center: Vector2 = art.get_global_transform_with_canvas() * ((center - Vector2(crop[0],crop[1])) * factor)
				check(rank.get_global_rect().get_center().distance_to(expected_center) < 1.5, "rank stays centered on its ring without skill offset")
				check(rank.get_global_transform_with_canvas().get_scale().is_equal_approx(Vector2.ONE), "rank text uses native pixels")
			for index in count:
				var label: Label = art.captions[index]
				var icon: TextureRect = art.icons[index]
				var native_scale := label.get_global_transform_with_canvas().get_scale()
				check(native_scale.is_equal_approx(Vector2.ONE), "new names render at native pixels")
				check(label.get_theme_font_size("font_size") == name_size and label.get_theme_color("font_color") == name_color and label.get_theme_font("font").get_font_name() == name_font, "names match Qingluo first spell font, size and color")
				var label_rect := label.get_global_rect()
				var icon_rect := icon.get_global_rect()
				check(absf(label_rect.get_center().x - icon_rect.get_center().x) <= 1.1 and label_rect.position.y > icon_rect.end.y, "name stays centered below its icon")
				check(art.get_global_rect().encloses(label_rect), "name stays within lower artwork")
				if index % expected_slots.size() != 0:
					check(not label_rect.intersects(art.captions[index - 1].get_global_rect()), "adjacent names do not overlap")
			check(art.texture.atlas.get_size() == Vector2(1605,567), "saved canvas matches source")
			check(FileAccess.get_sha256(art.reference.texture) == art.reference.baseline_sha256, "recorded baseline hash matches current source")
			for option in expected_slots.size():
				var retained: Rect2 = art.choice_icon_rect(0,option)
				check((art.position + retained.position).is_equal_approx(expected_source_origin + expected_slots[option].position * baseline_scale) and retained.size.is_equal_approx(expected_slots[option].size * baseline_scale), "first-column measured icon maps to centered source position and size")
			for column in 5:
				for option in expected_slots.size():
					check(Rect2(Vector2.ZERO,art.size).encloses(art.choice_icon_rect(column,option)), "future overlay slot stays inside frame crop")
			check(art.choice_icon_rect(5,0) == Rect2() and art.choice_icon_rect(0,expected_slots.size()) == Rect2(), "invalid future slots are rejected")
	art.show_book("base.cultivation_book.unknown_01")
	check(not art.visible, "unregistered elements do not borrow wood frames")
	check(map.loadout.snapshot() == before, "presentation leaves player state unchanged")
	map.queue_free()
	await settle()
	print("CHOICE FRAMES: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _check_skill_icons(art: TextureRect) -> void:
	var records: Array = []
	for stage in art.content.stages:
		if stage.has("spell"): records.append(stage.spell)
		records.append_array(stage.choices)
	check(art.icons.size() == records.size(), "every declared skill has an icon")
	var expected_statuses: Array = []
	for record in records:
		expected_statuses.append_array(record.get("status_icons", []))
	check(art.status_icons.size() == expected_statuses.size(), "status icons follow this book without leaking across book switches")
	var kurong: bool = art.content.book_id == "base.cultivation_book.wood_03"
	check(art.status_backplates.size() == (15 if kurong else 0), "all fifteen Kurong groups have a backing")
	for plate in art.status_backplates:
		var paired: bool = plate.get_meta("column") == 2
		check(plate.texture.resource_path == "res://assets/UI-wood-middown-53-button.webp" and plate.texture.get_image().has_mipmaps(), "correct mipmapped circular backing")
		var source_rect: Rect2 = plate.get_meta("source_rect")
		check(source_rect.size.is_equal_approx(Vector2(100 if paired else 70,69)), "third column widens symmetrically to 100; all heights stay 69")
		var circle_center := source_rect.position + Vector2(50 if paired else 35,34)
		var matches: Array[Rect2] = []
		for status in art.status_icons:
			var status_rect: Rect2 = status.get_meta("source_rect")
			var delta := status_rect.get_center() - circle_center
			if absf(delta.y) < 0.01 and absf(delta.x) < (30 if paired else 0.01):
				matches.append(status_rect)
				check(plate.get_index() < status.get_index(), "symbols draw above their shared backing")
		check(matches.size() == (2 if paired else 1), "one backing holds the intended single or paired status group")
		if paired and matches.size() == 2:
			check(matches[0].size.is_equal_approx(Vector2.ONE * 28.8) and matches[1].size.is_equal_approx(Vector2.ONE * 28.8), "paired status icons shrink ten percent")
			check(absf(matches[1].position.x - matches[0].end.x) < 0.01, "paired icon gap decreases from four to zero")
			check(((matches[0].get_center() + matches[1].get_center()) * 0.5).is_equal_approx(circle_center), "paired symbols remain centered as a group")
		var crop: Array = art.reference.display_crop
		var factor: Vector2 = art.size / Vector2(crop[2],crop[3])
		var original_position: Vector2 = art.get_global_transform_with_canvas() * ((source_rect.position - Vector2(crop[0],crop[1])) * factor)
		check((plate.get_global_rect().position - original_position).is_equal_approx(Vector2(0,-2)), "all backings move up exactly two screen pixels")
	for index in expected_statuses.size():
		var status: TextureRect = art.status_icons[index]
		check(status.get_meta("status_name") == expected_statuses[index].name and status.texture.atlas.resource_path == expected_statuses[index].icon, "status badge uses its matching existing buff or debuff art")
		check(art.get_global_rect().encloses(status.get_global_rect()), "status badge stays inside artwork")
		var source: Rect2 = status.get_meta("source_rect")
		var crop: Array = art.reference.display_crop
		var factor: Vector2 = art.size / Vector2(crop[2], crop[3])
		var original_position: Vector2 = art.get_global_transform_with_canvas() * ((source.position - Vector2(crop[0], crop[1])) * factor)
		var expected_x := -1.0 if index in [4,5,14] else 0.0
		check((status.get_global_rect().position - original_position).is_equal_approx(Vector2(expected_x,0)), "only Shigu, Jinfu and Gugen status symbols shift left one screen pixel")
		for label in art.captions:
			check(not status.get_global_rect().intersects(label.get_global_rect()), "status badge does not overlap a skill name")
	for index in records.size():
		var icon: TextureRect = art.icons[index]
		check(icon.texture.resource_path == records[index].icon and ("-effect-%02d-" % (index + 1)) in icon.texture.resource_path, "skill icons follow source ordinal order")
		check(icon.texture.get_image().has_mipmaps(), "effect icon uses refreshed mipmaps")
		check(icon.material.get_shader_parameter("line_width") == 1.0 and icon.material.get_shader_parameter("corner_radius") == 3.0, "gold border and rounded corners retained")
		if art.reference.get("layout_kind", "") == "five_choices":
			var choices := int(art.reference.choices_per_column)
			var retained: Rect2 = art.choice_icon_rect(index / choices, index % choices)
			var actual_shift := (icon.position - retained.position) * art.get_global_transform_with_canvas().get_scale()
			check(actual_shift.is_equal_approx(Vector2(0, 5 if choices == 2 else 0)) and icon.size.is_equal_approx(retained.size), "two-choice icons shift exactly five screen pixels; three-choice icons retain original slots")
			var crop: Array = art.reference.display_crop
			var factor: Vector2 = art.size / Vector2(crop[2], crop[3])
			var name_rect: Rect2 = art.captions[index].get_meta("source_rect")
			var screen_position: Vector2 = (art.get_global_transform_with_canvas() * ((name_rect.position - Vector2(crop[0], crop[1])) * factor)).round()
			check(absf(art.captions[index].get_global_rect().position.y - screen_position.y - (5 if choices == 2 else 0)) < 0.01, "two-choice names share the exact five-pixel shift")
			check(art.captions[index].text.replace("\n", "") == records[index].name, "skill name matches source record")
