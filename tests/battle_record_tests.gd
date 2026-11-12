extends "res://tests/cultivation_combat_tests.gd"

func records(sim: BattleSimulation) -> BattleLog:
	var log := BattleLog.new()
	log.bind(sim.state.teams)
	log.consume(sim.drain_events(), registry, false)
	return log

func run() -> void:
	check(registry.load_base_content(), "content loads")
	check(MapLoadoutStore.create_state(registry, registry.get_board("base.board.bag")).error.is_empty(), "item catalog loads")
	if not failures.is_empty(): finish(); return
	test_rows()
	test_segments()
	test_status_ticks()
	test_shield_sources()
	test_filters()
	# Instrumentation reaches every implemented spell opcode without changing its rules.
	test_all_spells()
	print("BATTLE_RECORD: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func test_rows() -> void:
	var sim := battle()
	var p: PartyMemberState = sim.state.teams[0][0]
	var e: PartyMemberState = sim.state.teams[1][0]
	var item := registry.get_item("base.map_item.t01_0033")
	sim.record_trace.begin(sim.t01.record_source(p, {"item_id": item.id}), 0)
	sim.t01.emit("item_activated", 0, {"stamina_cost": 2, "spirit_cost": 4})
	sim.t01.damage(p, e, 12, "钝击", "base.element.none", 0, {"adjusted": true}, true, {})
	sim.t01.apply_status(e, "破甲", 1, p, 0)
	sim.record_trace.end()
	var log := records(sim)
	check(log.rows.size() == 2 and log.rows[0].system, "one system start and one combined settlement")
	var row := log.rows[1]
	check(row.tags.has("damage") and row.tags.has("debuff") and row.effects.size() == 1, "damage and status share a row")
	check(row.item_id == item.id and row.source_id == p.id and row.target_id == e.id, "source item and target preserved")
	check(row.cost == Vector2(2, 4), "common costs recorded once")
	check(not log.result_text(row).contains("耗体") and not log.result_text(row).contains("耗灵"), "cost information omitted from display")
	check(log.filtered("damage").size() == 1 and log.filtered("debuff").size() == 1 and log.filtered("all").size() == 2, "multi-category filtering does not duplicate all")
	check(log.filtered("me").size() == 1 and log.filtered("enemy").is_empty(), "faction follows source")
	sim.t01.restore(p, "hp", 10, 1, -1, sim.t01.record_source(p, {"item_id": item.id}))
	sim.t01.restore(p, "stamina", 1, 2)
	log.consume(sim.drain_events(), registry, false)
	check(log.filtered("recovery").size() == 1 and log.filtered("recovery")[0].restores.hp == 0, "full-health healing retained; natural recovery omitted")
	sim._finish("victory", 3)
	log.consume(sim.drain_events(), registry, false)
	check(log.rows[-1].system and log.rows[-1].event_name == "战斗结束 · 胜利", "one actual end row")

func test_segments() -> void:
	var p := actor("segments.player")
	var e := actor("segments.enemy")
	check(p.inventory.add_item("multi", "base.organ.qingfenglingtang_qingfenglianzhi", Vector2i.ZERO), "equip real multi-hit item")
	var sim := BattleSimulation.new([p], [e], registry)
	check(sim.start(), "multi-hit battle starts")
	sim.timeline.set_all(p, false)
	sim.t01.forced_rolls.assign([0, .99, .999])
	sim.t01.activate("multi", 0)
	sim.advance(.2)
	var log := records(sim)
	var attacks := log.filtered("damage")
	check(attacks.size() == 2, "two independent segments")
	if attacks.size() != 2: return
	check(attacks[0].cost.x == 3 and attacks[1].cost == Vector2.ZERO, "multi-hit fee only on first segment")
	check(attacks[0].action_id == attacks[1].action_id, "segments link to one action")
	check(attacks[1].miss.begins_with("未命中") and attacks[1].at_usec == 200000, "miss retained at actual segment time")

func test_status_ticks() -> void:
	var sim := battle()
	var p: PartyMemberState = sim.state.teams[0][0]
	var e: PartyMemberState = sim.state.teams[1][0]
	sim.record_trace.begin(sim.t01.record_source(p, {"item_id": "base.spell.wood_02"}), 0)
	sim.t01.apply_status(e, "毒蚀", 2, p, 0)
	sim.record_trace.end()
	sim.advance(1.1)
	var log := records(sim)
	var dot := log.filtered("damage")
	check(not dot.is_empty(), "actual poison ticks recorded")
	for row: Dictionary in dot:
		check(row.source_id == p.id and row.item_id == "base.spell.wood_02" and row.event_name == "毒蚀", "DOT keeps original owner and item")
	var before := log.rows.size()
	sim.t01.apply_status(e, "毒蚀", 1000, p, 1100000)
	sim.t01.apply_status(e, "毒蚀", 1, p, 1200000)
	log.consume(sim.drain_events(), registry, false)
	check(log.rows.size() > before and log.rows[-1].applications.is_empty() and log.result_text(log.rows[-1]).contains("上限"), "failed full-cap application retained with zero count")
	sim.record_trace.begin(sim.t01.record_source(p, {"item_id": "base.spell.metal_01"}), 1300000)
	sim.t01.apply_status(e, "流血", 2, p, 1300000)
	sim.record_trace.end()
	sim.advance(6.5)
	log.consume(sim.drain_events(), registry, false)
	check(log.status_details.any(func(v): return v.status == "流血"), "natural expiry retained in details")
	check(not log.rows.any(func(v): return v.event_name.contains("到期")), "natural expiry does not create action row")
	p.hp -= 20
	sim.record_trace.begin(sim.t01.record_source(p, {"item_id": "base.spell.wood_02"}), sim.state.time_usec)
	sim.t01.apply_status(p, "生机", 2, p, sim.state.time_usec)
	sim.record_trace.end()
	sim.advance(1.1)
	log.consume(sim.drain_events(), registry, false)
	var healing := log.filtered("recovery")
	check(not healing.is_empty() and healing[-1].event_name == "生机" and healing[-1].source_id == p.id, "HOT names its actual status and original source")

func test_shield_sources() -> void:
	var sim := battle()
	var p: PartyMemberState = sim.state.teams[0][0]
	var e: PartyMemberState = sim.state.teams[1][0]
	p.thunder_shields.assign([3.0])
	p.armor = 4
	sim.t01.damage(e, p, 20, "钝击", "base.element.none", 0, {"adjusted": true}, true, {"special": true})
	var log := records(sim)
	var attack: Dictionary = log.filtered("enemy")[0]
	var reaction: Dictionary = log.filtered("me")[0]
	check(attack.damage.thunder_shield == 3 and attack.damage.armor == 4 and attack.damage.hp == 13, "shield armor HP share actual attacker result")
	check(log.result_text(attack).contains("雷盾破裂") and log.result_text(attack).contains("护甲耗尽"), "break and depleted notes belong to incoming attack")
	check(reaction.event_name == "雷盾·破裂" and reaction.tags == ["debuff"] and reaction.target_id == e.id, "defender separately owns paralysis")
	check(attack.action_id == reaction.parent_id and log.rows.find(attack) < log.rows.find(reaction), "shield reaction links to triggering action in order")
	check(reaction.applications.get("麻痹", 0) == 1, "new control counts once")
	p.thunder_shields.assign([1.0])
	sim.t01.damage(e, p, 20, "钝击", "base.element.none", 0, {"adjusted": true}, true, {"special": true})
	log.consume(sim.drain_events(), registry, false)
	check(log.filtered("me")[-1].applications.is_empty(), "same-time non-extending control counts zero")

func test_filters() -> void:
	var sim := battle()
	var p: PartyMemberState = sim.state.teams[0][0]
	p.stamina -= 10
	sim.record_trace.begin(sim.t01.record_source(p, {"item_id": "base.map_item.t01_0033"}), 0)
	sim.t01.restore(p, "stamina", 3, 0)
	sim.cultivation.add_barrier(p, 4, "test")
	sim.t01.emit("temporary_buff", 0, {"target_id": p.id, "target_name": p.definition.name, "label": "攻击提高", "value": .2, "duration": 5})
	sim.record_trace.end()
	var log := records(sim)
	check(log.filtered("recovery").is_empty() and log.filtered("buff").size() == 1, "non-HP restoration excluded from healing")
	check(log.segments(log.rows[-1]).all(func(v): return v.color == BattleLog.COLORS.buff), "restoration and buff colored blue")
