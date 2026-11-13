extends SceneTree
const State = GameCursorManager.State
var checks := 0
var failures := 0
var cursors: GameCursorManager

func _initialize() -> void: run.call_deferred()

func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("CURSOR: " + note)

func settle(frames := 3) -> void:
	for i in frames: await process_frame

func move(point: Vector2, held := false, relative := Vector2.ZERO) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	Input.parse_input_event(event)
	await settle()

func mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(event)
	await settle()

func escape() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	Input.parse_input_event(event)
	await settle()

func run() -> void:
	create_timer(50).timeout.connect(func(): quit(2))
	if DisplayServer.get_name() != "headless":
		push_error("Use cursor_visual_preview.gd for rendered cursor checks.")
		quit(1)
		return
	root.size = Vector2i(2560,1440)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	AudioServer.set_bus_mute(0,true)
	cursors = root.get_node("CursorManager")
	check(cursors.custom_enabled and cursors.size_name == "normal", "default custom standard cursor")
	for label in ["normal", "large"]:
		for state in 5:
			var texture := cursors.texture_for(state, label)
			var side := 40 if label == "normal" else 56
			check(texture.get_size() == Vector2.ONE*side, "native texture size %s/%d" % [label,state])
			check(Rect2(Vector2.ZERO,texture.get_size()).has_point(cursors.hotspot_for(state,label)), "hotspot inside texture")
		check(cursors.hotspot_for(State.DRAG_READY,label)==cursors.hotspot_for(State.DRAGGING,label), "shared hand hotspot")
	var cursor_config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/cursors.json"))
	for state: int in [State.NORMAL,State.INTERACT,State.FORBIDDEN]:
		var entry: Dictionary = cursor_config.states[state]
		var texture: Texture2D = load(str(entry.texture))
		var image := texture.get_image()
		if image.is_compressed(): image.decompress()
		check(image.get_pixel(int(entry.hotspot[0]),int(entry.hotspot[1])).a>=0.5,"updated arrow hotspot is on visible tip")
	check(Input.CURSOR_IBEAM not in cursors.SHAPES and Input.CURSOR_HSIZE not in cursors.SHAPES, "preserve text and resize cursors")
	await basic_ui()
	await map_and_inventory()
	await battle_board()
	await settings()
	check(cursors._drag_owner == null, "all sources released")
	print("CURSOR CHECKS ",checks," FAILURES ",failures)
	quit(1 if failures else 0)

func basic_ui() -> void:
	var background := Control.new()
	background.size = Vector2(root.size)
	root.add_child(background)
	var button := Button.new()
	button.position = Vector2(120,120)
	button.size = Vector2(180,60)
	background.add_child(button)
	await move(Vector2(150,140))
	check(cursors.current_state == State.INTERACT, "enabled button")
	var count := cursors.registration_count
	await settle(5)
	check(cursors.registration_count == count, "no per-frame hardware re-registration")
	button.disabled = true
	await settle()
	check(cursors.current_state == State.FORBIDDEN, "stationary pointer sees disabled permission")
	await move(Vector2(700,700))
	check(cursors.current_state == State.NORMAL, "plain background is normal")
	button.disabled = false
	var decoration := ColorRect.new()
	decoration.position = button.position
	decoration.size = button.size
	decoration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.add_child(decoration)
	await move(Vector2(150,140))
	check(cursors.current_state == State.INTERACT, "decorative overlay passes hover")
	var modal := Control.new()
	modal.size = Vector2(root.size)
	background.add_child(modal)
	await move(Vector2(151,140))
	check(cursors.current_state == State.NORMAL, "modal empty area blocks underlying button")
	modal.queue_free()
	await settle()
	await move(Vector2(150,140))
	check(cursors.current_state == State.INTERACT, "closing modal restores hover")
	var edit := LineEdit.new()
	edit.position = Vector2(500,120)
	edit.size = Vector2(200,50)
	background.add_child(edit)
	await move(Vector2(550,140))
	check(cursors.current_state == State.NORMAL and edit.mouse_default_cursor_shape == Control.CURSOR_IBEAM, "native text cursor preserved")
	cursors.begin_drag(button,false)
	await settle()
	check(cursors.current_state == State.DRAGGING, "actual manual drag has priority")
	button.queue_free()
	await settle()
	check(cursors._drag_owner == null and cursors.current_state != State.DRAGGING, "deleted source releases cursor")
	background.queue_free()
	await settle()

