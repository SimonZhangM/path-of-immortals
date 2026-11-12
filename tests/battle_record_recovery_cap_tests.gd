extends "res://tests/cultivation_combat_tests.gd"

func run() -> void:
	check(registry.load_base_content(), "content loads")
	check(MapLoadoutStore.create_state(registry, registry.get_board("base.board.bag")).error.is_empty(), "real item catalog loads")
	for spec: Array in [["base.map_item.t01_0019", "hp", 8.0], ["base.map_item.t01_0020", "stamina", 12.0]]:
		for initial: float in [50.0, 40.0, 33.0, 30.0, 10.0]:
			var p := actor("test.cap.player")
			var e := actor("test.cap.enemy")
			p.board = null
			p.definition.max_hp = 50
			p.definition.max_stamina = 50
			e.inventory.add_item("enemy_weapon", "base.map_item.qingshi_short_sword", Vector2i.ZERO)
			check(p.inventory.add_item("recovery", spec[0], Vector2i.ZERO), "equip real capped item")
			var sim := BattleSimulation.new([p], [e], registry)
			check(sim.start(), "battle starts")
			sim.timeline.set_all(p, false)
			p.set(spec[1], initial)
			sim.t01.activate("recovery", 7500000)
			var expected := minf(spec[2], maxf(0, 33 - initial))
			check(is_equal_approx(p.get(spec[1]), initial + expected), "actual recovery obeys floor(50 * 2/3), never reduces resources")
			var log := BattleLog.new()
			log.bind(sim.state.teams)
			log.consume(sim.drain_events(), registry, false)
			check(log.rows.size() == 2, "start plus one activation; no extra zero-result row")
			var row: Dictionary = log.rows[-1]
			check(row.target_id == p.id and row.restores[spec[1]] == expected, "self target and actual value preserved, including zero stamina")
			check(log.filtered("recovery").size() == (1 if spec[1] == "hp" else 0), "only HP belongs to healing filter")
			var description := log.result_text(row)
			check(not description.contains("发动"), "activation has explicit outcome")
			check(description.contains("当前%s，已达本物品恢复上限33" % int(initial)) if expected == 0 else not description.contains("已达"), "zero cap result explains current value and ceiling")
			if initial == 40: print(registry.get_item(spec[0]).display_name + ": " + description)
			var count := log.rows.size()
			sim.t01.restore(p, "stamina", 0, 8000000, -1, sim.t01.record_source(p, {"item_id": spec[0]}))
			log.consume(sim.drain_events(), registry, false)
			check(log.rows.size() == count, "standalone no-change resource callback stays omitted")
			check(log.segments(row)[0].color == BattleLog.COLORS.recovery, "restoration text uses recovery color")
	print("BATTLE_RECORD_RECOVERY_CAP: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
