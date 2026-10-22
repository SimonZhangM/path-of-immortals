extends "res://tests/map_shop_tests.gd"

const BOOK := "base.cultivation_book.water_04"

func run() -> void:
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
	var detail = screen.enhancement_detail
	screen.focus_book(BOOK)
	var progress: Array = []
	for viewport in [Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		root.size = viewport
		for rank in [2, 4, 6, 8]:
			screen.progress_art.rank_selection.select_rank(rank)
			await settle()
			check(detail.visible and not screen.spell_detail.visible, "enhancement replaces odd-rank page")
			check(detail.selected_rank == rank and detail.cards.size() == 2, "correct rank has two cards")
			var entry: Dictionary = detail.enhancements[BOOK].ranks[str(rank)]
			var spell: Dictionary = detail.records[entry.spell_id]
			check(detail.labels.SpellName.text == spell.name and detail.spell_icon.texture.resource_path == spell.icon, "preceding spell summary")
			check(detail.labels.Poem.text == "“%s”" % spell.poem and not detail.labels.Description.visible, "summary includes poem but omits full spell description")
			check(not detail.labels.LearningHeading.visible and not detail.condition_icons[0].visible, "spell learning conditions are not copied")
			check(detail.artwork.texture.atlas.resource_path.ends_with("fashu1in2.webp"), "requested background")
			var current: Array = [detail.labels.Practice.text, detail.labels.ProgressValue0.text, detail.labels.ProgressValue1.text, detail.labels.ProgressValue2.text]
			if progress.is_empty(): progress = current
			check(current == progress, "shared actual progress independent of viewed rank")
			check(detail.labels.Practice.text.ends_with("/ 3600"), "stage target shown as integer")
			check(detail.labels.ProgressValue0.get_theme_font_size("font_size") == detail.labels.ProgressValue1.get_theme_font_size("font_size") and detail.labels.ProgressValue1.get_theme_font_size("font_size") == detail.labels.ProgressValue2.get_theme_font_size("font_size"), "three progress values share font size")
			check(detail.options_scroll.get_global_transform_with_canvas().get_scale().is_equal_approx(Vector2.ONE), "scroll text uses native pixels")
			var button_box: Rect2 = detail.learning_button.get_global_rect()
			check(detail.options_scroll.get_global_rect().end.y < button_box.position.y, "scroll region clears fixed button")
			check(detail.learning_button.position.is_equal_approx(Vector2(78, 1098)), "same button position as spell page")
			check(detail.cards[0].selected != detail.cards[1].selected, "exactly one selected circle")
			for index in 2:
				var card = detail.cards[index]
				var copy: Dictionary = entry.choices[index]
				check(card.record == copy and card.icon.texture.resource_path == copy.icon, "complete registered enhancement copy and art")
				check(card.description_label.text == copy.description, "enhancement prose restored")
				check(card.tags.size() == copy.categories.size(), "all classification tags")
				for point in copy.core_points.size():
					check(card.find_child("CorePoint%d" % point, true, false).text == copy.core_points[point], "all core points")
				for label: Label in card.labels:
					check(label.get_line_count() == label.get_visible_line_count(), "complete wrapped label: " + str(label.name))
					check(label.get_global_transform_with_canvas().get_scale().is_equal_approx(Vector2.ONE), "card text stays sharp")
					check(label.get_global_rect().end.x <= detail.options_scroll.get_global_rect().end.x, "text stays inside scroll width")
				var gap := roundf(float(card.config.point_gap) * card.ui_scale)
				var description: Label = card.description_label
				var description_font := description.get_theme_font("font")
				var description_size := description.get_theme_font_size("font_size")
				var description_ink := CooldownRing.ink_vertical_bounds(description_font, description.text, description_size)
				var previous_bottom: float = description.global_position.y + description.size.y - description_font.get_height(description_size) + description_font.get_ascent(description_size) + description_ink.y
				for point_index in card.point_labels.size():
					var point: Label = card.point_labels[point_index]
					var font := point.get_theme_font("font")
					var font_size := point.get_theme_font_size("font_size")
					var ink := CooldownRing.ink_vertical_bounds(font, point.text, font_size)
					var ink_top: float = point.get_global_rect().position.y + font.get_ascent(font_size) + ink.x
					check(absf(ink_top - previous_bottom - gap) <= 1, "visible paragraph gaps match image-to-first-point gap")
					var first_center: float = ink_top + (ink.y - ink.x) * 0.5
					check(absf(card.dots[point_index].get_global_rect().get_center().y - first_center) <= 1, "dot centered on first text line")
					previous_bottom = point.get_global_rect().position.y + point.size.y - font.get_height(font_size) + font.get_ascent(font_size) + ink.y
				check(absf(card.get_global_rect().end.y - previous_bottom - gap) <= 1, "last point bottom gap matches paragraph gap")
				for tag: Label in card.tags:
					var font := tag.get_theme_font("font")
					var font_size := tag.get_theme_font_size("font_size")
					var ink := CooldownRing.ink_vertical_bounds(font, tag.text, font_size)
					var style := tag.get_theme_stylebox("normal")
					var top: float = style.get_content_margin(SIDE_TOP)
					var bottom: float = style.get_content_margin(SIDE_BOTTOM)
					var center: float = top + (tag.size.y - top - bottom - font.get_height(font_size)) * 0.5 + font.get_ascent(font_size) + (ink.x + ink.y) * 0.5
					check(absf(center - tag.size.y * 0.5) <= 1, "classification ink vertically centered")
			detail.options_scroll.scroll_vertical = 0
			await settle()
			await capture(screen, "rank-%d-%d-top" % [rank, viewport.x])
			detail.options_scroll.scroll_vertical = int(detail.options_scroll.get_v_scroll_bar().max_value)
			await settle()
			await capture(screen, "rank-%d-%d-bottom" % [rank, viewport.x])
			check(detail.learning_button.get_global_rect().is_equal_approx(button_box), "button stays fixed during scrolling")
			check(detail.cards[1].get_global_rect().end.y <= detail.options_scroll.get_global_rect().end.y + 2, "second card end can be reached")
		if OS.get_environment("TECHNIQUE_ENHANCEMENT_VISUAL_ONLY") == "1": continue
		# Run input checks only when the change concerns interaction.
		screen.progress_art.rank_selection.select_rank(4)
		detail.options_scroll.scroll_vertical = 0
		await settle()
		var wheel := InputEventMouseButton.new()
		wheel.position = detail.options_scroll.get_global_rect().get_center()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		for step in 5:
			for pressed in [true, false]:
				wheel.pressed = pressed
				root.push_input(wheel, true)
		await settle()
		check(detail.options_scroll.scroll_vertical > 0, "wheel scrolls over choice content")
		detail.options_scroll.scroll_vertical = roundi(detail.cards[1].position.y)
		await settle()
		var marker: Control = detail.cards[1].marker
		var motion := InputEventMouseMotion.new()
		motion.position = marker.get_global_rect().get_center()
		root.push_input(motion, true)
		await settle()
		check(root.gui_get_hovered_control() == detail.cards[1].hit_button, "circle routes to its card button")
		for pressed in [true, false]:
			var event := InputEventMouseButton.new()
			event.position = marker.get_global_rect().get_center()
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			root.push_input(event, true)
			await settle()
		check(detail.cards[1].selected and not detail.cards[0].selected, "click second circle switches exclusively")
		check(detail.cards[1].marker.checked and not detail.cards[0].marker.checked, "checkmark follows selection")
		await capture(screen, "rank-4-%d-second-selected" % viewport.x)
		screen.progress_art.rank_selection.select_rank(3)
		await settle()
		check(not detail.visible and screen.spell_detail.visible and screen.spell_detail.labels.SpellName.text == "玄冰枪", "odd-rank spell page preserved")
		screen.progress_art.rank_selection.select_rank(4)
		await settle()
		check(detail.selected_branch == "裂冰", "preview selection survives rank switch")
		await click(detail.learning_button)
		check(map.loadout.snapshot() == before, "button and preview do not commit learning")
	screen.focus_book("base.cultivation_book.water_05")
	screen.progress_art.rank_selection.select_rank(4)
	await settle()
	check(detail.visible and not screen.spell_detail.visible and detail.current_book_id == "base.cultivation_book.water_05", "Canglan has its own enhancement page")
	screen.focus_book(BOOK)
	screen.progress_art.rank_selection.select_rank(4)
	map.loadout.knowledge.practice[BOOK] = 236.0
	map.loadout.changed.emit()
	await settle()
	check(detail.progress_bar.value == 236, "enhancement page refreshes actual book progress")
	map.loadout.knowledge.practice.erase(BOOK)
	map.queue_free()
	await settle()
	print("HANYUE ENHANCEMENT: %d checks, %d failures; input checks %s" % [checks, failures, "skipped" if OS.get_environment("TECHNIQUE_ENHANCEMENT_VISUAL_ONLY") == "1" else "included"])
	quit(1 if failures else 0)

func capture(screen: MapTechniqueScreen, suffix: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().get_region(Rect2i(screen.right_panel.get_global_rect())).save_png("res://artifacts/hanyue-enhancement-%s.png" % suffix)
