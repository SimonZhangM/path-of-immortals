extends "res://tests/breakthrough_audio_tests.gd"

func run() -> void:
	if not await prepare_audio_fixture("res://artifacts/mortal-spirit-20261109"): quit(1); return
	restore_fixture()
	check(baseline.growth.resources.spirit==5000 and state.growth.resources.spirit==0,"legacy mortal spirit is normalized on restore without mutating input")
	check(map.player_status.resources.spirit==0 and map.player_status.maxima.spirit==0,"mortal status is zero of zero")
	map.player_status.set_resource("spirit",50)
	map.player_status.rest(100,1,"test.rest")
	check(map.player_status.resources.spirit==0,"assignment and full rest cannot grant mortal spirit")
	var boosted := BoardLayout.plain()
	boosted.id="test.spirit_bonus"
	boosted.resource_bonuses={"spirit":99}
	map.player_status.apply_board(boosted)
	map.player_status.apply_growth(state.growth)
	check(map.player_status.maxima.spirit==0 and map.player_status.resources.spirit==0,"board bonus cannot raise mortal spirit")
	var member := PartyMemberState.new(map.player_status.battle_snapshot().character,state.registry)
	member.board=boosted
	member.reset_resources()
	check(member.maximum("spirit")==0 and member.spirit==0,"combat member also suppresses mortal board bonus")
	map.player_status.apply_board(state.board)
	restore_fixture(); equip_guide()
	var guide := state.registry.get_item(GUIDE)
	check(guide.cooldown_usec==3000000 and guide.stamina_cost==3 and guide.spirit_cost==0,"guide has three-second three-stamina cost")
	var attempt := new_run()
	check(attempt.start(),"mortal begins first qi without spirit")
	attempt.advance(2.5)
	check(attempt.progress()==0 and state.growth.resources.stamina==5000,"no early activation")
	attempt.advance(0.5)
	check(attempt.progress()==300 and state.growth.resources.stamina==4700 and state.growth.resources.spirit==0,"first activation spends only three stamina at three seconds")
	attempt.advance(3)
	check(attempt.progress()==600 and state.growth.resources.stamina==4400,"second activation repeats after three seconds")
	attempt.set_paused(true)
	var loaded := MapLoadoutStore.candidate(state)
	check(loaded.error.is_empty() and MapLoadoutStore.load_into(loaded.state,path).is_empty(),"saved progress reloads")
	check(loaded.state.growth.resources.spirit==0 and loaded.state.growth.breakthrough_attempt.progress==600,"reload preserves zero spirit and earned points")
	# Run the complete zero-spirit first breakthrough using an existing stamina restorer.
	restore_fixture()
	var raw := state.snapshot()
	var equipment := {"test.first_qi.guide":GUIDE,"test.stamina":"base.map_item.t01_0020","test.spirit":"base.map_item.t01_0021","test.mirror":"base.map_item.t01_0087"}
	var column := 0
	for id: String in equipment:
		raw.owned_units[id]=equipment[id]
		raw.placements.append({"instance_id":id,"item_id":equipment[id],"cell":[column,0]})
		column+=1
	check(state.restore(raw).is_empty(),"equip guide, stamina restorer, spirit restorer and spirit-cost mirror")
	map.player_status.apply_growth(state.growth)
	var full := new_run()
	check(full.start(),"start full first breakthrough")
	full.advance(30)
	check(full.progress()==3000 and state.growth.resources.spirit==0,"ten guide activations earn thirty points and spirit restoration remains zero")
	check(full.training.simulation.state.item_runtime["test.mirror"].activation_count==0,"mortal cannot activate spirit-cost artifact")
	full.advance(270)
	check(full.phase=="succeeded" and state.growth.realm==1,"complete real first breakthrough within unchanged deadline")
	check(full.progress()==20000,"first breakthrough still requires two hundred points")
	check(full.result_snapshot().gains.spirit==100,"breakthrough grants one hundred base spirit")
	check(map.player_status.resources.spirit==100 and map.player_status.maxima.spirit==100,"qi player gains usable spirit")
	var cultivator := PartyMemberState.new(map.player_status.battle_snapshot().character,state.registry)
	var copy := MapLoadoutStore.candidate(state)
	cultivator.inventory=copy.state.inventory
	cultivator.board=state.board
	for key: String in map.player_status.resources: cultivator.set(key,map.player_status.resources[key])
	var training := CultivationTraining.new(cultivator,state.registry)
	check(training.start(),"qi simulation starts")
	training.advance(7)
	check(training.state.item_runtime["test.mirror"].activation_count==1 and cultivator.spirit==94,"qi artifact activates and actually pays six spirit")
	check(MapLoadoutStore.candidate(state).state.growth.resources.spirit==10000,"qi spirit survives state hydration")
	map.queue_free()
	await settle()
	print("Mortal spirit: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
