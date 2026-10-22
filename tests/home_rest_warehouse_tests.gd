extends SceneTree

var checks := 0
var failures := 0
var normal_bag_rect := Rect2()
var normal_middle_rect := Rect2()
const POINT := "base.map.qingshizhen.point.n03"
const EVENT := "base.map_event.qingshizhen.home_rest"

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: "+message)
func settle() -> void:
	for frame in 8: await process_frame
func click(control: Control, button := MOUSE_BUTTON_LEFT) -> void:
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.position = control.get_global_rect().get_center()
		event.pressed = pressed
		root.push_input(event,true)
	await settle()
func hover(control: Control) -> void:
	var event := InputEventMouseMotion.new()
	event.position = control.get_global_rect().get_center()
	event.global_position = event.position
	root.push_input(event,true)
	await settle()
func escape() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	root.push_input(event,true)
	await settle()
func open_home(map: Node) -> void:
	check(map._try_start_event(POINT,"click",true),"reopen home from stationary node")
	await settle()
func screenshot(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func visual_contract(map: Node) -> void:
	var dialog: MapRestDialog = map.rest_dialog
	check(dialog.heading.text=="自己家" and dialog.description.text=="这是你在青石镇的家。虽简朴，却温暖安宁。\n这里可供你休息恢复，也可存放各类物品。","home copy")
	check(dialog.backing.texture.atlas.resource_path.ends_with("tanchuang-qingshizhen-shineizijia1.webp"),"home background")
	check(dialog.illustration.texture.resource_path.ends_with("tanchuang-qingshizhen-shineizijia2.webp"),"home illustration")
	check(dialog.percentage.text=="100%" and dialog.days.text=="1","100 percent and one day")
	check(dialog.warehouse_label.text=="进入仓储" and dialog.start_label.text=="开始休息","two action captions")
	check(dialog.warehouse_label.get_theme_font("font")==dialog.start_label.get_theme_font("font") and dialog.warehouse_label.get_theme_font_size("font_size")==dialog.start_label.get_theme_font_size("font_size"),"action typography shared")
	check(not dialog.warehouse_button.get_global_rect().intersects(dialog.start_button.get_global_rect()),"actions do not overlap")
	for label: Label in [dialog.description,dialog.note,dialog.warning,dialog.percentage]:
		check(label.get_visible_line_count()==label.get_line_count(),"text fits: "+label.text)
	for asset in ["tanchuang-qingshizhen-shineizijia1","tanchuang-qingshizhen-shineizijia2","tanchuang-huifu-cangku1","tanchuang-huifu-cangku2"]:
		var settings := ConfigFile.new()
		settings.load("res://assets/%s.webp.import" % asset)
		check(settings.get_value("params","mipmaps/generate",false),"mipmaps: "+asset)
	check(not map.calendar_readout.visible,"existing hidden date remains hidden")

func warehouse_contract(map: Node, bag_rect: Rect2) -> void:
	var screen: MapInventoryScreen = map.inventory_screen
	check(screen.visible and not map.rest_dialog.visible and screen.warehouse_id=="base.warehouse.qingshizhen.home","warehouse view from home")
	check(screen.storage_panel.get_global_rect().is_equal_approx(bag_rect),"bag geometry unchanged")
	var warehouse_rect := screen.board_panel.get_global_rect()
	check(is_equal_approx(warehouse_rect.size.x,bag_rect.size.x),"warehouse matches bag width")
	check(is_equal_approx(warehouse_rect.position.x,normal_middle_rect.position.x),"warehouse left edge fixed")
	check(warehouse_rect.end.x<normal_middle_rect.end.x and bag_rect.position.x-warehouse_rect.end.x>bag_rect.position.x-normal_middle_rect.end.x,"only warehouse right edge retracts and reserves the gap")
	check(screen.board_panel.name=="WarehousePanel","middle panel named for warehouse")
	check(screen.sidebar.is_visible_in_tree() and screen.sidebar_art.is_visible_in_tree() and screen.warehouse_pane.is_visible_in_tree(),"sidebar and real warehouse retained")
	check(screen.warehouse_pane.storage_panel.get_node("StorageBackgroundLayer/StoragePanelBackground").is_visible_in_tree(),"warehouse uses bag background")
	check(screen._equipment_sections.all(func(control):return not control.is_visible_in_tree()),"left and middle content empty")
	check(screen.grid.get_child_count()>0 and screen.return_button.is_visible_in_tree(),"bag populated and return available")
	for card in screen.grid.get_children():
		if card is MapInventoryItemCard:
			check(not card.equipment_actions_enabled and card.loadout==map.loadout,"bag reads actual state without hidden equip actions")

func interaction(map: Node) -> void:
	var dialog: MapRestDialog = map.rest_dialog
	var before: Dictionary = map.loadout.snapshot()
	var resources: Dictionary = map.player_status.resources.duplicate()
	await click(dialog.later_button)
	check(not dialog.visible and map.loadout.snapshot()==before and map.player_status.resources==resources,"cancel costs no time or resources")
	await open_home(map)
	await hover(dialog.warehouse_button)
	check(dialog.warehouse_button.is_hovered() and dialog.warehouse_label.get_theme_color("font_color")==Color.BLACK and dialog.warehouse_button.texture_hover.resource_path.ends_with("cangku2.webp"),"warehouse hover art and black caption")
	var screen: MapInventoryScreen = map.inventory_screen
	dialog.set_busy(true)
	await click(dialog.warehouse_button)
	check(dialog.visible and not screen.visible,"busy home blocks warehouse")
	dialog.set_busy(false)
	await click(dialog.warehouse_button)
	warehouse_contract(map,normal_bag_rect)
	check(map.loadout.snapshot()==before and map.player_status.resources==resources,"enter warehouse costs no day or resources")
	var card: MapInventoryItemCard = screen.grid.get_child(0)
	await click(card)
	check(card.selected,"warehouse bag keeps card selection")
	var tooltip := card.build_item_tooltip("")
	check(tooltip is ItemTooltip,"warehouse bag keeps item description")
	tooltip.free()
	check(card._storage_drag_data().kind == "warehouse_transfer","warehouse uses transfer drag, never hidden equipment drag")
	await click(card,MOUSE_BUTTON_RIGHT)
	check(map.loadout.warehouse_records(screen.warehouse_id).size()==1 and screen.visible,"right click deposits without closing home")
	await click(screen.warehouse_pane.grid.get_child(0),MOUSE_BUTTON_RIGHT)
	check(map.loadout.snapshot()==before,"withdrawing restores both inventories")
	await click(screen.return_button)
	check(not dialog.visible and not screen.visible and screen.warehouse_id.is_empty() and not map.event_state.is_active() and not map.travel.paused,"return to travel closes warehouse and home")
	await open_home(map)
	await click(dialog.warehouse_button)
	await escape()
	check(not dialog.visible and not screen.visible and not map.event_state.is_active() and map.loadout.snapshot()==before,"escape returns to map without time or inventory mutation")
	await open_home(map)
	for resource in ["hp","stamina","spirit"]: map.player_status.set_resource(resource,0.25)
	var day_before := WorldCalendar.current_day(map.loadout.calendar)
	var real_path: String = map.inventory_save_path
	map.inventory_save_path="res://artifacts/nonexistent-home-directory/save.json"
	await click(dialog.start_button)
	check(dialog.visible and not dialog.error_label.text.is_empty() and WorldCalendar.current_day(map.loadout.calendar)==day_before and map.player_status.resources.hp==0.25,"failed home save retains time/resources and retry")
	map.inventory_save_path=real_path
	await click(dialog.start_button)
	check(not dialog.visible and not map.player_status.needs_rest(),"home rest restores all three resources to maxima")
	check(WorldCalendar.current_day(map.loadout.calendar)==day_before+1,"home rest advances one day")
	map._confirm_rest()
	check(WorldCalendar.current_day(map.loadout.calendar)==day_before+1,"duplicate rest ignored")
	check(not map.event_state.completed.has(EVENT) and map.content.get_node("Points/N03/Sign").visible,"home remains reusable")
	await open_home(map)
	check(not dialog.start_button.disabled,"full state home rest enabled")
	await click(dialog.start_button)
	check(WorldCalendar.current_day(map.loadout.calendar)==day_before+2 and map.player_status.last_rest.gains.values().all(func(value):return is_zero_approx(float(value))),"full rest one day and zero gains")
	map.set_inventory_open(true)
	await settle()
	check(screen.visible and screen.warehouse_id.is_empty() and screen._equipment_sections.all(func(control):return control.is_visible_in_tree()),"normal inventory contents restored")
	check(screen.grid.get_children().all(func(control):return not control is MapInventoryItemCard or control.equipment_actions_enabled),"normal equipment actions restored")
	map.set_inventory_open(false)
	var river: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_events/qingshihewan_rest_n13.json"))
	dialog.present(river,true)
	check(not dialog.warehouse_button.visible and not dialog.warehouse_label.visible and dialog.start_button.get_meta("source_rect")==Rect2(944,684,376,127),"existing river rest keeps one original button")
	dialog.hide()

func run() -> void:
	create_timer(40).timeout.connect(func():quit(2))
	AudioServer.set_bus_mute(0,true)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size=Vector2i.ZERO
	root.size=Vector2i(2560,1440)
	MapEventState.session_completed.clear()
	var map=load("res://scenes/maps/qingshizhen.tscn").instantiate()
	map.inventory_save_path="res://artifacts/home-rest-%d.json" % Time.get_ticks_usec()
	map.defer_map_music=true
	root.add_child(map)
	current_scene=map
	map.set_process(false)
	await settle()
	check(map.startup_error.is_empty(),"town startup: "+map.startup_error)
	if not map.startup_error.is_empty(): quit(1); return
	check(map.event_registry.by_point.get(POINT)==EVENT,"home event on screenshot node")
	# Compare fully laid-out visible containers, not the initially hidden bag.
	map.set_inventory_open(true)
	await settle()
	normal_bag_rect=map.inventory_screen.storage_panel.get_global_rect()
	normal_middle_rect=map.inventory_screen.board_panel.get_global_rect()
	map.set_inventory_open(false)
	var origin: String = map.travel.adjacency[POINT][0].to
	map.travel.current_node_id=origin
	map.travel.map_position=map.travel.node_positions[origin]
	map.travel.mode="idle"
	check(map.travel.request_destination(POINT),"travel to home")
	map.travel.advance(1000)
	await settle()
	check(not map.event_state.is_active() and not map.rest_dialog.visible and not map.travel.paused,"arrival does not open home")
	check(map._try_start_event(POINT,"click",true),"manual click opens home")
	await settle()
	check(map.event_state.phase=="rest" and map.rest_dialog.visible and map.travel.paused,"manual interaction opens home")
	visual_contract(map)
	if DisplayServer.get_name()=="headless":
		await interaction(map)
	else:
		await screenshot("res://artifacts/home-rest.png")
		map._open_home_warehouse()
		await settle()
		warehouse_contract(map,normal_bag_rect)
		await screenshot("res://artifacts/home-warehouse.png")
		map._close_home_warehouse()
		map.set_inventory_open(true)
		await settle()
		check(map.inventory_screen.board_panel.get_global_rect().is_equal_approx(normal_middle_rect),"ordinary inventory middle panel restored")
		check(map.inventory_screen.storage_panel.get_global_rect().is_equal_approx(normal_bag_rect),"ordinary bag stays unchanged")
	map.queue_free()
	await settle()
	print("HOME REST / WAREHOUSE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
