extends SceneTree

var clicks := 0
var checks := 0

func _initialize() -> void: run.call_deferred()
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		push_error(message)
		quit(1)
func settle() -> void:
	for i in 4: await process_frame
func pointer(point: Vector2, down: bool) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion,true)
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	root.push_input(event,true)
func click(button: BaseButton) -> void:
	var center := button.get_global_rect().get_center()
	pointer(center,true)
	pointer(center,false)
	await settle()

func run() -> void:
	create_timer(25).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(2560,1440)
	var audio := root.get_node("UiButtonAudio")
	audio.click_played.connect(func(): clicks += 1)
	check(audio.player.stream.resource_path == "res://assets/click.ogg" and not audio.player.stream.loop, "global click uses non-looping user asset")
	check(audio.player.stream.get_length() > 0, "click asset decodes")
	if DisplayServer.get_name() == "headless":
		# Only the changed audio hookup needs native button input checks.
		var host := Control.new()
		host.process_mode = Node.PROCESS_MODE_ALWAYS
		root.add_child(host)
		host.size = Vector2(600,600)
		for button: BaseButton in [Button.new(),TextureButton.new(),CheckBox.new(),BattleActionButton.new()]:
			button.position = Vector2(60,60)
			button.custom_minimum_size = Vector2(200,80)
			button.size = Vector2(200,80)
			host.add_child(button)
			await settle()
			var before := clicks
			await click(button)
			check(clicks == before+1, "each button subtype plays exactly once")
			button.disabled = true
			await click(button)
			check(clicks == before+1, "disabled button is silent")
			button.disabled = false
			pointer(button.get_global_rect().get_center(),true)
			pointer(Vector2(500,500),false)
			await settle()
			check(clicks == before+1, "cancelled pointer press is silent")
			button.queue_free()
			await settle()
		var closing := Button.new()
		closing.position = Vector2(60,60)
		closing.size = Vector2(200,80)
		closing.pressed.connect(func(): closing.disabled = true)
		host.add_child(closing)
		paused = true
		var before := clicks
		await click(closing)
		check(clicks == before+1, "self-disabling action still sounds while gameplay is paused")
		paused = false
		closing.disabled = false
		host.remove_child(closing)
		host.add_child(closing)
		await click(closing)
		check(clicks == before+2, "reentering tree does not double connect")
		host.queue_free()
		await settle()
	var scene = load("res://scenes/maps/gathering_preview.tscn").instantiate()
	root.add_child(scene)
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await settle()
	var dialog: MapGatheringDialog = scene.dialog
	check(dialog.options.background == "res://assets/tanchuang-caiyao.webp" and (load(dialog.options.background) as Texture2D).get_image().has_mipmaps(), "new herbal popup with mipmaps")
	check(dialog.location_frame.texture.get_image().has_mipmaps(), "shared inset border mipmaps")
	for item_id: String in dialog.options.locations:
		var location: Dictionary = dialog.options.locations[item_id]
		dialog.bind_herb(scene.model.records[item_id],scene.model)
		dialog.present(location.title)
		await settle()
		check(dialog.location_description.text == location.description and dialog.method_note.text.is_empty(), "location description matches; no stale note before choice")
		check(dialog.location_description.get_theme_font("font").get_font_name() == "KaiTi" and dialog.location_description.get_meta("source_font_size") == 23, "description matches mining KaiTi 23")
		if location.has("illustration"):
			check(dialog.location_illustration.visible and dialog.location_frame.visible and dialog.location_illustration.texture.resource_path == location.illustration, "matching herb illustration")
			check(dialog.location_illustration.texture.get_image().has_mipmaps(), "herb scene mipmaps")
			var frame_rect: Rect2 = dialog.location_frame.get_meta("source_rect")
			check(frame_rect.size == Vector2(463,694) and frame_rect.get_center() == Vector2(349,451), "native frame size and mining alignment")
			check(dialog.location_illustration.get_meta("source_rect") == frame_rect.grow(-4) and dialog.location_illustration.clip_contents, "illustration contained inside border")
		else:
			check(not dialog.location_illustration.visible and not dialog.location_frame.visible and dialog.location_illustration.texture == null, "unreleased herb has no stale scene image")
		check(dialog.heading.get_meta("source_rect").position.x-689 == 26, "title-logo gap halved")
		check(dialog.location_description.get_global_rect().position.x > dialog.heading.get_global_rect().end.x, "description is to right of title")
		var divider_y := dialog.canvas.global_position.y+(179-dialog.FRAME.position.y)*1.2
		check(dialog.location_description.get_global_rect().end.y < divider_y, "wrapped description stays above divider")
		check(dialog.location_description.get_global_rect().end.x < dialog.later_button.get_global_rect().position.x, "description avoids later button")
		check(dialog.herb_name.get_meta("source_font_size") == 26 and dialog.herb_grade.get_meta("source_font_size") == 14, "herb text reduced one size")
		for label: Label in [dialog.herb_name,dialog.herb_grade,dialog.herb_category]:
			var top := 413.0 if label == dialog.herb_name else 449.0
			var bottom := 449.0 if label == dialog.herb_name else 484.0
			var rect := label.get_global_rect()
			var offset := dialog.options.item_name_offset_y if label == dialog.herb_name else dialog.options.item_tags_offset_y
			check(rect.position.y >= dialog.canvas.global_position.y+(top+offset-32)*1.2-1 and rect.end.y <= dialog.canvas.global_position.y+(bottom+offset-32)*1.2+1, "label bounds fit their shifted layout bands")
			check(absf(rect.get_center().y-(dialog.canvas.global_position.y+((top+bottom)*0.5+offset-32)*1.2)) <= 1, "text uses mining band offsets")
		for index in 3:
			dialog.select_method(index)
			await settle()
			check((dialog.canvas.get_node("MethodName%d" % index).get_meta("source_rect") as Rect2).position.y == 602, "method title lowered like mining")
			if location.has("illustration"): check(dialog.method_note.get_line_count() == 2, "river herb note fixed to two lines")
			check(dialog.method_note.text == location.notes[dialog.options.methods[index].id], "note follows selected method")
			check(dialog.method_note.get_theme_font("font").get_font_name() == "KaiTi", "method note uses KaiTi")
			check(dialog.method_note.get_meta("source_font_size") == 18 and dialog.method_note.get_meta("source_rect").get_center().y == 450, "note enlarged by two and vertically centered in freed band")
			check(not dialog._geometry.any(func(control): return control is RichTextLabel and control.get_parsed_text().begins_with("预计合计")), "total summary removed")
			check(dialog.method_note.get_global_rect().end.y < dialog.canvas.global_position.y+(484-32)*1.2, "note stays inside forecast frame")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/gathering-copy-%s.png" % item_id.get_slice(".",2))
	if DisplayServer.get_name() == "headless":
		dialog.present("潮湿溪石")
		await settle()
		var before := clicks
		await click(dialog.method_cards[0])
		check(clicks == before+1 and dialog.selected_index == 0, "real gathering choice sounds once")
		await click(dialog.action_buttons[0])
		check(clicks == before+2 and scene.result_dialog.visible, "gather button sounds once on opening reward dialog")
		await click(scene.result_dialog.accept_button)
		check(clicks == before+3, "reward accept sounds once")
		dialog.present("潮湿溪石")
		await settle()
		await click(dialog.later_button)
		check(clicks == before+4 and not dialog.visible, "later button sounds once and closes")
	scene.queue_free()
	await settle()
	audio.player.stop()
	print("GATHERING COPY / GLOBAL CLICK: ",checks," checks passed; no player save used")
	quit()
