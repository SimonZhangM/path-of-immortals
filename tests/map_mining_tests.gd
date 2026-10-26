extends "res://tests/map_gathering_rewards_tests.gd"

func stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
	for child in node.get_children(): stop_audio(child)

func dispose_map(map: Node) -> void:
	stop_audio(map)
	map.queue_free()
	await settle()

func wait_for_mining(map: Node) -> void:
	var deadline := Time.get_ticks_msec() + 8000
	while map.event_state.phase == "gathering_animation" and Time.get_ticks_msec() < deadline:
		await process_frame
	check(map.event_state.phase == "gathering_reward", "mining playback completes before reward")

func run() -> void:
	create_timer(50).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	save_path = "res://artifacts/mining-live-%d.json" % Time.get_ticks_usec()
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(2560,1440)
	MapEventState.session_completed.clear()
	var map := await new_map()
	if not map.startup_error.is_empty(): quit(1); return
	var options := MapGatheringOptions.new()
	check(options.load_options("res://data/ui/mining_options.json").is_empty(), "mining profile valid")
	check(options.location_font_size == 23 and not options.text_buttons, "smaller location description and texture buttons")
	var herb_options := MapGatheringOptions.new()
	check(herb_options.load_options().is_empty() and herb_options.location_font_size == 23 and herb_options.item_name_offset_y == -2 and herb_options.item_tags_offset_y == -1 and herb_options.method_name_offset_y == 2, "herb layout now follows mining polish")
	for method: Dictionary in options.methods:
		for key in ["button_idle", "button_selected"]:
			check((load(method[key]) as Texture2D).get_image().has_mipmaps(), "mining button mipmaps")
	check((load(options.background) as Texture2D).get_image().has_mipmaps(), "background mipmap")
	check((load(options.illustration_frame) as Texture2D).get_image().has_mipmaps(), "illustration frame mipmap")
	var rows := [["n19","溪湾砂矿","cutiekuang"],["n22","西崖矿隙","chitongkuang"]]
	for row: Array in rows:
		var id: String = "base.material."+row[2]
		var record: Dictionary = map.loadout.records[id]
		var item: ItemData = map.loadout.registry.get_item(id)
		check(item.category == "mineral" and item.quality == "下品", "mineral category and grade")
		check(ItemTooltip.effect_text(item) == record.description, "exact mineral tooltip")
		check(not map.loadout.snapshot().owned_units.values().has(id), "no free minerals")
		check(not map.loadout.inventory.add_item("test.mineral",id,Vector2i.ZERO), "mineral cannot equip")
		check((load(record.icon) as Texture2D).get_image().has_mipmaps(), "mineral mipmap")
		map._set_gathering_profile(MapGatheringOptions.path_for_record(record))
		map.gathering_dialog.bind_herb(record,map.loadout)
		map.gathering_dialog.present(row[1])
		check(map.gathering_dialog.location_description.get_meta("source_font_size") == 23, "actual mining description size")
		check((map.gathering_dialog.herb_name.get_meta("source_rect") as Rect2).get_center().y == 429, "item name up 2 source pixels")
		for tag in [map.gathering_dialog.herb_grade, map.gathering_dialog.herb_category]:
			check((tag.get_meta("source_rect") as Rect2).get_center().y == 465.5, "item tags up 1 source pixel")
		for index in 3:
			check((map.gathering_dialog.canvas.get_node("MethodName%d" % index).get_meta("source_rect") as Rect2).position.y == 602, "method names down 2 source pixels")
			map.gathering_dialog.select_method(index)
			var forecast := options.forecast(index)
			check(forecast.base == index+1 and forecast.days == index+1 and forecast.total_max == index+2, "three yield/day tiers")
			check(map.gathering_dialog.method_note.text == options.locations[id].notes[forecast.method_id], "location-specific method note")
			await settle()
			check(map.gathering_dialog.method_note.get_line_count() == 2, "each harvest description has exactly two lines")
			var button := map.gathering_dialog.action_buttons[index] as TextureButton
			check(button != null and button.texture_normal.resource_path == options.methods[index].button_selected and button.texture_hover == button.texture_normal, "selected art persists without hover")
			check(map.gathering_dialog.value_labels[0].text.contains("块") and not map.gathering_dialog.value_labels[0].text.contains("株"), "mining forecast unit")
		check(map.gathering_dialog.herb_category.text == "矿石", "mineral rounded tag")
		var tip: ItemTooltip = map.gathering_dialog.herb_slot.build_item_tooltip("")
		check(tip.description == record.description, "actual slot tooltip")
		tip.free()
		await settle()
		var frame: TextureRect = map.gathering_dialog.location_frame
		var picture: TextureRect = map.gathering_dialog.location_illustration
		var frame_rect: Rect2 = frame.get_meta("source_rect")
		check(frame_rect.size == Vector2(463,694) and frame_rect.size == frame.texture.get_size(), "frame native source size preserved")
		check(frame_rect.get_center() == Vector2(349,451), "center between inner rim and divider, vertically between inner rims")
		check(is_equal_approx(frame_rect.position.x-80,618-frame_rect.end.x) and is_equal_approx(frame_rect.position.y-80,822-frame_rect.end.y), "equal horizontal and vertical margins")
		check(picture.texture.resource_path == options.locations[id].illustration and picture.texture.get_image().has_mipmaps(), "correct ore scene image with mipmaps")
		check(picture.get_meta("source_rect") == frame_rect.grow(-4) and picture.clip_contents and picture.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, "scene image contained without stretching")
		await capture("res://artifacts/mining-%s.png" % row[2])
		map.gathering_dialog.hide()
	# Rendering is static only; native input is confined to headless checks below.
	if DisplayServer.get_name() != "headless":
		await dispose_map(map)
		stop_audio(root)
		print("MINING PREVIEW: ",checks," checks, ",failures," failures")
		quit(1 if failures else 0)
		return
	var before_count: int = map.loadout.snapshot().owned_units.size()
	var gained := 0
	for index in 2:
		var row: Array = rows[index]
		var point: String = "base.map.qingshihewan.point."+row[0]
		var event: Dictionary = map.event_registry.events[map.event_registry.by_point[point]]
		check(event.title == row[1] and event.item_id == "base.material."+row[2], "red/blue node mapping")
		await arrive(map,point)
		check(map.event_state.phase == "gathering" and map.travel.paused and map.gathering_dialog.visible, "arrival opens mining modal")
		await click(map.gathering_dialog.later_button,MOUSE_BUTTON_RIGHT)
		check(not map.event_state.is_active() and not map.travel.paused, "right cancel resumes travel")
		check(map._try_start_event(point,"click",true), "reopen mining node")
		var snapshot: Dictionary = map.loadout.snapshot()
		check(not MapGatheringRewards.prepare(map.loadout,event,"base.gathering.quick",save_path,map._gathering_rng).is_empty() and map.loadout.snapshot() == snapshot, "reject herb method for ore")
		var method_index := index*2
		await click(map.gathering_dialog.action_buttons[method_index])
		check(map.event_state.phase == "gathering", "first click selects, no roll")
		if index == 0:
			map.inventory_save_path = "res://artifacts/missing-mining-directory/save.json"
			await click(map.gathering_dialog.action_buttons[method_index])
			check(map.loadout.snapshot() == snapshot and not map.gathering_dialog.error_label.text.is_empty(), "failed preparation atomic")
			map.inventory_save_path = save_path
		await click(map.gathering_dialog.action_buttons[method_index])
		check(map.event_state.phase == "gathering_animation" and not map.gathering_result.visible, "second click starts mining playback")
		await wait_for_mining(map)
		check(map.gathering_result.visible, "playback then shows saved result")
		var offer: Dictionary = map.loadout.gathering_offers[event.id].duplicate(true)
		check(offer.quantity in [method_index+1,method_index+2] and offer.days == method_index+1, "actual bounded roll")
		check(map.gathering_result.quantity_label.text == "数量：%d块" % offer.quantity, "reward unit")
		check(not map.loadout.has_reward(offer.id), "not granted before confirmation")
		if index == 0:
			await click(map.gathering_result.accept_button,MOUSE_BUTTON_RIGHT)
			await dispose_map(map)
			map = await new_map()
			await arrive(map,point)
			check(map.gathering_result.visible and map.loadout.gathering_offers[event.id] == offer, "saved pending roll survives restart")
			map.inventory_save_path = "res://artifacts/missing-mining-directory/save.json"
			await click(map.gathering_result.accept_button)
			check(not map.loadout.has_reward(offer.id) and not map.gathering_result.accept_button.disabled, "failed claim retryable")
			map.inventory_save_path = save_path
		await click(map.gathering_result.accept_button)
		gained += int(offer.quantity)
		check(map.loadout.has_reward(offer.id) and map.loadout.snapshot().owned_units.values().count(event.item_id) == offer.quantity, "ore quantity in bag")
		snapshot = map.loadout.snapshot()
		check(MapGatheringRewards.claim(map.loadout,event,save_path).is_empty() and map.loadout.snapshot() == snapshot, "duplicate claim no grant")
		check(not map._try_start_event(point,"click",true), "completed mine not repeatable this session")
		await create_timer(0.4).timeout
		check(not map.content.get_node("Points/"+row[0].to_upper()+"/Sign").visible, "completed mine sign hidden")
	check(map.loadout.snapshot().owned_units.size() == before_count+gained, "only mined quantities added")
	# Switch the shared dialog back to herbs, exercising the unchanged middle tier.
	await arrive(map,"base.map.qingshihewan.point.n04")
	check(map.gathering_dialog.options.unit == "株" and map.gathering_dialog.action_buttons[1] is TextureButton, "herb profile restored")
	await click(map.gathering_dialog.action_buttons[1])
	await click(map.gathering_dialog.action_buttons[1])
	await wait_for_gathering(map)
	check(map.gathering_result.quantity_label.text.ends_with("株"), "herb reward compatibility")
	await click(map.gathering_result.accept_button)
	await dispose_map(map)
	MapEventState.session_completed.clear()
	map = await new_map()
	await arrive(map,"base.map.qingshihewan.point.n19")
	check(map.event_state.phase == "gathering", "restart mine available after claimed roll")
	await click(map.gathering_dialog.action_buttons[1])
	await click(map.gathering_dialog.action_buttons[1])
	await wait_for_mining(map)
	var again: Dictionary = map.loadout.gathering_offers["base.map_event.qingshihewan.mining_n19"]
	check(again.id.ends_with(".2") and again.days == 2 and again.quantity in [2,3], "middle tier fresh receipt")
	await click(map.gathering_result.accept_button)
	var broken: Dictionary = map.loadout.snapshot()
	broken.gathering_offers["base.map_event.qingshihewan.mining_n19"].quantity = 999
	check(not map.loadout.restore(broken).is_empty(), "invalid mineral yield rejected")
	broken = map.loadout.snapshot()
	broken.gathering_offers["base.map_event.qingshihewan.mining_n19"].method_id = "base.gathering.careful"
	check(not map.loadout.restore(broken).is_empty(), "saved mismatched profile rejected")
	await dispose_map(map)
	stop_audio(root)
	await settle()
	print("MINING FLOW: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
