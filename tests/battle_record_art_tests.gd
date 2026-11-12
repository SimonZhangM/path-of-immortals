extends "res://tests/battle_record_ui_tests.gd"

func static_preview(scene: Node, ui: Control) -> void:
	# Artwork layout fixtures reuse real registered spells, not combat balance values.
	for footprint: Vector2i in [Vector2i(1, 2), Vector2i(2, 1)]:
		for id: String in registry.library.spells:
			var item := registry.get_item(id)
			if item.grid_size != footprint: continue
			var row: Dictionary = ui._battle_log.rows[4].duplicate(true)
			row.item_id = item.id
			row.event_name = item.display_name
			row.at_usec = 6000000
			ui._battle_log.rows.insert(5, row)
			ui._battle_log.revision += 1
			break
	ui._open_battle_record()
	await settle()
	var panel = ui._log_panel
	check(panel.format_time(7500000) == "7.5秒" and panel.format_time(0) == "0.0秒", "time uses A.B seconds without brackets or zero padding")
	for dimensions in [Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		root.size = dimensions
		await settle()
		var tall_count := 0
		var spell_count := 0
		for row_node in panel.content.get_children():
			if row_node == panel.empty_label: continue
			var cells: HBoxContainer = row_node.get_node("Cells")
			var time: Label = cells.get_node("TimeCell/Time")
			check(time.text.ends_with("秒") and not time.text.contains("["), "rendered time format")
			var event: HBoxContainer = cells.get_node("EventCell/Event")
			var art := event.get_node_or_null("SpellArtwork")
			if art == null: continue
			spell_count += 1
			check(art is MapItemArtwork and event.get_children().filter(func(child): return child is PanelContainer).is_empty(), "spell uses its own artwork without reward backing")
			if art.custom_minimum_size == Vector2(30, 60):
				tall_count += 1
				check(is_equal_approx(row_node.size.y, 76), "vertical 1x2 spell occupies two 38px rows")
			check(art.size == art.custom_minimum_size and art.get_rect().end.y <= event.size.y + .1, "native spell shape fits its cell")
		check(tall_count == 1 and spell_count >= 3, "square, wide and tall spell fixtures visible")
		for button: Button in panel.filter_buttons.values():
			var center: CenterContainer = button.get_node("CenteredCaption")
			var caption: HBoxContainer = center.get_child(0)
			check(caption.get_rect().get_center().distance_to(center.size * .5) <= 1, "tab icon and text centered together")
			check(is_equal_approx(caption.get_child(1).position.x - caption.get_child(0).get_rect().end.x, 12), "reference icon text spacing")
		var factor: Vector2 = panel.close_button.size / panel.close_button.texture_normal.get_size()
		var gold := Rect2(panel.close_button.position + panel.CLOSE_GOLD_REGION.position * factor, panel.CLOSE_GOLD_REGION.size * factor)
		check(gold.get_center().distance_to(panel.CLOSE_CENTER) < .01 and gold.size.distance_to(Vector2(48, 48)) < .01, "visible gold ring matches marked center and diameter")
		check(not panel.close_button.texture_click_mask.get_bitv(Vector2i.ZERO), "transparent close-button corner excluded")
		await screenshot("art-update-1080p.png" if dimensions.x == 1920 else "art-update-2k.png")
	check(panel.close_button.texture_normal.get_image().has_mipmaps(), "close artwork mipmap enabled")
	# Only the newly replaced close control receives a mouse check.
	click(panel.close_button)
	await settle()
	check(not panel.visible and ui.manager.simulation.clock.paused, "new image button closes without resuming")
	scene.queue_free()
	await settle()
	print("BATTLE_RECORD_ART: %d checks, %d failures; close button only mouse check" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
