extends "res://tests/introduction_page_preview.gd"

var confirmed := {}

func capture(suffix: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(DIR + "root-panel-" + suffix + ".png")

func run() -> void:
	create_timer(40).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0, true)
	root.content_scale_size = Vector2i.ZERO
	var page = PAGE.instantiate()
	root.add_child(page)
	current_scene = page
	await settle()
	var catalog = page.root_catalog
	var counts := [0, 0, 0, 0, 0]
	for record: Dictionary in catalog.records: counts[int(record.count) - 1] += 1
	check(counts == [7, 21, 35, 5, 5], "73 equally eligible prose records, not 119 combination tickets")
	var seen := {}
	for combination: Array in catalog.configurations:
		var key := ",".join(combination)
		seen[key] = true
		check(not catalog.describe(combination).is_empty(), "every combination has matching description")
	check(seen.size() == 119, "119 distinct supported attribute combinations")
	var valid := true
	for index in 500:
		var result: Dictionary = catalog.draw()
		var unique := {}
		for id in result.elements: unique[id] = true
		valid = valid and unique.size() == int(result.count)
		valid = valid and result.name in ["四灵根", "五灵根"] if int(result.count) >= 4 else valid
	check(valid, "random results use unique attributes and clean titles")
	page.creation_draft.set_manual_name("欧阳澈")
	page.creation_draft.gender = "male"
	page.show_page(4)
	await settle()
	var panel = page.root_panel
	check(panel.root_name.text == "请选择灵根" and panel._phrase_text == "静候灵机 · 探寻仙缘", "initial copy")
	check(panel.enter_button.disabled and not panel.random_button.disabled, "requires result before enter")
	print("BODY_FONT=", panel._harmony.get_font_name())
	check(panel._harmony.get_font_name().contains("Harmony"), "Huawei Harmony regular available")
	for viewport in [Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		root.size = viewport
		await settle()
		check(page.get_global_rect().encloses(panel.get_global_rect()), "right panel within viewport")
		check(panel._random_caption.get_theme_font_size("font_size") < panel._enter_caption.get_theme_font_size("font_size"), "random caption smaller")
		for record: Dictionary in catalog.records:
			panel.show_result(record)
			await process_frame
			var text_height: float = panel.description.get_line_count() * panel.description.get_line_height() + maxi(0, panel.description.get_line_count() - 1) * panel.description.get_theme_constant("line_spacing")
			var available: float = panel._config.description_rect[3] * panel.size.y / panel._source.y
			check(text_height <= available + 2, "description fits authored band")
		panel.show_result({})
		await settle()
		await capture("empty-" + str(viewport.x))
	var before := Time.get_ticks_msec()
	await click(panel.random_button)
	check(page.root_selection_spin.active and panel.random_button.disabled and panel.enter_button.disabled, "roll locks both actions")
	check(page.creation_draft.root_selection.is_empty() and panel.root_name.text == "请选择灵根", "result withheld until rotation ends")
	await page.root_result_revealed
	check(Time.get_ticks_msec() - before >= 1000, "full one second rotation")
	check(panel.root_name.text == page.creation_draft.root_selection.name, "panel and draft agree")
	check(page.root_selection_effects.get_selected_roots() == page.creation_draft.root_selection.elements, "left highlight matches result")
	check(not panel.enter_button.disabled and not panel.random_button.disabled, "actions enabled on complete")
	await capture("random")
	page.preparation_requested.connect(func(details: Dictionary): confirmed = details)
	await click(panel.enter_button)
	check(confirmed.has("root_selection") and confirmed.root_selection == page.creation_draft.root_selection, "enter emits current draft hook")
	var previous: Dictionary = page.creation_draft.root_selection.duplicate(true)
	await click(panel.random_button)
	page.show_page(3)
	page.show_page(4)
	check(page.creation_draft.root_selection == previous and not page.root_selection_spin.active, "cancel keeps prior completed result")
	check(not panel.random_button.disabled and panel.root_name.text == previous.name, "return restores usable panel")
	for combination in [["wood", "water"], ["metal", "wood", "water", "fire"], ["metal", "water", "earth", "wind", "thunder"]]:
		panel.show_result(catalog.describe(combination))
		page.root_selection_effects.set_selected_roots(combination)
		await settle()
		await capture(str(combination.size()) + "-roots")
	print("ROOT_PANEL_CHECKS=", checks, " FAILURES=", failures)
	quit(1 if failures else 0)
