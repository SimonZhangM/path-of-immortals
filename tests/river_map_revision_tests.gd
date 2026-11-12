extends "res://tests/merchant_road_quest_tests.gd"

func run() -> void:
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size=Vector2i.ZERO
	root.size=Vector2i(1920,1080)
	var layout=load("res://scenes/maps/qingshihewan_layout.tscn").instantiate()
	root.add_child(layout)
	await settle()
	check(layout.get_node("Background").texture.get_size()==Vector2(2765,1580),"new native background dimensions")
	check(layout.get_node("Points").get_child_count()==42 and layout.get_node("Routes").get_child_count()==46,"42 points / 46 routes")
	for route:MapRoute in layout.get_node("Routes").get_children():
		check(route.curve.get_point_position(0).distance_to(route.get_node(route.start_point).position)<0.01 and route.curve.get_point_position(route.curve.point_count-1).distance_to(route.get_node(route.end_point).position)<0.01,"route endpoint alignment "+route.route_id)
	var next_nodes:Array=[]
	for route:MapRoute in layout.get_node("Routes").get_children():
		var a=route.get_node(route.start_point)
		var b=route.get_node(route.end_point)
		if a.name=="N41": next_nodes.append(b.point_id)
		if b.name=="N41": next_nodes.append(a.point_id)
	next_nodes.sort()
	check(next_nodes==["base.map.qingshihewan.point.n16","base.map.qingshihewan.point.n17","base.map.qingshihewan.point.n27"],"new junction joins north road / forest / south road")
	for pair in [["qingshihewan_encounter_n17","n12"],["qingshihewan_encounter_n12","n27"],["qingshihewan_chest_n27","n17"]]:
		var event:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/map_events/"+pair[0]+".json"))
		check(event.point_id=="base.map.qingshihewan.point."+pair[1],"content moved with stable event identity "+pair[0])
	check(layout.has_node("Points/N17/Sign/EventIcon") and layout.has_node("Points/N27/Sign/EnemyIcon"),"chest and encounter signs follow content")
	for scene in ["ambush","rescued"]:
		var old:=Merchant.initial()
		old.merge({"accepted_at":1,"updated_at":1,"accepted_location":RiverQuest.TOWN,"active":scene,"line":1,"location":{"map_id":RiverQuest.RIVER,"point_id":RiverQuest.RIVER+".point.n17"},"stage":"searching" if scene=="ambush" else "rescued"},true)
		check(Merchant.valid(old),"old active scene accepted "+scene)
		var migrated:=Merchant.normalized(old)
		check(migrated.location==Merchant.data.road and migrated.line==1 and old.location.point_id.ends_with("n17"),"old scene relocates without changing dialogue cursor or source "+scene)
	if DisplayServer.get_name()!="headless":
		for point:Node2D in layout.get_node("Points").get_children():
			var label:=Label.new()
			label.text=point.name; label.position=point.position+Vector2(12,0)
			label.add_theme_font_size_override("font_size",20)
			label.add_theme_color_override("font_shadow_color",Color.BLACK)
			label.add_theme_constant_override("shadow_offset_x",2)
			label.add_theme_constant_override("shadow_offset_y",2)
			layout.add_child(label)
		layout.scale=Vector2.ONE*0.675
		layout.position=Vector2(26,5)
		await settle(); await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/river-map-revision-overview.png")
		layout.scale=Vector2.ONE*1.3; layout.position=Vector2(-1690,-900)
		await settle(); await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/river-map-revision-southeast.png")
	layout.free()
	await settle()
	await super.run()
