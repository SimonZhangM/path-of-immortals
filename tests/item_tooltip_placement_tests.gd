extends "res://tests/item_selection_tooltip_tests.gd"
## Narrow check: card-area offset, repeat-click dismissal and nearby placement.
func run() -> void:
	create_timer(30).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(2560,1440)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	var registry := ContentRegistry.new()
	check(registry.load_base_content(), "registry")
	var made := MapLoadoutStore.create_state(registry, registry.get_board("base.board.bag"))
	check(made.error.is_empty(), "loadout")
	var model: MapLoadoutState = made.state
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/map_inventory.json"))
	var catalog := MapInventoryCatalog.new()
	catalog.configure(config)
	var records: Array[Dictionary] = []
	for record: Dictionary in model.storage_records():
		if record.category != "board": records.append(record)
		if records.size() == 20: break
	catalog.replace_entries(records)
	var ui := MapInventoryScreen.new()
	ui.configure(catalog, config, model.board, model)
	root.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.show()
	await settle()
	var well := ui.find_child("StorageItemWell",true,false) as Control
	var column := well.get_parent() as VBoxContainer
	check(column.get_theme_constant("separation") == 1, "item well gap is now 1")
	column.add_theme_constant_override("separation",8)
	await settle()
	var old_well := well.get_global_rect()
	var old_toolbar := ui.storage_toolbar.get_global_rect()
	column.add_theme_constant_override("separation",1)
	await settle()
	check(is_equal_approx(old_well.position.y-well.get_global_rect().position.y,7*ui.stage.scale.y), "well top moves up seven design pixels in total")
	check(is_equal_approx(old_well.end.y,well.get_global_rect().end.y), "well bottom stays inside storage border")
	check(old_toolbar == ui.storage_toolbar.get_global_rect(), "toolbar unchanged")
	var before := model.snapshot()
	var host := ItemTooltipHost.for_control(ui)
	for index in [10,14]:
		var card := ui.grid.get_child(index) as MapInventoryItemCard
		var point := card.get_global_rect().get_center()
		if DisplayServer.get_name() == "headless":
			await click(point)
			await hover(point)
		else:
			host.select_card(card)
			host._show(card,card.entry.id)
			await settle()
		check(is_instance_valid(host.tooltip) and host.pinned, "selected tooltip opens")
		if not is_instance_valid(host.tooltip): quit(1); return
		var tip := host.tooltip
		var rect := card.get_global_transform_with_canvas() * Rect2(Vector2.ZERO,card.size)
		var right_fits := rect.end.x+12+tip.size.x <= 2552
		check(right_fits == (index == 10), "fixture covers right and left fallback")
		var expected_x := rect.end.x+12 if right_fits else rect.position.x-tip.size.x-12
		check(is_equal_approx(tip.position.x,expected_x), "tooltip hugs preferred card side")
		var core := tip.find_child("SummaryPanel",true,false) as Control
		check(is_equal_approx(tip.position.y,rect.position.y-core.size.y*0.6), "tooltip diagonally above card using settled core height")
		check(root.get_visible_rect().encloses(tip.get_global_rect()), "tooltip within screen")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/item-tooltip-near-%d.png" % index)
		else:
			await click(point)
			await hover(point)
			check(not is_instance_valid(host.tooltip), "second click closes without immediate reopen")
			check(card.selected, "dismissal preserves selected highlight")
			await hover(Vector2(20,1400))
			await hover(point)
			check(is_instance_valid(host.tooltip) and host.pinned, "leave and return can show tooltip again")
			await click(Vector2(20,1400),MOUSE_BUTTON_RIGHT)
			check(not is_instance_valid(host.tooltip), "outside right click still closes")
		host.dismiss(false)
		await settle()
	check(model.snapshot() == before, "presentation does not change inventory")
	ui.queue_free()
	await settle()
	print("TOOLTIP NEAR CARD: ",checks," checks, ",failures," failures; render is static, headless only uses targeted viewport input; no real save")
	quit(1 if failures else 0)
