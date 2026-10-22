extends "res://tests/map_shop_tests.gd"

# Content/layout only: no mouse injection, gameplay, or real save writes.
const METAL_BOOKS := {
	"base.cultivation_book.metal_01": "xuanjinbailianlu",
	"base.cultivation_book.metal_02": "gengjinzhenjie",
	"base.cultivation_book.metal_03": "jinshacangfengjing",
	"base.cultivation_book.metal_04": "xuangengjianjue",
	"base.cultivation_book.metal_05": "baibingyulingjue",
}

func preview_books() -> Dictionary:
	return METAL_BOOKS

func preview_element() -> String:
	return "metal"

func run() -> void:
	var books := preview_books()
	var element := preview_element()
	AudioServer.set_bus_mute(0, true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(2560, 1440)
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
	screen.category_buttons[["metal", "wood", "water", "fire", "earth", "wind", "thunder"].find(element)].button_pressed = true
	await settle()
	check(screen.overview.records.has_all(books.keys()), "all five %s overviews registered" % element)
	for book_id: String in books:
		for card in screen.book_cards:
			if card.book_id == book_id: card.button_pressed = true
		await settle()
		var overview: Control = screen.overview
		var record: Dictionary = overview.records[book_id]
		var source_copy := FileAccess.get_file_as_string("res://" + record.source_document)
		check(source_copy.contains(record.origin), "complete origin matches the established source document")
		var normalized_copy := source_copy.replace("\r", "").replace("\n", "").replace(" ", "").replace(">", "")
		check(normalized_copy.contains(String(record.poem).replace("\n", "")), "poem matches source, with display line breaks only")
		for viewport_size in [Vector2i(1920,1080), Vector2i(2560,1080), Vector2i(2560,1440)]:
			root.size = viewport_size
			await settle()
			var bounds := overview.get_global_rect()
			check(overview.visible and overview.selected_book_id == book_id, "correct overview displayed")
			check(bounds.end.y < screen.progress_title.get_global_rect().get_center().y, "upper overview stays above divider")
			var book: TextureRect = overview.artwork.book
			var line_mid_y := (screen.middle_panel.get_global_rect().position.y + screen.progress_title.get_global_rect().get_center().y) * 0.5
			check(absf(book.get_global_rect().get_center().y - line_mid_y) < 0.01, "visible book centered between upper rim and divider")
			var metrics := preload("res://scripts/map/map_texture_metrics.gd").inspect(book.texture.atlas)
			var used := Rect2(metrics.used_rect)
			var visible_art := Rect2(metrics.visible_rect)
			var old_box := Rect2(overview.size.x * 0.36, 10, overview.size.x * 0.45, overview.size.y - 22)
			var previous_scale := minf(old_box.size.x / used.size.x, old_box.size.y / used.size.y)
			check(book.size.is_equal_approx(visible_art.size * previous_scale), "visible book physical size unchanged")
			var previous_x := old_box.position.x + (old_box.size.x - used.size.x * previous_scale) * 0.5 + (visible_art.position.x - used.position.x) * previous_scale
			check(is_equal_approx((book.position.x - previous_x) * overview.get_global_transform_with_canvas().get_scale().x, 10.0), "visible book moves right ten screen pixels")
			check(screen.progress_art.visible == screen.progress_art.books.has(book_id), "lower charts follow their own registry")
			for key: String in overview.artwork:
				var art: TextureRect = overview.artwork[key]
				check(art.texture.atlas.resource_path == record[key] and String(record[key]).contains("UI-%s-%s-" % [element, books[book_id]]), "own artwork bound: " + key)
				check(bounds.encloses(art.get_global_rect()), "complete art fits: " + key)
				check(art.texture.atlas.get_image().has_mipmaps(), "mipmaps enabled: " + key)
				check(is_equal_approx(art.size.x / art.size.y, art.texture.get_width() / float(art.texture.get_height())), "art preserves aspect: " + key)
			for label: Label in [overview.poem, overview.origin]:
				check(bounds.encloses(label.get_global_rect()), "full copy fits upper region")
				check(label.get_global_transform_with_canvas().get_scale().is_equal_approx(Vector2.ONE), "text renders at native pixel scale")
				check(label.get_theme_color("font_color") == Color("f1ead6"), "same light cream typography")
			check(overview.poem.text == record.poem and overview.origin.text == record.origin, "copy has no omissions")
			check(not overview.copy_box.get_global_rect().intersects(overview.artwork.book.get_global_rect()), "book avoids copy")
			if DisplayServer.get_name() != "headless" and viewport_size == Vector2i(2560,1440):
				await RenderingServer.frame_post_draw
				var shot := root.get_texture().get_image()
				shot.get_region(Rect2i(bounds)).save_png("res://artifacts/technique-overview-%s.png" % books[book_id])
				shot.save_png("res://artifacts/technique-%s-%s.png" % [element, books[book_id]])
	# Upper art is registered independently from the lower skill tree.
	check(screen.progress_art.content.book_id.begins_with("base.cultivation_book.%s_" % element), "upper artwork has its own element's lower content")
	screen.overview.show_book("base.cultivation_book.unknown_01")
	check(not screen.overview.visible, "unregistered books do not borrow another overview")
	screen.overview.show_book("base.cultivation_book.wood_05")
	check(screen.overview.visible and screen.overview.poem.text == screen.overview.records["base.cultivation_book.wood_05"].poem, "switching back restores the existing wood overview")
	check(map.loadout.snapshot() == before, "presentation does not change player state")
	map.queue_free()
	await settle()
	print("%s OVERVIEWS: %d checks, %d failures" % [element.to_upper(), checks, failures])
	quit(1 if failures else 0)
