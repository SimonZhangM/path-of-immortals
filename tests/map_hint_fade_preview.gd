extends SceneTree

func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for i in 8: await process_frame
func run() -> void:
	create_timer(30).timeout.connect(func(): quit(2))
	root.size = Vector2i(2560,1440)
	var background := ColorRect.new()
	background.color = Color("11212a")
	background.size = Vector2(2560,1440)
	root.add_child(background)
	var layout = load("res://scenes/maps/qingshihewan_layout.tscn").instantiate()
	root.add_child(layout)
	layout.position = Vector2(-1850,-260)
	layout.scale = Vector2.ONE * 1.1
	var visited := {"EastExit":true, "N15":true}
	var revealed := visited.duplicate()
	for route: MapRoute in layout.get_node("Routes").get_children():
		var first: String = route.get_node(route.start_point).name
		var last: String = route.get_node(route.end_point).name
		if visited.has(first): revealed[last] = true
		if visited.has(last): revealed[first] = true
	for point: MapRoutePoint in layout.get_node("Points").get_children():
		point.present_exploration(revealed.has(str(point.name)), visited.has(str(point.name)))
	for route: MapRoute in layout.get_node("Routes").get_children():
		var first: String = route.get_node(route.start_point).name
		var last: String = route.get_node(route.end_point).name
		route.present_exploration(visited.has(first) or visited.has(last), revealed.has(first), revealed.has(last),72)
	assert(MapRoute.hint_profile(0) == Vector2(1,0))
	assert(MapRoute.hint_profile(1) == Vector2(0,1))
	var previous := Vector2(1,0)
	for i in range(1,101):
		var profile := MapRoute.hint_profile(i / 100.0)
		assert(profile.x <= previous.x and profile.y >= previous.y)
		previous = profile
	await settle()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/map-hint-fade.png")
	layout.queue_free()
	await settle()
	var registry := ContentRegistry.new()
	assert(registry.load_base_content())
	var created := MapLoadoutStore.create_state(registry,registry.get_board("base.board.bag"))
	assert(created.error.is_empty())
	var model: MapLoadoutState = created.state
	var record: Dictionary = model.records["base.map_item.qinglan_board_5"]
	var card := MapInventoryItemCard.new()
	card.configure(record,"阵盘")
	card.size = Vector2(190,254)
	card.position = Vector2(120,100)
	root.add_child(card)
	card._layout()
	var tip := ItemTooltip.new()
	tip.configure(registry.get_item(record.id))
	tip.position = Vector2(440,100)
	root.add_child(tip)
	var card_name: Label = card.find_child("ItemName",true,false)
	var tip_name: Label = tip.find_child("ItemTitle",true,false)
	assert(card_name.get_theme_color("font_color") == tip_name.get_theme_color("font_color"))
	assert(card_name.get_theme_color("font_color") == Color("f9f8c8"))
	await settle()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/item-name-matched.png")
	card.queue_free()
	tip.queue_free()
	background.queue_free()
	await settle()
	print("VISUAL: matched card/tooltip title colors; smooth monotonic hint fading and blur; real layout rendered")
	quit()
