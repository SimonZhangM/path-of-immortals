extends SceneTree

var checks := 0
var failures := 0
var map: Control
var view: Control

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func settle() -> void:
	for i in 4: await process_frame
func key(code: Key, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	event.echo = echo
	root.push_input(event,true)
	await settle()
func mouse(point: Vector2, button: MouseButton, pressed := true) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = button
	event.pressed = pressed
	root.push_input(event,true)
	await settle()
func motion(point: Vector2, held := false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	root.push_input(event,true)
	await settle()
func click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	await motion(point)
	await mouse(point,MOUSE_BUTTON_LEFT)
	await mouse(point,MOUSE_BUTTON_LEFT,false)
func check_star() -> void:
	var expected := lerpf(view.TRACK_BOTTOM,view.TRACK_TOP,float(view.zoom_index)/(view.zoom_levels.size()-1))
	check(is_equal_approx(view.scroll_star.get_rect().get_center().y,expected),"star follows discrete zoom level")
func check_default(map_id: String) -> void:
	check(view.zoom_index==view.zoom_levels.size()-3,"open defaults to maximum minus two levels")
	var wanted: Vector2 = view.map_window.size*0.5-view.world_position_for(map_id)*view.zoom_levels[view.zoom_index]
	for axis in 2: wanted[axis]=clampf(wanted[axis],view.map_window.size[axis]-view.map_image.size[axis],0)
	check(view.map_image.position.is_equal_approx(wanted),"current map point centered subject to edges")
	check_star()
func contained() -> void:
	check(view.map_image.position.x <= 0.01 and view.map_image.position.y <= 0.01,"top and left covered")
	check(view.map_image.position.x+view.map_image.size.x >= view.map_window.size.x-0.01 and view.map_image.position.y+view.map_image.size.y >= view.map_window.size.y-0.01,"bottom and right covered")
func run() -> void:
	create_timer(55).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1920,1080)
	preload("res://scripts/entry/game_save_session.gd").index_path = "res://artifacts/worldmap-unused-session.json"
	map = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path = ""
	map.defer_map_music = true
	map.defer_location_save = true
	map.defer_optional_views = true
	root.add_child(map)
	await settle()
	check(map.startup_error.is_empty(),"actual map startup")
	if not map.startup_error.is_empty(): quit(1); return
	map.set_process(false)
	var snapshot: Dictionary = map.loadout.snapshot().duplicate(true)
	check(map.world_map == null,"world view lazily constructed")
	if DisplayServer.get_name() == "headless": await key(KEY_M)
	else: map.set_world_map_open(true)
	await settle()
	check(map.is_world_map_open(),"M opens world map")
	view = map.world_map
	check(view.stage.find_child("CloseWorldMap",true,false)==null,"close cross removed")
	check(view.zoom_levels.size()==21 and is_equal_approx(view.zoom_levels[-1],1.5),"fit to 150 percent is twenty notches")
	check(view.map_window.clip_contents,"left column clips")
	check(view.frame.get_index()>view.map_window.get_index(),"frame above map")
	check(view.title.texture.atlas.resource_path=="res://assets/map-worldmap-title.webp","title image replaces text")
	var title_ink_center: Vector2 = view.title.position+(view.TITLE_INK_CENTER-view.title.texture.region.position)*(view.title.size.x/view.title.texture.region.size.x)
	check(title_ink_center.is_equal_approx(Vector2(1271,84)),"visible gold title lettering uses requested plaque offset")
	check(view.zoom_control.get_index()>view.frame.get_index(),"slider stays above frame and map")
	check_default(map.definition.id)
	check(view.locations.size()==4 and view.world_position_for("base.map.qingshizhen")==Vector2(2381,1776),"four user specified anchors configured")
	check(view.shade.color.a > 0 and view.shade.color.a < 1,"translucent black backdrop")
	check(view.map_image.texture.get_image().has_mipmaps() and view.frame.texture.get_image().has_mipmaps(),"mipmaps")
	contained()
	if DisplayServer.get_name() == "headless":
		await sidebar_checks()
		await interaction_checks()
	else:
		DirAccess.make_dir_recursive_absolute("res://artifacts/worldmap-sidebar")
		for dimensions in [Vector2i(1920,1080),Vector2i(2560,1440)]:
			root.size = dimensions
			await settle()
			view.present(map.definition.id,map.loadout.map_visited)
			await settle()
			check_default(map.definition.id)
			for location_id: String in view.locations:
				if not view.locations[location_id].map_id.is_empty():
					view.present(view.locations[location_id].map_id,map.loadout.map_visited)
				view.select_location(location_id)
				await settle()
				check_sidebar_layout()
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://artifacts/worldmap-sidebar/%s-%d.png" % [location_id.get_slice(".",2),dimensions.x])
			contained()
	check(map.loadout.snapshot()==snapshot,"browsing does not mutate save state")
	map.queue_free()
	await settle()
	print("WORLD MAP: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func check_sidebar_layout() -> void:
	var panel: Control = view.sidebar
	var values: Array = [panel.region_name,panel.connections,panel.percentage,panel.region_description]
	for index in values.size():
		var label: Label = panel.get_node("RegionLabel%d" % index)
		var value: Label = values[index]
		check(is_equal_approx(label.get_global_rect().position.y,value.get_global_rect().position.y),"each row's first text line aligns with its label")
	var marker: TextureRect = view.landmark_markers[view.player_location_id]
	check(is_equal_approx(view.location_marker.size.x,48.0),"player pointer half previous width")
	check(is_equal_approx(view.location_marker.get_rect().get_center().x,marker.get_rect().get_center().x),"player pointer directly above actual location")
	check(is_equal_approx(view.location_marker.get_rect().end.y,marker.position.y-6.0),"player pointer clears location marker")
	check(panel.find_child("ExplorationCount",true,false)==null,"no node-count caption under progress bar")
	check(panel.description.position.y+panel.description.size.y<=488,"location description stays inside top frame")
	check(panel.region_description.position.y+panel.region_description.size.y<=922,"region introduction stays inside middle frame")
	check(panel.connections.position.y+panel.connections.size.y<=727,"adjacent regions stay inside their row")
	check(panel.picture.texture.get_image().has_mipmaps(),"location picture mipmaps imported")
	var title_path: String = view.locations[view.selected_location_id].get("title_image","")
	check(panel.location_title.visible==not title_path.is_empty() and panel.location_name.visible==title_path.is_empty(),"only artwork or fallback name is visible")
	if not title_path.is_empty():
		check(panel.location_title.texture.atlas.resource_path==title_path,"selected location uses matching title art")
		check(panel.location_title.texture.atlas.get_image().has_mipmaps(),"title art mipmaps imported")
		check(panel.location_title.get_rect().get_center().is_equal_approx(panel.location_name.get_rect().get_center()),"title art centered in original name slot")
		check(panel.location_title.get_rect().end.y<panel.phrase.position.y,"title and phrase do not overlap")
	var edge_fraction: Variant = panel.picture.material.get_shader_parameter("edge_fraction")
	check(edge_fraction is float and is_equal_approx(edge_fraction,0.1),"scene edges fade over ten percent of each side")

func sidebar_checks() -> void:
	var region := "base.world_region.qinglanshanlu"
	var river := "base.world_location.qingshihewan"
	var town := "base.world_location.qingshizhen"
	var shrine := "base.world_location.wumingjiuci"
	check(view.selected_location_id==river,"opening defaults to current location")
	check(view.sidebar.region_name.text=="青岚山麓","configured current region")
	check(view.sidebar.connections.text=="天河商域、万灵南域","current adjacent region names")
	check(view.sidebar.location_name.get_theme_font("font") is SystemFont and "SimSun" in view.sidebar.location_name.get_theme_font("font").font_names,"location uses Song font")
	check(view.sidebar.description.get_theme_font("font").resource_path.ends_with("HarmonyOS_Sans_SC_Regular.ttf"),"description uses Huawei Regular")
	check(view.sidebar.region_name.get_theme_font("font").resource_path.ends_with("HarmonyOS_Sans_SC_Regular.ttf"),"region content uses Huawei Regular")
	var fixture := {
		"base.map.qingshihewan":["base.map.qingshihewan.point.n01","base.map.qingshihewan.point.n01","base.map.qingshihewan.point.east_exit","deleted"],
		"base.map.qingshizhen":["base.map.qingshizhen.point.n01","base.map.qingshihewan.point.n02"],
		"base.map.xiyuanyaopo":["base.map.xiyuanyaopo.point.n19"],
		"obsolete.map":["old"],"": ["planned.shrine.point"]
	}
	var progress: Dictionary = view.catalog.region_progress(region,fixture)
	check(progress.total==89 and progress.visited==4,"unique valid nodes only: three developed maps, shrine excluded")
	check(view.catalog._points_by_map["base.map.qingshihewan"].size()==40,"river includes east exit")
	check(view.catalog._points_by_map["base.map.qingshizhen"].size()==30,"all surviving town nodes in denominator")
	check(view.catalog._points_by_map["base.map.xiyuanyaopo"].size()==19,"all slope nodes in denominator")
	check(view.catalog.region_progress(region,{}).visited==0,"empty ledger does not imply revealed nodes are visited")
	var complete: Dictionary = {}
	for map_id: String in view.catalog._points_by_map:
		complete[map_id] = view.catalog._points_by_map[map_id].keys()
	check(view.catalog.region_progress(region,complete).ratio==1.0,"all 89 nodes reach 100 percent")
	var saved_ledger: Dictionary = map.loadout.map_visited.duplicate(true)
	map.set_world_map_open(false)
	map.loadout.map_visited = fixture.duplicate(true)
	map.set_world_map_open(true)
	await settle()
	check(view._visited==fixture,"MapScreen reads current visit ledger on open")
	check(view.sidebar.percentage.text=="4.5%" and is_equal_approx(view.sidebar.progress.value,4.0/89.0),"bar uses exact ratio; displayed percent one decimal")
	var actual_position: Vector2 = view.player_world_position
	var actual_node: String = map.travel.current_node_id
	for zoom in [0,view.zoom_levels.size()-3,view.zoom_levels.size()-1]:
		view._apply_zoom(view.map_window.size*0.5,zoom)
		view.map_image.position = view.map_window.size*0.5-actual_position*view.zoom_levels[zoom]
		view._clamp_map()
		for location_id: String in view.locations:
			check(view.map_window.get_global_rect().has_point(view.landmark_markers[location_id].get_global_rect().get_center()),"fixture marker visible before click")
			await click(view.landmark_markers[location_id])
			check(view.selected_location_id==location_id,"marker click selects %s at zoom %d" % [location_id,zoom])
			check(view.sidebar.location_name.text==view.locations[location_id].name,"name changes with selected marker")
			check(view.sidebar.picture.texture.resource_path==view.locations[location_id].picture,"matching location illustration")
			check(view.sidebar.description.text==view.locations[location_id].description,"matching location description")
			check(is_equal_approx(view.sidebar.progress.value,4.0/89.0),"shared region progress for all locations including shrine")
		check(view.player_world_position==actual_position and map.travel.current_node_id==actual_node,"browsing never changes actual player position")
	view.present(map.definition.id,fixture)
	var point: Vector2 = view.landmark_markers[town].get_global_rect().get_center()
	await motion(point)
	await mouse(point,MOUSE_BUTTON_LEFT)
	await motion(point+Vector2(2,1),true)
	await mouse(point+Vector2(2,1),MOUSE_BUTTON_LEFT,false)
	check(view.selected_location_id==town and not view.dragging,"small pointer jitter remains a click")
	point = view.landmark_markers[shrine].get_global_rect().get_center()
	var before: Vector2 = view.map_image.position
	await motion(point)
	await mouse(point,MOUSE_BUTTON_LEFT)
	await motion(point+Vector2(-45,-30),true)
	await mouse(point+Vector2(-45,-30),MOUSE_BUTTON_LEFT,false)
	check(view.selected_location_id==town and view.map_image.position!=before,"dragging from a location moves map without selecting it")
	var blank: Vector2 = view.map_window.get_global_rect().position+Vector2(200,200)
	await motion(blank)
	await mouse(blank,MOUSE_BUTTON_LEFT)
	await mouse(blank,MOUSE_BUTTON_LEFT,false)
	check(view.selected_location_id==town,"empty map click keeps current details")
	point = view.landmark_markers[river].get_global_rect().get_center()
	await motion(point)
	await mouse(point,MOUSE_BUTTON_LEFT)
	await key(KEY_ESCAPE)
	check(not view._pointer_down and not view.dragging,"closing clears pending location click")
	map.loadout.map_visited = saved_ledger
	await key(KEY_M)
	check(view.selected_location_id==river,"reopen returns details to actual current map")
	var expected: Dictionary = view.catalog.region_progress(region,saved_ledger)
	check(is_equal_approx(view.sidebar.progress.value,expected.ratio),"reopen refreshes progress from authoritative state")
	check(map.loadout.map_visited==saved_ledger,"read-only browsing preserves ledger")

func interaction_checks() -> void:
	await key(KEY_M,true)
	check(map.is_world_map_open(),"held M ignored")
	await key(KEY_I)
	await key(KEY_G)
	check(map.is_world_map_open() and not map.is_inventory_open() and not map.is_technique_open(),"other shortcuts cannot open behind overlay")
	await slider_checks()
	await click(view.minus_button)
	check(view.map_image.size.distance_to(view.map_window.size)<3,"minimum fits opening")
	var point: Vector2 = view.map_window.get_global_rect().get_center()
	await motion(point)
	var map_zoom: float = map.zoom_factor
	for step in range(1,view.zoom_levels.size()):
		var previous_size: Vector2 = view.map_image.size
		var anchor_local: Vector2 = view.map_window.get_global_transform().affine_inverse()*point
		var source_point: Vector2 = (anchor_local-view.map_image.position)/view.map_image.size
		await mouse(point,MOUSE_BUTTON_WHEEL_UP)
		check(view.zoom_index==step,"one wheel step advances one level")
		check_star()
		check(view.map_image.size.x>previous_size.x,"wheel visibly enlarges map")
		check(((anchor_local-view.map_image.position)/view.map_image.size).distance_to(source_point)<0.001,"zoom stays anchored at cursor")
		if step < view.zoom_levels.size()-1:
			check(is_equal_approx((view.map_image.size.x-previous_size.x)/view.map_image.texture.get_width(),0.05),"regular notch adds five percentage points")
		contained()
	await mouse(point,MOUSE_BUTTON_WHEEL_UP)
	check(view.zoom_index==view.zoom_levels.size()-1,"maximum clamps")
	check(map.zoom_factor==map_zoom,"wheel cannot zoom travel map")
	var old_position: Vector2 = view.map_image.position
	await mouse(point,MOUSE_BUTTON_LEFT)
	await motion(point+Vector2(40,30),true)
	check(view.dragging,"left drag starts")
	if view.zoom_levels.size()>1: check(view.map_image.position!=old_position,"drag moves enlarged map")
	contained()
	await motion(point+Vector2(4000,4000),true)
	await mouse(point+Vector2(4000,4000),MOUSE_BUTTON_LEFT,false)
	check(not view.dragging,"release outside ends drag")
	contained()
	var zoom: int = view.zoom_index
	var sidebar: Vector2 = view.stage.get_global_transform()*Vector2(2100,600)
	await motion(sidebar)
	await mouse(sidebar,MOUSE_BUTTON_WHEEL_DOWN)
	check(view.zoom_index==zoom,"right column does not zoom map")
	await motion(point)
	for step in range(view.zoom_levels.size()+2): await mouse(point,MOUSE_BUTTON_WHEEL_DOWN)
	check(view.zoom_index==0,"minimum clamps")
	contained()
	await mouse(point,MOUSE_BUTTON_LEFT)
	await motion(point+Vector2(-500,-500),true)
	await mouse(point+Vector2(-500,-500),MOUSE_BUTTON_LEFT,false)
	contained()
	check(view.map_image.position.length()<3,"minimum cannot be dragged out of place")
	await key(KEY_ESCAPE)
	check(not map.is_world_map_open(),"Esc closes")
	var edge: Dictionary = map.travel.adjacency[map.travel.current_node_id][0]
	map.travel.request_destination(edge.to)
	map._process(0.01)
	var position: Vector2 = map.travel.map_position
	await key(KEY_M)
	check_default(map.definition.id)
	map._process(0.1)
	check(map.travel.map_position==position,"travel paused while viewing")
	await key(KEY_M)
	map._process(0.01)
	check(map.travel.map_position!=position,"same route resumes")
	map.travel.stop_at_current_node()
	await key(KEY_M)
	await key(KEY_ESCAPE)
	check(not map.is_world_map_open(),"Esc closes without a close button")
	map.event_state.phase="rest"
	map.event_state.active_id="fixture"
	await key(KEY_M)
	check(not map.is_world_map_open(),"active event blocks world view")
	map.event_state.phase=""
	map.event_state.active_id=""
	map.set_inventory_open(true)
	await key(KEY_M)
	check(map.is_inventory_open() and not map.is_world_map_open(),"inventory stays exclusive")
	map.inventory_screen.search_box.grab_focus()
	await key(KEY_M)
	check(not map.is_world_map_open(),"M in text input does not open map")
	map.inventory_screen.search_box.release_focus()
	map.set_inventory_open(false)

func slider_checks() -> void:
	await click(view.plus_button)
	check(view.zoom_index==view.zoom_levels.size()-1,"plus jumps to maximum")
	check_star()
	await click(view.minus_button)
	check(view.zoom_index==0,"minus jumps to minimum")
	check_star()
	await motion(view.scroll_star.get_global_rect().get_center())
	await mouse(view.scroll_star.get_global_rect().get_center(),MOUSE_BUTTON_LEFT)
	for step in range(view.zoom_levels.size()):
		var y := lerpf(view.TRACK_BOTTOM,view.TRACK_TOP,float(step)/(view.zoom_levels.size()-1))
		var point: Vector2 = view.zoom_control.get_global_transform()*Vector2(view.SLIDER_SIZE.x*0.5,y)
		await motion(point,true)
		check(view.zoom_index==step,"star drag snaps to matching zoom level")
		check_star()
	await mouse(view.scroll_star.get_global_rect().get_center(),MOUSE_BUTTON_LEFT,false)
	check(not view._star_dragging and not view.dragging,"star release never starts map panning")
	for map_id in ["base.map.qingshizhen","base.map.xiyuanyaopo","base.map.qingshihewan"]:
		view.present(map_id)
		check_default(map_id)
		contained()
