extends "res://tests/breakthrough_audio_tests.gd"
## Focused VFX clock/layer integration. Uses isolated storage; no OS mouse automation.
func run() -> void:
	root.content_scale_size=Vector2i.ZERO
	root.size=Vector2i(1920,1080)
	if not await prepare_audio_fixture("res://artifacts/breakthrough-vfx-20261112"):
		quit(1)
		return
	var screen: Control=map.breakthrough_screen
	var vfx: Control=screen.ambient_vfx
	vfx.set_process(false)
	check(vfx.small_motif_count==48,"six small motifs in each eighth")
	check(vfx.fixed_stars.size()==20 and vfx.moving_stars.size()==20,"forty varied glints, twenty moving")
	check(vfx.get_index()<screen.character_art.get_index() and vfx.get_index()<screen.board_reference.get_index(),"native board and actual-alpha character above VFX")
	check(is_equal_approx(screen.character_art.size.x,366.24),"character enlarged five percent")
	check(screen.chance_value.get_theme_font_size("font_size")==73,"success chance increased three points")
	check(not screen.chance_value.text.contains("%") and screen.chance_percent.text=="%","percent excluded from numeric centering")
	check(is_equal_approx(float(vfx.config.blue_speed_scale),.5),"blue ribbons and particles half-speed")
	var flow: RefCounted=map.breakthrough_session
	vfx.advance_visual(3.0)
	check(is_zero_approx(vfx.visual_time),"ready stage is static")
	check(flow.start(),"real breakthrough starts")
	var before: Dictionary=state.snapshot()
	var elapsed: int=flow.elapsed_usec
	for setting: Array in [[.5,.75],[1.0,1.0],[2.0,1.5],[4.0,2.0]]:
		var phase: float=vfx.visual_time
		flow.set_speed(setting[0])
		check(is_equal_approx(vfx.visual_time,phase),"speed change does not jump phase")
		vfx.advance_visual(2.0)
		check(is_equal_approx(vfx.visual_time-phase,2.0*setting[1]),"visual speed mapping "+str(setting[0]))
	check(flow.elapsed_usec==elapsed and state.snapshot()==before,"VFX never advances simulation or mutates inventory/growth")
	flow.set_paused(true)
	var frozen: float=vfx.visual_time
	vfx.advance_visual(3.0)
	check(is_equal_approx(vfx.visual_time,frozen),"paused visual clock stays still")
	flow.set_paused(false)
	screen.hide()
	vfx.advance_visual(3.0)
	check(is_equal_approx(vfx.visual_time,frozen),"hidden screen freezes without accumulating catch-up")
	screen.show()
	vfx.advance_visual(.5)
	check(is_equal_approx(vfx.visual_time,frozen+1.0),"resume continues same phase at mapped rate")
	flow.set_paused(true)
	var stub := preload("res://scripts/map/map_breakthrough_session.gd").new()
	vfx.session=stub
	for phase: String in ["failed","succeeded"]:
		stub.phase=phase
		frozen=vfx.visual_time
		vfx.advance_visual(3.0)
		check(is_equal_approx(vfx.visual_time,frozen),"completed phase freezes "+phase)
	vfx.session=flow
	flow.set_paused(false)
	flow.set_speed(2.0)
	frozen=vfx.visual_time
	elapsed=flow.elapsed_usec
	map._process(.1)
	check(is_equal_approx(vfx.visual_time,frozen+.15) and flow.elapsed_usec==elapsed+200000,"native frame advances independent visual and simulation clocks")
	map._exit_breakthrough()
	frozen=vfx.visual_time
	map._process(1.0)
	check(is_equal_approx(vfx.visual_time,frozen),"exit confirmation suspends VFX along with simulation")
	map.breakthrough_exit_dialog.hide()
	flow.set_paused(true)
	for asset: String in ["star","flower"]:
		check(load("res://assets/UI-tupo-"+asset+".webp").get_image().has_mipmaps(),"mipmapped motif "+asset)
	if DisplayServer.get_name()!="headless":
		for resolution: Vector2i in [Vector2i(1920,1080),Vector2i(2560,1440)]:
			root.size=resolution
			for time: float in [6.0,6.12]:
				vfx.visual_time=time
				vfx._update_frame()
				await settle()
				await RenderingServer.frame_post_draw
				var target := directory+"native-%d-%.2f.png" % [resolution.x,time]
				root.get_texture().get_image().save_png(target)
				print("VFX_CAPTURE ",target)
		# Diagnostic frame timing with fixed gameplay. Includes rendering, not simulation.
		var started := Time.get_ticks_usec()
		for i in range(60):
			vfx.visual_time=6.0+i/60.0
			vfx._update_frame()
			await process_frame
		print("VFX_FRAME_MS ",(Time.get_ticks_usec()-started)/60000.0)
	Meta.stop()
	map.deactivate_location()
	map.queue_free()
	await settle()
	print("Breakthrough VFX: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
