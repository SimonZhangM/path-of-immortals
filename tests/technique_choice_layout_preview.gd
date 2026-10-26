extends "res://tests/map_shop_tests.gd"

# Static layout only: no input injection, training, or save writes.
func run() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var registry := ContentRegistry.new()
	check(registry.load_base_content(), "registry")
	var created := MapLoadoutStore.create_state(registry, registry.get_board("base.board.bag"))
	check(created.error.is_empty(), "isolated inventory")
	if not created.error.is_empty(): quit(1); return
	var state: MapLoadoutState = created.state
	var grant = preload("res://tools/grant_test_cultivation_books.gd")
	check(state.restore(grant.prepare(state).snapshot).is_empty(), "isolated book fixture")
	var records: Array[Dictionary] = []
	for record: Dictionary in state.storage_records():
		if record.category == "book": records.append(record)
	check(records.size() == 35, "35 actual book cards")
	var picker := MapTechniqueChoiceDialog.new()
	root.add_child(picker)
	for viewport_size in [Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		root.size = viewport_size
		picker.size = Vector2(viewport_size)
		for count in [0, 1, 4, 5, 35]:
			var rows: Array[Dictionary] = []
			for index in count: rows.append(records[index])
			var selected: Array[String] = []
			if count > 0: selected.append(str(rows[0].id))
			picker.present_multiple(rows, selected, 2)
			await settle()
			check(picker.heading.text == "功法选择", "title omits selection limit")
			check(picker.selection_limit == 2, "actual selection limit unchanged")
			check(picker.grid.columns == 4 and picker.cards.size() == count, "four columns and all cards retained")
			check(picker.empty_label.visible == (count == 0), "empty state retained")
			if count == 0: continue
			var viewport := picker.scroll.get_global_rect()
			for index in mini(count, 4):
				var card := picker.cards[index]
				check(is_equal_approx(card.size.x, 104), "card width increased to 104")
				check(viewport.encloses(card.get_global_rect()), "first row fits entirely in scroll viewport")
			check(picker.scroll.get_global_rect().end.y < picker.confirm_button.get_global_rect().position.y, "cards remain above action buttons")
			if count > 4:
				check(picker.cards[4].position.y > picker.cards[0].position.y, "fifth card wraps to second row")
				check(picker.scroll.get_v_scroll_bar().visible, "extra rows keep scrollbar")
			if count == 35 and DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://artifacts/technique-choice-four-%d.png" % viewport_size.x)
	picker.queue_free()
	await settle()
	print("TECHNIQUE CHOICE LAYOUT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
