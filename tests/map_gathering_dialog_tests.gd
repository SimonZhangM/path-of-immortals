extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	for i in 4: await process_frame

func click(control: Control, button := MOUSE_BUTTON_LEFT) -> void:
	var position := control.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = button
		event.pressed = pressed
		root.push_input(event, true)
	await settle()

func capture(path: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(2560,1440)
	AudioServer.set_bus_mute(0,true)
	var preview: Control = load("res://scenes/maps/gathering_preview.tscn").instantiate()
	root.add_child(preview)
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await settle()
	var dialog: MapGatheringDialog = preview.dialog
	check(dialog.visible and dialog.selected_index == -1, "default unselected")
	check(dialog.canvas.scale == Vector2.ONE, "native pixel layout")
	check(dialog.method_note.text.is_empty(), "no unsupported default method note")
	check(Rect2(Vector2.ZERO, root.size).encloses(dialog.canvas.get_global_rect()), "2K bounds")
	await capture("res://artifacts/gathering-default.png")
	if "--render-only" in OS.get_cmdline_user_args():
		for index in 3:
			dialog.select_method(index)
			await settle()
			await capture("res://artifacts/gathering-selected-%d.png" % index)
		preview.queue_free()
		await settle()
		print("GATHERING: static 2K previews complete (no mouse checks)")
		quit(1 if failures else 0)
		return
	# GUI hit dispatch checks only the interactions introduced in this request.
	for index in 3:
		dialog.present()
		preview.result_dialog.hide()
		await settle()
		# Press a card header (away from its distinct action button).
		var p := dialog.method_cards[index].get_global_rect().position + Vector2(70,70)
		for pressed in [true,false]:
			var event := InputEventMouseButton.new()
			event.position = p
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			root.push_input(event,true)
		await settle()
		check(dialog.selected_index == index and dialog.visible, "card selects only")
		for other in 3:
			check(dialog.selection_frames[other].visible == (other == index), "exclusive selection")
			var expected: String = dialog.options.methods[other]["button_selected" if other == index else "button_idle"]
			check(dialog.action_buttons[other].texture_normal.resource_path == dialog.options.methods[other].button_idle, "selection alone keeps idle art")
			check(dialog.action_buttons[other].texture_hover.resource_path == expected, "hover art follows selection")
		check(dialog.value_labels[0].get_parsed_text() == "%d株" % (index+1), "base forecast")
		check(dialog.value_labels[1].get_parsed_text() == "0～1株", "extra forecast")
		check(dialog.value_labels[2].get_parsed_text() == dialog.options.methods[index].name, "method forecast")
		check(dialog.value_labels[3].get_parsed_text() == "%d天" % (index+1), "days forecast")
		check(dialog.method_note.text == dialog.options.locations[dialog.herb_slot.item_id].notes[dialog.options.methods[index].id], "selected method note")
		for row in [0,1,3]: check(dialog.value_labels[row].text.contains("[color=#ffffff]"), "white units")
		await capture("res://artifacts/gathering-selected-%d.png" % index)
		await click(dialog.action_buttons[index])
		check(not dialog.visible and preview.result_dialog.visible, "lit button opens result immediately")
		check(preview.result_dialog.heading.text == "获得止血草" and preview.result_dialog.quantity_label.text == "数量：%d株" % (index+1), "result shows herb and quantity")
		await click(preview.result_dialog.accept_button, MOUSE_BUTTON_RIGHT)
		check(not preview.result_dialog.visible, "right click closes result")
	dialog.present()
	await settle()
	await click(dialog.action_buttons[1])
	check(dialog.selected_index == 1 and dialog.visible and not preview.result_dialog.visible, "idle button selects without starting")
	await click(dialog.action_buttons[1])
	await capture("res://artifacts/gathering-result.png")
	preview.result_dialog.hide()
	dialog.present()
	await click(dialog.later_button)
	check(not dialog.visible, "later closes")
	dialog.present()
	await click(dialog.method_cards[0],MOUSE_BUTTON_RIGHT)
	check(not dialog.visible and not preview.result_dialog.visible, "right click cancels without gathering")
	preview.queue_free()
	await settle()
	print("GATHERING DIALOG: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
