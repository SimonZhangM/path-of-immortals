extends "res://tests/breakthrough_audio_tests.gd"

func run() -> void:
	root.content_scale_size=Vector2i.ZERO
	root.size=Vector2i(2560,1440)
	if not await prepare_audio_fixture("res://artifacts/breakthrough-resource-accounting-20261105"): quit(1); return
	restore_fixture(); equip_guide()
	var flow: RefCounted=map.breakthrough_session
	var screen: Control=map.breakthrough_screen
	check(flow.start(),"start actual first breakthrough")
	flow.advance(3)
	check(flow.runtime.progress()==300 and flow.runtime.recent_gain()==300,"three stamina awards three cultivation without spirit")
	check(screen.progress_current.text=="3.0" and screen.progress_required.text=="200" and screen.efficiency_number.text=="3.0","readout and efficiency show actual credited points")
	check(not screen.status_value.visible,"running status caption removed")
	flow.set_paused(true)
	check(not screen.status_value.visible,"paused status caption removed")
	var paused := state.snapshot()
	flow.advance(10)
	check(state.snapshot()==paused,"pause preserves resources and actual points")
	if DisplayServer.get_name()!="headless":
		for resolution in [Vector2i(2560,1440),Vector2i(1920,1080)]:
			root.size=resolution
			await capture("actual-values-%d" % resolution.x)
	check(flow.reset(),"reset isolated preview")
	var guide := state.registry.get_item(GUIDE)
	var original := Vector2(guide.stamina_cost,guide.spirit_cost)
	for cost in [Vector2(2,0),Vector2(0,3),Vector2(2,3),Vector2(0.25,0),Vector2.ZERO]:
		restore_fixture(); equip_guide()
		guide.stamina_cost=cost.x; guide.spirit_cost=cost.y
		var attempt := new_run()
		check(attempt.start(),"start cost case "+str(cost))
		var emitted: Array[Dictionary]=[]
		attempt.presentation_events.connect(func(events): emitted.append_array(events))
		attempt.advance(3)
		var expected := CultivationGrowth.cents(cost.x) if cost.y==0 else 0
		check(attempt.progress()==expected,"paid stamina converts one-for-one; mortal spirit-cost actions cannot activate "+str(cost))
		check(state.growth.resources.stamina==5000-expected and state.growth.resources.spirit==0,"resources charged exactly once")
		var gained := 0
		for event: Dictionary in emitted:
			if event.kind=="cultivation_gained": gained+=CultivationGrowth.cents(event.value)
		check(gained==expected,"feedback events equal credited cultivation")
		attempt.set_paused(true)
	guide.stamina_cost=original.x; guide.spirit_cost=original.y
	# An unaffordable activation must not produce theoretical income.
	restore_fixture(); equip_guide()
	state.growth.resources.stamina=100
	map.player_status.apply_growth(state.growth)
	var poor := new_run()
	check(poor.start(),"start resource-starved attempt")
	poor.advance(10)
	check(poor.progress()==0 and state.growth.resources.stamina==100,"unpaid action earns zero")
	# Congestion is a real payment; restoration in the same period must not erase it.
	restore_fixture()
	var expanded := state.snapshot()
	expanded.owned_units["test.second.sword"]="base.map_item.qingshi_short_sword"
	expanded.owned_units["test.restore.stamina"]="base.map_item.t01_0020"
	expanded.placements=[{"instance_id":"test.audio.sword","item_id":"base.map_item.qingshi_short_sword","cell":[0,0]},
		{"instance_id":"test.second.sword","item_id":"base.map_item.qingshi_short_sword","cell":[1,0]},
		{"instance_id":"test.restore.stamina","item_id":"base.map_item.t01_0020","cell":[3,0]}]
	expanded.growth.resources.stamina=2000
	check(state.restore(expanded).is_empty(),"two weapons and real stamina recovery fixture")
	map.player_status.apply_growth(state.growth)
	var combined := new_run()
	check(combined.start(),"start weapon cost case")
	var events: Array[Dictionary]=[]
	combined.presentation_events.connect(func(batch): events.append_array(batch))
	combined.advance(9)
	var spent := 0
	var restored := 0
	for event: Dictionary in events:
		if event.kind=="item_activated": spent+=CultivationGrowth.cents(float(event.get("stamina_cost",0))+float(event.get("spirit_cost",0)))
		if event.kind=="restore" and event.get("resource","")=="stamina": restored+=CultivationGrowth.cents(event.value)
	check(spent>0 and combined.progress()==spent,"all actual weapon costs including congestion credited")
	check(restored>0 and state.growth.resources.stamina==2000-spent+restored,"restoration neither reduces nor adds spent-resource cultivation")
	check(events.any(func(e): return e.kind=="item_activated" and float(e.get("stamina_cost",0))>state.registry.get_item("base.map_item.qingshi_short_sword").stamina_cost),"fixture exercised modified actual weapon cost")
	# Final payment may only fill the remaining target; failed persistence publishes nothing.
	var last := seed_attempt(19950,0,true)
	last.set_paused(false)
	last.advance(6)
	check(last.phase=="succeeded" and last.progress()==20000 and last.recent_gain()==50,"last payment caps at target and succeeds")
	restore_fixture(); equip_guide()
	var failed := new_run()
	check(failed.start(),"start failed-save fixture")
	failed.advance(2)
	failed.training.save_path=directory+"missing/save.json"
	var before := state.snapshot()
	failed.advance(1)
	check(failed.phase=="paused" and state.snapshot()==before and failed.progress()==0,"failed save rolls back actual resource income")
	restore_fixture(); equip_guide()
	var ordinary := MapCultivationSession.new()
	state.growth.progress=0
	ordinary.begin({"id":"base.map_event.qingshizhen.cultivation","durations":[5],"modes":[{"id":"cultivation","name":"修炼"}]},"cultivation",5,WorldCalendar.current_day(state.calendar))
	check(ordinary.bind(state,map.player_status,""),"ordinary training binds")
	ordinary.set_paused(false,0); ordinary.advance(6)
	check(state.growth.progress==72,"ordinary training keeps original 0.12 / 0.18 rates")
	map.queue_free()
	await settle()
	await create_timer(0.3).timeout
	print("Breakthrough actual resource accounting: %d checks, %d failures; %s" % [checks,failures,directory])
	quit(1 if failures else 0)
