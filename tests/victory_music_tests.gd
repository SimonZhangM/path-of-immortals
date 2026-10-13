extends SceneTree

func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for i in 8: await process_frame
func run() -> void:
	create_timer(20).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0, true)
	var scene = load("res://scenes/main/main.tscn").instantiate()
	var game: GameManager = scene.get_node("GameManager")
	game.use_saved_loadout = true
	game.loadout_save_path = ""
	game.enemy_id = "base.enemy.chisong_liaozhu"
	root.add_child(scene)
	game.set_process(false)
	assert(game.startup_error.is_empty())
	await settle()
	var ui = scene.get_node("MainUI")
	var audio: GameAudio = ui.game_audio
	assert(audio.music.playing and audio.music.stream.loop)
	var battle_stream := audio.music.stream
	game.start_battle()
	game.simulation._finish("victory", 0)
	game._process(0)
	ui._refresh()
	assert(audio.music.playing and not audio.music.stream.loop)
	assert(audio.music.stream != battle_stream)
	var expected: AudioStreamMP3 = load("res://assets/victory-song2.mp3")
	assert(audio.music.stream.data == expected.data)
	var playback := audio.music.get_stream_playback()
	ui._show_victory_rewards()
	ui._review_victory()
	ui._show_victory_rewards()
	ui._refresh()
	audio.play_victory()
	assert(audio.music.get_stream_playback() == playback)
	# Seek near the real file's end to verify natural one-shot completion quickly.
	audio.music.seek(audio.music.stream.get_length() - 0.1)
	await create_timer(0.6).timeout
	assert(not audio.music.playing)
	ui._refresh()
	audio.play_victory()
	assert(not audio.music.playing)
	game.restart()
	game.set_process(false)
	assert(audio.music.playing and audio.music.stream.loop and not audio._victory_started)
	game.start_battle()
	game.simulation._finish("defeat", 1)
	game._process(0)
	ui._refresh()
	assert(not audio._victory_started and audio.music.stream.loop)
	audio.stop_all()
	scene.queue_free()
	await settle()
	await create_timer(0.2).timeout
	print("VICTORY MUSIC: battle replacement, non-looping file, no replay in review/rewards, natural end, restart and defeat isolation passed")
	quit()
