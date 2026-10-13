extends "res://tests/map_shop_tests.gd"

func town_interactions(map: Node) -> void:
	for event: Dictionary in map.event_registry.events.values():
		check(event.trigger=="click","ordinary town location uses manual trigger: "+event.id)
		var point: String = event.point_id
		var origin: String = map.travel.adjacency[point][0].to
		map.travel.current_node_id = origin
		map.travel.map_position = map.travel.node_positions[origin]
		map.travel.mode = "idle"
		check(map.travel.request_destination(point),"can walk to location")
		map.travel.advance(1000)
		await settle()
		check(map.travel.current_node_id==point and not map.travel.paused and not map.event_state.is_active(),"arrival finishes without opening or pausing")
		check(not map.shop_dialog.visible and not map.rest_dialog.visible and not map.clinic_dialog.visible,"location dialogs remain closed")
		map.travel.node_arrived.emit(point)
		check(not map.event_state.is_active(),"repeated arrival never opens ordinary location")
		map.content.position = map.map_viewport.size*0.5-map.travel.map_position*map.content.scale
		map._select_destination(map.map_to_screen(map.travel.map_position))
		await settle()
		check(map.event_state.active_id==event.id and map.travel.paused,"click current location opens correct interaction")
		if event.type=="shop": map._close_shop()
		elif event.type=="clinic": map._close_clinic()
		else: map._close_rest()
		check(not map.event_state.is_active() and not map.travel.paused,"closing restores movement")
	# A future town story can explicitly opt into arrival without a global blocker.
	var story: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_events/qingshihewan_bridge_dialogue.json"))
	story.id = "base.map_event.test.town_story"
	story.point_id = "base.map.qingshizhen.point.n03"
	var registry := MapEventRegistry.new()
	check(registry.configure([story],[story.point_id]).is_empty(),"explicit town story configuration accepted")
	var events := MapEventState.new(registry,{})
	check(events.try_start(story.point_id,story.point_id,true,"arrival"),"explicit story still triggers on arrival")

func quantity_preview(map: Node) -> void:
	var fixture: Dictionary = map.loadout.snapshot()
	var amounts := [1,2,3,10,99,999,1,2]
	var materials: Array = map.loadout.records.keys().filter(func(id): return map.loadout.records[id].category=="beast")
	for index in 8:
		for unit in amounts[index]: fixture.owned_units["quantity.%d.%d" % [index,unit]] = materials[index]
	check(map.loadout.restore(fixture).is_empty(),"isolated quantity fixture")
	var dialog: MapShopDialog = map.shop_dialog
	var event: Dictionary = map.event_registry.events["base.map_event.qingshizhen.blacksmith"]
	dialog.present(event,map.shops[event.id],map.loadout)
	dialog.set_selling(true)
	dialog.set_category("material")
	await settle()
	var before: Dictionary = map.loadout.snapshot()
	for index in dialog._visible_products.size():
		var row: Dictionary = dialog._visible_products[index]
		var amount := dialog.slot_contents[index].get_node_or_null("AvailableQuantity")
		if int(row.quantity)==1:
			check(amount==null,"single item has no multiplication badge")
		else:
			check(amount is HBoxContainer and amount.get_child_count()==2,"multiplier and count styled separately")
			check(amount.get_child(0).text=="×" and amount.get_child(0).get_theme_font_size("font_size")==17,"multiplication sign reduced two points")
			check(amount.get_child(1).text==str(int(row.quantity)) and amount.get_child(1).get_theme_font_size("font_size")==19,"actual count keeps original size")
			check(is_equal_approx(amount.position.x+amount.size.x,105),"quantity right edge three pixels left")
			check(amount.get_child(1).get_global_rect().end.x<=dialog.slot_contents[index].get_global_rect().end.x,"count remains inside card")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/shop-quantity-refined.png")
	check(map.loadout.snapshot()==before,"visual refresh changes no items, wallet or calendar")

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
	if DisplayServer.get_name()=="headless": await town_interactions(map)
	else: await quantity_preview(map)
	map.queue_free()
	await settle()
	print("SHOP QUANTITY / TOWN: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
