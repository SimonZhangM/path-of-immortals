extends "res://tests/cultivation_combat_tests.gd"

func run() -> void:
	check(registry.load_base_content(),"content loads")
	if not registry.errors.is_empty():
		finish()
		return
	var catalog := MapLoadoutStore.create_state(registry,registry.get_board("base.board.bag"))
	check(catalog.error.is_empty(),"map item content loads")
	if not catalog.error.is_empty():
		finish()
		return
	for strengthened in [false,true]:
		for layer_count in [1,2]:
			var sim := battle()
			var defender: PartyMemberState = sim.state.teams[0][0]
			var attacker: PartyMemberState = sim.state.teams[1][0]
			if strengthened:
				learn(defender,"base.cultivation_book.thunder_02",1,"雷罡")
			var duration := 2_000_000 if strengthened else 1_000_000
			sim.advance(2.0)
			for layer in layer_count:
				defender.thunder_shields.append(1.0)
			var damage := sim.t01.damage(attacker,defender,20.0,"钝击","base.element.none",2_000_000,{"kind":"active"},true,{"special":true})
			check(defender.thunder_shields.is_empty() and damage.effective>0,"actual incoming hit breaks all shield layers")
			check(attacker.paralyzed_until==2_000_000+duration,"base one second or Lei Gang two seconds; layers refresh")
			sim.advance(float(duration-1)/1_000_000.0)
			check(attacker.paralyzed_until>sim.state.time_usec,"paralysis lasts until its final microsecond")
			sim.advance(0.000001)
			check(attacker.paralyzed_until==sim.state.time_usec,"paralysis expires at the exact deadline")
			var at: int = sim.state.time_usec
			defender.thunder_shields.assign([1.0])
			sim.t01.damage(attacker,defender,20.0,"钝击","base.element.none",at,{"kind":"active"},true,{"special":true})
			check(attacker.paralyzed_until==at+duration,"another break reapplies the configured duration")
			defender.thunder_shields.assign([1.0])
			sim.t01.damage(attacker,defender,20.0,"钝击","base.element.none",at+500_000,{"kind":"active"},true,{"special":true})
			check(attacker.paralyzed_until==at+500_000+duration,"overlapping breaks refresh instead of adding durations")
			attacker.paralyzed_until=at+10_000_000
			defender.thunder_shields.assign([1.0])
			sim.t01.damage(attacker,defender,20.0,"钝击","base.element.none",at+500_000,{"kind":"active"},true,{"special":true})
			check(attacker.paralyzed_until==at+10_000_000,"existing longer control deadline is preserved")
	print("THUNDER_SHIELD_PARALYSIS: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
