extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var screen: Control = load("res://scenes/maps/qingshizhen.tscn").instantiate()
	screen.inventory_save_path = ""
	root.add_child(screen)
	for frame in 5:
		await process_frame
	_check(screen.startup_error.is_empty(), "town map starts without errors")
	if not screen.startup_error.is_empty():
		screen.queue_free()
		quit(1)
		return
	var points: Node2D = screen.content.get_node("Points")
	var routes: Node2D = screen.content.get_node("Routes")
	_check(screen.definition.id == "base.map.qingshizhen", "town definition loads")
	_check(points.get_child_count() == 30, "all thirty marked nodes are present")
	_check(routes.get_child_count() == 39, "all authored town route segments are present")
	_check(screen.content.get_node("Background").texture.resource_path == "res://assets/map-qingshizhen.webp", "plain town artwork is used instead of marked reference")
	_check(screen.content.get_node("Background").texture.get_size() == Vector2(3317, 1865), "town artwork retains original dimensions")
	_check(screen.travel.current_node_id == "base.map.qingshizhen.point.n25", "player starts at southwest bridge node")
	_check(screen.player.position.distance_to(Vector2(1624, 1800)) < 1.0, "player stands at the marked southern entry")
	_check(screen.event_registry.events.is_empty(), "no unwritten town events are added")
	_check(not screen.status_header.map_title.visible, "river-bay title artwork is hidden in town")
	var ids := {}
	var location_icons := {
		"N01": "res://assets/map-xiuliansuo.webp",
		"N02": "res://assets/map-likai-you.webp",
		"N03": "res://assets/map-home.webp",
		"N04": "res://assets/map-likai-you.webp",
		"N05": "res://assets/map-xianmenshangpu.webp",
		"N11": "res://assets/map-xuyuanshu.webp",
		"N12": "res://assets/map-cangku.webp",
		"N13": "res://assets/map-jiuguan.webp",
		"N14": "res://assets/map-caoyaopu.webp",
		"N15": "res://assets/map-likai-zuo.webp",
		"N16": "res://assets/map-shangpu.webp",
		"N18": "res://assets/map-gonggaolan.webp",
		"N19": "res://assets/map-yiguan.webp",
		"N21": "res://assets/map-xuanshanglan.webp",
		"N22": "res://assets/map-zhiwu.webp",
		"N23": "res://assets/map-tiejiangpu.webp",
		"N24": "res://assets/map-yizhan.webp",
		"N25": "res://assets/map-likai-zuo.webp",
		"N27": "res://assets/map-tudici.webp",
		"N30": "res://assets/map-likai-zuo.webp",
	}
	for point: MapRoutePoint in points.get_children():
		_check(point.texture.resource_path == "res://assets/mapdot.webp", "town markers reuse river-bay mapdot")
		if location_icons.has(point.name):
			var sign := point.get_node_or_null("Sign") as Sprite2D
			_check(sign != null, "assigned town stop has a location signpost")
			if sign != null:
				var frame_path := "res://assets/mapdot5.webp"
				var frame_scale := 0.95663265
				if point.name in ["N11", "N22", "N27"]:
					frame_path = "res://assets/mapdot2.webp"
					frame_scale = 0.81168831
				elif point.name == "N03":
					frame_path = "res://assets/mapdot3.webp"
					frame_scale = 0.861276987
				_check(sign.texture is AtlasTexture and sign.texture.atlas.resource_path == frame_path, "town signpost uses its assigned frame")
				var authored_position: Vector2 = screen.sign_motion.signs[point.point_id].position
				_check(authored_position == Vector2(0, -223.928571) and sign.scale.is_equal_approx(Vector2.ONE * frame_scale), "town signpost matches the river-bay authored size and offset")
				var icon_name := "EventIcon" if point.name in ["N11", "N22", "N27"] else ("RestIcon" if point.name == "N03" else "LocationIcon")
				var icon := sign.get_node_or_null(icon_name) as Sprite2D
				_check(icon != null and icon.texture is AtlasTexture and icon.texture.atlas.resource_path == location_icons[point.name], "assigned emblem appears inside its signpost")
		else:
			_check(not point.has_node("Sign"), "other town signposts remain unassigned")
		_check(point.point_id.begins_with("base.map.qingshizhen.point.") and not ids.has(point.point_id), "town point has a unique stable ID")
		ids[point.point_id] = true
	for route: MapRoute in routes.get_children():
		_check(route._get_configuration_warnings().is_empty(), "town route has editable curve and endpoints")
		_check(not ids.has(route.route_id), "town route has a unique stable ID")
		ids[route.route_id] = true
		var from_point := route.get_node(route.start_point) as MapRoutePoint
		var to_point := route.get_node(route.end_point) as MapRoutePoint
		_check(route.curve.get_point_position(0).distance_to(from_point.position) < 1.0, "route starts at marker center")
		_check(route.curve.get_point_position(route.curve.point_count - 1).distance_to(to_point.position) < 1.0, "route ends at marker center")
		_check(route.light_color == Color("fff2af") and route.glow_color == Color("ffbf42") and route.dash_spacing == 18.0, "route matches river-bay visual style")
	for point: MapRoutePoint in points.get_children():
		_check(not screen.travel.shortest_path(screen.travel.current_node_id, point.point_id).is_empty() or point.point_id == screen.travel.current_node_id, "every town node is reachable from the entry")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png("res://artifacts/qingshizhen_start.png") == OK, "town starting view renders")
		screen._zoom_at(1.0, Vector2(960, 540))
		screen.content.position = screen.map_viewport.size * 0.5 - Vector2(3317, 1865) * screen.content.scale * 0.5
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png("res://artifacts/qingshizhen_overview.png") == OK, "town overview renders")
	screen.queue_free()
	await process_frame
	print("QINGSHIZHEN MAP RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)
