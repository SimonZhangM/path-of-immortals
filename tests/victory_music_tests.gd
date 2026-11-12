extends SceneTree

func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for i in 8: await process_frame
func run() -> void:
	create_timer(20).timeout.connect(func(): quit(2))
	var settings := root.get_node("GameSettings")
	settings.apply_values({"background_pause": false, "background_mute": false, "volume_master": 1.0, "volume_music": 1.0})
	settings.set_application_focus(true)
	settings._base_gain.volume_master = 0.000001
	settings.apply_values({"volume_master": 1.0})
	var presentation := root.get_node("MapPresentation")
	var region: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/qingshihewan.json"))
	presentation.enter_map(region, 0.0)
	var region_stream: AudioStream = presentation.music.stream
	var scene = load("res://scenes/main/main.tscn").instantiate()
	var game: GameManager = scene.get_node("GameManager")
	game.use_saved_loadout = true
	game.loadout_save_path = ""
	game.enemy_id = "base.enemy.chisong_liaozhu"
	scene.get_node("MainUI").source_map_id = region.id
	root.add_child(scene)
	game.set_process(false)
	assert(game.startup_error.is_empty())
	await settle()
	var ui = scene.get_node("MainUI")
	var audio: GameAudio = ui.game_audio
	assert(audio.music.playing and audio.music.stream.loop)
	assert(presentation.music.context_paused and presentation.music_state == "paused")
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
	assert(not presentation.music.context_paused and presentation.music.playing)
	assert(presentation.music.stream == region_stream and presentation.music_state in ["playing", "resuming"])
	var region_playback: AudioStreamPlayback = presentation.music.get_stream_playback()
	ui._refresh()
	audio.play_victory()
	assert(not audio.music.playing)
	assert(presentation.music.get_stream_playback() == region_playback)
	game.restart()
	game.set_process(false)
	assert(audio.music.playing and audio.music.stream.loop and not audio._victory_started)
	assert(presentation.music.context_paused and presentation.music_state == "paused")
	game.start_battle()
	game.simulation._finish("defeat", 1)
	game._process(0)
	ui._refresh()
	assert(not audio._victory_started and audio.music.stream.loop)
	audio.stop_all()
	presentation.music.stop()
	scene.queue_free()
	await settle()
	await create_timer(0.2).timeout
	print("VICTORY MUSIC: one-shot victory resumes the same regional stream, refresh preserves playback, restart pauses region, defeat isolation passed")
	quit()
