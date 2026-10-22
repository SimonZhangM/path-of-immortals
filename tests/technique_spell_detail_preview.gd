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
	map.set_technique_open(true)
	var screen: MapTechniqueScreen = map.technique_screen
	screen.focus_book(BOOK)
	screen.progress_art.rank_selection.select_rank(3)
	await settle()
	var detail = screen.spell_detail
	check(detail.visible, "water third rank shows spell detail")
	check(detail.labels.SpellName.text == "玄冰枪", "requested spell selected")
	check(detail.labels.CorePoint0.text == "造成26点水属性伤害。", "source damage copy used")
	check(detail.labels.Condition2.text == "《寒月凝冰诀》第3重修炼完成。", "learning condition uses completed rank")
	check(detail.labels.LearningCost.text == "200", "currency has no fractional suffix")
	check(detail.progress_bar.value == 0, "initial progress reads actual zero")
	check(detail.labels.ProgressValue0.text == "2 / 8", "requested book preview starts after second rank")
	check(detail.labels.ProgressValue1.text == "第3重", "preview starts training third rank")
	check(detail.labels.ProgressValue2.text == "修炼度 3600", "third stage uses its actual requirement with a separating space")
	for rank in range(1, 9):
		screen.progress_art.rank_selection.select_rank(rank)
		var current_detail: Control = detail if rank % 2 == 1 else screen.enhancement_detail
		check(current_detail.visible and current_detail.labels.ProgressValue0.text == "2 / 8", "book progress stays visible and consistent at rank %d" % rank)
		check(detail.progress_bar.max_value == 3600 and detail.progress_bar.value == 0, "selection does not change current training target")
		check(detail.labels.SpellName.visible == (rank % 2 == 1), "odd ranks show their registered spell detail")
	screen.progress_art.rank_selection.select_rank(3)
	var other: Dictionary = detail.PracticeView.read(map.loadout, "base.cultivation_book.wood_04")
	check(other.achieved == 0 and other.target == 600, "another book has independent progress")
	map.loadout.knowledge.learned[BOOK] = {"level": 2, "branches": {}}
	map.loadout.knowledge.practice[BOOK] = 236.0
	map.loadout.spirit_stones = 199
	map.loadout.growth.realm = 2
	map.loadout.changed.emit()
	await settle()
	check(detail.progress_bar.value == 236, "actual partial progress refreshes")
	check(detail.labels.ProgressValue0.text == "2 / 8", "selected third stage retains two prerequisite ranks")
	check(detail.labels.ProgressValue1.text == "第3重", "next uncompleted rank shown")
	check(detail.condition_flags == Vector3(1, 0, 0), "real conditions drive check or cross")
	check(detail.condition_icons[0].texture.resource_path.ends_with("greengou.webp"), "satisfied condition uses green check")
	check(detail.condition_icons[1].texture.resource_path.ends_with("redcha.webp"), "unmet condition uses red cross")
	map.loadout.knowledge.practice[BOOK] = 0.0
	map.loadout.changed.emit()
	await settle()
	var before: Dictionary = map.loadout.snapshot().duplicate(true)
	for viewport in [Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		root.size = viewport
		await settle()
		for label: Label in detail.labels.values():
			if not label.is_visible_in_tree(): continue
			check(label.get_global_transform_with_canvas().get_scale().is_equal_approx(Vector2.ONE), "font renders at native pixel scale: " + str(label.name))
			check(label.get_global_rect().end.y <= screen.right_panel.get_global_rect().end.y, "text remains inside sidebar: " + str(label.name))
			check(label.get_line_count() == label.get_visible_line_count(), "text lines fit: " + str(label.name))
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var shot := root.get_texture().get_image()
			shot.save_png("res://artifacts/technique-xuanbingqiang-%d.png" % viewport.x)
			shot.get_region(Rect2i(screen.right_panel.get_global_rect())).save_png("res://artifacts/technique-xuanbingqiang-%d-right.png" % viewport.x)
		check(not detail.labels.has("CoreHeading"), "redundant core heading removed")
		check(detail.condition_icons[0].size.is_equal_approx(Vector2(30.6, 30.6)), "condition icons shrink ten percent")
		var text_end: float = detail.labels.Condition1.get_global_rect().position.x + detail.text_ink_x(detail.labels.Condition1).y
		var icon_box: Rect2 = detail.currency_icon.get_global_rect()
		var amount_start: float = detail.labels.LearningCost.get_global_rect().position.x + detail.text_ink_x(detail.labels.LearningCost).x
		check(absf((icon_box.position.x - text_end) - (amount_start - icon_box.end.x)) < 1, "currency gaps are equal between visible glyphs")
		var poem: Label = detail.labels.Poem
		var font: Font = poem.get_theme_font("font")
		var font_size: int = poem.get_theme_font_size("font_size")
		var ink := CooldownRing.ink_vertical_bounds(font, poem.text, font_size)
		var first_line_bottom := poem.get_global_rect().position.y + font.get_ascent(font_size) + ink.y
		check(absf(first_line_bottom - detail.spell_icon.get_global_rect().end.y) <= 1, "poem first line ink aligns with image bottom")
		if OS.get_environment("TECHNIQUE_DETAIL_VISUAL_ONLY") != "1":
			await button_feedback(detail, screen, viewport.x)
	screen.progress_art.rank_selection.select_rank(4)
	check(screen.enhancement_detail.visible and not detail.visible, "even rank retains shared progress in enhancement detail")
	screen.focus_book("base.cultivation_book.wood_04")
	check(not detail.visible, "other book hides detail")
	screen.focus_book(BOOK)
	screen.progress_art.rank_selection.select_rank(3)
	check(detail.visible, "return restores target detail")
	check(map.loadout.snapshot() == before, "viewing never changes progress, funds or learning")
	map.loadout.knowledge.learned[BOOK].level = 3
	map.loadout.spirit_stones = 200
	map.loadout.changed.emit()
	await settle()
	check(detail.condition_flags == Vector3.ONE, "satisfied conditions refresh from real state")
	check(detail.labels.LearningButtonCaption.text == "已领悟", "existing automatic odd-rank learning respected")
	check(detail.progress_bar.value == 0 and detail.progress_bar.max_value == 10800, "third rank completion advances shared progress to fourth rank")
	check(detail.labels.ProgressValue0.text == "3 / 8" and detail.labels.ProgressValue1.text == "第4重", "real book progress overrides temporary preview")
	map.queue_free()
	await settle()
	print("TECHNIQUE SPELL DETAIL: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func button_feedback(detail: Control, screen: MapTechniqueScreen, width: int) -> void:
	var button: Button = detail.learning_button
	var motion := InputEventMouseMotion.new()
	motion.position = button.get_global_rect().get_center()
	root.push_input(motion, true)
	await settle()
	check(detail.button_art.texture.atlas.resource_path.ends_with("goldbtn.webp"), "pointer hover uses gold art")
	check(detail.labels.LearningButtonCaption.get_theme_color("font_color") == Color.BLACK, "gold button has black text")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().get_region(Rect2i(screen.right_panel.get_global_rect())).save_png("res://artifacts/technique-xuanbingqiang-%d-hover.png" % width)
	var down := InputEventMouseButton.new()
	down.position = motion.position
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	root.push_input(down, true)
	await create_timer(0.15).timeout
	await settle()
	check(is_equal_approx(detail.button_art.scale.x, 0.97), "held button shrinks three percent (%d: %f)" % [width, detail.button_art.scale.x])
	var up := down.duplicate()
	up.pressed = false
	root.push_input(up, true)
	await create_timer(0.16).timeout
	check(is_equal_approx(detail.button_art.scale.x, 1.0), "release restores button")
	motion = InputEventMouseMotion.new()
	motion.position = Vector2(2, 2)
	root.push_input(motion, true)
	await settle()
	check(detail.button_art.texture.atlas.resource_path.ends_with("blackbtn.webp"), "pointer exit restores dark art")
	check(detail.labels.LearningButtonCaption.get_theme_color("font_color") == Color.WHITE, "dark button has white text")
