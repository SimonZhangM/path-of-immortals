extends "res://tests/save_actions_tests.gd"

const EntryMusic = preload("res://scripts/entry/entry_music.gd")

func check_tail(player: MusicPlayer, label: String) -> void:
	var length := player.stream.get_length()
	player.seek(length - 0.8)
	await create_timer(0.06).timeout
	var ratio := clampf(length - player.get_playback_position(), 0.0, 1.0)
	check(absf(player.volume_linear - player.music_gain * ratio) < 0.025, label + " fades during the final second")
	check(player.volume_linear < player.music_gain * 0.9, label + " process applies the fade")
	player.set_context_paused(true)
	var gain := player.volume_linear
	await create_timer(0.1).timeout
	check(is_equal_approx(player.volume_linear, gain), label + " tail freezes with playback")
	player.set_context_paused(false)
	player.music_gain *= 0.5
	ratio = clampf(length - player.get_playback_position(), 0.0, 1.0)
	check(absf(player.volume_linear - player.music_gain * ratio) < 0.025, label + " transition gain composes with the tail")
	player.seek(0.0)
	await create_timer(0.06).timeout
	check(is_equal_approx(player.volume_linear, player.music_gain), label + " seeking to the beginning restores gain")

func run() -> void:
	create_timer(25).timeout.connect(func(): quit(2))
	directory = "res://artifacts/diecuifeng-music-20261110/run-%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	var settings := root.get_node("GameSettings")
	settings.apply_values({"background_pause":false, "background_mute":false, "volume_master":1.0, "volume_music":1.0})
	settings.set_application_focus(true)
	settings._base_gain.volume_master = 0.000001
	settings.apply_values({"volume_master":1.0})
	var presentation := root.get_node("MapPresentation")
	var definition: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/diecuifeng.json"))
	check(definition.music == ["res://assets/bgm-diecuifeng-qinglanshandao.mp3"], "peak binds the requested track")
	check(presentation.validate_music(definition).is_empty(), "imported peak music passes normal validation")
	presentation.enter_map(definition, 0.0)
	check(presentation.music.playing and presentation.music.stream.get_length() > 1.0, "peak music loads and starts through normal map playback")
	await check_tail(presentation.music, "map playlist")
	await presentation._uniform_fade(1.0, presentation.music, 0.0)
	check(is_zero_approx(presentation.music.music_gain) and is_zero_approx(presentation.music.volume_linear), "battle transition reaches silence through the separate gain")
	await presentation._uniform_fade(0.0, presentation.music, presentation.MUSIC_VOLUME)
	check(is_equal_approx(presentation.music.volume_linear, presentation.MUSIC_VOLUME), "battle reveal restores map gain")
	presentation.music.seek(presentation.music.stream.get_length() - 0.8)
	await create_timer(0.06).timeout
	await presentation.fade_out(true, 0.12)
	check(presentation.music.context_paused and is_zero_approx(presentation.music.volume_linear), "transition during the tail reaches zero and pauses")
	presentation.enter_map(definition, 0.0)
	var remaining: float = presentation.music.stream.get_length() - presentation.music.get_playback_position()
	check(not presentation.music.context_paused and absf(presentation.music.volume_linear - presentation.MUSIC_VOLUME * remaining) < 0.025, "resuming in the tail applies both gains")
	presentation.music.seek(presentation.music.stream.get_length() - 0.1)
	await create_timer(0.4).timeout
	check(presentation.music.playing and presentation.music.get_playback_position() < 1.0 and is_equal_approx(presentation.music.volume_linear, presentation.music.music_gain), "map playlist repeats with restored gain")
	presentation.music.stop()
	var menu: MusicPlayer = EntryMusic.ensure_for(self)
	await settle()
	await check_tail(menu, "menu playlist")
	var previous_track: int = menu.track_index
	menu.seek(menu.stream.get_length() - 0.1)
	await create_timer(0.4).timeout
	check(menu.track_index != previous_track and is_equal_approx(menu.volume_linear, menu.music_gain), "menu advances and restores gain")
	menu.stop()
	menu.queue_free()
	var manager := GameManager.new()
	var battle := GameAudio.new()
	root.add_child(battle)
	battle.configure(manager, true)
	battle.start_music()
	await check_tail(battle.music, "looping battle music")
	battle.music.seek(battle.music.stream.get_length() - 0.1)
	await create_timer(0.4).timeout
	check(battle.music.playing and battle.music.get_playback_position() < 1.0 and is_equal_approx(battle.music.volume_linear, battle.music.music_gain), "native loop restores gain at its beginning")
	battle.play_victory()
	await check_tail(battle.music, "victory music")
	battle.music.seek(battle.music.stream.get_length() - 0.1)
	await create_timer(0.4).timeout
	check(not battle.music.playing, "one-shot music still ends normally")
	battle.queue_free()
	manager.free()
	for map_id in ["base.map.diecuifeng", "base.map.qinglanshandao", "base.map.qingshihewan", ""]:
		var regional_manager := GameManager.new()
		var regional_audio := GameAudio.new()
		root.add_child(regional_audio)
		regional_audio.configure(regional_manager, true, map_id)
		regional_audio.start_music()
		var expected_path := "res://assets/battle2.mp3" if map_id in ["base.map.diecuifeng", "base.map.qinglanshandao"] else "res://assets/battle.mp3"
		var expected := load(expected_path) as AudioStreamMP3
		check(regional_audio.music.stream.data == expected.data and regional_audio.music.stream.loop, "regional battle track: " + map_id)
		regional_audio.play_victory()
		regional_manager.battle_restarted.emit()
		check(regional_audio.music.stream.data == expected.data and not regional_audio._victory_started, "restart retains regional battle track: " + map_id)
		regional_audio.free()
		regional_manager.free()
	await create_timer(0.2).timeout
	settings._base_gain.volume_master = 1.0
	var result := {"checks":checks, "failures":failures}
	FileAccess.open(directory+"validation.json", FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	print("MUSIC TRACK TAIL: "+JSON.stringify(result))
	quit(1 if failures else 0)
