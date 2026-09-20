extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _near(actual: float, expected: float, message: String) -> void:
	_check(is_equal_approx(actual, expected), "%s: %s expected %s" % [message, actual, expected])

func _fixture(slow_attack := true) -> Dictionary:
	var registry := ContentRegistry.new()
	registry.load_base_content()
	MapLoadoutStore.create_state(registry, registry.get_board("base.board.bag"))
	var hero := PartyMemberState.new(registry.get_character(GameManager.PARTY_IDS[0]), registry)
	var dog := PartyMemberState.new(registry.get_enemy(GameManager.ENEMY_ID), registry)
	hero.definition.max_hp = 95
	dog.definition.max_hp = 95
	hero.hp = 100
	dog.hp = 100
	if slow_attack:
		registry.register_item({"id": "test.combat.slow", "name": "慢攻击", "type": "weapon", "tags": [], "cooldown": 60, "size": [1, 1], "effects": [{"trigger": "on_activate", "effect": "damage", "value": 1}]})
		dog.inventory.add_item("slow", "test.combat.slow", Vector2i.ZERO)
	return {"registry": registry, "hero": hero, "dog": dog, "battle": BattleSimulation.new([hero], [dog], registry)}

func _damage(f: Dictionary, damage_type: String, value: int, side := 0) -> Dictionary:
	return EffectSystem.new().apply({"trigger": "on_activate", "effect": "damage", "value": value, "damage_type": damage_type}, f.battle.state, f.dog if side == 0 else f.hero, 0, {"side": side, "owner_name": "测试", "item_id": "base.map_item.qingshi_short_sword", "stamina_cost": 0})

