extends "res://tests/map_shop_tests.gd"

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
	var detail = screen.enhancement_detail
	var knowledge: CultivationKnowledge = map.loadout.knowledge
	var original: Dictionary = knowledge.snapshot()
	for viewport in [Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		root.size = viewport
		for book_index in range(1, 4):
			var book_id := "base.cultivation_book.water_%02d" % book_index
			screen.focus_book(book_id)
			for rank in range(1, 6):
				screen.progress_art.rank_selection.select_rank(rank)
				for eligible in [false, true]:
					knowledge.learned[book_id] = {"level": rank if eligible else rank - 1, "branches": {}}
					map.loadout.changed.emit()
					await settle()
					check(detail.visible and detail.progress_condition_icon.visible and detail.labels.EnhancementCondition.visible, "condition shown for all five-rank choices")
					check(detail.progress_requirement_met == eligible and detail.learning_button.disabled != eligible, "eligibility comes from book achievement")
					check(detail.labels.EnhancementCondition.text == ("已达到所需的修炼进度。" if eligible else "未达到所需的修炼进度。"), "exact condition text")
					check(detail.progress_condition_icon.texture.resource_path == detail.layout["condition_true_texture" if eligible else "condition_false_texture"], "matching green check / red cross")
					check(detail.labels.LearningButtonCaption.text == ("确认强化" if eligible else "无法强化"), "button caption follows eligibility")
					verify_footer(detail)
					if rank == 1:
						await capture(screen, "%02d-%d-%s" % [book_index, viewport.x, "met" if eligible else "unmet"])
					if viewport.x == 2560 and rank == 1 and OS.get_environment("TECHNIQUE_ENHANCEMENT_VISUAL_ONLY") != "1":
						var before: Dictionary = knowledge.snapshot()
						var motion := InputEventMouseMotion.new()
						motion.position = detail.learning_button.get_global_rect().get_center()
						root.push_input(motion, true)
						await settle()
						check(detail.button_art.texture.atlas.resource_path.ends_with("goldbtn.webp" if eligible else "blackbtn.webp"), "unmet button has no gold hover")
						check(detail.labels.LearningButtonCaption.get_theme_color("font_color") == (Color.BLACK if eligible else Color.WHITE), "unmet button keeps white caption")
						var event := InputEventMouseButton.new()
						event.position = motion.position
						event.button_index = MOUSE_BUTTON_LEFT
						event.pressed = true
						root.push_input(event, true)
						await create_timer(0.12).timeout
						check(is_equal_approx(detail._button_scale, 0.97 if eligible else 1.0), "disabled click stays still; eligible click retains feedback")
						event.pressed = false
						root.push_input(event, true)
						await create_timer(0.15).timeout
						check(knowledge.snapshot() == before, "preview button does not mutate learning")
						motion.position = Vector2(10, 10)
						root.push_input(motion, true)
						await settle()
	# Real progression crosses the requirement and notifies the same UI reader.
	var first := "base.cultivation_book.water_02"
	var other := "base.cultivation_book.water_03"
	knowledge.learned[first] = {"level": 0, "branches": {}}
	knowledge.practice[first] = 599.99
	knowledge.learned[other] = {"level": 0, "branches": {}}
	screen.focus_book(first)
	screen.progress_art.rank_selection.select_rank(1)
	map.loadout.changed.emit()
	await settle()
	check(detail.learning_button.disabled, "one hundredth below threshold remains unmet")
	var awarded := CultivationGrowth.award_book(map.loadout.growth, map.loadout.registry.library, knowledge, first, 1)
	map.loadout.changed.emit()
	await settle()
	check(awarded == 1 and knowledge.level(first) == 1 and not detail.learning_button.disabled, "actual earned stage unlocks progress condition")
	screen.focus_book(other)
	screen.progress_art.rank_selection.select_rank(1)
	await settle()
	check(detail.learning_button.disabled, "another book's achievement cannot unlock this book")
	for book_id in ["base.cultivation_book.water_04", "base.cultivation_book.water_05"]:
		screen.focus_book(book_id)
		screen.progress_art.rank_selection.select_rank(2)
		await settle()
		check(not detail.progress_condition_icon.visible and not detail.labels.EnhancementCondition.visible, "combat enhancement has no five-rank footer")
		check(not detail.learning_button.disabled and detail.labels.LearningButtonCaption.text == "确认强化", "combat button keeps previous behavior")
	screen.progress_art.rank_selection.select_rank(1)
	await settle()
	check(screen.spell_detail.visible and not screen.spell_detail.learning_button.disabled, "ordinary spell button unaffected")
	knowledge.learned = original.learned.duplicate(true)
	knowledge.practice = original.practice.duplicate()
	map.queue_free()
	await settle()
	print("ENHANCEMENT CONDITIONS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func verify_footer(detail) -> void:
	var transform: Transform2D = detail.canvas.get_global_transform_with_canvas()
	var button: Rect2 = detail._rect(detail.layout.learning_button_rect)
	var center_y: float = (transform * Vector2(0, (button.end.y + detail.canvas.size.y) * 0.5)).y
	var icon: TextureRect = detail.progress_condition_icon
	check(absf(icon.get_global_rect().get_center().y - center_y) <= 0.6, "icon centered below button")
	check(absf(icon.get_global_rect().get_center().x - (transform * Vector2(120, 0)).x) <= 0.6, "icon uses original spell check horizontal position")
	var label: Label = detail.labels.EnhancementCondition
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var ink := CooldownRing.ink_vertical_bounds(font, label.text, font_size)
	var top: float = label.global_position.y + font.get_ascent(font_size) + ink.x
	var bottom: float = label.global_position.y + font.get_ascent(font_size) + ink.y
	check(absf((top + bottom) * 0.5 - center_y) <= 0.6, "visible condition text shares vertical center")
	check(top > detail.learning_button.get_global_rect().end.y and bottom < (transform * detail.canvas.size).y, "condition remains in footer")
	check(label.get_line_count() == 1 and font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= label.size.x, "complete condition fits on one line")
	check(label.get_global_transform_with_canvas().get_scale().is_equal_approx(Vector2.ONE), "condition uses native pixels")

func capture(screen: MapTechniqueScreen, suffix: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().get_region(Rect2i(screen.right_panel.get_global_rect())).save_png("res://artifacts/enhancement-condition-%s.png" % suffix)
