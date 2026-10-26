extends "res://tests/introduction_page_preview.gd"

func run() -> void:
	create_timer(25).timeout.connect(func(): quit(2))
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i.ZERO
	var page = PAGE.instantiate()
	root.add_child(page)
	current_scene = page
	page.show_page(4)
	var effects = page.root_selection_effects
	check(not effects.visible and effects.get_selected_roots().is_empty(), "no default selection or automatic effect")
	var ids := ["metal", "wood", "water", "fire", "earth", "wind", "thunder"]
	for id: String in ids:
		check(not effects._rings[id].visible, "each ring starts hidden")
		effects._rings[id].material.set_shader_parameter("animate", false)
		effects._rings[id].material.set_shader_parameter("preview_time", 0.7)
	for viewport_size in [Vector2i(2560,1440), Vector2i(1920,1080)]:
		root.size = viewport_size
		await settle()
		check(page._page.root_selection_art.offset == [-9.0, 0.0], "six pixels right from prior minus fifteen")
		check(effects.mouse_filter == Control.MOUSE_FILTER_IGNORE, "effect does not intercept inputs")
		check(effects.size.is_equal_approx(page.root_selection_art.size), "effect follows scaled art")
		for id: String in ids:
			check(effects.set_selected_roots([id]), "single element accepted")
			for other: String in ids:
				check(effects._rings[other].visible == (other == id), "only requested root is highlighted")
			var ring: ColorRect = effects._rings[id]
			var radii: Vector2 = ring.material.get_shader_parameter("radii")
			check(radii.x > 0 and radii.y > 0, "independently configured ellipse radii are valid")
			check(page.root_selection_art.get_global_rect().encloses(ring.get_global_rect()), "full halo fits source artwork bounds")
		check(effects.set_selected_roots(["fire"]), "fire selection for preview")
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(DIR + "root-selected-fire-%d.png" % viewport_size.x)
		check(not effects.set_selected_roots(["invalid"]), "unknown ID rejected")
		check(effects.get_selected_roots() == ["fire"], "invalid selection does not corrupt existing effect")
		effects.set_selected_roots(ids)
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(DIR + "root-selected-all-%d.png" % viewport_size.x)
		effects.clear_selection()
		check(not effects.visible, "clear hides overlay")
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(DIR + "root-unselected-%d.png" % viewport_size.x)
	page.show_page(3)
	page.show_page(4)
	check(not effects.visible, "revisiting does not activate effect")
	print("ROOT SELECTION EFFECTS: %d checks; %d failures" % [checks, failures])
	quit(1 if failures else 0)
