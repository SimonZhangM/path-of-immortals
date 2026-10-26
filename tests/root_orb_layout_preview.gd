extends "res://tests/introduction_page_preview.gd"
## Static render only: no input events, animation waits, or save writes.

func run() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0, true)
	root.content_scale_size = Vector2i.ZERO
	var page = PAGE.instantiate()
	root.add_child(page)
	current_scene = page
	await settle()
	page.creation_draft.set_manual_name("林知秋")
	page.creation_draft.gender = "female"
	page.show_page(4)
	await settle()
	var panel = page.root_panel
	check(panel.root_orbs.all(func(orb): return not orb.visible), "no circles before a result")
	for id in ["metal", "wood", "water", "fire", "earth", "wind", "thunder"]:
		panel.show_result(page.root_catalog.describe([id]))
		check(panel.root_orbs[0].texture.resource_path == "res://assets/UI-root-%s-orb.webp" % id, "single root uses its own element artwork")
	var examples := [["wood"], ["wood", "water"], ["water", "earth", "thunder"], ["metal", "wood", "water", "fire"], ["metal", "water", "earth", "wind", "thunder"]]
	if OS.get_environment("ROOT_ORB_ALIGNMENT_ONLY") == "1":
		examples = [["wind"], ["water", "thunder"]]
	for viewport in [Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		root.size = viewport
		await settle()
		for elements: Array in examples:
			panel.show_result(page.root_catalog.describe(elements))
			page.root_selection_effects.set_selected_roots(elements)
			await settle()
			var visible: Array = panel.root_orbs.filter(func(orb): return orb.visible)
			check(visible.size() == elements.size(), "result circle count matches")
			var valid := true
			for orb: TextureRect in visible:
				valid = valid and orb.texture != null and absf(orb.size.x - orb.size.y) < 0.02
				valid = valid and panel.get_global_rect().encloses(orb.get_global_rect())
				valid = valid and orb.mouse_filter == Control.MOUSE_FILTER_IGNORE
				if elements.size() >= 4:
					var key := "four" if elements.size() == 4 else "five"
					valid = valid and orb.texture.resource_path == "res://assets/UI-root-pseudo-%s-orb.webp" % key
			check(valid, "square circles use proper assets and remain within panel")
			if elements.size() <= 2:
				# The background's painted horizontal connector is at source y=305.
				var line_y: float = panel.global_position.y + 305.0 / 1450.0 * panel.size.y
				check(visible.all(func(orb): return absf(orb.get_global_rect().get_center().y - line_y) < 0.1), "single and dual circles share the painted array centerline")
			if elements.size() == 5:
				check(is_equal_approx(visible[0].position.y, visible[1].position.y) and visible[2].position.y > visible[0].position.y and is_equal_approx(visible[2].position.y, visible[3].position.y) and is_equal_approx(visible[3].position.y, visible[4].position.y), "five roots arranged two above three below")
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(DIR + "root-orbs-%d-%d.png" % [elements.size(), viewport.x])
	panel.show_result({})
	check(panel.root_orbs.all(func(orb): return not orb.visible and orb.texture == null), "clearing result removes stale circles")
	print("ROOT_ORB_LAYOUT_CHECKS=", checks, " FAILURES=", failures)
	quit(1 if failures else 0)
