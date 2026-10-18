extends "res://tests/map_shop_tests.gd"

const INN_POINT := "base.map.qingshizhen.point.n13"
const INN_EVENT := "base.map_event.qingshizhen.inn"

func open_inn(map: Node) -> void:
	map.content.position = map.map_viewport.size*0.5-map.travel.map_position*map.content.scale
	map._select_destination(map.map_to_screen(map.travel.map_position))
	await settle()
	check(map.event_state.phase=="inn" and map.inn_dialog.visible and map.travel.paused,"node opens inn modal")
	check(map.inn_dialog.mode=="conversation","reopening defaults to conversation")

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
	var event: Dictionary = map.event_registry.events[INN_EVENT]
	check(event.point_id==INN_POINT and event.trigger=="click","manual N13 entry")
	check(map.content.get_node("Points/N13").location_note=="客栈","node renamed")
	map.travel.current_node_id = INN_POINT
	map.travel.map_position = map.travel.node_positions[INN_POINT]
	map.travel.stop_at_current_node()
	map.travel.node_arrived.emit(INN_POINT)
	check(not map.event_state.is_active(),"passing inn does not open it")
	var before: Dictionary = MapLoadoutStore.candidate(map.loadout).state.snapshot()
	var resources: Dictionary = map.player_status.resources.duplicate(true)
	await open_inn(map)
	var dialog: MapInnDialog = map.inn_dialog
	check(dialog.title_label.text=="清石客栈" and dialog.leave_button.text=="离开客栈","header and leave")
	check([dialog.conversation_tab.text,dialog.food_tab.text,dialog.lodging_tab.text]==["交谈","吃食","住宿"],"three authored tabs")
	check(dialog.library!=null and dialog.library.definition.id=="base.npc.tongwantang" and dialog.dialogue_rows.get_child_count()>0,"authored Tong conversation connected")
	check(dialog.food_view.shop.products().size()==9 and dialog.lodging_content.get_child_count()>0,"nine food products and lodging connected")
	check(not dialog.treatment_tab.visible and not dialog.treatment_content.visible,"no clinic controls exposed")
	check(event.presentation.conversation_portrait=="res://assets/ui-portrait-tongwantang.webp","Tong portrait binding")
	check(dialog.illustration.texture.resource_path==event.presentation.illustration,"correct shared scene")
	for key in ["background","food_background","lodging_background","illustration","conversation_portrait"]:
		check(load(event.presentation[key]).get_image().has_mipmaps(),"mipmaps: "+key)
	check(map.event_state.advance().is_empty() and map.event_state.phase=="inn","generic dialogue cannot complete inn")
	var scene_rect := dialog.illustration.get_global_rect()
	var pages := ["food","lodging","conversation"]
	if DisplayServer.get_name()=="headless": pages.append_array(["lodging","food","conversation"])
	for page in pages:
		if DisplayServer.get_name()=="headless":
			var button: Button = dialog.conversation_tab if page=="conversation" else (dialog.food_tab if page=="food" else dialog.lodging_tab)
			await click(button)
		else:
			dialog.set_mode(page)
			await settle()
		var key: String = "background" if page=="conversation" else page+"_background"
		check(dialog.mode==page and dialog.backing.texture.atlas.resource_path==event.presentation[key],"tab and background: "+page)
		check(dialog.conversation_content.visible==(page=="conversation") and dialog.food_content.visible==(page=="food") and dialog.lodging_content.visible==(page=="lodging"),"exclusive content: "+page)
		check(dialog.illustration.get_global_rect()==scene_rect,"scene remains fixed: "+page)
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/inn-"+page+".png")
	if DisplayServer.get_name()=="headless":
		await click(dialog.leave_button)
		check(not dialog.visible and not map.event_state.is_active() and not map.travel.paused,"leave restores travel")
		for close_method in ["right","escape"]:
			await open_inn(map)
			await click(dialog.lodging_tab)
			if close_method=="right":
				var input := InputEventMouseButton.new()
				input.button_index = MOUSE_BUTTON_RIGHT
				input.pressed = true
				input.position = dialog.canvas.get_global_rect().get_center()
				root.push_input(input,true)
			else:
				var input := InputEventKey.new()
				input.keycode = KEY_ESCAPE
				input.pressed = true
				root.push_input(input,true)
			await settle()
			check(not dialog.visible and not map.event_state.is_active() and not map.travel.paused,"close: "+close_method)
		var registry := MapEventRegistry.new()
		for key in ["food_background","lodging_background","conversation_portrait"]:
			var bad := event.duplicate(true)
			bad.presentation[key] = "res://missing-inn.webp"
			check(not registry.configure([bad],[INN_POINT]).is_empty(),"reject bad inn art: "+key)
	else: map._close_inn()
	check(not map.event_state.completed.has(INN_EVENT),"inn remains reusable")
	var after: Dictionary = map.loadout.snapshot()
	check(after.narrative.npcs.has("base.npc.tongwantang"),"only real visits create Tong journal")
	before.erase("narrative")
	after.erase("narrative")
	check(after==before and map.player_status.resources==resources,"tabs do not alter inventory, money, date or resources")
	map.queue_free()
	await settle()
	root.get_node("UiButtonAudio").player.stop()
	await create_timer(0.1).timeout
	print("INN TABS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
