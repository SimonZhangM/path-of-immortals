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
	check(map.startup_error.is_empty(), "map starts with isolated state")
	if not map.startup_error.is_empty(): quit(1); return
	var before: Dictionary = map.loadout.snapshot().duplicate(true)
	map.set_technique_open(true)
	var screen: MapTechniqueScreen = map.technique_screen
	if OS.get_environment("TECHNIQUE_RANK_VISUAL_ONLY") == "1":
		await visual_checks(screen)
		check(map.loadout.snapshot() == before, "visual changes leave learning and resources unchanged")
		map.queue_free()
		await settle()
		print("TECHNIQUE RANK VISUAL: %d checks, %d failures" % [checks, failures])
		quit(1 if failures else 0)
		return
	screen.focus_book("base.cultivation_book.water_04")
	await settle()
	var art = screen.progress_art
	var selection = art.rank_selection
	check(selection.rank_buttons.size() == 8, "eight independent rank buttons")
	for rank in range(1, 9):
		await click(selection.rank_buttons[rank - 1])
		check(selection.selected_rank == rank, "circle click selects rank %d" % rank)
		check(selection.rank_buttons.filter(func(b): return b.button_pressed).size() == 1, "only one selected circle")
		check(selection.card_buttons.filter(func(b): return b.button_pressed).size() == 1, "only one selected frame")
	await click(selection.card_buttons[2])
	check(selection.selected_rank == 3, "card click selects matching rank")
	await click(selection.rank_buttons[2])
	check(selection.selected_rank == 3 and selection.rank_buttons[2].button_pressed, "click selected rank keeps it selected")
	var circle: Button = selection.rank_buttons[2]
	check(not circle._has_point(Vector2.ZERO), "transparent corner of circle does not capture input")
	# Keyboard activation uses the same native Button command as pointer input.
	selection.rank_buttons[3].grab_focus()
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_SPACE
		key.pressed = pressed
		root.push_input(key, true)
	await settle()
	check(selection.selected_rank == 4, "focused rank supports keyboard activation")
	await click(selection.rank_buttons[2])
	for suffix in ["01", "02", "03"]:
		screen.focus_book("base.cultivation_book.wood_" + suffix)
		await settle()
		selection = art.rank_selection
		check(selection.rank_buttons.size() == 5, "five-rank layout has five choices")
		await click(selection.card_buttons[4])
		check(selection.selected_rank == 5, "five-rank final card selects without overlap")
		await click(selection.rank_buttons[2])
		check(selection.selected_rank == 3, "five-rank ring selects corresponding column")
		if suffix == "03": await capture(screen, "five-three")
	screen.focus_book("base.cultivation_book.water_04")
	await settle()
	check(art.rank_selection.selected_rank == 3, "return to book retains its browsed rank")
	for viewport in [Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		root.size = viewport
		await settle()
		selection = art.rank_selection
		await click(selection.rank_buttons[2])
		check(selection.selected_rank == 3, "scaled circle remains clickable")
		for button in selection.card_buttons:
			check(screen.middle_panel.get_global_rect().encloses(button.get_global_rect()), "card hit area stays in middle panel")
		await capture(screen, "water-third-%d" % viewport.x)
	# Every element uses its own original texture with the same selection geometry.
	for element in ["metal", "wood", "water", "fire", "earth", "wind", "thunder"]:
		for suffix in ["01", "02", "03", "04", "05"]:
			screen.focus_book("base.cultivation_book.%s_%s" % [element, suffix])
			await process_frame
			selection = art.rank_selection
			selection.select_rank(3)
			check(selection._selected_glow.material.get_shader_parameter("artwork") == art.texture.atlas, "highlight traces selected book's own art")
			check(selection._selected_glow.visible, "selected frame available for all thirty-five books")
	check(map.loadout.snapshot() == before, "browsing does not learn skills, choose branches or change resources")
	map.queue_free()
	await settle()
	print("TECHNIQUE RANK SELECTION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func capture(screen: MapTechniqueScreen, suffix: String) -> void:
	if DisplayServer.get_name() == "headless": return
	# Clear cursor/focus preview so screenshots show only the selected rank.
	var selection = screen.progress_art.rank_selection
	selection._hovered_rank = 0
	selection._focused_rank = 0
	selection._update_glows()
	await RenderingServer.frame_post_draw
	var shot := root.get_texture().get_image()
	shot.save_png("res://artifacts/technique-rank-%s.png" % suffix)
	var panel: Rect2 = screen.middle_panel.get_global_rect()
	var art: Rect2 = screen.progress_art.get_global_rect()
	var crop := Rect2i(Vector2(panel.position.x, art.position.y - 12), Vector2(panel.size.x, art.size.y + 24))
	shot.get_region(crop).save_png("res://artifacts/technique-rank-%s-detail.png" % suffix)

# Visual-only requests deliberately skip the mouse/keyboard checks above.
func visual_checks(screen: MapTechniqueScreen) -> void:
	root.size = Vector2i(2560, 1440)
	var categories: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/technique_categories.json"))
	for category: Dictionary in categories:
		var element: String = category.element_id.get_slice(".", 2)
		for suffix in ["01", "02", "03", "04", "05"]:
			screen.focus_book("base.cultivation_book.%s_%s" % [element, suffix])
			await settle()
			var selection = screen.progress_art.rank_selection
			selection.select_rank(4)
			check(selection.theme_color == Color(category.color), "selection shares existing element category color")
			check(screen.spell_detail.visible == (element == "water" and suffix in ["04", "05"]), "configured book retains shared progress; other right sidebars stay empty")
			check(screen.right_panel.find_children("*", "Button", true, false).filter(func(button): return button.is_visible_in_tree()).is_empty(), "unconfigured right sidebar contains no visible buttons")
			if suffix == "04": await capture(screen, "theme-" + element)
	for sample in [{"book": "water_01", "level": 4}, {"book": "water_02", "level": 4}, {"book": "water_03", "level": 3}, {"book": "water_04", "level": 4}]:
		screen.focus_book("base.cultivation_book." + sample.book)
		await settle()
		var selection = screen.progress_art.rank_selection
		selection.select_rank(sample.level)
		selection._hovered_rank = 0
		selection._focused_rank = 0
		selection._update_glows()
		if DisplayServer.get_name() == "headless": continue
		await RenderingServer.frame_post_draw
		var highlighted := root.get_texture().get_image()
		selection._selected_glow.hide()
		await RenderingServer.frame_post_draw
		var original := root.get_texture().get_image()
		selection._selected_glow.show()
		var geometry: Dictionary = selection.geometry[sample.level - 1]
		var card: Rect2 = geometry.card
		# The two header ornaments must both be affected, beyond just the horizontal rim.
		for side in [0, 1]:
			var decoration := Rect2(card.position + Vector2(14 if side == 0 else card.size.x - 40, 12), Vector2(26, 24))
			check(pixel_delta(screen.progress_art, original, highlighted, decoration) > 0.025, "header ornament is highlighted: %s side %d" % [sample.book, side])
		# Neither side of the existing connector receives a thicker luminous segment.
		var ring: Vector2 = geometry.ring
		for side in [-1, 1]:
			var start_x: float = ring.x + (geometry.ring_radius + 5 if side > 0 else -geometry.ring_radius - 29)
			var connector := Rect2(Vector2(start_x, ring.y - 3), Vector2(24, 6))
			check(pixel_delta(screen.progress_art, original, highlighted, connector) < 0.005, "connector pixels unchanged: %s side %d" % [sample.book, side])
		await capture(screen, "revised-" + sample.book)

func pixel_delta(art: TextureRect, before: Image, after: Image, source: Rect2) -> float:
	var crop: Array = art.reference.display_crop
	var factor := art.size / Vector2(crop[2], crop[3])
	var transform := art.get_global_transform_with_canvas()
	var corner: Vector2 = transform * ((source.position - Vector2(crop[0], crop[1])) * factor)
	var extent: Vector2 = source.size * factor * transform.get_scale()
	var rect := Rect2i(corner.round(), extent.round())
	var total := 0.0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var a := before.get_pixel(x, y)
			var b := after.get_pixel(x, y)
			total += maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))
	return total / maxf(1, rect.size.x * rect.size.y)
