extends SceneTree

func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for i in 6: await process_frame
func click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
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
	game.start_battle()
	game._process(1.0)
	game.simulation._finish("victory", game.simulation.state.time_usec)
	game._process(0)
	ui._refresh()
	assert(ui._log_button.disabled)
	ui._show_victory_rewards()
	assert(ui._log_button.disabled)
	await settle()
	click(ui.victory_rewards.review_button.get_global_rect().get_center())
	await settle()
	assert(ui.victory_view == ui.VictoryView.REVIEW and not ui._log_button.disabled)
	assert(ui._bag_button.disabled and ui._retreat_button.disabled and not ui._battle_button.disabled)
	var record: String = ui._log_label.text
	assert(not record.is_empty())
	var time: int = game.simulation.state.time_usec
	click(ui._log_button.get_global_rect().get_center())
	await settle()
	assert(ui._log_panel.is_visible_in_tree() and ui._log_label.text == record)
	var close: Button
	for button in ui._log_panel.find_children("*", "Button", true, false):
		if button.text == "关闭 ×": close = button
	assert(close != null)
	click(close.get_global_rect().get_center())
	await settle()
	assert(not ui._log_panel.visible and ui.victory_view == ui.VictoryView.REVIEW)
	assert(game.simulation.state.is_finished() and game.simulation.state.time_usec == time)
	click(ui._battle_button.get_global_rect().get_center())
	await settle()
	assert(ui.victory_rewards.visible and ui._log_button.disabled)
	scene.queue_free()
	await settle()
	await create_timer(.2).timeout
	print("PASS: review opens real log contents, closes back to review, exit restores rewards; no battle resume")
	quit()
