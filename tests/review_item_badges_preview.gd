extends SceneTree

func _initialize() -> void: run.call_deferred()

func settle() -> void:
	for i in 8: await process_frame

func check_badges(ui: Control, expected: bool) -> void:
	for panel in [ui.ally_panel, ui.enemy_panel]:
		assert(not panel.bags.is_empty())
		for board: InventoryView in panel.bags:
			assert(board.show_cooldown_badges == expected)

func run() -> void:
	create_timer(25).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0, true)
	var scene = load("res://scenes/main/main.tscn").instantiate()
	var game: GameManager = scene.get_node("GameManager")
	game.loadout_save_path = ""
	root.add_child(scene)
	game.set_process(false)
	assert(game.startup_error.is_empty())
	await settle()
	var ui = scene.get_node("MainUI")
	game.party[0].inventory.add_item("review.preview.weapon", "base.map_item.qingshi_short_sword", Vector2i.ZERO)
	assert(not game.party[0].inventory.get_instances().is_empty())
	for board: InventoryView in ui.ally_panel.bags:
		board._refresh_artworks()
		board.queue_redraw()
	check_badges(ui, true)
	game.start_battle()
	ui._refresh()
	check_badges(ui, true)
	game.simulation._finish("victory", 0)
	game._process(0)
	ui._refresh()
	ui._show_victory_rewards()
	ui._review_victory()
	assert(ui.victory_view == ui.VictoryView.REVIEW)
	check_badges(ui, false)
	await settle()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/review-item-badges.png")
	ui._show_victory_rewards()
	check_badges(ui, true)
	game.restart()
	game.set_process(false)
	ui._refresh()
	check_badges(ui, true)
	ui.game_audio.stop_all()
	scene.queue_free()
	await settle()
	print("PASS: both boards hide ready/countdown circles only in review; preparation, battle and restart unchanged. No mouse input or durable save.")
	quit()
