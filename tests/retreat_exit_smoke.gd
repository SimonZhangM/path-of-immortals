extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	AudioServer.set_bus_mute(0, true)
	var scene: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(scene)
	var manager: GameManager = scene.get_node("GameManager")
	manager.set_process(false)
	var ui: Control = scene.get_node("MainUI")
	manager.start_battle()
	manager.request_retreat()
	manager._process(3)
	await process_frame
	ui._refresh()
	if manager.simulation.state.result != "retreat" or not ui._retreat_dialog.visible:
		printerr("FAIL: retreat dialog unavailable for exit")
		quit(1)
		return
	print("EXIT BUTTON: requesting real application exit")
	create_timer(2).timeout.connect(func():
		printerr("FAIL: exit button did not close application")
		quit(1)
	)
	ui._exit_button.pressed.emit()
