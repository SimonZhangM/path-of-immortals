extends "res://tests/map_shop_tests.gd"

const PREFIX := "base.map.qingshizhen.point."

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
	var points: Node = map.content.get_node("Points")
	var routes: Node = map.content.get_node("Routes")
	check(points.get_child_count()==31 and routes.get_child_count()==42,"31 nodes with two added routes")
	check(points.get_node("N12").location_note=="炼丹房" and points.get_node("N12").position==Vector2(2804,792),"alchemy relocated to red-box N12")
	check(points.get_node("N19").location_note=="医馆" and points.get_node("N19").position==Vector2(2489,1141),"blue-box N19 restored clinic")
	check(map.event_registry.by_point.get(PREFIX+"n19")=="base.map_event.qingshizhen.clinic","clinic has its own event rather than alchemy")
	var alchemy: Dictionary = map.event_registry.events["base.map_event.qingshizhen.alchemy"]
	check(alchemy.point_id==PREFIX+"n12" and alchemy.trigger=="click","stable alchemy event moved to N12")
	for route: MapRoute in routes.get_children():
		check(route.curve.get_point_position(0).is_equal_approx(route.get_node(route.start_point).position) and route.curve.get_point_position(route.curve.point_count-1).is_equal_approx(route.get_node(route.end_point).position),"aligned route endpoints: "+route.route_id)
	var baseline: Dictionary = map.loadout.snapshot()
	if DisplayServer.get_name()=="headless":
		for pair in [["n14","n19","r41"],["n19","n14","r41"],["n23","n19","r42"],["n19","n23","r42"]]:
			var start: String = PREFIX+pair[0]
			var finish: String = PREFIX+pair[1]
			var path: Array = map.travel.shortest_path(start,finish)
			check(path.size()==1 and path[0].id=="base.map.qingshizhen.route."+pair[2],"new connection used directly both ways")
			map.travel.current_node_id = start
			map.travel.map_position = map.travel.node_positions[start]
			map.travel.stop_at_current_node()
			check(map.travel.request_destination(finish),"route can be traversed")
			map.travel.advance(100)
			await settle()
			check(map.travel.current_node_id==finish and map.travel.map_position==map.travel.node_positions[finish],"travel reaches endpoint")
			check(not map.event_state.is_active() and not map.travel.paused,"new roads do not auto-open town dialogs")
		map.travel.current_node_id = PREFIX+"n19"
		map.travel.stop_at_current_node()
		check(map._try_start_event(PREFIX+"n19","click",true) and map.event_state.phase=="clinic","clinic click opens clinic rather than alchemy")
		map._close_clinic()
		map.travel.current_node_id = PREFIX+"n12"
		map.travel.map_position = map.travel.node_positions[PREFIX+"n12"]
		map.travel.stop_at_current_node()
		map.content.position = map.map_viewport.size*0.5-map.travel.map_position*map.content.scale
		map._select_destination(map.map_to_screen(map.travel.map_position))
		await settle()
		check(map.event_state.active_id==alchemy.id and map.shop_dialog.title_label.text=="炼丹房" and map.shop_dialog.craft_tab.text=="炼丹","new N12 click opens unchanged alchemy shop")
		map._close_shop()
	else:
		map.content.scale = Vector2.ONE*1.8
		map.content.position = map.map_viewport.size*0.5-Vector2(2530,1080)*map.content.scale
		map._clamp_position()
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/town-clinic-new-routes.png")
	check(map.loadout.spirit_stones==baseline.spirit_stones and map.loadout.snapshot().owned_units==baseline.owned_units and map.loadout.calendar==baseline.calendar,"route checks do not change inventory, money or date")
	map.queue_free()
	await settle()
	root.get_node("UiButtonAudio").player.stop()
	await create_timer(0.1).timeout
	print("TOWN CLINIC ROUTES: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
