extends "res://tests/breakthrough_audio_tests.gd"
const Flight = preload("res://scripts/ui/restore_flight.gd")

func run() -> void:
	root.content_scale_size=Vector2i.ZERO
	root.size=Vector2i(2560,1440)
	if not await prepare_audio_fixture("res://artifacts/breakthrough-feedback-20261105"): quit(1); return
	var screen: Control=map.breakthrough_screen
	var flow: RefCounted=map.breakthrough_session
	var feedback: Control=screen.stage.get_node("GainFeedback")
	var audio: Node=screen.get_node("BreakthroughAudio")
	var presentation: Node=root.get_node("MapPresentation")
	presentation.enter_map(map.definition,0.0)
	var expanded := state.snapshot()
	expanded.owned_units["test.feedback.stamina"]="base.map_item.t01_0020"
	expanded.owned_units["test.feedback.spirit"]="base.map_item.t01_0021"
	expanded.placements.append({"instance_id":"test.feedback.stamina","item_id":"base.map_item.t01_0020","cell":[0,1]})
	expanded.placements.append({"instance_id":"test.feedback.spirit","item_id":"base.map_item.t01_0021","cell":[2,1]})
	expanded.growth.resources={"hp":1000,"stamina":1000,"spirit":1000}
	check(state.restore(expanded).is_empty(),"real three-resource recovery fixture")
	map.player_status.apply_growth(state.growth)
	var emitted: Array[Dictionary]=[]
	flow.runtime.presentation_events.connect(func(events): emitted.append_array(events))
	check(flow.start(),"start actual breakthrough")
	feedback.set_process(false)
	flow.advance(8)
	var gains: Array=emitted.filter(func(e): return e.kind=="cultivation_gained")
	var total := 0
	for event: Dictionary in gains: total+=CultivationGrowth.cents(event.value)
	check(total==flow.runtime.progress() and total>0,"cultivation events equal actual credited gain")
	check(gains.any(func(e): return e.instance_id=="test.first_qi.guide") and gains.any(func(e): return e.instance_id=="test.audio.sword"),"guide and weapon each retain instance attribution")
	check(feedback.flights.size()==gains.size()+emitted.filter(func(e): return e.kind=="restore" and e.value>0 and e.get("resource","") in Flight.RESOURCE_ICONS).size(),"one icon per actual item gain or positive recovery")
	check(not emitted.any(func(e): return e.kind=="restore" and e.get("resource","")=="spirit" and e.value>0),"mortal spirit restoration produces no positive feedback")
	for key in ["hp","stamina"]:
		check(emitted.any(func(e): return e.kind=="restore" and e.get("resource","")==key and e.value>0),"real "+key+" recovery occurred")
		check(feedback.flights.any(func(f): return f.destination==map.status_header.bars[key] and f.texture==Flight.RESOURCE_ICONS[key]),"correct top bar and icon for "+key)
	check(feedback.flights.any(func(f): return f.destination==screen.progress_fill and f.texture.resource_path.ends_with("player-status-level.webp")),"cultivation targets breakthrough bar rather than header cultivation")
	var gameplay := state.snapshot()
	for resolution in [Vector2i(2560,1440),Vector2i(1920,1080)]:
		root.size=resolution
		await settle()
		feedback.clear(); feedback.present(emitted)
		var source: Vector2=screen.board_view.recovery_origin(gains[0])
		var example: Control=feedback.flights.filter(func(f): return f.destination==screen.progress_fill)[0]
		check((feedback.get_global_transform_with_canvas()*example.origin).distance_to(source)<0.1,"item source uses transformed footprint "+str(resolution))
		check(is_equal_approx(feedback.get_global_transform().get_scale().x*example.size.x,48.0*resolution.x/2560.0),"battle-sized icon at "+str(resolution))
		for flight: Control in feedback.flights: flight.advance(0.75)
		if DisplayServer.get_name()!="headless": await capture("flights-%d" % resolution.x)
		for flight: Control in feedback.flights:
			flight.advance(0.75)
			var end: Vector2=flight.destination.get_global_transform_with_canvas()*(flight.destination.size*0.5)
			var center := feedback.get_global_transform_with_canvas()*(flight.position+flight.size*0.5)
			check(center.distance_to(end)<0.1,"flight ends at actual bar center")
		feedback._process(0)
		check(feedback.flights.is_empty(),"completed icons removed")
	check(state.snapshot()==gameplay,"animation never alters gameplay")
	feedback.present(emitted)
	var count: int=feedback.flights.size()
	var zero_events: Array[Dictionary]=[{"kind":"restore","target_id":map.player_status.character_id,"instance_id":"test.audio.restore","resource":"hp","value":0}]
	feedback.present(zero_events)
	check(feedback.flights.size()==count,"zero recovery creates no icon")
	await click(screen.pause_button)
	gameplay=state.snapshot()
	var track: AudioStream=audio.music.stream
	audio.music.seek(5.0)
	await click(screen.change_button)
	check(map._breakthrough_adjusting and map.is_inventory_open(),"pause change opens actual bag")
	check(feedback.flights.is_empty(),"hidden breakthrough clears in-flight icons")
	await create_timer(0.2).timeout
	check(audio.music.playing and not audio.music.stream_paused and audio.music.stream==track and audio.music.get_playback_position()>5.0,"adjustment keeps same music advancing without restart")
	check(presentation.music.stream_paused,"regional track stays suspended during adjustment")
	map.set_inventory_open(false)
	check(map.is_breakthrough_open() and flow.phase=="paused" and not audio.music.stream_paused,"return remains paused with uninterrupted music")
	check(state.snapshot()==gameplay,"adjustment navigation does not advance attempt")
	feedback.present(emitted)
	check(feedback.flights.is_empty(),"paused view rejects new effects")
	flow.set_paused(false)
	feedback.present(emitted)
	check(not feedback.flights.is_empty(),"resume permits new feedback")
	map.set_breakthrough_open(false)
	check(feedback.flights.is_empty() and not presentation.music.stream_paused,"ordinary close clears effects and restores region music")
	map.set_breakthrough_open(true)
	# Actual recovery at/above its cap must not create any flight.
	check(flow.reset(),"reset for full-resource fixture")
	expanded.placements=expanded.placements.filter(func(e): return e.item_id in ["base.map_item.t01_0019","base.map_item.t01_0020","base.map_item.t01_0021"])
	expanded.growth.resources={"hp":6000,"stamina":6000,"spirit":5000}
	check(state.restore(expanded).is_empty(),"full-resource fixture restores")
	map.player_status.apply_growth(state.growth)
	emitted.clear()
	check(flow.start(),"start full-resource fixture")
	flow.advance(8)
	check(feedback.flights.is_empty() and flow.runtime.progress()==0,"capped recovery and no production produce no icons")
	check(emitted.all(func(e): return e.kind!="cultivation_gained" and (e.kind!="restore" or e.value==0)),"actual zero recovery values remain zero")
	# Award is truncated at the target, including the presentation amount.
	map.set_breakthrough_open(false)
	var boundary := seed_attempt(9999,0,true)
	var boundary_events: Array[Dictionary]=[]
	boundary.presentation_events.connect(func(events): boundary_events.append_array(events))
	boundary.set_paused(false); boundary.advance(6)
	var final_gains: Array=boundary_events.filter(func(e): return e.kind=="cultivation_gained")
	check(boundary.phase=="succeeded" and final_gains.size()==1 and is_equal_approx(final_gains[0].value,0.01),"final icon corresponds only to actual remaining cultivation")
	# Failed save publishes no gains or recovery effects.
	restore_fixture(); equip_guide()
	var broken := new_run()
	var rejected: Array[Dictionary]=[]
	broken.presentation_events.connect(func(events): rejected.append_array(events))
	check(broken.start(),"start failure fixture")
	broken.advance(5); rejected.clear()
	broken.training.save_path=directory+"missing/save.json"
	gameplay=state.snapshot(); broken.advance(1)
	check(rejected.is_empty() and state.snapshot()==gameplay and broken.phase=="paused","failed commit creates no icons or gains")
	map.queue_free(); await settle()
	presentation.music.stop(); presentation.music.stream=null
	await create_timer(0.2).timeout
	print("Breakthrough feedback: ",checks," checks, ",failures," failures; ",directory)
	quit(1 if failures else 0)