func map_and_inventory() -> void:
	var map = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path = ""
	map.defer_map_music = true
	root.add_child(map)
	current_scene = map
	await settle(8)
	check(map.startup_error.is_empty(), "actual map startup")
	var point := Vector2.ZERO
	for route_point: MapRoutePoint in map.content.get_node("Points").get_children():
		if not route_point.is_visible_in_tree(): continue
		var candidate: Vector2 = map.map_to_screen(map.content.to_local(route_point.global_position))
		if map.map_viewport.get_rect().grow(-100).has_point(candidate):
			point = candidate
			break
	check(point != Vector2.ZERO, "visible node fixture")
	await move(point)
	check(cursors.current_state == State.INTERACT, "real map node uses existing hit region")
	await mouse(point,true)
	check(cursors.current_state == State.INTERACT and not map._dragging,"regional path node press retains interaction arrow")
	await move(point+Vector2(2,0),true,Vector2(2,0))
	check(cursors.current_state == State.INTERACT and not map._dragging,"node click below pan threshold retains interaction arrow")
	# End the fixture press before release so it does not start a route/event.
	map._end_drag()
	await mouse(point+Vector2(2,0),false)
	check(cursors.current_state == State.INTERACT,"node release retains interaction arrow")
	var plain := Vector2.ZERO
	for y in range(300,1100,100):
		for x in range(400,2000,100):
			var candidate := Vector2(x,y)
			if not map.map_viewport.get_rect().grow(-100).has_point(candidate) or not map._node_at(candidate).is_empty(): continue
			await move(candidate)
			if root.gui_get_hovered_control() == map:
				plain = candidate
				break
		if plain != Vector2.ZERO: break
	check(plain != Vector2.ZERO,"unobstructed map background fixture")
	check(cursors.current_state == State.NORMAL, "regional map background uses normal arrow")
	await mouse(plain,true)
	check(cursors.current_state == State.DRAGGING and not map._dragging,"map press shows grip before movement")
	await move(plain+Vector2(2,0),true,Vector2(2,0))
	check(cursors.current_state == State.DRAGGING and not map._dragging, "map press feedback preserves six-pixel pan threshold")
	await move(plain+Vector2(20,0),true,Vector2(18,0))
	check(cursors.current_state == State.DRAGGING and map._dragging, "actual map panning")
	await mouse(plain+Vector2(20,0),false)
	check(cursors.current_state == State.NORMAL and not map._dragging, "pan release restores normal arrow")
	var old_scale: Vector2 = map.content.scale
	map.content.scale = Vector2.ONE*0.01
	await move(plain)
	check(cursors.current_state==State.NORMAL,"unscrollable map background is normal")
	await mouse(plain,true)
	check(cursors.current_state==State.NORMAL and not map._dragging,"unscrollable map press remains normal")
	await move(plain+Vector2(20,0),true,Vector2(20,0))
	check(cursors.current_state==State.NORMAL,"unscrollable map hold remains normal")
	await mouse(plain+Vector2(20,0),false)
	map.content.scale = old_scale
	var rest: MapRestDialog = map.rest_dialog
	rest.show()
	await settle()
	var popup_body: Vector2 = rest.canvas.get_global_transform_with_canvas()*Vector2(800,230)
	await move(popup_body)
	check(cursors.current_state==State.NORMAL,"real rest popup body uses normal arrow")
	await mouse(popup_body,true)
	check(cursors.current_state==State.NORMAL,"popup body press retains normal arrow")
	await mouse(popup_body,false)
	var popup_button: Vector2 = rest.later_button.get_global_rect().get_center()
	await move(popup_button)
	check(cursors.current_state==State.INTERACT,"real popup button uses interaction arrow")
	await mouse(popup_button,true)
	check(cursors.current_state==State.INTERACT,"popup button press retains interaction arrow")
	rest.hide()
	await mouse(popup_button,false)
	map._ensure_world_map_view()
	var world = map.world_map
	world.present(map.definition.id, {})
	await settle()
	var world_point: Vector2 = world.map_window.get_global_transform_with_canvas()*Vector2(500,500)
	await move(world_point)
	check(cursors.current_state == State.NORMAL, "world map background uses normal arrow")
	await mouse(world_point,true)
	check(cursors.current_state==State.DRAGGING and not world.dragging,"world map press shows grip before movement")
	await move(world_point+Vector2(30,20),true,Vector2(30,20))
	check(cursors.current_state == State.DRAGGING and world.dragging, "world map actual drag")
	await mouse(world_point+Vector2(30,20),false)
	check(cursors.current_state==State.NORMAL,"world map release restores normal arrow")
	var location_point := Vector2.ZERO
	for marker: TextureRect in world.landmark_markers.values():
		if marker.visible and Rect2(Vector2.ZERO,world.map_window.size).has_point(marker.get_rect().get_center()):
			location_point = world.map_window.get_global_transform_with_canvas()*marker.get_rect().get_center()
			break
	check(location_point!=Vector2.ZERO,"visible world location fixture")
	await move(location_point)
	await mouse(location_point,true)
	check(cursors.current_state==State.INTERACT and not world.dragging,"world location click retains interaction arrow")
	await mouse(location_point,false)
	check(cursors.current_state==State.INTERACT,"world location release restores interaction arrow")
	var frame_point: Vector2 = world.stage.get_global_transform_with_canvas()*Vector2(2370,400)
	await move(frame_point)
	await mouse(frame_point,true)
	check(cursors.current_state==State.NORMAL and not world.dragging,"world popup frame uses normal arrow")
	await mouse(frame_point,false)
	check(cursors.current_state!=State.DRAGGING,"world popup frame release clears grip")
	var outside: Vector2 = world.stage.get_global_transform_with_canvas()*Vector2(20,400)
	await move(outside)
	await mouse(outside,true)
	check(cursors.current_state!=State.DRAGGING,"world popup shade is outside press feedback")
	await mouse(outside,false)
	var zoom_button_center: Vector2 = world.plus_button.get_global_rect().get_center()
	await move(zoom_button_center)
	await mouse(zoom_button_center,true)
	check(cursors.current_state==State.INTERACT,"world popup button press retains interaction arrow")
	await mouse(zoom_button_center,false)
	check(world.zoom_index==world.zoom_levels.size()-1 and cursors.current_state==State.INTERACT,"world popup button still selects maximum zoom and restores hover")
	world.hide()
	map._end_drag()
	var model: MapLoadoutState = map.loadout
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/map_inventory.json"))
	var catalog := MapInventoryCatalog.new()
	catalog.configure(config)
	var records: Array[Dictionary] = []
	for record: Dictionary in model.storage_records():
		if record.name == "开山斧": records.append(record)
	check(records.size()==1,"storage fixture")
	catalog.replace_entries(records)
	var inventory := MapInventoryScreen.new()
	inventory.configure(catalog,config,model.board,model)
	root.add_child(inventory)
	inventory.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inventory.show()
	await settle(6)
	var card: MapInventoryItemCard = inventory.grid.get_child(0)
	var center := card.get_global_rect().get_center()
	var before := model.snapshot()
	await move(center)
	check(cursors.current_state == State.DRAG_READY,"real storage draggable item")
	await mouse(center,true)
	await move(center+Vector2(2,0),true,Vector2(2,0))
	check(not root.gui_is_dragging() and cursors.current_state == State.DRAG_READY, "card click does not become a drag")
	await mouse(center+Vector2(2,0),false)
	check(card.selected and model.snapshot()==before,"selection still preserves inventory")
	await mouse(center,true)
	await move(center+Vector2(15,0),true,Vector2(15,0))
	check(root.gui_is_dragging(),"existing card threshold starts native drag")
	var board: MapLoadoutBoard = inventory.loadout_board
	var data: Variant = root.gui_get_drag_data()
	var invalid_point := Vector2(2,2)
	await move(board.get_global_transform()*invalid_point,true)
	check(cursors.current_state == State.FORBIDDEN and not board._can_drop_data(invalid_point,data),"explicit bad board drop")
	var valid := Vector2.ZERO
	for y in model.inventory.grid_size.y:
		for x in model.inventory.grid_size.x:
			var candidate := board.layout.footprint_rect(Vector2i(x,y),Vector2i.ONE,board.size).get_center()
			if board._can_drop_data(candidate,data): valid=candidate; break
		if valid != Vector2.ZERO: break
	check(valid!=Vector2.ZERO,"available board drop fixture")
	await move(board.get_global_transform()*valid,true)
	check(cursors.current_state == State.DRAGGING,"valid drop restores gripping hand")
	check(model.snapshot()==before,"cursor queries never execute a drop")
	await escape()
	check(not root.gui_is_dragging() and cursors._drag_owner==null,"escape clears native drag")
	check(model.snapshot()==before,"cancel preserves inventory")
	await move(center)
	await mouse(center,true)
	await move(center+Vector2(15,0),true,Vector2(15,0))
	await move(board.get_global_transform()*valid,true)
	await mouse(board.get_global_transform()*valid,false)
	check(not root.gui_is_dragging() and cursors._drag_owner == null,"native release ends drag")
	check(model.snapshot()!=before and cursors.current_state==State.DRAG_READY,"successful drop keeps business placement and refreshes hover")
	inventory.set_warehouse("cursor_test_warehouse")
	await settle(5)
	var transfer := inventory._warehouse_drag(records[0].id)
	check(cursors.drop_state_for(inventory.grid,transfer)==0,"warehouse rejects same pane")
	check(cursors.drop_state_for(inventory.warehouse_pane.grid,transfer)==1,"warehouse accepts opposite pane")
	var reverse := inventory.warehouse_pane._warehouse_drag(records[0].id)
	check(cursors.drop_state_for(inventory.grid,reverse)==1,"warehouse withdrawal accepts bag")
	check(cursors.drop_state_for(inventory.warehouse_pane.grid,reverse)==0,"warehouse withdrawal rejects source")
	cursors.begin_drag(inventory,false)
	var settings_panel = load("res://scripts/settings/settings_panel.gd").new()
	root.add_child(settings_panel)
	await settle()
	check(cursors._drag_owner==null,"opening settings cancels active drag")
	settings_panel.queue_free()
	cursors.begin_drag(inventory,false)
	inventory.hide()
	await settle()
	check(cursors._drag_owner==null,"hidden source releases drag")
	inventory.queue_free()
	map.queue_free()
	current_scene = null
	await settle(8)

