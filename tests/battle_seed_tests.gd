extends "res://tests/cultivation_combat_tests.gd"

func spell_outcomes(seed_value: int) -> Array:
	var p:=actor("test.seed.player")
	learn(p,"base.cultivation_book.wood_05",1)
	p.inventory.add_item("vines","base.spell.wood_05",Vector2i.ZERO)
	var e:=PartyMemberState.new(registry.get_enemy("base.enemy.biyetengling"),registry)
	e.equip_definition_loadout()
	var sim:=BattleSimulation.new([p],[e],registry,[],[],false,seed_value)
	check(sim.random_seed==seed_value and sim.t01.rng.seed==seed_value,"explicit seed injected")
	check(sim.start(),"seeded simulation starts")
	var outcomes:Array=[]
	for step in 30:
		sim.advance(.5)
		for event:Dictionary in sim.drain_events():
			if event.kind=="started": check(event.random_seed==seed_value,"start event retains seed")
			if event.get("item_id","")=="base.spell.wood_05" and event.kind in ["miss","damage","status_applied"]:
				outcomes.append([event.at_usec,event.kind,event.get("value",0),event.get("status","")])
	return outcomes

func run()->void:
	check(registry.load_base_content(),"registry")
	check(MapLoadoutStore.create_state(registry,registry.get_board("base.board.bag")).error.is_empty(),"catalog")
	var first:=spell_outcomes(42)
	check(not first.is_empty() and spell_outcomes(42)==first,"same seed reproduces actual spell damage and statuses")
	var stream_a:=BattleSimulation.new([actor("a")],[actor("b")],registry,[],[],false,42)
	var stream_b:=BattleSimulation.new([actor("c")],[actor("d")],registry,[],[],false,43)
	check(stream_a.t01.roll()!=stream_b.t01.roll(),"different seeds select different random streams")
	var game:=GameManager.new()
	game.use_saved_loadout=false
	root.add_child(game);game.set_process(false)
	check(game.startup_error.is_empty(),"real manager startup")
	var previous:=game.simulation.random_seed
	check(previous==game.simulation.t01.rng.seed,"production seed reaches rules")
	for result:String in ["defeat","retreat","victory"]:
		game.start_battle()
		var seed_state:=game.simulation.t01.rng.state
		game.toggle_pause();game.set_adjustment(true);game.set_adjustment(false);game.toggle_pause()
		game.set_speed(2.0);game.set_speed(1.0)
		check(game.simulation.random_seed==previous and game.simulation.t01.rng.state==seed_state,"pause adjustment speed retain stream")
		if result=="retreat":
			check(game.request_retreat(),"real retreat request")
			game.simulation.advance(3.0)
			check(game.simulation.state.is_finished(),"retreat reaches terminal state")
		else: game.simulation._finish(result,game.simulation.state.time_usec)
		game.restart()
		check(game.simulation.random_seed!=previous,"new seed after "+result)
		previous=game.simulation.random_seed
	game.free()
	var next:=GameManager.new()
	root.add_child(next);next.set_process(false)
	check(next.startup_error.is_empty() and next.simulation.random_seed!=previous,"recreated scene gets new seed")
	next.battle_seed_override=42;next.restart()
	check(next.simulation.random_seed==42,"explicit manager fixture seed")
	next.restart()
	check(next.simulation.random_seed==42,"fixture restart reproducible")
	next.free()
	print("BATTLE_SEED: %d checks, %d failures"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
