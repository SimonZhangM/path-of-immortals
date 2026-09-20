extends SceneTree

var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _fixture(effects: Array, cd: float, uses: int = 0) -> Dictionary:
	var registry := ContentRegistry.new()
	registry.load_base_content()
	_check(registry.register_item({"id": "test.support.item", "name": "效果测试", "type": "artifact", "category": "artifact", "tags": [], "cooldown": cd, "uses_per_unit": uses, "size": [1, 1], "effects": effects}), "support effect registers")
	var hero := PartyMemberState.new(registry.get_character(GameManager.PARTY_IDS[0]), registry)
	var dog := PartyMemberState.new(registry.get_enemy(GameManager.ENEMY_ID), registry)
	hero.inventory.add_item("support", "test.support.item", Vector2i.ZERO)
	# A slow attack keeps the battle active while isolating support timing.
	registry.register_item({"id": "test.support.attack", "name": "慢攻击", "type": "weapon", "tags": [], "cooldown": 60, "size": [1, 1], "effects": [{"trigger": "on_activate", "effect": "damage", "value": 1}]})
	dog.inventory.add_item("attack", "test.support.attack", Vector2i.ZERO)
	return {"hero": hero, "battle": BattleSimulation.new([hero], [dog], registry)}

func _run() -> void:
	var effects := [{"trigger": "on_activate", "effect": "restore_capped", "resource": "hp", "value": 4, "cap_numerator": 2, "cap_denominator": 3}, {"trigger": "on_activate", "effect": "restore_capped", "resource": "stamina", "value": 6, "cap_numerator": 2, "cap_denominator": 3}]
	var f := _fixture(effects, 4.0)
	f.hero.hp = 34
	f.hero.stamina = 32
	f.battle.start()
	f.battle.advance(3.999)
	_check(f.hero.hp == 34 and f.hero.stamina == 32, "jade waits full cooldown")
	f.battle.advance(0.001)
	_check(f.hero.hp == 36 and f.hero.stamina == 36, "both resources cap at floor of55 times two thirds")
	f.hero.hp = 45
	f.hero.stamina = 1
	f.battle.advance(4.0)
	_check(f.hero.hp == 45 and f.hero.stamina == 7, "one resource above ceiling never decreases or blocks other recovery")
	for resource in ["hp", "stamina"]:
		var amount := 2 if resource == "hp" else 4
		var cd := 6.5 if resource == "hp" else 7.5
		f = _fixture([{"trigger": "on_activate", "effect": "restore_ticks", "resource": resource, "value": amount, "ticks": 3, "interval": 2.0}], cd, 1)
		f.hero.set(resource, 10)
		f.battle.start()
		f.battle.advance(cd)
		_check(f.hero.get(resource) == 10, "medicine activation has no immediate recovery")
		_check(f.hero.inventory.get_instance("support").is_empty(), "finite-use test item is consumed while effect remains scheduled")
		for tick in 3:
			f.battle.advance(1.999)
			_check(f.hero.get(resource) == 10 + tick * amount, "no early periodic tick")
			f.battle.advance(0.001)
			_check(f.hero.get(resource) == 10 + (tick + 1) * amount, "exact2-second tick after item consumption")
		f.battle.advance(2.0)
		_check(f.hero.get(resource) == 10 + 3 * amount, "exactly three ticks")
	var invalid: Dictionary = effects[0].duplicate()
	invalid.cap_denominator = 0
	_check(not EffectSystem.validate_definition(invalid), "invalid recovery cap rejected")
	f = _fixture([{"trigger": "on_activate", "effect": "cleanse_toxin", "duration": 15}], 5.5, 1)
	_check(f.hero.apply_toxin(5, 0), "toxin may be applied before immunity")
	f.battle.start()
	f.battle.advance(5.499)
	_check(f.hero.toxin_stacks == 1 and f.hero.hp == 41 and not f.hero.inventory.get_instance("support").is_empty(), "toxin ticks5/4/3/2 while detox waits its full5.5-second cooldown")
	f.battle.advance(0.001)
	_check(f.hero.toxin_stacks == 0 and f.hero.inventory.get_instance("support").is_empty(), "detox clears toxin and consumes one bottle")
	_check(f.hero.toxin_immune_until_usec == 20_500_000 and not f.hero.apply_toxin(8, f.battle.state.time_usec), "detox grants fifteen seconds immunity after activation")
	f.battle.clock.paused = true
	f.battle.advance(100)
	_check(f.battle.state.time_usec == 5_500_000 and not f.hero.apply_toxin(1, f.battle.state.time_usec), "pause does not consume immunity")
	f.battle.clock.paused = false
	f.battle.advance(14.999)
	_check(not f.hero.apply_toxin(1, f.battle.state.time_usec), "immunity remains until its exact deadline")
	f.battle.advance(0.001)
	_check(f.hero.apply_toxin(2, f.battle.state.time_usec) and f.hero.toxin_stacks == 2, "toxin can apply when immunity expires")
	var registry := ContentRegistry.new()
	registry.load_base_content()
	var created := MapLoadoutStore.create_state(registry, registry.get_board("base.board.bag"))
	_check(created.error.is_empty(), "ten live records load")
	var live_jade := registry.get_item("base.map_item.warm_jade")
	_check(live_jade.cooldown_usec == 4_000_000 and live_jade.grid_size == Vector2i.ONE and live_jade.effects == JSON.parse_string(JSON.stringify(effects)) and not live_jade.is_consumable(), "live jade has exact footprint, cadence, dual recovery and ceiling")
	var expected_cooldowns := [6_500_000, 7_500_000, 5_500_000]
	var expected_effects := [
		{"trigger": "on_activate", "effect": "restore_ticks", "resource": "hp", "value": 2, "ticks": 3, "interval": 2.0},
		{"trigger": "on_activate", "effect": "restore_ticks", "resource": "stamina", "value": 4, "ticks": 3, "interval": 2.0},
		{"trigger": "on_activate", "effect": "cleanse_toxin", "duration": 15},
	]
	var index := 0
	for id in ["hemostatic_pill", "sinew_pill", "detox_powder"]:
		var full_id: String = "base.map_item." + id
		var owned: String = "owned." + full_id + ".0"
		var live_item := registry.get_item(full_id)
		_check(live_item.grid_size == Vector2i.ONE and live_item.cooldown_usec == expected_cooldowns[index] and live_item.effects == JSON.parse_string(JSON.stringify([expected_effects[index]])), "live medicine contains exact requested effect and cooldown")
		index += 1
		_check(registry.get_item(full_id).uses_per_unit == 1 and created.state.storage.get_entry(owned).units[0].uses_left == 1, "canonical bottle starts with exactly one use")
		_check(created.state.place(created.state.drag_data("storage", owned), Vector2i.ZERO), "bottle can equip")
		_check(created.state.take_back(created.state.drag_data("board", owned)), "unused bottle can return to storage")
	print("SUPPORT EFFECTS: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
