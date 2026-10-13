extends "res://tests/item_selection_tooltip_tests.gd"
const WAREHOUSE := "base.warehouse.qingshizhen.home"
const Transfer := preload("res://scripts/map/map_warehouse_transfer.gd")
func run() -> void:
	create_timer(50).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(2560,1440)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	var registry := ContentRegistry.new()
	check(registry.load_base_content(),"registry")
	var state: MapLoadoutState = MapLoadoutStore.create_state(registry,registry.get_board("base.board.bag")).state
	var original := state.snapshot()
	var item := ""
	var quantity := 0
	for record: Dictionary in state.storage_records():
		if record.name == "火砂": item = record.id; quantity = record.quantity
	check(not item.is_empty(),"fixture")
	if DisplayServer.get_name() == "headless":
		for index in 19: original.owned_units["test.warehouse.stack.%d" % index] = item
		check(state.restore(original).is_empty(),"twenty-unit stack fixture")
		quantity += 19
		check(Transfer.execute(state,WAREHOUSE,item,false,"").is_empty(),"deposit full stack")
		check(state.warehouse_records(WAREHOUSE).size() == 1,"one kind stored")
		check(state.warehouse_records(WAREHOUSE)[0].quantity == quantity,"all units stored")
		check(state.storage_used_slots() == 121,"bag count excludes deposited kind")
		check(state.snapshot().owned_units == original.owned_units,"ownership conserved")
		check(not state.transfer_warehouse(WAREHOUSE,item,false).is_empty(),"repeat deposit rejected")
		var saved := state.snapshot()
		var invalid := saved.duplicate(true)
		invalid.warehouses[WAREHOUSE]["missing.unit"] = item
		check(not state.restore(invalid).is_empty() and state.snapshot() == saved,"invalid warehouse rejected atomically")
		check(not Transfer.execute(state,WAREHOUSE,item,true,"res://artifacts/no-such-warehouse-directory/save.json").is_empty(),"save failure reported")
		check(state.snapshot() == saved,"save failure leaves both sides intact")
		var path := "res://artifacts/warehouse-inventory-test-%d.json" % Time.get_ticks_usec()
		check(MapLoadoutStore.save(state,path).is_empty(),"isolated save")
		var reload_registry := ContentRegistry.new()
		check(reload_registry.load_base_content(),"fresh session registry")
		var recreated := MapLoadoutStore.create_state(reload_registry,reload_registry.get_board("base.board.bag"))
		check(recreated.error.is_empty(),"fresh session model")
		var fresh: MapLoadoutState = recreated.state
		var reload_error := MapLoadoutStore.load_into(fresh,path)
		check(reload_error.is_empty(),"reload: "+reload_error)
		check(fresh.snapshot() == state.snapshot(),"warehouse survives reload, absent from bag")
		var manager := GameManager.new()
		manager.registry = reload_registry
		manager.loadout_save_path = ""
		manager._durable_loadout = fresh
		manager._durable_snapshot = fresh.snapshot()
		manager.storage = fresh.storage
		var member := PartyMemberState.new(reload_registry.get_character("base.character.chen_yu"),reload_registry)
		member.inventory = fresh.inventory
		manager.party.append(member)
		var consumed_id: String = fresh.storage.entries()[0].instance_id
		manager.storage.take_one(consumed_id)
		check(manager.persist_consumption(),"battle consumption saves with home inventory")
		check(manager._durable_snapshot.warehouses == saved.warehouses,"battle does not delete warehouse contents")
		check(manager._durable_snapshot.owned_units.size() == saved.owned_units.size()-1,"only carried consumed unit removed")
		manager.free()
		check(Transfer.execute(state,WAREHOUSE,item,true,"").is_empty(),"withdraw full stack")
		check(state.warehouse_records(WAREHOUSE).is_empty() and state.storage_used_slots() == 122,"counts restored")
		check(state.snapshot().owned_units == original.owned_units,"withdraw conserves ownership")
		check(not state.transfer_warehouse(WAREHOUSE,"base.map_item.bag_board",false).is_empty(),"active board protected")
		# Existing formations cannot retrieve items left at home.
		check(state.transfer_warehouse(WAREHOUSE,item,false).is_empty(),"store for placement isolation")
		var unit_id: String = state.warehouses[WAREHOUSE].keys()[0]
		var layout := state.layout_snapshot()
		layout.placements = [{"instance_id":unit_id,"item_id":item,"cell":[0,0],"unit_ids":[unit_id]}]
		check(not state._validate_layout(layout).error.is_empty(),"stored units unavailable to formation")
		check(state.restore(original).is_empty(),"reset isolated model")
		for record: Dictionary in state.storage_records():
			if record.get("board_layout","") == state.board.id: continue
			check(state.transfer_warehouse(WAREHOUSE,record.id,false).is_empty(),"test overflow deposit")
		check(state.warehouse_records(WAREHOUSE).size() > 99 and state.warehouse_capacity_limit(WAREHOUSE) == 99,"warehouse permits truthful overflow")
	# Real shared layout: no production save and no input in Render mode.
	var map = load("res://scenes/maps/qingshizhen.tscn").instantiate()
	map.inventory_save_path = ""
	map.defer_map_music = true
	root.add_child(map)
	map.set_process(false)
	await settle()
	check(map.startup_error.is_empty(),"map ready")
	var ui_owned: Dictionary = map.loadout.snapshot().owned_units
	var ui: MapInventoryScreen = map.inventory_screen
	ui.set_warehouse(WAREHOUSE)
	ui.show()
	await settle()
	var pane := ui.warehouse_pane
	check(pane != null and pane.visible,"warehouse pane")
	check(pane.storage_capacity.text == "0/99","empty warehouse uses own real zero")
	check(pane.storage_panel.size.is_equal_approx(ui.storage_panel.size),"same panel dimensions")
	check(pane.grid.columns == 5 and pane.grid.get_theme_constant("h_separation") == ui.grid.get_theme_constant("h_separation"),"shared card layout")
	check(pane.storage_capacity.display_font_size() == ui.storage_capacity.display_font_size(),"two storage capacity number sizes match")
	check((pane.find_child("StorageTitleArtwork",true,false).texture as AtlasTexture).atlas.resource_path.ends_with("UI-title-cangku.webp"),"warehouse title")
	for badge in [pane.storage_capacity,ui.storage_capacity,ui.board_capacity]:
		check((badge.texture as AtlasTexture).atlas.get_image().has_mipmaps(),"capacity art mipmaps")
	check((pane.storage_capacity.texture as AtlasTexture).atlas.resource_path.ends_with("UI-title-rongliang-kucun.webp"),"warehouse art")
	check((ui.storage_capacity.texture as AtlasTexture).atlas.resource_path.ends_with("UI-title-rongliang-chuwudai.webp"),"bag art")
	check((ui.board_capacity.texture as AtlasTexture).atlas.resource_path.ends_with("UI-title-rongliang-zhange.webp"),"board art")
	if DisplayServer.get_name() == "headless":
		var card := find_card(ui,item)
		await click(card.get_global_rect().get_center(),MOUSE_BUTTON_RIGHT)
		check(map.loadout.warehouse_records(WAREHOUSE).size() == 1,"real right click deposits")
		check(pane.storage_capacity.text == "1/99" and ui.storage_capacity.text == "121/99","both counts update")
		card = find_card(pane,item)
		await click(card.get_global_rect().get_center(),MOUSE_BUTTON_RIGHT)
		check(map.loadout.warehouse_records(WAREHOUSE).is_empty(),"real right click withdraws")
		card = find_card(ui,item)
		var start := card.get_global_rect().get_center()
		motion(start)
		button(start,MOUSE_BUTTON_LEFT,true)
		motion(start+Vector2(15,0),true)
		await settle()
		check(root.gui_is_dragging(),"warehouse item drag starts")
		var target := pane.storage_panel.get_global_rect().get_center()
		motion(target,true)
		await settle()
		button(target,MOUSE_BUTTON_LEFT,false)
		await settle()
		check(map.loadout.warehouse_records(WAREHOUSE).size() == 1,"drag deposit succeeds")
		check(map.loadout.snapshot().owned_units == ui_owned,"UI transfers conserve units")
		card = find_card(pane,item)
		start = card.get_global_rect().get_center()
		motion(start)
		button(start,MOUSE_BUTTON_LEFT,true)
		motion(start+Vector2(15,0),true)
		await settle()
		check(root.gui_is_dragging(),"withdraw drag starts")
		target = ui.storage_panel.get_global_rect().get_center()
		motion(target,true)
		await settle()
		button(target,MOUSE_BUTTON_LEFT,false)
		await settle()
		check(map.loadout.warehouse_records(WAREHOUSE).is_empty(),"drag withdrawal succeeds")
		var drag := ui._warehouse_drag(item)
		check(pane._can_transfer(drag) and not ui._can_transfer(drag),"only opposite side accepts transfer")
		drag.revision -= 1
		check(not pane._can_transfer(drag),"stale drag rejected")
	else:
		for record: Dictionary in map.loadout.storage_records().duplicate():
			if record.category != "board":
				check(map.loadout.transfer_warehouse(WAREHOUSE,record.id,false).is_empty(),"preview fixture deposit")
			if map.loadout.warehouse_records(WAREHOUSE).size() == 16: break
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/warehouse-inventory.png")
	ui.set_warehouse()
	await settle()
	check(ui.board_panel.visible and not pane.visible,"ordinary inventory restores board")
	check(find_card(ui,"base.map_item.qinglan_board_1").equipment_actions_enabled,"normal equip restored")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/inventory-capacity-art.png")
	map.queue_free()
	await settle()
	print("WAREHOUSE INVENTORY: ",checks," checks, ",failures," failures; isolated saves only; Render has no mouse")
	quit(1 if failures else 0)

func find_card(ui: MapInventoryScreen, item: String) -> MapInventoryItemCard:
	for card: MapInventoryItemCard in ui.grid.get_children():
		if card.entry.id == item: return card
	return null
