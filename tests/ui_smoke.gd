extends SceneTree

var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var manager: GameManager = scene.get_node("GameManager")
	var ui: Control = scene.get_node("MainUI")
	manager.set_process(false)
	_check(manager.startup_error.is_empty(), "scene loads JSON and creates battle")
	_press(ui, "重新开始")
	_press(ui, "8×")
	manager._process(0.375)
	ui._refresh()
	_check(manager.simulation.state.enemy_hp == 90, "speed button drives manager and simulation")
	_check(ui._hp.text == "气血  90 / 100", "HP label reads authoritative state")
	_check(ui._log_label.text.contains("造成 10 伤害"), "events reach presentation log")
	_press(ui, "暂停")
	manager._process(10)
	ui._refresh()
	_check(manager.simulation.state.time_usec == 3_000_000 and ui._pause.text == "继续", "pause button freezes time")
	_press(ui, "继续")
	manager._process(3.375)
	ui._refresh()
	_check(manager.simulation.state.is_finished() and ui._status.text.contains("30.00"), "victory displayed at exact time")
	_check(ui._log_label.text.contains("试炼完成"), "defeat event displayed")
	_press(ui, "重新开始")
	ui._refresh()
	_check(manager.simulation.state.enemy_hp == 100 and manager.simulation.clock.speed_multiplier == 1, "restart resets HP and speed")
	_check(ui._log_label.text.contains("试炼开始") and not ui._log_label.text.contains("造成"), "restart clears stale log")
	manager._process(12.5)
	ui._refresh()
	if DisplayServer.get_name() != "headless":
		for size in [Vector2i(1280, 720), Vector2i(1280, 800), Vector2i(1720, 720), Vector2i(960, 540)]:
			root.size = size
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			var path := "res://artifacts/prototype_%dx%d.png" % [size.x, size.y]
			_check(root.get_texture().get_image().save_png(path) == OK, "save rendered viewport " + path)
			_check(ui.get_rect().size.x <= root.get_visible_rect().size.x + 1, "UI fits viewport width")
	print("UI RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func _press(node: Node, label: String) -> bool:
	if node is Button and node.text == label:
		node.pressed.emit()
		return true
	for child in node.get_children():
		if _press(child, label):
			return true
	return false

func _check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + description)
