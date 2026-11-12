extends "res://tests/breakthrough_audio_tests.gd"

func step_fade(picture: MapEventPicture, seconds: float) -> void:
	if picture._group_tween!=null:
		picture._group_tween.pause()
		picture._group_tween.custom_step(seconds)

func key(code: Key, pressed := true, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=pressed
	event.echo=echo
	root.push_input(event,true)

func run() -> void:
	if not await prepare_audio_fixture("res://artifacts/breakthrough-success-flow-20261106"): quit(1); return
	root.content_scale_size=Vector2i.ZERO
	root.size=Vector2i(2560,1440)
	state.narrative.flags[HomecomingQuest.PREPARATION_FLAG]=true
	map.travel.current_node_id=HomecomingQuest.data.home.point_id
	map.travel.stop_at_current_node()
	var flow: RefCounted=map.breakthrough_session
	var screen: Control=map.breakthrough_screen
	var audio: Node=screen.get_node("BreakthroughAudio")
	var presentation: Node=root.get_node("MapPresentation")
	presentation.enter_map(map.definition,0.0)
	check(flow.start(),"start actual first breakthrough")
	state.growth.breakthrough_attempt.progress=19900
	flow.advance(9)
	check(flow.phase=="succeeded" and audio.music.playing,"success retains playing breakthrough music")
	var before := state.snapshot()
	await click(screen.start_button)
	var picture: MapEventPicture=screen.completion_illustration
	check(picture!=null and picture.visible and not screen.result_view.visible,"completed-button click shows illustration before result page")
	check(picture.illustration.texture.resource_path=="res://assets/UI-player-pojing1.webp","requested illustration is displayed")
	check(is_equal_approx(picture.fade_in_seconds,1) and is_equal_approx(picture.fade_out_seconds,1),"illustration has one-second entry and exit")
	key(KEY_SPACE)
	check(picture.requested_visible,"entry ignores early advance")
	picture._group_tween.pause()
	var elapsed := picture._group_tween.get_total_elapsed_time()
	step_fade(picture,maxf(0.0,0.5-elapsed))
	check(is_equal_approx(picture.modulate.a,0.5),"illustration entry is half transparent at half a second")
	step_fade(picture,0.501)
	check(is_equal_approx(picture.modulate.a,1.0),"entry completes at one second")
	await create_timer(0.15).timeout
	check(picture.visible and picture.requested_visible and state.snapshot()==before,"picture waits for input and preserves committed result")
	map.homecoming_story_controller._process(0)
	check(HomecomingQuest.story(state).active.is_empty(),"picture does not launch map story")
	for code: Key in [KEY_T,KEY_ESCAPE,KEY_I,KEY_R,KEY_M]: key(code)
	key(KEY_SPACE,false)
	key(KEY_SPACE,true,true)
	check(picture.requested_visible and map.is_breakthrough_open(),"other keys and repeats do not skip picture")
	if DisplayServer.get_name()!="headless":
		for width: int in [2560,1920]:
			root.size=Vector2i(width,width*9/16)
			await settle()
			check(picture.get_global_rect().is_equal_approx(Rect2(Vector2.ZERO,root.size)),"illustration fills viewport at "+str(width))
			await capture("illustration-"+str(width))
	var music_stream: AudioStream=audio.music.stream
	key(KEY_SPACE)
	check(not picture.requested_visible and picture.visible and screen.result_view.visible,"space reveals success page beneath outgoing picture")
	step_fade(picture,0.5)
	check(is_equal_approx(picture.modulate.a,0.5) and HomecomingQuest.story(state).active.is_empty(),"illustration exit reaches half opacity at half a second")
	check(audio.music.playing and not audio.music.stream_paused and presentation.music.stream_paused,"music stays on breakthrough during picture exit")
	step_fade(picture,0.501)
	check(not picture.visible and screen.result_view.visible and flow.phase=="succeeded","one-second picture exit finishes on success results")
	check(screen.result_view.current_value.text=="200" and screen.result_view.completion_value.text=="100%","success result values remain full")
	check(state.snapshot()==before and audio.music.stream==music_stream,"picture and results neither resettle nor replace music")
	await click(screen.result_view.review_button)
	flow.activate_primary()
	check(screen.result_view.visible and not picture.visible,"review returns to results without replaying illustration")
	flow.runtime.save_path=directory+"missing/confirmation.json"
	screen.result_view.confirm_button.pressed.emit()
	check(map._breakthrough_result_tween==null and state.snapshot()==before and not screen.result_view.error_label.text.is_empty(),"failed confirmation keeps result and blocks map transition")
	check(audio.music.playing and not audio.music.stream_paused,"failed save preserves success music")
	flow.runtime.save_path=path
	screen.result_view.confirm_button.pressed.emit()
	var transition: Tween=map._breakthrough_result_tween
	transition.pause()
	check(not state.growth.has("breakthrough_attempt") and state.growth.realm==1,"confirmation clears attempt while retaining promotion")
	check(is_zero_approx(map.map_viewport.modulate.a) and is_equal_approx(screen.modulate.a,1),"map starts transparent while success page starts opaque")
	check(audio.music.playing and presentation.music.stream_paused,"music continues until return transition finishes")
	map._finish_breakthrough_result()
	key(KEY_SPACE); key(KEY_T); key(KEY_I)
	check(map._breakthrough_result_tween==transition and flow.phase=="ready" and map.is_breakthrough_open(),"transition rejects duplicate confirmation and input")
	transition.custom_step(0.5)
	check(is_equal_approx(map.map_viewport.modulate.a,0.5) and is_equal_approx(screen.modulate.a,0.5),"map and success page share the same half-second crossfade")
	check(HomecomingQuest.story(state).active.is_empty() and audio.music.playing,"story and music wait for full crossfade")
	if DisplayServer.get_name()!="headless":
		for width: int in [2560,1920]:
			root.size=Vector2i(width,width*9/16)
			await capture("crossfade-half-"+str(width))
	transition.custom_step(0.501)
	check(map._breakthrough_result_tween==null and not map.is_breakthrough_open() and is_equal_approx(map.map_viewport.modulate.a,1),"both scenes finish switching after the same one second")
	check(not audio.music.playing and not presentation.music.stream_paused,"return stops breakthrough music and restores regional music")
	check(HomecomingQuest.story(state).active=="rejoice","mother dialogue starts after the return transition")
	check(is_equal_approx(screen.modulate.a,1),"hidden breakthrough screen resets opacity for next opening")
	# Mouse uses the same one-second dismissal in the fullscreen picture component.
	var mouse_picture=preload("res://scripts/map/map_breakthrough_illustration.gd").new()
	root.add_child(mouse_picture)
	mouse_picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_picture.present(load("res://assets/UI-player-pojing1.webp"))
	step_fade(mouse_picture,1.001)
	var mouse := InputEventMouseButton.new()
	mouse.button_index=MOUSE_BUTTON_LEFT
	mouse.pressed=true
	mouse_picture.handle_input(mouse)
	check(not mouse_picture.requested_visible and mouse_picture.visible,"left click begins picture exit")
	step_fade(mouse_picture,0.5)
	check(is_equal_approx(mouse_picture.modulate.a,0.5),"mouse exit uses the same one-second timing")
	step_fade(mouse_picture,0.501)
	check(not mouse_picture.visible,"mouse exit finishes after one second")
	mouse_picture.queue_free()
	map.deactivate_location()
	map.queue_free()
	await settle()
	print("Breakthrough success flow: ",checks," checks, ",failures," failures; ",directory)
	quit(1 if failures else 0)
