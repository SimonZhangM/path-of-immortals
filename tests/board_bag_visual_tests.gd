extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func settle() -> void:
	for i in 8: await process_frame
func run() -> void:
	create_timer(35).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(2560,1440)
	var registry := ContentRegistry.new()
	check(registry.load_base_content(), "content loads")
	var created := MapLoadoutStore.create_state(registry,registry.get_board("base.board.bag"))
	check(created.error.is_empty(), "catalog loads: " + created.error)
	if not created.error.is_empty(): quit(1); return
	var model: MapLoadoutState = created.state
	var legacy := model.snapshot()
	legacy.content_grants.erase("starter.bag.v1")
	legacy.owned_units.erase("owned.base.map_item.bag_board.0")
	check(model.restore(legacy).is_empty(), "existing save grants bag")
	check(model._owned.values().count("base.map_item.bag_board") == 1, "one bag granted")
	var once := model.snapshot()
	check(model.restore(once).is_empty() and model.snapshot() == once, "bag grant idempotent")
	check(model.select_board("base.map_item.qinglan_board_6").is_empty(), "use spirit board")
	var overflow_id := ""
	for entry: Dictionary in model.storage.entries():
		var item := registry.get_item(entry.item_id)
		if item.category == "weapon" and item.grid_size == Vector2i.ONE:
			overflow_id = entry.instance_id
			break
	check(model.place(model.drag_data("storage", overflow_id),Vector2i(5,5)), "put fixture in outer cell")
	var owned: Dictionary = model.snapshot().owned_units
	check(model.select_board("base.map_item.bag_board").is_empty(), "bag selectable")
	check(model.inventory.grid_size == Vector2i(3,3) and model.board.resource_bonus("hp") == 5 and model.board.resource_bonus("stamina") == 5, "original bag layout and bonuses")
	check(not model.storage.get_entry(overflow_id).is_empty() and model.snapshot().owned_units == owned, "bag switch returns overflow without loss")
	check(MapLoadoutStore.save(model,"res://artifacts/bag-test.json").is_empty(), "save bag selection")
	var reloaded_registry := ContentRegistry.new()
	reloaded_registry.load_base_content()
	var restored := MapLoadoutStore.create_state(reloaded_registry,reloaded_registry.get_board("base.board.qinglan_1"))
	var reload_error := MapLoadoutStore.load_into(restored.state,"res://artifacts/bag-test.json")
	check(reload_error.is_empty() and restored.state.board.id == "base.board.bag", "reload selected bag: " + restored.error + reload_error)
	model.select_board("base.map_item.qinglan_board_5")
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/map_inventory.json"))
	var catalog := MapInventoryCatalog.new()
	catalog.configure(config)
	catalog.replace_entries(model.storage_records())
	catalog.set_filter("category", "board")
	var ui := MapInventoryScreen.new()
	ui.configure(catalog,config,model.board,model)
	root.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.show()
	await settle()
	check(ui.grid.get_child_count() == 7, "seven usable board cards")
	for card in ui.grid.get_children():
		check(card.find_children("*", "Label", true, false).all(func(label): return label.text != "使用中"), "no active caption")
	var tip := ItemTooltip.new()
	tip.configure(registry.get_item("base.map_item.qinglan_board_6"))
	root.add_child(tip)
	tip.z_index = 100
	tip.position = Vector2(1550,720)
	check(tip.description.is_empty() and tip.find_child("BoardDescriptionSlot",true,false) != null, "blank tooltip retains reserved container")
	check(tip.find_children("*","RichTextLabel",true,false).is_empty(), "board has no explanatory text")
	if DisplayServer.get_name() != "headless":
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/board-bag-tooltip.png")
	tip.queue_free()
	model.select_board("base.map_item.qinglan_board_6")
	await settle()
	var layout := model.board
	var original_scale := minf(ui.loadout_board.size.x / layout.source_size.x, ui.loadout_board.size.y / layout.source_size.y)
	check(is_equal_approx(layout.scale_for(ui.loadout_board.size), original_scale * 1.1), "spirit board 10 percent larger")
	check(ui.loadout_board._board_art.get_rect().is_equal_approx(layout.art_rect(ui.loadout_board.size)), "map artwork uses shared transform")
	check(layout.cell_at(layout.footprint_rect(Vector2i(5,5),Vector2i.ONE,ui.loadout_board.size).get_center(),ui.loadout_board.size) == Vector2i(5,5), "enlarged grid mapping aligned")
	check(registry.get_board("base.board.qinglan_5").display_scale == 1.0, "other boards unchanged")
	check(MapInventoryScreen.BOARD_BACKGROUND_X_SHIFT == -7.5, "background latest horizontal offset")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/spirit-board-enlarged.png")
	ui.queue_free()
	await settle()
	print("BAG / BOARD VISUAL: %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)
