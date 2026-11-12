extends "res://tests/breakthrough_audio_tests.gd"

func sample(cooldown: float) -> RefCounted:
	restore_fixture()
	state.records = state.records.duplicate(true)
	state.records[GUIDE].cooldown = cooldown
	state.registry.get_item(GUIDE).cooldown_usec = roundi(cooldown*1000000.0)
	equip_guide()
	var run := new_run()
	check(run.start(),"start isolated cooldown sample")
	return run

func last_payment_time() -> int:
	var gains: Array = state.growth.breakthrough_attempt.recent_gains
	return int(gains.back().at_usec) if not gains.is_empty() else -1

func run() -> void:
	if not await prepare_audio_fixture("res://artifacts/breakthrough-half-second-20261107"): quit(1); return
	var flow := sample(5.5)
	flow.advance(5.49)
	check(flow.elapsed_usec()==5000000 and flow.progress()==0,"before 5.5 seconds no early payment")
	flow.advance(0.01)
	check(flow.elapsed_usec()==5500000 and flow.progress()==300,"5.5 second action settles in its exact batch")
	check(last_payment_time()==5500000,"5.5 second authoritative event time")
	flow.advance(5.5)
	check(flow.progress()==600 and last_payment_time()==11000000,"next 5.5 second cycle remains 11.0")
	flow = sample(5.7)
	flow.advance(5.7)
	check(flow.elapsed_usec()==5500000 and flow.progress()==0,"5.7 second due action waits for next half-second batch")
	flow.advance(0.3)
	check(flow.elapsed_usec()==6000000 and flow.progress()==300 and last_payment_time()==5700000,"6.0 batch commits the action due at 5.7")
	check(is_equal_approx(flow.cooldown_snapshot()["test.first_qi.guide"].remaining,5400000.0),"next cooldown already progressed by the delayed 0.3 seconds")
	flow.advance(5.0)
	check(flow.progress()==300,"no next payment before actual next due time")
	flow.advance(0.5)
	check(flow.progress()==600 and last_payment_time()==11400000,"11.5 batch retains next authoritative due time 11.4")
	flow = sample(6.0)
	flow.advance(5.7)
	flow.set_paused(true)
	check(flow.phase=="paused" and flow.elapsed_usec()==5700000 and flow.progress()==0,"pause flushes only the fractional uncommitted time")
	var reloaded: MapLoadoutState = MapLoadoutStore.candidate(state).state
	check(MapLoadoutStore.load_into(reloaded,path).is_empty() and int(reloaded.growth.breakthrough_attempt.elapsed_usec)==5700000,"fractional pause persists through disk reload")
	# The deadline can split the last half-second batch at the exact due time.
	restore_fixture()
	state.records = state.records.duplicate(true)
	state.records[GUIDE].cooldown = 5.7
	state.registry.get_item(GUIDE).cooldown_usec = 5700000
	equip_guide()
	state.growth.breakthrough_attempt={"version":2,"id":"base.breakthrough.first_qi","phase":"paused","progress":19950,"elapsed_usec":294300000,"recent_gains":[]}
	flow = new_run()
	flow.set_paused(false)
	flow.advance(5.7)
	check(flow.phase=="succeeded" and flow.elapsed_usec()==300000000 and flow.progress()==20000,"fractional deadline payment reaches target successfully")
	check(state.growth.realm==1 and state.growth.layer==1,"half-second batching commits the actual realm transition")
	restore_fixture()
	state.growth.breakthrough_attempt={"version":2,"id":"base.breakthrough.first_qi","phase":"paused","progress":0,"elapsed_usec":299800000,"recent_gains":[]}
	flow = new_run()
	flow.set_paused(false)
	flow.advance(0.2)
	check(flow.phase=="failed" and flow.elapsed_usec()==300000000,"fractional timeout cannot exceed the deadline")
	flow = sample(5.7)
	flow.advance(5.5)
	var before := state.snapshot()
	var events: Array = []
	flow.presentation_events.connect(func(batch): events.append_array(batch))
	flow.training.save_path = directory+"missing/step.json"
	flow.advance(0.5)
	check(flow.phase=="paused" and state.snapshot()==before and events.is_empty(),"failed half-second transaction rolls back state and presentation events")
	print("HALF-SECOND BREAKTHROUGH: %d checks, %d failures; %s" % [checks,failures,directory])
	map.deactivate_location(); map.free()
	quit(1 if failures else 0)
