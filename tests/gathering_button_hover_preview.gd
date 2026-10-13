extends SceneTree

func _initialize() -> void: run.call_deferred()

func settle() -> void:
	for i in 4: await process_frame

func hover(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	root.push_input(event,true)
	await settle()

func run() -> void:
	create_timer(15).timeout.connect(func(): quit(2))
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(2560,1440)
	var scene = load("res://scenes/maps/gathering_preview.tscn").instantiate()
	root.add_child(scene)
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await settle()
	var dialog: MapGatheringDialog = scene.dialog
	var black_labels := ["林间草坡","稍后再说","预计收获","基础收获","随机额外","采集方式","采集耗时","选择采集方式","快速采摘","细心采集","深入搜寻"]
	var count := 0
	for control in dialog._geometry:
		if control is Label and control.text in black_labels:
			assert(control.get_theme_font("font").get_font_name() == "SimHei")
			count += 1
	assert(count == black_labels.size())
	var card := MapInventoryItemCard.new()
	card.configure(scene.model.records["base.material.zhixuecao"],"草木")
	root.add_child(card)
	card.hide()
	assert(dialog.herb_name.get_theme_font("font") == card.canvas.get_node("ItemName").get_theme_font("font"))
	assert(dialog.herb_grade.get_theme_font("font") == card.canvas.get_node("CategoryTags").get_child(0).get_theme_font("font"))
	for index in 3:
		dialog.present("林间草坡")
		var button := dialog.action_buttons[index]
		var rect: Rect2 = button.get_meta("source_rect")
		assert(is_equal_approx(rect.get_center().y,(dialog.METHOD_TIME_BOTTOM+dialog.CARD_RECTS[index].end.y)*0.5))
		await hover(button.get_global_rect().get_center())
		assert(button.is_hovered() and button.texture_hover == dialog._idle_textures[index])
		var header := dialog.method_cards[index].get_global_rect().position + Vector2(70,70)
		await hover(header)
		for pressed in [true,false]:
			var click := InputEventMouseButton.new()
			click.position = header
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = pressed
			root.push_input(click,true)
		await settle()
		assert(dialog.selected_index == index and not button.is_hovered())
		assert(button.texture_normal == dialog._idle_textures[index])
		await hover(button.get_global_rect().get_center())
		assert(button.is_hovered() and button.texture_hover == dialog._selected_textures[index])
		if index == 1 and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/gathering-button-hover.png")
		await hover(header)
		assert(not button.is_hovered() and button.texture_normal == dialog._idle_textures[index])
		assert(dialog.visible and not scene.result_dialog.visible)
	card.queue_free()
	scene.queue_free()
	await settle()
	print("GATHERING HOVER: 3 buttons idle/selected/hover/exit, centered positions, 11 black labels and card-matched herb fonts passed")
	quit()
