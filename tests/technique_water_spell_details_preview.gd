extends "res://tests/map_shop_tests.gd"

func run() -> void:
	var element := OS.get_environment("TECHNIQUE_SPELL_ELEMENT")
	if element.is_empty(): element = "water"
	AudioServer.set_bus_mute(0, true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1920, 1080)
	var map = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path = ""
	map.defer_map_music = true
	root.add_child(map)
	map.set_process(false)
	await settle()
	check(map.startup_error.is_empty(), "isolated map starts")
	if not map.startup_error.is_empty(): quit(1); return
	var before: Dictionary = map.loadout.snapshot().duplicate(true)
	map.set_technique_open(true)
	var screen: MapTechniqueScreen = map.technique_screen
	var detail = screen.spell_detail
	check(detail.records.size() == 56, "all 56 spells registered")
	for viewport in [Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		root.size = viewport
		var progress_by_book := {}
		var review: Image
		for index in 8:
			var id := "base.spell.%s_%02d" % [element, index + 1]
			var entry: Dictionary = detail.records[id]
			screen.focus_book(entry.book_id)
			screen.progress_art.rank_selection.select_rank(entry.rank)
			await settle()
			check(detail.selected_spell_id == id, "correct spell for book/rank: " + id)
			check(detail.labels.SpellName.text == entry.name, "correct spell name")
			check(detail.spell_icon.texture.resource_path == entry.icon, "correct original square skill art")
			check(detail.labels.Poem.text == "“%s”" % entry.poem and detail.labels.Description.text == entry.description, "complete source prose")
			check(detail.labels.LearningCost.text == str(int(entry.learning_cost)), "correct learning cost")
			check(detail.labels.Condition0.text == entry.learning_conditions[0] and detail.labels.Condition2.text == entry.learning_conditions[2], "correct realm and book rank conditions")
			var current: Array = [detail.labels.Practice.text, detail.labels.ProgressValue0.text, detail.labels.ProgressValue1.text, detail.labels.ProgressValue2.text]
			if progress_by_book.has(entry.book_id):
				check(current == progress_by_book[entry.book_id], "one progress record shared by book")
			else:
				progress_by_book[entry.book_id] = current
			var visible_categories: Array = detail.visible_spell_categories(entry)
			for category in visible_categories.size():
				var tag: Label = detail.labels["Category%d" % category]
				check(tag.visible and tag.text == visible_categories[category], "visible spell classification tags present")
				check(tag.get_global_rect().end.x <= screen.right_panel.get_global_rect().end.x - 8, "tag stays in panel")
			for point in entry.core_points.size():
				var label: Label = detail.labels["CorePoint%d" % point]
				if detail.body_scroll.visible:
					check(detail.body_labels[point + 1].text == entry.core_points[point], "full scrollable core text")
					continue
				check(label.visible and label.text == entry.core_points[point], "every core point present")
				check(label.get_global_rect().end.y < detail.labels.LearningHeading.get_global_rect().position.y, "core point stays above learning section")
				if point > 0:
					check(label.get_global_rect().position.y >= detail.labels["CorePoint%d" % (point - 1)].get_global_rect().end.y - 3, "core point paragraphs do not overlap")
			for label: Label in detail.labels.values():
				if not label.is_visible_in_tree(): continue
				check(label.get_line_count() == label.get_visible_line_count(), "all text lines visible: " + str(label.name))
			if detail.body_scroll.visible:
				check(detail.body_labels[0].text == entry.description, "full scrollable description")
				check(detail.body_scroll.get_global_rect().end.y < detail.labels.LearningHeading.get_global_rect().position.y, "body clears fixed learning section")
				for label: Label in detail.body_labels:
					check(label.get_line_count() == label.get_visible_line_count(), "all body text available")
					check(label.get_global_transform_with_canvas().get_scale().is_equal_approx(Vector2.ONE), "body text native pixels")
				detail.body_scroll.scroll_vertical = int(detail.body_scroll.get_v_scroll_bar().max_value)
				await settle()
				check(detail.body_labels[-1].get_global_rect().end.y <= detail.body_scroll.get_global_rect().end.y + 2, "last core point reachable")
				if DisplayServer.get_name() != "headless":
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().get_region(Rect2i(screen.right_panel.get_global_rect())).save_png("res://artifacts/%s-spell-%02d-%d-bottom.png" % [element,index + 1,viewport.x])
				detail.body_scroll.scroll_vertical = 0
				await settle()
			else:
				check(detail.labels.Description.get_global_rect().end.y < detail.labels.CorePoint0.get_global_rect().position.y + 1, "description clears first point")
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				var crop: Image = root.get_texture().get_image().get_region(Rect2i(screen.right_panel.get_global_rect()))
				crop.save_png("res://artifacts/%s-spell-%02d-%d.png" % [element,index + 1, viewport.x])
				if viewport.x == 1920:
					if index % 4 == 0: review = Image.create(crop.get_width() * 4, crop.get_height(), false, crop.get_format())
					review.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), Vector2i((index % 4) * crop.get_width(), 0))
					if index % 4 == 3: review.save_png("res://artifacts/%s-spell-book-%d-review.png" % [element,index / 4 + 1])
			if element == "wind" and viewport.x == 2560 and index == 0:
				check(FileAccess.get_sha256(screen.progress_art.reference.texture) == screen.progress_art.reference.baseline_sha256, "updated wind art baseline")
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://artifacts/wind-spell-full-screen.png")
		for suffix in ["04", "05"]:
			screen.focus_book("base.cultivation_book." + element + "_" + suffix)
			screen.progress_art.rank_selection.select_rank(2)
			check(screen.enhancement_detail.visible and not detail.visible, "combat even rank shows its enhancement page")
		check(progress_by_book.size() == 2, "each book has its own progress record")
	detail.show_selection("base.cultivation_book." + element + "_01", 1, map.loadout)
	check(not detail.visible, "craft book does not borrow a spell page")
	check(map.loadout.snapshot() == before, "all browsing leaves authoritative state unchanged")
	map.queue_free()
	await settle()
	print("%s SPELL DETAILS: %d checks, %d failures" % [element.to_upper(),checks, failures])
	quit(1 if failures else 0)
