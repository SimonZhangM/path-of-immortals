extends "res://tests/introduction_page_preview.gd"

var completions := 0

func run() -> void:
	create_timer(30).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0, true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1920, 1080)
	var page = PAGE.instantiate()
	root.add_child(page)
	current_scene = page
	await settle()
	check(not page.play_root_selection_result(["fire"]), "wrong page rejects spin")
	page.show_page(4)
	await settle()
	var spin = page.root_selection_spin
	var core: TextureRect = page.root_selection_core
	var effects = page.root_selection_effects
	page.root_result_revealed.connect(func(_ids): completions += 1)
	check(not spin.active and not effects.visible and core.rotation == 0, "idle initially")
	check(is_equal_approx(page._page.root_selection_art.offset[0], -5.0) and is_zero_approx(page._page.root_selection_art.offset[1]), "both layers use latest shared horizontal offset")
	for viewport in [Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		root.size = viewport
		await settle()
		check(core.get_global_rect().is_equal_approx(page.root_selection_art.get_global_rect()), "two layers share display rect")
		check(core.pivot_offset.is_equal_approx(core.size * Vector2(610.0 / 1226, 706.0 / 1400)), "visible center remains pivot after resize")
	check(not page.play_root_selection_result(["invalid"]), "invalid root rejected")
	check(not page.play_root_selection_result([]), "empty result rejected")
	check(page.play_root_selection_result(["fire"]), "start fire result")
	spin.set_process(false)
	check(not page.play_root_selection_result(["wood"]), "repeat start ignored")
	for step in 30:
		spin._advance_elapsed((float(step) + 0.1) / 30.0)
		check(spin.frame == step and is_equal_approx(core.rotation, TAU * step / 30.0), "30Hz quantized pose")
		check(not effects.visible and completions == 0, "no result before full turn")
	spin._advance_elapsed(0.9999)
	check(spin.active and spin.frame == 29, "still turning before one second")
	spin._advance_elapsed(1.0)
	check(not spin.active and core.rotation == 0 and effects.get_selected_roots() == ["fire"] and completions == 1, "exactly one second reveals fire once")
	spin._advance_elapsed(3.0)
	check(completions == 1, "completion emitted once")
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(DIR + "root-spin-result.png")
	page.play_root_selection_result(["wood", "water"])
	spin.set_process(false)
	spin._advance_elapsed(0.25)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(DIR + "root-spin-mid.png")
	page.show_page(3)
	check(not spin.active and core.rotation == 0 and completions == 1, "leaving page cancels without result")
	page.show_page(4)
	check(effects.get_selected_roots() == ["fire"], "cancellation restores prior result")
	var began := Time.get_ticks_msec()
	page.play_root_selection_result(["wood", "water"])
	await page.root_result_revealed
	var elapsed := Time.get_ticks_msec() - began
	check(elapsed >= 1000 and elapsed < 1400, "real playback lasts one second")
	check(effects.get_selected_roots() == ["wood", "water"] and completions == 2, "multiple roots revealed together")
	var pool: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/character_name_pool.json"))
	var draft = page.Draft.new(pool.names)
	var last := ""
	for cycle in 20:
		var seen: Array[String] = []
		for draw in 5:
			var next: String = draft.draw_name()
			check(not seen.has(next) and next != last, "shuffle bag unique and no adjacent repeat")
			seen.append(next)
			last = next
	print("ROOT_SPIN_CHECKS=", checks, " FAILURES=", failures, " PLAYBACK_MS=", elapsed)
	quit(1 if failures else 0)
