extends SceneTree

func _initialize() -> void: run.call_deferred()

func run() -> void:
	create_timer(15).timeout.connect(func(): quit(2))
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(2560,1440)
	var scene = load("res://scenes/maps/gathering_preview.tscn").instantiate()
	root.add_child(scene)
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in 5: await process_frame
	var dialog: MapGatheringDialog = scene.dialog
	var record: Dictionary
	for value: Dictionary in scene.model.records.values():
		if value.name == "苦艾叶": record = value
	assert(not record.is_empty())
	dialog.bind_herb(record,scene.model)
	dialog.present("山坡荒地")
	dialog.select_method(0)
	for i in 5: await process_frame
	assert(dialog.canvas.size == (dialog.FRAME.size * 1.2).round())
	assert(absf(dialog.method_heading.get_global_rect().get_center().x - dialog.method_cards[1].get_global_rect().get_center().x) <= 1)
	assert(dialog.method_heading.get_meta("source_font_size") == 23)
	assert(dialog.herb_name.get_meta("source_rect").get_center().y == 429)
	assert(dialog.herb_grade.get_meta("source_rect").get_center().y == 465.5)
	assert(dialog.herb_art.get_meta("source_rect").get_center().y == (198.0+413.0)*0.5)
	assert(dialog.herb_art.get_meta("source_rect").get_center().x == dialog.HERB_FRAME.get_center().x)
	assert(dialog.method_heading.get_meta("source_rect").get_center().y == 516.0)
	assert(dialog.method_note.get_meta("source_rect").get_center().x == dialog.FORECAST_FRAME.get_center().x)
	for row in 4:
		assert(dialog.value_labels[row].get_meta("source_rect").get_center().y == 275.0+41.0*row)
	for index in 3:
		assert(dialog.action_buttons[index].get_meta("source_rect").get_center().y == (733.0+dialog.CARD_RECTS[index].end.y)*0.5)
	for value in dialog.value_labels:
		assert(value.get_theme_font("normal_font").get_font_name() == "KaiTi")
	var method_rows := 0
	for control in dialog._geometry:
		if not control is Label: continue
		if control.text.begins_with("获得 ") or control.text.begins_with("耗时 "):
			assert(control.get_meta("source_font_size") == 18)
			assert(control.get_theme_font("font").get_font_name() == "KaiTi")
			method_rows += 1
		if control.text == "稍后再说":
			assert(control.get_meta("source_rect").get_center().y == dialog.later_button.get_meta("source_rect").get_center().y)
			assert(absf(control.get_meta("source_rect").get_center().x - dialog.later_button.get_meta("source_rect").get_center().x) <= 1)
	assert(method_rows == 6)
	assert(dialog.canvas.get_node("LaterChevron").text == ">")
	assert(dialog.herb_grade.text == "下品" and dialog.herb_category.text == "药材")
	assert(dialog.herb_grade.get_meta("source_rect").position.y > dialog.HERB_NAME_BOTTOM)
	assert(dialog.herb_grade.get_theme_stylebox("normal") is StyleBoxFlat)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/gathering-layout-refined.png")
	var card := MapInventoryItemCard.new()
	card.configure(record,"草木")
	root.add_child(card)
	assert(card.canvas.get_node("ItemName").z_index > card.canvas.get_node("ItemArtwork").z_index)
	assert(card.canvas.get_node("CategoryTags").z_index > card.canvas.get_node("ItemArtwork").z_index)
	var encounter := MapEncounterDialog.new()
	for label: Label in [encounter.heading,encounter.description,encounter.enemy_name]:
		assert(label.get_theme_font("font").font_names[0] == "SimHei")
	print("ENCOUNTER FONT: ", encounter.heading.get_theme_font("font").get_font_name())
	encounter.free()
	card.queue_free()
	scene.queue_free()
	for i in 5: await process_frame
	print("LAYOUT: updated gathering artwork bands, centered herb/name/tags/forecast/buttons, preserved fonts and 90% scale passed")
	quit()
