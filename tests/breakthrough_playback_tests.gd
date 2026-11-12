extends "res://tests/breakthrough_audio_tests.gd"

func run() -> void:
	root.content_scale_size=Vector2i.ZERO
	root.size=Vector2i(2560,1440)
	if not await prepare_audio_fixture("res://artifacts/breakthrough-playback-20261105"): quit(1); return
	var screen: Control=map.breakthrough_screen
	var flow: RefCounted=map.breakthrough_session
	var sound_view: Node=screen.get_node("BreakthroughAudio")
	var music: AudioStreamPlayer=sound_view.music
	var presentation: Node=root.get_node("MapPresentation")
	presentation.enter_map(map.definition,0.0)
	var region_stream: AudioStream=presentation.music.stream
	check(not music.playing and presentation.music.playing,"ready screen retains regional music")
	check(music.stream is AudioStreamMP3 and music.stream.loop and music.stream.loop_offset==0,"breakthrough MP3 loops from start")
	check(music.bus=="Music" and is_equal_approx(music.pitch_scale,1.0),"BGM respects Music bus and normal pitch")
	check(screen.playback_controls.get_child_count()==5,"five playback buttons")
	check(screen.speed_buttons[4.0].symbol=="quad","four-speed uses four triangles symbol")
	for resolution in [Vector2i(2560,1440),Vector2i(1920,1080)]:
		root.size=resolution
		await settle()
		for button: Control in screen.playback_controls.get_children():
			var rect := button.get_global_rect()
			check(is_equal_approx(rect.size.x,rect.size.y) and Rect2(Vector2.ZERO,Vector2(resolution)).encloses(rect),"square button stays in viewport "+str(resolution))
		check(not screen.playback_controls.get_global_rect().intersects(screen.start_button.get_global_rect()),"buttons do not overlap main hit area")
		if DisplayServer.get_name()!="headless": await capture("ready-%d" % resolution.x)
	root.size=Vector2i(2560,1440)
	await settle()
	await click(screen.speed_buttons[4.0])
	check(flow.speed==4.0 and flow.phase=="ready","selecting speed does not start unrequested attempt")
	await click(screen.start_button)
	check(flow.phase=="running" and music.playing and not music.stream_paused,"actual start begins breakthrough music")
	check(presentation.music.stream_paused and presentation.music.stream==region_stream,"regional music suspended without restarting")
	flow.advance(1.5)
	check(flow.runtime.elapsed_usec()==6000000 and flow.runtime.progress()>0,"4x advances actual cooldown payments and progress by six simulated seconds")
	check(int(state.growth.resources.stamina)<5000,"4x spends actual resources")
	var music_position := music.get_playback_position()
	await click(screen.playback_pause)
	var snapshot := state.snapshot()
	flow.advance(5)
	await create_timer(0.18).timeout
	check(flow.phase=="paused" and state.snapshot()==snapshot,"square pause freezes simulation")
	check(music.playing and not music.stream_paused and music.get_playback_position()>music_position,"paused breakthrough keeps music advancing")
	await click(screen.pause_button)
	check(flow.phase=="running" and not screen.playback_pause.button_pressed,"existing pause button resumes same session")
	for rate: float in [0.5,2.0,4.0]:
		await click(screen.speed_buttons[rate])
		var before: int=flow.runtime.presentation_usec()
		flow.advance(2.0)
		check(flow.runtime.presentation_usec()-before==roundi(rate*2000000.0),"real speed selection "+str(rate))
		check(is_equal_approx(music.pitch_scale,1.0) and is_equal_approx(Engine.time_scale,1.0),"speed keeps audio and global time unchanged")
	await click(screen.playback_pause)
	await click(screen.speed_buttons[1.0])
	check(flow.phase=="running" and flow.speed==1.0,"play button resumes at normal speed")
	await click(screen.speed_buttons[4.0])
	if DisplayServer.get_name()!="headless": await capture("running-2560")
	root.size=Vector2i(1920,1080)
	await settle()
	if DisplayServer.get_name()!="headless": await capture("running-1920")
	# Reach the native loop boundary without waiting through the entire track.
	var length := music.stream.get_length()
	check(length>1.0,"actual BGM stream loaded")
	music.seek(length-0.06)
	await create_timer(0.3).timeout
	check(music.playing and music.get_playback_position()<1.0,"native music loop wraps after track end")
	map.set_breakthrough_open(false)
	check(music.stream_paused and not presentation.music.stream_paused,"closing restores map music")
	music_position=music.get_playback_position()
	await create_timer(0.12).timeout
	map.set_breakthrough_open(true)
	check(flow.phase=="paused" and music.playing and not music.stream_paused,"reopening paused attempt resumes its BGM")
	check(absf(music.get_playback_position()-music_position)<0.1,"reopen retains music position")
	await click(screen.exit_button)
	await click(map.breakthrough_exit_dialog.confirm_button)
	check(flow.phase=="ready" and flow.speed==1.0 and not music.playing,"red exit resets music and playback speed")
	check(not presentation.music.stream_paused,"red exit releases regional music")
	map.set_breakthrough_open(true)
	state.growth.realm=1
	await click(screen.start_button)
	check(flow.phase=="ready" and not music.playing,"failed start never switches BGM")
	map.queue_free()
	await settle()
	presentation.music.stop()
	print("Breakthrough playback: ",checks," checks, ",failures," failures; artifacts: ",directory)
	quit(1 if failures else 0)
