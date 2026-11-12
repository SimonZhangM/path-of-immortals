extends "res://tests/breakthrough_audio_tests.gd"
const OUTPUT := "res://artifacts/breakthrough-results-20261106/"

func run() -> void:
	if not await prepare_audio_fixture(OUTPUT): quit(1); return
	root.content_scale_size=Vector2i.ZERO
	root.size=Vector2i(2560,1440)
	await settle()
	if DisplayServer.get_name()!="headless":
		await render_results()
		map.queue_free()
		await settle()
		print("Breakthrough result render: ",checks," checks, ",failures," failures")
		quit(1 if failures else 0)
		return
	var flow: RefCounted=map.breakthrough_session
	var screen: Control=map.breakthrough_screen
	var result: Control=screen.result_view
	check(not screen.primary_complete_art.visible,"ready state hides completed button")
	await click(screen.start_button)
	check(flow.phase=="running","normal start button begins attempt")
	state.growth.breakthrough_attempt.progress=19900
	flow.advance(9)
	check(flow.phase=="succeeded","actual payment completes breakthrough")
	check(screen.primary_complete_art.visible and not screen.primary_running_art.visible and not screen.primary_start_art.visible,"completion replaces both original button images")
	check(screen.primary_complete_art.get_rect()==screen.primary_start_art.get_rect(),"completed image shares original size and center")
	check(not screen.rotation_reference.visible and screen.change_button.disabled,"finished panel stops ring and equipment editing")
	check(not result.visible and not screen.start_button.disabled,"results wait for enabled completed-button click")
	var success := state.snapshot()
	var report: Dictionary=flow.runtime.result_snapshot()
	check(int(report.progress)==20000 and int(report.target)==20000 and is_equal_approx(report.chance,1.0),"success records full target and source-realm total chance")
	check(int(report.gains.hp)==50 and int(report.gains.spirit)==100 and int(report.gains.stamina)==30 and int(report.gains.cultivation_efficiency_percent)==0,"report uses actual configured increases")
	write_fixture("success",success)
	await click(screen.start_button)
	var picture: MapEventPicture=screen.completion_illustration
	check(picture!=null and picture.visible,"first completed-button click opens illustration before results")
	picture._group_tween.pause()
	picture._group_tween.custom_step(1.001)
	picture.dismiss()
	picture._group_tween.pause()
	picture._group_tween.custom_step(1.001)
	check(result.visible and not screen.stage.visible and not screen.composition_art.visible,"completed-button click opens result page")
	check(result.current_value.text=="200" and result.target_value.text=="200" and result.completion_value.text=="100%" and is_equal_approx(result.progress_bar.value,100),"success page shows full value and completion")
	check(result.chance_value.text=="100%（合计）","success chance uses total instead of post-promotion base")
	check(state.snapshot()==success,"viewing results never awards growth again")
	await click(result.review_button)
	check(not result.visible and screen.stage.visible and screen.primary_complete_art.visible,"review returns to finished panel")
	flow.activate_primary()
	check(result.visible,"finished primary keyboard command opens results")
	await click(result.confirm_button)
	map._breakthrough_result_tween.pause()
	map._breakthrough_result_tween.custom_step(1.001)
	check(not map.is_breakthrough_open() and not state.growth.has("breakthrough_attempt") and state.growth.realm==1,"confirmation closes attempt and preserves promotion")
	map._finish_breakthrough_result()
	check(state.growth.realm==1 and int(state.growth.breakthrough_serial)==int(success.growth.breakthrough_serial),"repeated confirmation cannot settle twice")
	# Preserve the earned value for the report while clearing retry progress.
	restore_fixture()
	state.growth.breakthrough_attempt={"version":2,"id":flow.runtime.rule.id,"phase":"paused","progress":12950,"elapsed_usec":299000000,"recent_gains":[]}
	flow.runtime.bind(state,map.player_status,path)
	map.set_breakthrough_open(true)
	flow.set_paused(false)
	flow.advance(1)
	check(flow.phase=="failed" and flow.runtime.progress()==0,"deadline still clears live attempt progress")
	var failure := state.snapshot()
	report=flow.runtime.result_snapshot()
	check(int(report.progress)==12950 and int(report.target)==20000,"failure report preserves actual pre-clear earnings")
	check(report.gains.values().all(func(value): return value==0),"failure reports no gains")
	write_fixture("failure",failure)
	var loaded := MapLoadoutStore.candidate(state)
	check(loaded.error.is_empty() and MapLoadoutStore.load_into(loaded.state,path).is_empty(),"result survives real JSON save round trip")
	check(int(loaded.state.growth.breakthrough_attempt.result.progress)==12950,"durable failure report retains pre-clear value")
	await click(screen.start_button)
	check(result.visible and result.current_value.text=="129.5" and result.completion_value.text=="64.8%","failure page uses earned value and actual completion")
	check(result.notice.text.contains("清零") and result.notice.text.contains("从0开始") and not result.gains_box.visible,"failure page explains zero-based retry")
	var invalid: Dictionary=failure.growth.duplicate(true)
	invalid.breakthrough_attempt.result.progress=20001
	check(not CultivationGrowth.valid(invalid),"out-of-range report cannot enter save")
	flow.runtime.save_path=directory+"missing/result.json"
	await click(result.confirm_button)
	check(result.visible and state.snapshot()==failure and not result.error_label.text.is_empty(),"failed confirmation save preserves result and reports error")
	flow.runtime.save_path=path
	await click(result.confirm_button)
	check(not map.is_breakthrough_open() and not state.growth.has("breakthrough_attempt"),"retrying confirmation clears attempt once")
	map.set_breakthrough_open(true)
	await click(screen.start_button)
	check(flow.phase=="running" and flow.runtime.progress()==0,"next attempt starts at zero")
	flow.reset()
	# Existing completed files remain readable without invented failure history.
	var legacy := success.duplicate(true)
	legacy.growth.breakthrough_attempt.erase("result")
	legacy.growth.breakthrough_attempt.version=1
	legacy.growth.breakthrough_attempt.progress=10000
	check(state.restore(legacy).is_empty(),"legacy successful save stays valid")
	flow.runtime.bind(state,map.player_status,path)
	report=flow.runtime.result_snapshot()
	check(int(report.progress)==10000 and int(report.target)==10000 and is_equal_approx(report.chance,1),"legacy success keeps historical full target")
	legacy=failure.duplicate(true)
	legacy.growth.breakthrough_attempt.erase("result")
	check(state.restore(legacy).is_empty(),"legacy failed save stays valid")
	flow.runtime.bind(state,map.player_status,path)
	check(int(flow.runtime.result_snapshot().progress)==-1,"missing legacy earnings are explicitly unavailable")
	map.queue_free()
	await settle()
	print("Breakthrough results: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

func write_fixture(label: String, snapshot: Dictionary) -> void:
	var file := FileAccess.open(OUTPUT+label+"-fixture.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(snapshot))

func render_results() -> void:
	var screen: Control=map.breakthrough_screen
	for label: String in ["success","failure"]:
		var snapshot: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUTPUT+label+"-fixture.json"))
		check(state.restore(snapshot).is_empty(),"restore isolated "+label+" result")
		map.player_status.apply_growth(state.growth)
		map.breakthrough_session.runtime.bind(state,map.player_status,path)
		screen._hide_result()
		root.size=Vector2i(2560,1440)
		await capture(label+"-completed-button-2560")
		screen.present_result(map.breakthrough_session.phase,map.breakthrough_session.runtime.result_snapshot())
		for width: int in [2560,1920]:
			root.size=Vector2i(width,width*9/16)
			await settle()
			var result: Control=screen.result_view
			check(result.get_global_rect().encloses(result.confirm_button.get_global_rect()),"confirmation fits at "+str(width))
			check(result.get_global_rect().encloses(result.summary.get_global_rect()),"result text fits at "+str(width))
			check(result.current_value.get_theme_font_size("font_size")==32,"result text uses readable 32px design font")
			if label=="failure":
				check(result.notice.get_rect()==Rect2(1830,990,545,105),"failure notice stays in its gold container")
			await capture(label+"-result-"+str(width))
