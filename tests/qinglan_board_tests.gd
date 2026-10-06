extends SceneTree
var checks := 0
var failures := 0
const SAVE := "res://artifacts/qinglan-board-test.json"
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func settle() -> void:
	for i in 8: await process_frame
func run() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(2560,1440)
	var registry := ContentRegistry.new()
	check(registry.load_base_content(),"content loads")
	var created := MapLoadoutStore.create_state(registry,registry.get_board("base.board.bag"))
	check(created.error.is_empty(),"catalog loads: "+created.error)
	if not created.error.is_empty(): quit(1); return
	var model: MapLoadoutState = created.state
	var sizes := [Vector2i(4,3),Vector2i(4,4),Vector2i(5,4),Vector2i(5,5),Vector2i(6,5),Vector2i(6,6)]
	for n in range(1,7):
		var board := registry.get_board("base.board.qinglan_%d"%n)
		var texture: Texture2D = load(board.texture_path)
		check(board.grid_size == sizes[n-1],"authored grid "+str(n))
		check(texture.get_size() == board.source_size and texture.get_image().has_mipmaps(),"dimensions / mipmaps "+str(n))
		check(board.resource_bonuses.is_empty() and board.buff_bonuses.is_empty() and board.faction == "青岚宗","zero bonuses and faction")
		check(model._owned.values().count("base.map_item.qinglan_board_%d"%n)==1,"grant one board")
	var old := model.snapshot()
	old.content_grants.erase("qinglan.boards.v1")
	for id in old.owned_units.keys():
		if "qinglan_board" in old.owned_units[id]: old.owned_units.erase(id)
	check(model.restore(old).is_empty(),"legacy save grants new boards")
	var once := model.snapshot()
	check(model.restore(once).is_empty() and model.snapshot()==once,"grant and restore idempotent")
	model.cultivation_rank_id = "base.cultivation.mortal"
	check(model.select_board("base.map_item.qinglan_board_2") != "","realm gate enforced")
	check(model.select_board("base.map_item.qinglan_board_1").is_empty(),"mortal can use first")
	model.cultivation_rank_id = "base.cultivation.nascent_soul"
	check(model.select_board("base.map_item.qinglan_board_6") != "","nascent cannot use sixth")
	check(model.select_board("base.map_item.qinglan_board_5").is_empty(),"select fifth")
	var forbidden := model.snapshot()
	forbidden.board_id = "base.board.qinglan_6"
	check(not model.restore(forbidden).is_empty() and model.board.id == "base.board.qinglan_5", "saved board cannot bypass realm gate")
	model.cultivation_rank_id = "base.cultivation.spirit_transformation"
	check(model.select_board("base.map_item.qinglan_board_6").is_empty(), "spirit transformation can use sixth")
	model.select_board("base.map_item.qinglan_board_5")
	model.cultivation_rank_id = "base.cultivation.nascent_soul"
	var candidates := []
	for row: Dictionary in model.storage.entries():
		var item := registry.get_item(row.item_id)
		if item.category == "weapon" and item.grid_size==Vector2i.ONE and model.can_use_item(item.id): candidates.append(row)
	check(candidates.size()>=2,"two unit fixtures")
	var a: Dictionary = candidates[0]
	var b: Dictionary = candidates[1]
	check(model.place(model.drag_data("storage",a.instance_id),Vector2i.ZERO),"place kept item")
	check(model.place(model.drag_data("storage",b.instance_id),Vector2i(5,4)),"place overflowing item")
	var units_before: Dictionary = model.snapshot().owned_units
	check(model.select_board("base.map_item.qinglan_board_1").is_empty(),"shrink board")
	check(model.inventory.get_instance(a.instance_id).cell==Vector2i.ZERO,"preserve original cell")
	check(model.inventory.get_instance(b.instance_id).is_empty() and not model.storage.get_entry(b.instance_id).is_empty(),"overflow returned")
	check(model.snapshot().owned_units==units_before,"no loss or duplication")
	check(not model.inventory.add_item("fake.board","base.map_item.qinglan_board_1",Vector2i(1,1)),"board cannot occupy item cells")
	check(MapLoadoutStore.save(model,SAVE).is_empty(),"save selected board")
	var scene = load("res://scenes/main/main.tscn").instantiate()
	var game: GameManager = scene.get_node("GameManager")
	game.loadout_save_path = SAVE
	game.use_saved_loadout = true
	root.add_child(scene)
	game.set_process(false)
	check(game.startup_error.is_empty(),"battle loads selected board")
	check(game.party[0].board.id==model.board.id and game.party[0].inventory.grid_size==Vector2i(4,3),"battle uses selected grid")
	scene.queue_free()
	await settle()
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/map_inventory.json"))
	var catalog := MapInventoryCatalog.new()
	catalog.configure(config)
	catalog.replace_entries(model.storage_records())
	catalog.set_filter("category","board")
	var ui := MapInventoryScreen.new()
	ui.configure(catalog,config,model.board,model)
	root.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.show()
	await settle()
	check(ui.formation_panel==null and ui.formation_dialog==null,"formation UI removed")
	check(ui.buff_bonus_values.keys()==["armor","shield"],"seven buffs removed only")
	check(ui.grid.columns==5,"five columns")
	check(absf(ui.storage_panel.size.x-MapInventoryScreen.STORAGE_WIDTH)<2,"storage width "+str(ui.storage_panel.size.x))
	check(absf(ui.board_panel.size.x-ui.board_panel.size.y)<2,"board panel scales proportionally")
	check(absf(ui.storage_panel.position.x-ui.board_panel.get_parent().position.x-ui.board_panel.size.x-19)<2,"preserve inter-panel gap")
	check(ui.grid.get_child_count()==7,"six Qinglan boards plus original bag")
	check(absf(ui.grid.get_child(0).size.x-(910-44-75)/6.0)<1,"card width unchanged: "+str(ui.grid.get_child(0).size.x))
	check("blueprint" in catalog.subcategories() and "pill_recipe" not in catalog.subcategories(),"merge recipe tabs")
	var board_card: MapInventoryItemCard
	for candidate in ui.grid.get_children():
		if candidate.entry.id == "base.map_item.qinglan_board_3": board_card = candidate
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	board_card._gui_input(right)
	await settle()
	check(ui.is_board_change_dialog_open(), "right-click requests confirmation")
	ui.board_change_dialog.confirm_button.pressed.emit()
	await settle()
	check(model.board.id=="base.board.qinglan_3","confirmed right-click selects board")
	check(ui.loadout_board.layout==model.board and ui.board_capacity.text.ends_with("/20"),"UI updates board and capacity")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/qinglan-inventory.png")
	ui.queue_free()
	await settle()
	if DisplayServer.get_name()!="headless":
		var background := ColorRect.new()
		background.color = Color("17212c")
		background.size = Vector2(2560,1440)
		root.add_child(background)
		for n in range(1,7):
			var preview := preload("res://tests/board_alignment_preview.gd").GridPreview.new()
			preview.layout = registry.get_board("base.board.qinglan_%d"%n)
			preview.texture = load(preview.layout.texture_path)
			preview.position = Vector2(((n-1)%3)*850+60, floori((n-1)/3.0)*720+50)
			preview.size = Vector2(730,650)
			background.add_child(preview)
			var label := Label.new()
			label.text = preview.layout.display_name+"  "+str(preview.layout.grid_size)
			label.position = preview.position-Vector2(0,35)
			background.add_child(label)
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/qinglan-board-grids.png")
		background.queue_free()
		await settle()
	print("QINGLAN: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)
