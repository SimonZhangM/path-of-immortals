extends SceneTree

func _initialize() -> void: run.call_deferred()
func run() -> void:
	create_timer(25).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(2560, 1440)
	var scene = load("res://scenes/main/main.tscn").instantiate()
	var game: GameManager = scene.get_node("GameManager")
	game.use_saved_loadout = true
	game.loadout_save_path = ""
	game.enemy_id = "base.enemy.chisong_liaozhu"
	root.add_child(scene)
	game.set_process(false)
	assert(game.startup_error.is_empty())
	var ui = scene.get_node("MainUI")
	for i in 8: await process_frame
	var buttons: HBoxContainer = ui.find_child("PlaybackControls", true, false)
	assert(buttons.get_child_count() == 5)
	for i in 5:
		var button: Button = buttons.get_child(i)
		assert(absf(button.size.x - 48 * sqrt(0.5)) < 0.1)
		assert(button.size.is_equal_approx(Vector2.ONE * button.size.x))
		if i > 0:
			var previous: Control = buttons.get_child(i - 1)
			assert(absf(button.position.x - previous.get_rect().end.x - 8) < 1)
	assert(not ui._status.is_visible_in_tree())
	for name in ["HeaderDividerLine", "LeftMotto", "RightMotto"]:
		assert(ui.find_child(name, true, false) == null)
	assert(is_equal_approx(ui.ally_panel.cards[0].global_position.y, 211.6666667))
	var emblem: BattleActionButton = ui._battle_emblem
	var original := emblem.get_global_rect()
	game.start_battle()
	await create_timer(3.2).timeout
	assert(emblem.get_global_rect().is_equal_approx(original) and emblem.modulate.a == 1.0 and emblem.scale == Vector2.ONE)
	game.toggle_pause()
	for i in 3: await process_frame
	assert(emblem.get_global_rect().is_equal_approx(original) and emblem.modulate.a == 1.0)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/battle-header-static.png")
	scene.queue_free()
	for i in 8: await process_frame
	await create_timer(0.2).timeout
	print("BATTLE HEADER: five half-area squares, 8px gaps, no divider/mottos/status, static emblem passed")
	quit()
