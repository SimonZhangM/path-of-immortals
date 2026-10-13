extends SceneTree

func _initialize() -> void: run.call_deferred()

func mouse(point: Vector2, pressed: bool) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event, true)

func run() -> void:
	create_timer(20).timeout.connect(func(): quit(2))
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
	var emblem: BattleActionButton = ui._battle_emblem
	var original := emblem.get_global_rect()
	assert(emblem.size == Vector2(216, 216))
	assert(emblem.artwork.atlas.get_image().has_mipmaps())
	assert(not emblem.disabled and game.simulation.state.phase == GameState.Phase.PREPARATION)
	var started := [0]
	game.battle_started.connect(func(): started[0] += 1)
	var point := original.get_center()
	mouse(point, true)
	await create_timer(0.08).timeout
	assert(emblem.press_depth > 0.9)
	assert(game.simulation.state.phase == GameState.Phase.PREPARATION)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/battle-emblem-pressed.png")
	mouse(point, false)
	assert(game.simulation.state.phase == GameState.Phase.BATTLE and started[0] == 1)
	assert(not game.simulation.clock.paused and emblem.disabled and not emblem.dim_when_disabled)
	await create_timer(.25).timeout
	assert(is_zero_approx(emblem.press_depth) and emblem.get_global_rect().is_equal_approx(original))
	mouse(point, true)
	mouse(point, false)
	assert(started[0] == 1 and not game.simulation.clock.paused)
	game.pause_battle()
	ui._refresh()
	mouse(point, true)
	mouse(point, false)
	assert(game.simulation.clock.paused and started[0] == 1)
	game.simulation._finish("defeat", 0)
	ui._refresh()
	ui._start_from_emblem()
	assert(started[0] == 1 and game.simulation.state.is_finished())
	scene.queue_free()
	for i in 8: await process_frame
	await create_timer(.2).timeout
	print("PASS: emblem click starts preparation once; shared press/release feedback, original geometry/color, inert during battle/pause/finish")
	quit()