func battle_board() -> void:
	var scene = load("res://scenes/main/main.tscn").instantiate()
	var game: GameManager = scene.get_node("GameManager")
	game.loadout_save_path = ""
	root.add_child(scene)
	game.set_process(false)
	await settle(6)
	check(game.startup_error.is_empty(),"actual battle startup")
	for entry: Dictionary in game.storage.entries():
		if entry.item_id == "base.map_item.short_iron_hammer":
			check(game.equip(entry.instance_id,0,Vector2i.ZERO),"equip battle cursor fixture")
			break
	var ui = scene.get_node("MainUI")
	var board: InventoryView = ui.ally_panel.bags[0]
	var entries := board.inventory.get_instances()
	check(not entries.is_empty(),"battle board fixture")
	if entries.is_empty():
		scene.queue_free()
		await settle()
		return
	var local := board.board_layout.footprint_rect(entries[0].cell,Vector2i.ONE,board.size).get_center()
	await move(board.get_global_transform()*local)
	check(cursors.current_state==State.DRAG_READY,"actual battle movable item")
	var data := board.drag_data_at(local)
	board.force_drag(data,board.make_drag_preview(game.registry.get_item(entries[0].item_id),entries[0]))
	cursors.begin_drag(board)
	await settle()
	var art := board.visible_art_rect()
	var bad := art.position+Vector2(4,4)
	await move(board.get_global_transform()*bad,true)
	check(cursors.current_state==State.FORBIDDEN,"battle rejects out-of-grid drop")
	cursors._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await settle()
	check(not root.gui_is_dragging() and cursors.current_state==State.NORMAL,"focus loss clears native drag")
	cursors._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await settle()
	game.start_battle()
	await move(board.get_global_transform()*local)
	check(cursors.current_state==State.NORMAL,"running battle has read-only board")
	var enemy: InventoryView = ui.enemy_panel.bags[0]
	check(enemy.cursor_hover_state(Vector2.ZERO)==State.NORMAL,"enemy board is read-only")
	scene.queue_free()
	await settle(8)

func settings() -> void:
	var panel = load("res://scripts/settings/settings_panel.gd").new()
	root.add_child(panel)
	await settle()
	panel.select_page("other")
	check(panel.widgets.has("custom_cursor") and panel.widgets.has("cursor_size"),"other page controls present")
	panel.draft.custom_cursor = false
	panel._refresh_values()
	check(panel.widgets.cursor_size.disabled and cursors.custom_enabled,"disabled size is draft-only")
	var service := root.get_node("GameSettings")
	check(service.apply_values({"custom_cursor":false}).is_empty(),"system cursor setting applies")
	check(not cursors.custom_enabled and cursors._registered_state==-1,"all custom shapes restored")
	check(service.apply_values({"custom_cursor":true,"cursor_size":"large"}).is_empty(),"large custom setting applies")
	check(cursors.custom_enabled and cursors.size_name=="large" and cursors._registered_state>=0,"native registration rebuilt")
	check(not service.validate_values({"cursor_size":"huge"}).is_empty(),"invalid size rejected")
	service.apply_values({"custom_cursor":true,"cursor_size":"normal"})
	panel.queue_free()
	await settle()
