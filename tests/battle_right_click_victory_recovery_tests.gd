extends SceneTree

func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for i in 8: await process_frame
func right_click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)

func run() -> void:
	create_timer(20).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(2560,1440)
	var scene = load("res://scenes/main/main.tscn").instantiate()
	var game: GameManager = scene.get_node("GameManager")
	game.use_saved_loadout = true
	game.loadout_save_path = ""
	game.enemy_id = "base.enemy.chisong_liaozhu"
	root.add_child(scene)
	game.set_process(false)
	assert(game.startup_error.is_empty())
	var ui = scene.get_node("MainUI")
	var hammer := ""
	for entry: Dictionary in game.storage.entries():
		if entry.item_id == "base.map_item.short_iron_hammer": hammer = entry.instance_id
	assert(not hammer.is_empty() and game.equip(hammer,0,Vector2i.ZERO))
	game.start_battle()
	game._process(1.2)
	game.pause_battle()
	game.set_adjustment(true)
	await settle()
	var board: InventoryView = ui.ally_panel.bags[0]
	var before := game.simulation.timeline.remaining(hammer)
	var center := board.get_global_transform_with_canvas() * board.cell_center(Vector2i.ZERO)
	right_click(center)
	await settle()
	assert(game.adjustment_open and ui.storage_panel.visible)
	assert(game.party[0].inventory.get_instance(hammer).is_empty())
	assert(not game.storage.get_entry(hammer).is_empty())
	assert(game.equip(hammer,0,Vector2i.ZERO))
	assert(game.simulation.timeline.remaining(hammer) == before)
	assert(game.simulation.cooling_remaining_usec(hammer) == 0)
	right_click(Vector2(20,600))
	assert(not game.adjustment_open)
	# Reproduce the reported hot-reload shape: a pre-update audio node that
	# exposes music but has no new play_victory method.
	var audio: Node = ui.game_audio
	audio.stop_all()
	var player: AudioStreamPlayer = audio.music
	var legacy := GDScript.new()
	legacy.source_code = "extends Node\nvar music: AudioStreamPlayer\n"
	assert(legacy.reload() == OK)
	audio.set_script(legacy)
	audio.set("music", player)
	assert(not audio.has_method("play_victory"))
	game.simulation._finish("victory",0)
	game._process(0)
	ui.victory_view = ui.VictoryView.BANNER
	ui.victory_banner.reset()
	ui._refresh()
	assert(ui.victory_banner.visible and not ui.victory_banner.timer.is_stopped())
	assert(player.playing and not player.stream.loop)
	await create_timer(3.2).timeout
	assert(ui.victory_rewards.visible and not ui.victory_banner.visible)
	ui._review_victory()
	assert(not ui.victory_rewards.visible and ui._battle_button.caption == "离开战场")
	ui._show_victory_rewards()
	assert(ui.victory_rewards.visible)
	player.stop()
	scene.queue_free()
	await settle()
	await create_timer(.2).timeout
	print("BATTLE FIXES: right-click returns item and retains bag/CD, outside closes; legacy audio cannot block victory timer, rewards or review")
	quit()
