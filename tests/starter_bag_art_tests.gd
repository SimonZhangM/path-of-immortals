extends SceneTree

const GridPreview = preload("res://tests/board_alignment_preview.gd").GridPreview
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
func capture(path: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	create_timer(40).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(2560, 1440)
	var registry := ContentRegistry.new()
	check(registry.load_base_content(), "content loads")
	var board := registry.get_board("base.board.bag")
	var texture: Texture2D = load(board.texture_path)
	check(board.texture_path == "res://assets/zhenpan-chushibag.webp", "starter uses new art")
	check(texture.get_size() == board.source_size, "source dimensions match")
	check(texture.get_image().has_mipmaps(), "imported texture has mipmaps")
	check(board.grid_size == Vector2i(3, 3), "nine cells preserved")
	check(board.resource_bonus("hp") == 5 and board.resource_bonus("stamina") == 5 and board.resource_bonus("spirit") == 0, "bonuses preserved")
	var created := MapLoadoutStore.create_state(registry, board)
	check(created.error.is_empty(), "isolated catalog loads")
	var model: MapLoadoutState = created.state
	check(model.select_board("base.map_item.bag_board").is_empty(), "bag usable")
	for entry: Dictionary in model.storage.entries():
		var item := registry.get_item(entry.item_id)
		if item.category not in ["weapon", "armor"] or item.icon_path.is_empty(): continue
		var cells := model.inventory.available_cells(item.id)
		if not cells.is_empty(): model.place(model.drag_data("storage", entry.instance_id), cells[0])
	check(registry.get_item("base.map_item.bag_board").icon_path == board.texture_path, "card and board share new art")
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/map_inventory.json"))
	var catalog := MapInventoryCatalog.new()
	catalog.configure(config)
	catalog.replace_entries(model.storage_records())
	catalog.set_filter("category", "board")
	var ui := MapInventoryScreen.new()
	ui.configure(catalog, config, board, model)
	root.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.show()
	await settle()
	var art := ui.loadout_board
	var used := Rect2(MapItemArtwork.TextureMetrics.inspect(texture).visible_rect)
	var old_texture: Texture2D = load("res://assets/zhenpan-bag.webp")
	var old_used := Rect2(MapItemArtwork.TextureMetrics.inspect(old_texture).visible_rect)
	var old_factor := minf(art.size.x / 1230.0, art.size.y / 1278.0)
	var new_size := used.size * board.scale_for(art.size)
	var old_size := old_used.size * old_factor
	check(absf(new_size.y / old_size.y - 1.0) < 0.001, "map visible height matches old art")
	check(absf(new_size.x / old_size.x - 1.0) < 0.04, "map visible width within four percent")
	check((art.get_global_transform() * board.source_to_view(used.get_center(), art.size)).is_equal_approx(ui.board_panel.get_global_rect().get_center()), "map visible center retained")
	check(art._board_art.get_rect().is_equal_approx(board.art_rect(art.size)), "map artwork and grid share transform")
	for y in 3:
		for x in 3:
			var cell := Vector2i(x, y)
			check(board.cell_at(board.footprint_rect(cell, Vector2i.ONE, art.size).get_center(), art.size) == cell, "cell geometry round trip")
	print("MAP visible old=", old_size, " new=", new_size)
	await capture("res://artifacts/starter-bag-map.png")
	ui.queue_free()
	await settle()
	var preview := GridPreview.new()
	preview.layout = board
	preview.texture = texture
	preview.size = Vector2(1200, 1200)
	preview.position = Vector2(680, 100)
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	root.add_child(preview)
	await settle()
	await capture("res://artifacts/starter-bag-grid.png")
	preview.queue_free()
	await settle()
	var scene = load("res://scenes/main/main.tscn").instantiate()
	var game: GameManager = scene.get_node("GameManager")
	game.use_saved_loadout = true
	game.loadout_save_path = ""
	game.enemy_id = "base.enemy.chisong_liaozhu"
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(scene)
	check(game.startup_error.is_empty(), "battle scene loads without real save")
	var member := game.party[0]
	member.board = game.registry.get_board(board.id)
	member.definition.board_layout = board.id
	member.inventory = InventoryState.new(game.registry, board.grid_size)
	for entry: Dictionary in game._durable_loadout.storage.entries():
		var item := game.registry.get_item(entry.item_id)
		if item.category not in ["weapon", "armor"] or item.icon_path.is_empty(): continue
		var cells := member.inventory.available_cells(item.id)
		if not cells.is_empty(): member.inventory.put(entry, cells[0])
	var battle_ui = scene.get_node("MainUI")
	battle_ui.ally_panel.rebuild()
	await settle()
	var bag: InventoryView = battle_ui.ally_panel.bags[0]
	check(bag.board_texture.resource_path == board.texture_path, "battle uses new art")
	check(is_equal_approx(used.size.y * board.scale_for(bag.size), 630.0), "battle visible height preserved")
	check(bag._board_art.get_rect().is_equal_approx(board.art_rect(bag.size)), "battle artwork and items share grid transform")
	for entry: Dictionary in member.inventory.get_instances():
		var item := game.registry.get_item(entry.item_id)
		var rect := board.footprint_rect(entry.cell, item.grid_size, bag.size).grow(-4)
		var inset := 23.0 * CooldownRing.SIZE_SCALE + 2.0
		check(InventoryView.rotation_ring_center(rect, item).is_equal_approx(rect.end - Vector2.ONE * inset), "cooldown corner follows new cell bounds")
	await capture("res://artifacts/starter-bag-battle.png")
	scene.queue_free()
	await settle()
	print("STARTER BAG ART: %d checks; %d failures" % [checks, failures])
	quit(1 if failures else 0)
