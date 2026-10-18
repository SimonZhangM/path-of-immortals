extends "res://tests/clinic_continue_input_tests.gd"

const HERB_POINT := "base.map.qingshizhen.point.n14"

func open_person(map: Node, point: String) -> MapClinicDialog:
	map.travel.current_node_id = point
	map.travel.map_position = map.travel.node_positions[point]
	map.travel.stop_at_current_node()
	map.content.position = map.map_viewport.size*0.5-map.travel.map_position*map.content.scale
	map._select_destination(map.map_to_screen(map.travel.map_position))
	await settle()
	return map.clinic_dialog if point==CLINIC_POINT else map.shop_dialog.conversation_view

func finish_greeting(dialog: MapClinicDialog) -> void:
	var guard := 0
	while dialog._view.can_continue and guard<30:
		dialog.request_continue()
		guard += 1
	await settle()
	check(guard<30,"welcome terminates")

func check_closed(dialog: MapClinicDialog) -> void:
	check(dialog.continue_button.visible and dialog.continue_button.text=="点击开启话题","last greeting keeps opening prompt")
	check(dialog.topic_buttons.values().all(func(button): return not button.visible),"all topic frames, badges and labels stay hidden")
	check(not dialog.topic_continue_hint.visible,"no competing next-stage prompt")

func check_open(dialog: MapClinicDialog, map: Node, before: Dictionary) -> void:
	check(dialog.topic_buttons.values().all(func(button): return button.is_visible_in_tree()),"exactly three authored topic cards appear")
	check(not dialog.continue_button.visible and map.loadout.snapshot()==before,"opening topics neither advances nor saves gameplay state")

func capture_gate(label: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/"+label+".png")

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
	check(map.startup_error.is_empty(),"town starts with shared welcome gate")
	if not map.startup_error.is_empty(): quit(1); return
	for point: String in [CLINIC_POINT,HERB_POINT]:
		var dialog := await open_person(map,point)
		await finish_greeting(dialog)
		check_closed(dialog)
		var before: Dictionary = map.loadout.snapshot()
		if DisplayServer.get_name()!="headless":
			await capture_gate("topic-gate-"+dialog.library.definition.name+"-closed")
			dialog.request_continue()
			check_open(dialog,map,before)
			await capture_gate("topic-gate-"+dialog.library.definition.name+"-open")
		else:
			await space(true)
			check_closed(dialog)
			# Page switches must not reveal topics or replay the greeting.
			if point==CLINIC_POINT:
				await click(dialog.treatment_tab)
				await click(dialog.conversation_tab)
			else:
				await click(dialog.canvas.get_node("ShopBuyTab"))
				await click(map.shop_dialog.conversation_tab)
			check_closed(dialog)
			await click(dialog.continue_button)
			check_open(dialog,map,before)
			if point==CLINIC_POINT:
				await click(dialog.treatment_tab)
				await click(dialog.conversation_tab)
			else:
				await click(dialog.canvas.get_node("ShopSellTab"))
				await click(map.shop_dialog.conversation_tab)
			check_open(dialog,map,before)
			# Reentry creates a new visit, including a one-line daily welcome.
			await click(dialog.leave_button)
			dialog = await open_person(map,point)
			await finish_greeting(dialog)
			check_closed(dialog)
			before = map.loadout.snapshot()
			await click_at(dialog.illustration.get_global_rect().get_center())
			check_open(dialog,map,before)
			await click(dialog.leave_button)
			map.player_status.set_resource("hp",10)
			dialog = await open_person(map,point)
			await finish_greeting(dialog)
			check_closed(dialog)
			before = map.loadout.snapshot()
			await space()
			check_open(dialog,map,before)
			if point==CLINIC_POINT:
				map.loadout.spirit_stones = 5
				await click(dialog.treatment_tab)
				map._confirm_clinic_treatment()
				await click(dialog.conversation_tab)
				await finish_greeting(dialog)
				check_closed(dialog)
				before = map.loadout.snapshot()
				await click(dialog.continue_button)
				check_open(dialog,map,before)
			map.player_status.set_resource("hp",map.player_status.maxima.hp)
		# Closing through the normal signal also works without synthetic input in Render.
		dialog.cancelled.emit()
		await settle()
	map.queue_free()
	await settle()
	root.get_node("UiButtonAudio").player.stop()
	await create_timer(0.1).timeout
	print("NPC TOPIC GATE: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
