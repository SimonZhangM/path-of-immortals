extends "res://tests/breakthrough_audio_tests.gd"

func press_key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode=code; event.physical_keycode=code; event.pressed=true
	root.push_input(event,true)
	await settle()

func run() -> void:
	root.content_scale_size=Vector2i.ZERO
	root.size=Vector2i(1920,1080)
	if not await prepare_audio_fixture("res://artifacts/breakthrough-confirmation-20261105"): quit(1); return
	var screen: Control=map.breakthrough_screen
	var flow: RefCounted=map.breakthrough_session
	var sound: Node=screen.get_node("BreakthroughAudio")
	var render := DisplayServer.get_name()!="headless"
	check(not sound.music.playing and not sound.music_focused,"opening ready panel keeps region music")
	check(flow.start(),"formal start succeeds")
	check(sound.music.playing and sound.music_focused,"formal start switches music")
	flow.advance(6)
	flow.set_paused(true)
	check(sound.music.playing and not sound.music.stream_paused,"pause retains breakthrough music")
	# Recreate presentation with the persisted paused attempt, as on loading a save.
	sound.free()
	sound=load("res://scripts/map/map_breakthrough_audio.gd").new()
	sound.name="BreakthroughAudio"; screen.add_child(sound)
	sound.configure(flow,screen,state.registry)
	check(not sound.music.playing and not sound.music_focused,"opening restored paused attempt does not switch music")
	flow.set_paused(false)
	check(sound.music.playing and sound.music_focused,"explicit resume starts restored attempt music")
	var before := state.snapshot()
	if not render: await click(screen.exit_button)
	else: map._exit_breakthrough()
	var dialog: MapExitDialog=map.breakthrough_exit_dialog
	check(dialog.visible and map.is_breakthrough_open() and state.snapshot()==before,"exit opens confirmation without clearing")
	check(dialog.message.text=="确定退出突破流程吗？" and dialog.error_label.text=="注意：退出后不保留当前进度。","exact two exit lines")
	map._process(5)
	check(state.snapshot()==before,"confirmation freezes breakthrough advancement")
	if not render:
		await press_key(KEY_SPACE)
		check(flow.phase=="running" and dialog.visible,"modal blocks space start/pause")
		await click(dialog.cancel_button)
		check(not dialog.visible and state.snapshot()==before and flow.phase=="running","cancel retains attempt and prior running state")
		await click(screen.exit_button)
		await press_key(KEY_ESCAPE)
		check(not dialog.visible and map.is_breakthrough_open(),"escape cancels only confirmation")
		await click(screen.exit_button)
		await click(dialog.confirm_button)
		check(not map.is_breakthrough_open() and flow.phase=="ready" and flow.runtime.progress()==0,"confirmed exit clears progress and closes")
		check(not sound.music_focused and not sound.music.playing,"confirmed exit releases breakthrough music")
		map.set_breakthrough_open(true)
		check(screen.primary_start_art.visible and not screen.primary_running_art.visible and not sound.music_focused,"reopen returns to ready without music")
	else:
		for resolution in [Vector2i(1920,1080),Vector2i(2560,1440)]:
			root.size=resolution
			await capture("exit-%d" % resolution.x)
		dialog.hide()
	map.set_breakthrough_open(false)
	var browser = preload("res://scripts/entry/save_browser.gd").new()
	browser.in_game=true
	browser.catalog.index_path=directory+"slots.json"
	browser.catalog.legacy_path=Slots.auto_path
	browser.catalog.manual_directory=directory
	map.add_child(browser)
	browser.z_index=80
	var writes := [0]
	browser.action_requested.connect(func(destination: String):
		var error: String=Ops.store_manual(browser.catalog,state,path,destination)
		check(error.is_empty(),"isolated manual save succeeds")
		writes[0]+=1
		browser.refresh())
	await settle()
	# Empty quick and manual slots save directly; both existing kinds need confirmation.
	for slot in [0,2]:
		browser.select(slot)
		var count: int=writes[0]
		if not render: await click(browser.back_button)
		else: browser._request_action()
		check(writes[0]==count+1,"empty slot saves directly")
		var destination: String=browser.entries[browser.selected_index].path
		var hash := FileAccess.get_sha256(destination)
		state.spirit_stones+=1
		if not render: await click(browser.back_button)
		else: browser._request_action()
		check(browser.overwrite_dialog.visible and FileAccess.get_sha256(destination)==hash and writes[0]==count+1,"existing slot waits without writing")
		check(browser.overwrite_dialog.message.text=="确定要覆盖存档吗？","exact overwrite text")
		if not render:
			await click(browser.overwrite_dialog.cancel_button)
			check(FileAccess.get_sha256(destination)==hash and writes[0]==count+1,"cancel overwrite preserves original")
			await click(browser.back_button)
			await press_key(KEY_ESCAPE)
			check(not browser.overwrite_dialog.visible and browser.visible,"escape cancels overwrite only")
			await click(browser.back_button)
			await click(browser.overwrite_dialog.confirm_button)
			check(writes[0]==count+2 and Files.read(destination).spirit_stones==state.spirit_stones,"confirm writes current state exactly once")
			check(FileAccess.get_sha256(destination+".bak")==hash,"overwrite retains previous backup")
		else:
			for resolution in [Vector2i(1920,1080),Vector2i(2560,1440)]:
				root.size=resolution
				await capture("overwrite-%d-%d" % [slot,resolution.x])
			browser._cancel_overwrite()
	browser.queue_free(); map.queue_free()
	await settle()
	await create_timer(0.5).timeout
	print("Breakthrough confirmations: %d checks, %d failures; %s" % [checks,failures,directory])
	quit(1 if failures else 0)
