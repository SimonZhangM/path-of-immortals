extends "res://tests/cultivation_combat_tests.gd"

const OUT := "res://artifacts/battle-record-20261111/"

func settle() -> void:
	for i in 7: await process_frame

func click(control: Control) -> void:
	var point := control.get_global_transform_with_canvas() * (control.size * .5)
	var move := InputEventMouseMotion.new()
	move.position = point
	root.push_input(move, true)
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)

func screenshot(path: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + path)

func run() -> void:
	create_timer(50).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(1920, 1080)
	var scene = load("res://scenes/main/main.tscn").instantiate()
	var game: GameManager = scene.get_node("GameManager")
	game.battle_seed_override = BattleSimulation.DEFAULT_RANDOM_SEED
	game.use_saved_loadout = false
	game.loadout_save_path = ""
	game.enemy_id = "base.enemy.qingfenglingtang"
	root.add_child(scene)
	game.set_process(false)
	check(game.startup_error.is_empty(), "real battle scene starts")
	registry = game.registry
	check(MapLoadoutStore.create_state(registry, registry.get_board("base.board.bag")).error.is_empty(), "reward artwork catalog loads")
	var p := actor("test.records.player")
	p.definition.cultivation_rank = "base.cultivation.spirit_transformation"
	p.cultivation_rank_id = "base.cultivation.spirit_transformation"
	p.inventory = InventoryState.new(registry, Vector2i(4, 4))
	check(p.inventory.add_item("blade", "base.map_item.t01_0033", Vector2i.ZERO), "equip actual blade")
	learn(p, "base.cultivation_book.wood_04", 4)
	check(p.inventory.add_item("spell", "base.spell.wood_02", Vector2i(2, 0)), "equip actual spell")
	check(p.inventory.add_item("heal", "base.map_item.t01_0083", Vector2i(3, 2)), "equip actual healing pendant")
	var e := PartyMemberState.new(registry.get_enemy(game.enemy_id), registry)
	e.definition.max_hp = 10000
	e.reset_resources()
	e.equip_definition_loadout()
	game.party.assign([p]); game.enemies.assign([e]); game.companions.clear()
	game.restart()
	p.hp -= 50
	var ui = scene.get_node("MainUI")
	await settle()
	check(ui._log_button.disabled, "record unavailable before battle")
	game.start_battle()
	game._process(9)
	ui._refresh()
	check(ui._log_button.disabled, "record unavailable while running")
	game.pause_battle()
	ui._refresh()
	await settle()
	check(not ui._log_button.disabled, "record available while paused")
	if OS.get_environment("BATTLE_RECORD_STATIC_ONLY") == "1":
		await static_preview(scene, ui)
		return
	click(ui._log_button)
	await settle()
	var panel = ui._log_panel
	check(panel.visible and panel.header.get_child_count() == 5 and panel.tabs.get_child_count() == 7, "five-column table and seven tabs open by click")
	check(panel._rows.size() == ui._battle_log.rows.size() and panel._rows.size() > 5, "actual simulation rows displayed")
	check(panel._rows.any(func(row): return not row.item_id.is_empty()), "events use real item IDs")
	for row_node in panel.content.get_children():
		if row_node == panel.empty_label: continue
		var cells: HBoxContainer = row_node.get_node("Cells")
		check(cells.get_child_count() == 5, "each row has five independent cells")
		for i in 4: check(cells.get_child(i).get_rect().end.x <= cells.get_child(i + 1).position.x + .1, "adjacent cells do not overlap")
		for cell: MarginContainer in cells.get_children():
			check(cell.get_child_count() == 1 and absf(cell.get_child(0).get_rect().get_center().y - cell.size.y * .5) <= 1.5 and is_zero_approx(cell.get_child(0).position.x), "cell content left aligned and vertically centered")
	var at: int = game.simulation.state.time_usec
	key(KEY_SPACE)
	check(game.simulation.clock.paused and game.simulation.state.time_usec == at, "modal consumes battle shortcut")
	await screenshot("table-1080p.png")
	for id in panel.filter_buttons:
		click(panel.filter_buttons[id])
		await settle()
		check(panel.active_filter == id and panel._rows.size() == ui._battle_log.filtered(id).size(), "click filter " + id)
		check(panel.filter_buttons.values().filter(func(button): return button.button_pressed).size() == 1, "exactly one selected filter")
	click(panel.close_button)
	await settle()
	check(not panel.visible and game.simulation.clock.paused, "close returns to paused battle")
	# Repeated real attacks retain all records and exercise scrolling beyond the first page.
	for i in 160:
		game.simulation.t01.activate("blade", at + i * 1000)
	ui._on_events(game.simulation.drain_events())
	click(ui._log_button)
	await settle()
	check(panel._rows.size() > 150 and panel.content.get_child_count() < 25, "full history retained, only visible rows mounted")
	var wheel := InputEventMouseButton.new()
	wheel.position = panel.scroll.get_global_transform_with_canvas() * (panel.scroll.size * .5)
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	root.push_input(wheel, true)
	await settle()
	check(panel.scroll.scroll_vertical > 0, "mouse wheel scrolls the table")
	panel.scroll.scroll_vertical = int(panel.content.size.y)
	await settle()
	check(panel._shown_range.y == panel._rows.size(), "last record reachable")
	key(KEY_ESCAPE)
	await settle()
	check(not panel.visible and game.simulation.clock.paused, "Escape closes without resuming")
	game.simulation._finish("defeat", at + 160000)
	game._process(0)
	ui._refresh()
	await settle()
	click(ui._review_button)
	await settle()
	check(panel.visible and ui._battle_log.rows[-1].system, "defeat dialog opens battle records")
	click(panel.close_button)
	await settle()
	check(ui._retreat_dialog.visible and game.simulation.state.is_finished(), "close returns to ended battle")
	# Reuse the real history in 2K; show the first page for visual review.
	root.size = Vector2i(2560, 1440)
	ui._open_battle_record()
	await settle()
	await screenshot("table-2k.png")
	for path in ["UI-battle-record", "UI-battle-record-all", "UI-battle-record-me", "UI-battle-record-enemy", "UI-battle-record-damage", "UI-battle-record-recovery", "UI-battle-record-buff", "UI-battle-record-debuff"]:
		check(load("res://assets/" + path + ".webp").get_image().has_mipmaps(), "mipmap " + path)
	FileAccess.open(OUT + "actual-records.txt", FileAccess.WRITE).store_string(ui._battle_log.text())
	scene.queue_free()
	await settle()
	print("BATTLE_RECORD_UI: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func static_preview(scene: Node, ui: Control) -> void:
	ui._open_battle_record()
	await settle()
	var panel = ui._log_panel
	for dimensions in [Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		root.size = dimensions
		await settle()
		check(panel._heights[0] == 38, "normal row shrinks from 62 to 38")
		for row_node in panel.content.get_children():
			if row_node == panel.empty_label: continue
			var cells: HBoxContainer = row_node.get_node("Cells")
			for cell: MarginContainer in cells.get_children():
				var child: Control = cell.get_child(0)
				check(is_zero_approx(child.position.x) and absf(child.get_rect().get_center().y - cell.size.y * .5) <= 1.5, "left aligned and vertically centered")
				check(child.get_rect().end.y <= cell.size.y + .1 and child.get_rect().end.x <= cell.size.x + .1, "content fits compact cell")
		await screenshot("table-1080p.png" if dimensions.x == 1920 else "table-2k.png")
	scene.queue_free()
	await settle()
	print("BATTLE_RECORD_STATIC: %d checks, %d failures; no mouse input" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
