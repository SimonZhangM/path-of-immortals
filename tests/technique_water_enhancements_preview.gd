extends "res://tests/map_shop_tests.gd"

# Defaults to water; TECHNIQUE_ENHANCEMENT_ELEMENT selects any of seven elements.
# Isolated state, no learning or save writes.
var element := "water"

func run() -> void:
	if not OS.get_environment("TECHNIQUE_ENHANCEMENT_ELEMENT").is_empty():
		element = OS.get_environment("TECHNIQUE_ENHANCEMENT_ELEMENT")
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
	var page_count := 0
	var choice_count := 0
	for viewport in [Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		root.size = viewport
		for book_index in range(1, 6):
			var book_id := "base.cultivation_book.%s_%02d" % [element, book_index]
			screen.focus_book(book_id)
			var progress: Array = []
			var ranks: Array = [2, 4, 6, 8] if book_index >= 4 else [1, 2, 3, 4, 5]
			for rank: int in ranks:
				screen.progress_art.rank_selection.select_rank(rank)
				await settle()
				page_count += 1
				var page: Dictionary = detail.enhancements[book_id].ranks[str(rank)]
				var expected_count := 3 if book_index == 3 else 2
				check(detail.visible and not screen.spell_detail.visible, "correct sidebar is visible")
				check(detail.current_book_id == book_id and detail.selected_rank == rank, "correct book/rank")
				check(detail.cards.size() == expected_count, "all choices for rank")
				check(detail.artwork.texture.atlas.resource_path.ends_with("fashu1in%d.webp" % expected_count), "matching two/three choice background")
				check(detail.artwork.texture.atlas.get_image().has_mipmaps(), "background has mipmaps")
				var combat := book_index >= 4
				check(detail.spell_icon.visible == combat and detail.labels.SpellName.visible == combat, "prerequisite only appears on combat pages")
				check(not detail.labels.Description.visible and not detail.labels.LearningHeading.visible, "no inherited spell description/conditions")
				check(not detail.body_scroll.visible, "full spell body never leaks into enhancement sidebar")
				if combat:
					var spell: Dictionary = page.prerequisite
					check(detail.selected_spell_id == page.spell_id and detail.labels.SpellName.text == spell.name and detail.spell_icon.texture.resource_path == spell.icon, "correct prerequisite spell summary")
					var visible_categories: Array = detail.visible_spell_categories(spell)
					for index in visible_categories.size():
						var tag: Label = detail.labels["Category%d" % index]
						check(tag.visible and tag.text == visible_categories[index], "visible prerequisite categories present")
						check(tag.get_theme_font("font").get_string_size(tag.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tag.get_theme_font_size("font_size")).x <= tag.size.x + 1, "prerequisite tag text fits")
						check(tag.get_global_rect().end.y < detail.labels.Poem.get_global_rect().position.y + 2, "summary tags clear poem")
					var poem: Label = detail.labels.Poem
					var poem_bottom := ink_box(poem).y - poem.size.y + poem.get_minimum_size().y
					check(poem_bottom < detail.options_scroll.get_global_rect().position.y, "summary poem clears enhancement cards")
				else:
					for index in detail.category_count:
						check(not detail.labels["Category%d" % index].visible, "no stale prerequisite categories")
				var current: Array = [detail.labels.Practice.text, detail.labels.ProgressValue0.text, detail.labels.ProgressValue1.text, detail.labels.ProgressValue2.text]
				if progress.is_empty(): progress = current
				check(current == progress, "book progress unchanged across ranks")
				var actual: Dictionary = detail.PracticeView.read(map.loadout, book_id)
				check(detail.labels.ProgressValue0.text == "%d / %d" % [actual.achieved, 8 if combat else 5], "correct five/eight rank progress denominator")
				check(detail.labels.Practice.text.ends_with("/ %d" % int(actual.target)), "integer actual target")
				check(detail.labels.ProgressValue0.get_theme_font_size("font_size") == detail.labels.ProgressValue1.get_theme_font_size("font_size") and detail.labels.ProgressValue1.get_theme_font_size("font_size") == detail.labels.ProgressValue2.get_theme_font_size("font_size"), "progress value font sizes match")
				var scroll_box: Rect2 = detail.options_scroll.get_global_rect()
				var button_box: Rect2 = detail.learning_button.get_global_rect()
				check(scroll_box.end.y < button_box.position.y, "options clear fixed button")
				check(detail.options_scroll.position.y > 590 if combat else detail.options_scroll.position.y < 440, "standalone cards use freed summary space")
				var selected_count := 0
				for index in expected_count:
					var card = detail.cards[index]
					var entry: Dictionary = page.choices[index]
					choice_count += 1
					if card.selected: selected_count += 1
					check(card.marker.checked == card.selected, "circle check reflects selection")
					check(card.record == entry and card.icon.texture.resource_path == entry.icon, "correct registered text and art")
					check(card.description_label.text == entry.description and not entry.description.is_empty(), "full description restored")
					check(card.tags.size() == entry.categories.size() and card.point_labels.size() == entry.core_points.size(), "all categories and points present")
					if book_index != 1:
						check(map.loadout.registry.library.books[book_id].branches[str(rank)].has(entry.branch_key), "published gameplay branch ID retained")
					else:
						check(entry.branch_key.begins_with("ui.enhancement.%s_01." % element), "craft preview has separate UI identity")
					var accent := Color("69dcff")
					for theme: Dictionary in detail.themes:
						if element != "water" and theme.element_id == "base.element." + element:
							accent = Color(theme.color)
					check(card.theme_color.is_equal_approx(accent), "selection uses own element theme")
					verify_card(card, scroll_box)
				check(selected_count == 1, "exactly one of two/three selected")
				detail.options_scroll.scroll_vertical = 0
				await settle()
				await capture(screen, "%02d-rank-%d-%d-top" % [book_index, rank, viewport.x])
				detail.options_scroll.scroll_vertical = int(detail.options_scroll.get_v_scroll_bar().max_value)
				await settle()
				check(detail.cards[-1].get_global_rect().end.y <= scroll_box.end.y + 2, "last option and complete text reachable")
				check(detail.learning_button.get_global_rect().is_equal_approx(button_box), "button stays fixed")
				await capture(screen, "%02d-rank-%d-%d-bottom" % [book_index, rank, viewport.x])
				if not combat:
					var knowledge: CultivationKnowledge = map.loadout.knowledge
					var original: Dictionary = knowledge.learned.duplicate(true)
					for eligible in [false, true]:
						knowledge.learned[book_id] = {"level": rank if eligible else rank - 1, "branches": {}}
						detail.show_selection(book_id, rank, map.loadout)
						check(detail.progress_requirement_met == eligible and detail.learning_button.disabled != eligible, "each book/rank reads own learning eligibility")
						check(detail.labels.EnhancementCondition.text == ("已达到所需的修炼进度。" if eligible else "未达到所需的修炼进度。"), "condition copy follows true achievement")
					knowledge.learned = original
					detail.show_selection(book_id, rank, map.loadout)
	check(page_count == 46 and choice_count == 102, "23 pages / 51 choices at each resolution")
	if OS.get_environment("TECHNIQUE_ENHANCEMENT_VISUAL_ONLY") != "1":
		# New three-way selection: scrolling to and clicking the third choice.
		screen.focus_book("base.cultivation_book.water_03")
		screen.progress_art.rank_selection.select_rank(1)
		await settle()
		detail.options_scroll.scroll_vertical = int(detail.cards[2].position.y)
		await settle()
		var chosen: String = detail.cards[2].record.branch_key
		await click(detail.cards[2].marker)
		check(detail.selected_branch == chosen and detail.cards[2].marker.checked, "third choice is clickable")
		check(not detail.cards[0].selected and not detail.cards[1].selected, "third choice deselects first two")
		screen.focus_book("base.cultivation_book.water_02")
		screen.progress_art.rank_selection.select_rank(1)
		await settle()
		detail.options_scroll.scroll_vertical = int(detail.cards[1].position.y)
		await settle()
		var second: String = detail.cards[1].record.branch_key
		await click(detail.cards[1].marker)
		check(detail.selected_branch == second and not detail.cards[0].selected, "new five-rank pair selects exclusively")
		screen.focus_book("base.cultivation_book.water_03")
		screen.progress_art.rank_selection.select_rank(1)
		await settle()
		check(detail.selected_branch == chosen, "three-way preview survives book switch")
		await click(detail.learning_button)
		await capture(screen, "03-third-selected")
	detail.show_selection("base.cultivation_book.%s_04" % element, 3, map.loadout)
	check(not detail.visible, "odd spell rank never shows enhancement cards")
	check(map.loadout.snapshot() == before, "browsing and choice preview leave state unchanged")
	map.queue_free()
	await settle()
	print("%s ENHANCEMENTS: %d checks, %d failures; input checks %s" % [element.to_upper(), checks, failures, "skipped" if OS.get_environment("TECHNIQUE_ENHANCEMENT_VISUAL_ONLY") == "1" else "included"])
	quit(1 if failures else 0)

func ink_box(label: Label) -> Vector2:
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var ink := CooldownRing.ink_vertical_bounds(font, label.text, font_size)
	var baseline: float = label.global_position.y + font.get_ascent(font_size)
	return Vector2(baseline + ink.x, baseline + label.size.y - font.get_height(font_size) + ink.y)

func verify_card(card, scroll_box: Rect2) -> void:
	for label: Label in card.labels:
		check(label.get_line_count() == label.get_visible_line_count(), "all lines visible: " + str(label.name))
		check(label.get_global_transform_with_canvas().get_scale().is_equal_approx(Vector2.ONE), "native pixel text")
		check(label.get_global_rect().end.x <= scroll_box.end.x, "text stays inside width")
	var gap := roundf(float(card.config.point_gap) * card.ui_scale)
	var description := ink_box(card.description_label)
	check(absf(description.x - card.icon.get_global_rect().end.y - gap) <= 1, "description clears image with standard gap")
	var previous_bottom: float = description.y
	for index in card.point_labels.size():
		var point: Label = card.point_labels[index]
		var box := ink_box(point)
		check(absf(box.x - previous_bottom - gap) <= 1, "description and points use equal visible gaps")
		var font := point.get_theme_font("font")
		var ink := CooldownRing.ink_vertical_bounds(font, point.text, point.get_theme_font_size("font_size"))
		check(absf(card.dots[index].get_global_rect().get_center().y - box.x - (ink.y - ink.x) * 0.5) <= 1, "diamond centered on first line")
		previous_bottom = box.y
	check(absf(card.get_global_rect().end.y - previous_bottom - gap) <= 1, "bottom gap matches body gaps")

func capture(screen: MapTechniqueScreen, suffix: String) -> void:
	if DisplayServer.get_name() == "headless": return
	# One representative stage per book, plus the long five-category summaries.
	if element != "water" and not "rank-1-" in suffix and not "rank-8-" in suffix and not (element == "thunder" and suffix.begins_with("05-rank-2-")) and not (element == "earth" and suffix.begins_with("05-rank-6-")): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().get_region(Rect2i(screen.right_panel.get_global_rect())).save_png("res://artifacts/%s-enhancement-%s.png" % [element, suffix])
