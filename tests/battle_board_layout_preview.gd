extends SceneTree

var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	assert(ok, message)

func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for i in 10: await process_frame
func run() -> void:
	create_timer(55).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(2560,1440)
	var scene = load("res://scenes/main/main.tscn").instantiate()
	var game: GameManager = scene.get_node("GameManager")
	game.use_saved_loadout = true
	game.loadout_save_path = ""
	game.enemy_id = "base.enemy.chisong_liaozhu"
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(scene)
	assert(game.startup_error.is_empty(), game.startup_error)
	var ui = scene.get_node("MainUI")
	var ids := ["base.board.bag"]
	for n in range(1,7): ids.append("base.board.qinglan_%d" % n)
	var previews: Array[Image] = []
	for id: String in ids:
		var member := game.party[0]
		member.board = game.registry.get_board(id)
		member.definition.board_layout = id
		member.inventory = InventoryState.new(game.registry,member.board.grid_size)
		member.hp = minf(member.hp, member.maximum("hp"))
		member.stamina = minf(member.stamina, member.maximum("stamina"))
		var index := 0
		for entry: Dictionary in game._durable_loadout.storage.entries():
			var item := game.registry.get_item(entry.item_id)
			if item.category not in ["weapon","armor"] or item.icon_path.is_empty(): continue
			var cells := member.inventory.available_cells(item.id)
			if cells.is_empty(): continue
			member.inventory.put(entry,cells[0])
			index += 1
			if index == 8: break
		ui.ally_panel.rebuild()
		await settle()
		var bag: InventoryView = ui.ally_panel.bags[0]
		var used := Rect2(MapItemArtwork.TextureMetrics.inspect(bag.board_texture).visible_rect)
		var visible_rect := Rect2(bag.board_layout.source_to_view(used.position,bag.size),used.size*bag.board_layout.scale_for(bag.size))
		print(id, " view=",bag.size," visible=",bag.get_global_transform()*visible_rect," actor=",ui.ally_panel.cards[0].get_global_rect())
		var global_art := bag.get_global_transform() * visible_rect
		check(global_art.position.y >= 580 and global_art.end.y <= 1430, "all visible boards stay below status area and inside screen")
		check(is_equal_approx(global_art.get_center().y,1004.0), "all player boards share elevated visual center")
		check(bag._board_art.get_rect().is_equal_approx(bag.board_layout.art_rect(bag.size)), "art and grid mapping agree")
		check(not bag._has_point(visible_rect.position - Vector2(0,1)), "transparent top padding does not cover status hover region")
		check(bag._has_point(visible_rect.get_center()), "board still accepts its visible center")
		for panel in [ui.ally_panel,ui.enemy_panel]:
			check(panel.status_icons.columns == 8, "status maximum eight per row")
			check(is_equal_approx(panel.cards[0].global_position.y,221.6666667), "actor group is five screen pixels higher")
			var icons: Array = panel.status_icons.get_children()
			check(icons[7].position.y == icons[0].position.y and icons[8].position.y > icons[0].position.y, "eight icons fit before wrap")
		for entry: Dictionary in member.inventory.get_instances():
			var item := game.registry.get_item(entry.item_id)
			var rect := bag.board_layout.footprint_rect(entry.cell,item.grid_size,bag.size).grow(-4)
			var center := InventoryView.rotation_ring_center(rect,item)
			var inset := 23.0 * CooldownRing.SIZE_SCALE + 2.0
			check(center.is_equal_approx(rect.end-Vector2.ONE*inset), "CD follows each item bottom-right corner")
			check(bag.board_layout.cell_at(bag.board_layout.footprint_rect(entry.cell,Vector2i.ONE,bag.size).get_center(),bag.size)==entry.cell, "scaled cell geometry remains consistent")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var screenshot := root.get_texture().get_image()
			screenshot.save_png("res://artifacts/battle-board-%s.png" % id.get_slice(".",2))
			previews.append(screenshot)
	scene.queue_free()
	await settle()
	if not previews.is_empty():
		var gallery := Control.new()
		root.add_child(gallery)
		for index in previews.size():
			var view := TextureRect.new()
			view.texture = ImageTexture.create_from_image(previews[index])
			view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			view.position = Vector2((index%3)*850,(index/3)*480)
			view.size = Vector2(850,478)
			gallery.add_child(view)
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/battle-boards-gallery.png")
		gallery.queue_free()
		await settle()
	print("BATTLE BOARD LAYOUT: %d checks passed" % checks)
	quit()