func _run() -> void:
	_test_damage()
	_test_toxin()
	_test_effect_pipeline()
	await _test_display()
	print("DAMAGE / TOXIN: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _test_damage() -> void:
	var expected := {"斩击": [1.2, 1.0, 0.8, 1.0], "穿刺": [1.0, 1.2, 0.8, 1.0], "钝击": [1.0, 1.0, 1.2, 1.0]}
	var armors := ["无甲", "轻甲", "重甲", "灵甲"]
	for kind: String in expected:
		for index in 4:
			for side in 2:
				var f := _fixture()
				var target: PartyMemberState = f.dog if side == 0 else f.hero
				target.armor_type_sources["test"] = armors[index]
				target.armor = 2.5
				var event := _damage(f, kind, 7, side)
				var adjusted: float = 7 * expected[kind][index]
				_near(event.adjusted_damage, adjusted, "both sides use exact matrix")
				_near(target.hp, 100 - (adjusted - 2.5), "multiplier precedes armor and preserves fractions")
				_near(f.battle.state.damage_totals[side], adjusted - 2.5, "statistics keep fractional HP loss")
	var f := _fixture()
	f.dog.armor = 10
	_damage(f, "斩击", 7)
	_near(f.dog.armor, 1.6, "fractional armor remains after full absorption")
	_near(f.dog.hp, 100, "armor absorbs entire adjusted hit")
	f.dog.armor_capacity_sources.test = 12
	EffectSystem.new().restore(f.dog, "armor", 3, 0, {})
	_near(f.dog.armor, 4.6, "armor restoration retains fractional remainder")
	f.dog.armor_capacity_sources.test = 4
	f.dog.remove_armor_source("unrelated")
	_near(f.dog.armor, 4, "removal clamps armor cap")
	f.hero.hp = 99.7
	var restored := EffectSystem.new().restore(f.hero, "hp", 2, 0, {})
	_near(restored.value, 0.3, "partial recovery reports exact actual gain")
	f.dog.hp = 0.4
	f.dog.armor = 0
	var lethal := _damage(f, "斩击", 7)
	_near(lethal.value, 0.4, "overkill reports actual fractional HP")
	_near(f.dog.hp, 0, "no residual floating-point life")
	for item_id in ["qingshi_short_sword", "hunting_bow", "short_iron_hammer"]:
		f = _fixture(false)
		var item: ItemData = f.registry.get_item("base.map_item." + item_id)
		f.hero.inventory.add_item("weapon", item.id, Vector2i.ZERO)
		f.battle = BattleSimulation.new([f.hero], [f.dog], f.registry)
		f.dog.armor_type_sources.test = "重甲"
		f.battle.start()
		f.battle.advance(item.cooldown_usec / 1_000_000.0)
		var damage_events: Array = f.battle.drain_events().filter(func(event): return event.kind == "damage")
		_check(damage_events.size() == 1 and damage_events[0].damage_type == item.effects[0].damage_type, "actual map weapon carries type into combat")
		_near(damage_events[0].adjusted_damage, float(item.effects[0].value) * (1.2 if item_id == "short_iron_hammer" else 0.8), "live weapon adjusted damage")
	_check(not EffectSystem.validate_definition({"trigger": "on_activate", "effect": "damage", "value": 3, "damage_type": "typo"}), "unknown damage type rejected")
	_check(not EffectSystem.validate_definition({"trigger": "on_activate", "effect": "apply_toxin", "value": 1.5}), "fractional toxin stacks rejected")

func _test_toxin() -> void:
	var f := _fixture(false)
	f.dog.armor = 30.5
	f.dog.armor_type_sources.test = "重甲"
	_check(f.battle.apply_toxin(f.dog, 5, 0), "prepare five toxin stacks")
	f.battle.start()
	_check(not f.battle.state.is_finished(), "pending toxin prevents premature draw")
	f.battle.advance(1.999)
	_near(f.dog.hp, 100, "no poison damage before two seconds")
	f.battle.advance(0.001)
	_near(f.dog.hp, 95, "first tick at exactly second two")
	_check(f.dog.toxin_stacks == 4, "one layer decays per tick")
	f.battle.advance(4)
	_near(f.dog.hp, 85, "five layers deal5+4+3+2+1")
	_near(f.dog.armor, 30.5, "toxin bypasses armor and armor type")
	_check(f.battle.state.result == "draw" and f.battle.state.finished_at_usec == 6_000_000, "draw only after final toxin tick")
	_check(not f.battle.apply_toxin(f.dog, 1, 0), "finished battle rejects new toxin")
	f = _fixture()
	f.battle.apply_toxin(f.hero, 2, 1)
	f.battle.start()
	f.battle.advance(1)
	f.battle.apply_toxin(f.hero, 3, 1)
	f.battle.advance(1)
	_near(f.hero.hp, 95, "adding during initial wait does not reset deadline")
	f.battle.apply_toxin(f.hero, 2, 1)
	f.battle.advance(1)
	_near(f.hero.hp, 89, "adding during ticking keeps existing one-second cadence")
	f.battle.clock.paused = true
	f.battle.advance(50)
	_near(f.hero.hp, 89, "pause freezes toxin")
	f.battle.clock.paused = false
	f.battle.clock.set_speed(2)
	f.battle.advance(0.5)
	_near(f.hero.hp, 84, "double speed uses combat seconds")
	f.hero.cleanse_toxin(f.battle.state.time_usec, 15_000_000)
	_check(not f.battle.apply_toxin(f.hero, 4, 1), "immunity blocks new layers")
	f.battle.clock.set_speed(1)
	f.battle.advance(14.999)
	_near(f.hero.hp, 84, "cleansing invalidates queued damage")
	_check(not f.battle.apply_toxin(f.hero, 1, 1), "immunity holds before deadline")
	f.battle.advance(0.001)
	_check(f.battle.apply_toxin(f.hero, 2, 1), "immunity expires at exact deadline")
	f.battle.advance(1.999)
	_near(f.hero.hp, 84, "new poison after cleanse waits full two seconds")
	f.battle.advance(0.001)
	_near(f.hero.hp, 82, "new generation ticks once")
	f = _fixture()
	f.battle.apply_toxin(f.hero, 5, 1)
	f.battle.start()
	f.battle.advance(1)
	f.hero.cleanse_toxin(1_000_000, 0)
	f.battle.apply_toxin(f.hero, 2, 1)
	f.battle.advance(1)
	_near(f.hero.hp, 100, "stale first-generation tick ignored")
	f.battle.advance(1)
	_near(f.hero.hp, 98, "replacement generation begins on its own deadline")
	for victim_side in 2:
		f = _fixture(false)
		var victim: PartyMemberState = f.hero if victim_side == 0 else f.dog
		victim.hp = 2.4
		f.battle.apply_toxin(victim, 5, 1 - victim_side)
		f.battle.start()
		f.battle.advance(10)
		_check(f.battle.state.result == ("defeat" if victim_side == 0 else "victory") and f.battle.state.finished_at_usec == 2_000_000, "toxin death ends either side immediately")
		_near(f.battle.state.damage_totals[1 - victim_side], 2.4, "lethal toxin counts actual fractional damage")
		_near(victim.hp, 0, "lethal toxin clamps zero")
	for speed in [0.5, 1.0, 2.0]:
		f = _fixture()
		f.battle.apply_toxin(f.hero, 5, 1)
		f.battle.start()
		f.battle.clock.set_speed(speed)
		for i in 120:
			f.battle.advance(6.0 / 120.0 / speed)
		_near(f.hero.hp, 85, "frame partition and speed invariant")

func _test_effect_pipeline() -> void:
	var f := _fixture()
	_check(f.registry.register_item({"id": "test.combat.toxic", "name": "施毒测试", "type": "weapon", "tags": [], "cooldown": 1, "stamina_cost": 1, "size": [1, 1], "effects": [{"trigger": "on_activate", "effect": "damage", "value": 1, "damage_type": "穿刺"}, {"trigger": "on_activate", "effect": "apply_toxin", "value": 3}]}), "future combined damage and toxin effect registers")
	f.hero.inventory.add_item("toxic", "test.combat.toxic", Vector2i.ZERO)
	f.battle = BattleSimulation.new([f.hero], [f.dog], f.registry)
	f.battle.start()
	f.battle.advance(1)
	_check(f.dog.toxin_stacks == 3 and f.dog.hp == 99, "configured attack applies direct damage and toxin")
	f.battle.detach("toxic")
	f.hero.inventory.take("toxic")
	f.battle.advance(2)
	_near(f.dog.hp, 96, "poison survives removal of source item")
	f = _fixture()
	f.hero.inventory.add_item("detox", "base.map_item.detox_powder", Vector2i.ZERO)
	f.battle = BattleSimulation.new([f.hero], [f.dog], f.registry)
	f.battle.start()
	f.battle.advance(3.5)
	f.battle.apply_toxin(f.hero, 9, 1)
	f.battle.advance(2)
	_near(f.hero.hp, 100, "same-time cleanse precedes toxin tick")
	_check(f.hero.toxin_stacks == 0 and f.hero.inventory.get_instance("detox").is_empty(), "real detox consumes bottle and clears toxin")
	f.battle.request_retreat()
	f.battle.advance(3)
	_check(f.battle.state.result == "retreat", "retreat stops battle normally")
	var hp: float = f.hero.hp
	f.battle.advance(100)
	_near(f.hero.hp, hp, "no effects execute after finish")

func _test_display() -> void:
	_check(EffectSystem.number_text(8.4) == "8.4" and EffectSystem.number_text(8.0) == "8", "number formatting preserves decimals without trailing zeros")
	var feedback := HitFeedback.new()
	root.add_child(feedback)
	feedback.configure(8.4)
	_check(feedback.damage_label.text == "-8.4", "floating damage text keeps decimals")
	feedback.queue_free()
	var f := _fixture()
	f.dog.hp = 100
	var hit := _damage(f, "斩击", 7)
	var log := BattleLog.new()
	var events: Array[Dictionary] = [hit]
	_check(log.consume(events, f.registry).contains("伤害8.4"), "battle log keeps fractional damage")
	f.hero.hp = 54.6
	f.hero.armor = 1.6
	f.hero.armor_capacity_sources.test = 7
	var card := PartyMemberCard.new()
	root.add_child(card)
	card.configure(0, f.hero)
	card.refresh(f.hero)
	_check(card.stat_values.hp.text == "54.6 / 100", "HP label preserves fractional value")
	_check(card.armor_status.text == "护甲 1.6 / 7", "armor label preserves fractional value")
	_near(card.stat_bars.hp.value, 54.6, "resource bar does not quantize to integer steps")
	card.queue_free()
	for id in ["qingshi_short_sword", "hunting_bow", "short_iron_hammer", "coarse_cloth_armor", "old_iron_helmet", "round_wood_shield", "warm_jade", "hemostatic_pill", "sinew_pill", "detox_powder"]:
		var words := ItemTooltip.keyword_meanings(f.registry.get_item("base.map_item." + id))
		for removed in ["冷却", "护甲上限", "恢复上限", "毒蚀免疫", "气血", "体力", "灵力", "消耗"]:
			_check(not words.has(removed), "removed glossary entry stays absent: " + removed)
	for i in 8:
		await process_frame
