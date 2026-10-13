extends SceneTree

func _initialize() -> void: run.call_deferred()

func run() -> void:
	create_timer(15).timeout.connect(func(): quit(2))
	var banner = load("res://scripts/ui/battle_victory_banner.gd").new()
	root.add_child(banner)
	assert(banner.FADE_DURATION == 0.5 and banner.timer.wait_time == 1.5)
	# Preload art and settle startup frames before measuring presentation time.
	banner.present("base.cultivation.mortal")
	banner.reset()
	await create_timer(0.2).timeout
	banner.present("base.cultivation.mortal")
	var started := Time.get_ticks_msec()
	assert(banner.modulate.a == 0 and banner.timer.is_stopped())
	while banner.timer.is_stopped(): await process_frame
	print("Victory fade measured: ", (Time.get_ticks_msec() - started) / 1000.0)
	assert(absf((Time.get_ticks_msec() - started) / 1000.0 - 0.5) < 0.2)
	assert(is_equal_approx(banner.modulate.a, 1.0))
	assert(banner.get_node("VictoryShade").color.a == 0.5)
	await banner.dismissed
	assert(absf((Time.get_ticks_msec() - started) / 1000.0 - 2.0) < 0.25)
	banner.present("base.cultivation.mortal")
	banner.dismiss()
	assert(not banner.visible and banner.timer.is_stopped() and banner._fade == null)
	var presentation = load("res://scripts/map/map_presentation.gd").new()
	root.add_child(presentation)
	assert(presentation.BATTLE_FADE == 0.5)
	assert(presentation.WIPE_OUT == 1.0 and presentation.WIPE_IN == 1.0)
	# Entry and return share these exact picture/audio fade phases.
	for direction in ["entry", "return"]:
		presentation._cover.modulate.a = 0
		presentation.music.volume_linear = presentation.MUSIC_VOLUME
		started = Time.get_ticks_msec()
		await presentation._uniform_fade(1.0, presentation.music, 0.0)
		assert(absf((Time.get_ticks_msec() - started) / 1000.0 - 0.5) < 0.2)
		assert(presentation._cover.modulate.a == 1.0 and presentation.music.volume_linear == 0)
		await presentation._uniform_fade(0.0, presentation.music, presentation.MUSIC_VOLUME)
		assert(absf((Time.get_ticks_msec() - started) / 1000.0 - 1.0) < 0.25)
		assert(presentation._cover.modulate.a == 0 and is_equal_approx(presentation.music.volume_linear, presentation.MUSIC_VOLUME))
		print(direction, ": 0.5s out + 0.5s in, picture/audio synchronized")
	banner.queue_free()
	presentation.queue_free()
	for i in 3: await process_frame
	print("TIMING: victory 0.5s fade + 1.5s hold, dismissal cancellation, battle fades and unchanged map wipe passed")
	quit()
