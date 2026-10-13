extends "res://tests/map_shop_tests.gd"

const CLINIC_POINT := "base.map.qingshizhen.point.n19"
const CLINIC_EVENT := "base.map_event.qingshizhen.clinic"

func open_clinic(map: Node) -> void:
	map.content.position = map.map_viewport.size*0.5-map.travel.map_position*map.content.scale
	map._select_destination(map.map_to_screen(map.travel.map_position))
	await settle()
	check(map.event_state.active_id==CLINIC_EVENT and map.clinic_dialog.visible and map.travel.paused,"node click opens clinic and pauses travel")
	check(map.clinic_dialog.mode=="conversation","each opening defaults to conversation")

func run() -> void:
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(2560,1440)
	var map = load("res://scenes/maps/qingshizhen.tscn").instantiate()
	map.inventory_save_path = ""
	map.defer_map_music = true
	root.add_child(map)
	map.set_process(false)
	await settle()
	check(map.startup_error.is_empty(),"town startup: "+map.startup_error)
	if not map.startup_error.is_empty(): quit(1); return
	var event: Dictionary = map.event_registry.events[CLINIC_EVENT]
	check(event.point_id==CLINIC_POINT and event.trigger=="click","clinic bound to N19 manual entry")
	check(map.shops.size()==5 and not map.shops.has(CLINIC_EVENT),"clinic is not a trading shop")
	map.travel.current_node_id = CLINIC_POINT
	map.travel.map_position = map.travel.node_positions[CLINIC_POINT]
	map.travel.stop_at_current_node()
	map.travel.node_arrived.emit(CLINIC_POINT)
	check(not map.event_state.is_active() and not map.clinic_dialog.visible,"passing clinic never opens popup")
	map.player_status.resources.hp -= 10
	var before: Dictionary = map.loadout.snapshot()
	var resources: Dictionary = map.player_status.resources.duplicate(true)
	await open_clinic(map)
	var dialog: MapClinicDialog = map.clinic_dialog
	check(dialog.title_label.text=="青石医馆" and dialog.leave_button.text=="离开医馆","header and exit authored text")
	check(dialog.description_label.text==event.description,"complete introduction")
	check(dialog.description_label.get_theme_font("font").get_string_size(event.description,HORIZONTAL_ALIGNMENT_LEFT,-1,dialog.description_label.get_theme_font_size("font_size")).x<=792,"single-line description fits header")
	check(dialog.illustration.texture.resource_path==event.presentation.illustration,"clinic scene image")
	check(dialog.backing.texture.atlas.resource_path==event.presentation.background,"clinic background")
	check(dialog.conversation_content.visible and dialog.dialogue_rows.get_child_count()>0 and dialog.conversation_options.get_child_count()==3,"welcome and three topic slots connected")
	check(dialog.treatment_content.get_child_count()>0 and not dialog.treatment_content.visible,"treatment starts hidden with preview controls")
	check(map.event_state.advance().is_empty() and map.event_state.phase=="clinic","generic dialogue advance cannot consume clinic")
	if DisplayServer.get_name()=="headless":
		var registry := MapEventRegistry.new()
		check(registry.configure([event],[CLINIC_POINT]).is_empty(),"clinic event validation accepts authored data")
		for key in ["title","description","leave_label"]:
			var invalid := event.duplicate(true)
			invalid[key] = " "
			check(not registry.configure([invalid],[CLINIC_POINT]).is_empty(),"reject empty clinic copy: "+key)
		for key in ["background","illustration","frame","treatment_background"]:
			var invalid := event.duplicate(true)
			invalid.presentation[key] = "res://missing-clinic-art.webp"
			check(not registry.configure([invalid],[CLINIC_POINT]).is_empty(),"reject missing clinic art: "+key)
		await click(dialog.treatment_tab)
		check(dialog.mode=="treatment" and dialog.treatment_content.visible and not dialog.conversation_content.visible,"native tab click opens treatment")
		check(dialog.backing.texture.atlas.resource_path==event.presentation.treatment_background,"treatment uses separate clinic art")
		await click(dialog.conversation_tab)
		check(dialog.mode=="conversation" and dialog.conversation_content.visible,"native tab click returns to conversation")
		await click(dialog.leave_button)
		check(not dialog.visible and not map.event_state.is_active() and not map.travel.paused,"leave button restores travel")
		for close_method in ["right","escape"]:
			await open_clinic(map)
			await click(dialog.treatment_tab)
			if close_method=="right":
				for pressed in [true,false]:
					var input := InputEventMouseButton.new()
					input.button_index = MOUSE_BUTTON_RIGHT
					input.pressed = pressed
					input.position = dialog.canvas.get_global_rect().get_center()
					root.push_input(input,true)
			else:
				var input := InputEventKey.new()
				input.keycode = KEY_ESCAPE
				input.pressed = true
				root.push_input(input,true)
			await settle()
			check(not dialog.visible and not map.event_state.is_active() and not map.travel.paused,"close restores travel: "+close_method)
		check(not map.event_state.completed.has(CLINIC_EVENT),"clinic remains reusable")
	else:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/clinic-conversation.png")
		dialog.set_mode("treatment")
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/clinic-treatment-empty.png")
		map._close_clinic()
	var after: Dictionary = map.loadout.snapshot()
	before.erase("narrative")
	after.erase("narrative")
	before.calendar = WorldCalendar.normalized(before.calendar)
	check(after==before,"clinic changes no inventory, currency or date")
	check(map.player_status.resources==resources,"viewing treatment never restores or spends resources")
	map.queue_free()
	await settle()
	root.get_node("UiButtonAudio").player.stop()
	await create_timer(0.1).timeout
	print("CLINIC DIALOG: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
