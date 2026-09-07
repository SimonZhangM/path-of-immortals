extends SceneTree

var failures: int = 0
var checks: int = 0
var registry := ContentRegistry.new()

func _initialize() -> void:
	_check(registry.load_base_content(), "base content loads")
	if not registry.errors.is_empty():
		printerr(registry.errors)
		quit(1)
		return
	_test_queue()
	_test_content()
	_test_inventory()
	_test_formation()
	_test_battle()
	_test_timing()
	_test_storage_and_medicine()
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _fixture(count: int = 3, enemy_hp: int = 100, ally_hp: int = 100, stamina: int = 100) -> BattleSimulation:
	var allies: Array = []
	for index in count:
		var raw := registry.get_character(GameManager.PARTY_IDS[index])
		raw["max_hp"] = ally_hp
		raw["max_stamina"] = stamina
		var member := PartyMemberState.new(raw, registry)
		member.inventory.add_item(GameManager.sword_instance(index), GameManager.ITEM_ID, Vector2i.ZERO)
		member.inventory.add_item(GameManager.armor_instance(index), GameManager.ARMOR_ID, Vector2i(1, 1))
		allies.append(member)
	var dog_raw := registry.get_enemy(GameManager.ENEMY_ID)
	dog_raw["max_hp"] = enemy_hp
	dog_raw["max_stamina"] = stamina
	var dog := PartyMemberState.new(dog_raw, registry)
	dog.inventory.add_item(GameManager.CLAW_INSTANCE, GameManager.CLAW_ID, Vector2i(1, 1))
	return BattleSimulation.new(allies, [dog], registry)

func _test_queue() -> void:
	var queue := EventQueue.new()
	for index in range(100):
		queue.schedule((99 - index) % 7, "test", {"index": index})
	var last_time := -1
	var last_sequence := -1
	while queue.size() > 0:
		var event := queue.pop_next()
		_check(int(event["due_usec"]) >= last_time, "heap chronological order")
		if int(event["due_usec"]) == last_time:
			_check(int(event["sequence"]) > last_sequence, "stable same-time order")
		last_time = event["due_usec"]
		last_sequence = event["sequence"]
	_check(queue.pop_next().is_empty(), "empty queue safe")

func _test_content() -> void:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/test_fire_sword.json"))
	for value in [0, -1, "three", null, INF]:
		var changed := raw.duplicate(true)
		changed["cooldown"] = value
		_check(not ContentRegistry.new().register_item(changed), "reject invalid cooldown")
	for value in [-1, 1.5, "5", INF, null]:
		var changed := raw.duplicate(true)
		changed["stamina_cost"] = value
		_check(not ContentRegistry.new().register_item(changed), "reject invalid stamina cost")
	for effect in [{"trigger": "unknown", "effect": "damage", "value": 10}, {"trigger": "on_activate", "effect": "damage", "value": 1.5}]:
		var changed := raw.duplicate(true)
		changed["effects"] = [effect]
		_check(not ContentRegistry.new().register_item(changed), "reject invalid effect")
	var registration := ContentRegistry.new()
	_check(registration.register_item(raw) and not registration.register_item(raw), "duplicate content ID rejected")
	_check(registry.get_item("missing.item.id") == null, "unknown item absent")
	var dog := registry.get_enemy(GameManager.ENEMY_ID)
	_check(dog["max_hp"] == 100 and dog["max_stamina"] == 100 and dog["max_spirit"] == 0, "dog resources include zero spirit")
	dog["max_spirit"] = -1
	_check(not ContentRegistry.new().register_enemy(dog), "negative enemy resource rejected")
	_check(registry.get_enemy(GameManager.ENEMY_ID)["max_spirit"] == 0, "definition reads isolated")
	var hero := registry.get_character(GameManager.PARTY_IDS[0])
	hero["max_stamina"] = 0
	hero["max_spirit"] = 0
	_check(ContentRegistry.new().register_character(hero), "zero stamina and spirit allowed")
	hero["max_hp"] = 0
	_check(not ContentRegistry.new().register_character(hero), "zero max HP rejected")

func _test_inventory() -> void:
	var bag := InventoryState.new(registry)
	_check(bag.add_item("sword", GameManager.ITEM_ID, Vector2i.ZERO), "sword 1x2")
	_check(bag.add_item("armor", GameManager.ARMOR_ID, Vector2i(1, 1)), "armor 2x2")
	_check(bag.occupied_cells() == 6 and bag.item_at(Vector2i(0, 1)) == "sword", "footprint occupancy")
	_check(not bag.add_item("sword", GameManager.ITEM_ID, Vector2i(3, 0)), "duplicate instance rejected")
	for cell in [Vector2i(1, 1), Vector2i(-1, 0), Vector2i(0, 3)]:
		_check(not bag.move_item("sword", cell), "overlap and overflow rejected")
	_check(not bag.move_item("armor", Vector2i(3, 0)), "armor overflow rejected")
	_check(bag.move_item("sword", Vector2i(0, 1)), "overlap with own footprint allowed")
	_check(bag.move_item("sword", Vector2i(3, 2)) and bag.move_item("armor", Vector2i(0, 2)), "legal bottom corner positions")
	bag.locked = true
	_check(not bag.move_item("sword", Vector2i.ZERO) and not bag.add_item("another", GameManager.ITEM_ID, Vector2i.ZERO), "locked inventory immutable")
	bag.locked = false
	_check(bag.add_item("another", GameManager.ITEM_ID, Vector2i.ZERO), "separate instances share definition")
	var copy := bag.get_instance("sword")
	copy["cell"] = Vector2i.ZERO
	_check(bag.get_instance("sword")["cell"] == Vector2i(3, 2), "instance reads isolated")
	var armor: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/iron_armor.json"))
	for footprint in [null, [], [1], [0, 2], [2.5, 2], [5, 2], ["2", 2]]:
		var changed := armor.duplicate(true)
		changed["size"] = footprint
		_check(not ContentRegistry.new().register_item(changed), "invalid dimensions rejected")
	armor["cooldown"] = 3
	_check(not ContentRegistry.new().register_item(armor), "passive armor has no cooldown")

func _test_formation() -> void:
	_check(FormationRules.rows(1)["single"] == [0], "single actor unranked")
	_check(FormationRules.rows(2)["front"] == [0] and FormationRules.rows(2, FormationRules.Kind.FRONT_TWO)["rear"] == [1], "two actors have one formation")
	_check(FormationRules.target_order(3) == [0, 1, 2], "front one target order")
	_check(FormationRules.target_order(3, FormationRules.Kind.FRONT_TWO) == [1, 2, 0], "front two target order")
	var battle := _fixture()
	_check(battle.state.target_for(1) == battle.state.teams[0][0], "dog targets front hero")
	battle.state.formations[0] = FormationRules.Kind.FRONT_TWO
	_check(battle.state.target_for(1) == battle.state.teams[0][1], "front two chooses upper member")
	battle.state.teams[0][1].hp = 0
	_check(battle.state.target_for(1) == battle.state.teams[0][2], "remaining front actor first")
	battle.state.teams[0][2].hp = 0
	_check(battle.state.target_for(1) == battle.state.teams[0][0], "rear exposed after front eliminated")
	_check(battle.state.target_for(0) == battle.state.teams[1][0], "unranked sole enemy target")
	var front_two := _fixture()
	front_two.state.formations[0] = FormationRules.Kind.FRONT_TWO
	front_two.start()
	front_two.advance(3)
	_check(front_two.state.teams[0][0].hp == 100 and front_two.state.teams[0][1].hp == 95, "formation affects actual damage target")

func _test_battle() -> void:
	var battle := _fixture()
	battle.advance(60)
	_check(battle.state.time_usec == 0 and battle.queue.size() == 0, "preparation frozen")
	_check(battle.start() and not battle.start() and battle.queue.size() == 4, "four active weapons scheduled once")
	battle.advance(1.5)
	_check(battle.activation_progress(GameManager.SWORD_INSTANCE) == 0.5 and battle.activation_progress(GameManager.CLAW_INSTANCE) == 0.5, "both sides reveal independently")
	battle.clock.paused = true
	battle.advance(50)
	_check(battle.state.time_usec == 1_500_000 and battle.activation_progress(GameManager.CLAW_INSTANCE) == 0.5, "pause freezes both sides")
	battle.clock.paused = false
	battle.advance(1.499999)
	_check(battle.state.teams[1][0].hp == 100, "no early attack")
	battle.advance(0.000001)
	_check(battle.state.teams[1][0].hp == 70 and battle.state.teams[0][0].hp == 95, "swords and claw cause 30 and 5 damage")
	for member in battle.state.teams[0] + battle.state.teams[1]:
		_check(member.stamina == 95, "each attacker pays five stamina")
	_check(battle.state.teams[0][1].hp == 100 and battle.state.teams[0][2].hp == 100, "rear allies protected")
	var events := battle.drain_events()
	_check(events.size() == 4 and events[0]["owner_id"] == GameManager.PARTY_IDS[0] and events[3]["owner_id"] == GameManager.ENEMY_ID, "stable same-time ownership order")
	battle.advance(100)
	_check(battle.state.result == "victory" and battle.state.finished_at_usec == 12_000_000, "default battle victory at twelve seconds")
	_check(battle.state.activation_counts == [10, 3] and battle.state.teams[0][0].hp == 85, "dead dog cannot retaliate at lethal timestamp")
	_check(battle.state.teams[0][0].stamina == 80 and battle.state.teams[1][0].stamina == 85, "only successful activations cost stamina")
	_check(battle.queue.size() == 0 and battle.activation_progress(GameManager.SWORD_INSTANCE) == 1, "finish clears queue and reveals equipment")
	battle.advance(100)
	_check(battle.state.time_usec == 12_000_000, "finished time frozen")
	var fallen := _fixture(3, 1000)
	fallen.state.teams[0][0].hp = 5
	fallen.start()
	fallen.advance(6)
	_check(fallen.state.teams[0][0].hp == 0 and fallen.state.teams[0][1].hp == 95, "dog switches to rear after front dies")
	_check(fallen.state.item_runtime[GameManager.SWORD_INSTANCE]["activation_count"] == 1, "fallen actor stops scheduled attacks")
	var lost := _fixture(1, 100, 5)
	lost.start()
	lost.advance(60)
	_check(lost.state.result == "defeat" and lost.state.time_usec == 3_000_000, "all allies dead is defeat")
	for stamina in [0, 4, 5]:
		var exhausted := _fixture(1, 1000, 1000, stamina)
		exhausted.start()
		exhausted.advance(60)
		_check(exhausted.state.result == "draw", "both sides unable to attack is draw")
		_check(exhausted.state.activation_counts == ([1, 1] if stamina == 5 else [0, 0]), "exactly five permits one attack; below five none")
		_check(exhausted.state.time_usec == (3_000_000 if stamina == 5 else 0), "draw freezes at exhaustion time")
	var one_sided := _fixture(1, 20)
	one_sided.state.teams[1][0].stamina = 0
	one_sided.start()
	one_sided.advance(60)
	_check(one_sided.state.result == "victory" and one_sided.state.activation_counts == [2, 0], "one side exhausted does not end the other's attacks")
	var overkill := _fixture(1, 3)
	overkill.start()
	overkill.advance(3)
	_check(overkill.state.damage_totals[0] == 3 and overkill.state.teams[0][0].stamina == 95, "overkill clamps damage and charges one activation")
	var passive := _fixture(1)
	for team in passive.state.teams:
		team[0].inventory = InventoryState.new(registry)
		team[0].inventory.add_item("armor." + team[0].id, GameManager.ARMOR_ID, Vector2i.ZERO)
	passive = BattleSimulation.new(passive.state.teams[0], passive.state.teams[1], registry)
	passive.start()
	_check(passive.state.result == "draw" and passive.queue.size() == 0, "no active weapons ends safely")

func _test_timing() -> void:
	for speed in SimulationClock.SPEEDS:
		for fps in [30, 60, 144]:
			var battle := _fixture(3, 1000, 1000)
			battle.start()
			battle.clock.set_speed(speed)
			for frame in range(int(60 * fps / speed)):
				battle.advance(1.0 / fps)
			_check(battle.state.time_usec == 60_000_000 and battle.state.activation_counts == [60, 20], "speed/fps invariant attack counts and time")
			_check(battle.state.damage_totals == [600, 100] and battle.state.result == "draw", "speed/fps invariant damage and exhaustion")
			var events := battle.drain_events()
			for index in 80:
				_check(events[index]["at_usec"] == (index / 4 + 1) * 3_000_000 and events[index]["side"] == (1 if index % 4 == 3 else 0), "exact deterministic timestamps for both teams")
	var partitioned := _fixture(3, 1000, 1000)
	partitioned.start()
	for delta in [0.01, 0.99, 8.2, 0.001, 20.0, 30.799]:
		partitioned.advance(delta)
	_check(partitioned.state.activation_counts == [60, 20] and partitioned.state.time_usec == 60_000_000, "uneven long frames catch up")
	var control := _fixture()
	control.start()
	control.clock.set_speed(2)
	control.clock.set_speed(3)
	control.advance(-1)
	control.advance(NAN)
	_check(control.state.time_usec == 0 and control.clock.speed_multiplier == 2, "invalid delta and unsupported speed ignored")
	control.advance(1.5)
	_check(control.state.time_usec == 3_000_000, "double speed clock")
	_check(control.drain_events().size() == 4 and control.drain_events().is_empty(), "events drain once")
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/test_fire_sword.json"))
	raw["id"] = "test.weapon.fast"
	raw["cooldown"] = 2
	_check(registry.register_item(raw), "second cooldown definition accepted")
	var template := _fixture(1, 1000, 1000)
	template.state.teams[0][0].inventory.add_item("run.fast", "test.weapon.fast", Vector2i(3, 0))
	var mixed := BattleSimulation.new(template.state.teams[0], template.state.teams[1], registry)
	mixed.start()
	mixed.advance(1.5)
	_check(mixed.activation_progress(GameManager.SWORD_INSTANCE) == 0.5 and mixed.activation_progress("run.fast") == 0.75, "different weapon cooldowns remain independent")
	mixed.advance(4.5)
	_check(mixed.state.item_runtime[GameManager.SWORD_INSTANCE]["activation_count"] == 2 and mixed.state.item_runtime["run.fast"]["activation_count"] == 3, "independent schedules on one owner")
	_check(mixed.state.teams[0][0].stamina == 75, "same-owner weapons share authoritative stamina")

func _test_storage_and_medicine() -> void:
	var game := GameManager.new()
	game._ready()
	_check(game.storage.entries().size() == 7, "four new equipment definitions and three pill stacks")
	_check(not game.can_edit_inventory() and game.can_adjust(), "preparation requires opening adjustment")
	game.set_adjustment(true)
	var pill_key := "run.storage.base.pill.huichun.0"
	var sword_key := "run.storage.base.weapon.qingfeng.0"
	_check(game.storage.get_entry(pill_key)["units"].size() == 10, "ten bottles in storage")
	_check(game.equip(pill_key, 0, Vector2i(3, 0)), "equip first medicine")
	var bag := game.party[0].inventory
	var pill_id := bag.matching_stack("base.pill.huichun")
	for index in 3:
		_check(game.equip_random(pill_key), "right click appends same medicine")
	_check(bag.get_instance(pill_id)["units"].size() == 4 and game.storage.get_entry(pill_key)["units"].size() == 6, "stack transfer conserves bottle total")
	_check(game.simulation.cooling_remaining_usec(pill_id) == 0, "prebattle medicine has no insertion cooldown")
	_check(game.equip(sword_key, 1, Vector2i(3, 0)), "any ally equips storage weapon")
	_check(game.storage.get_entry(sword_key).is_empty(), "equipped weapon absent from storage")
	_check(not game.equip("missing", 0, Vector2i.ZERO), "unknown storage id rejected")
	_check(not game.equip("run.storage.base.armor.qinglin.0", 0, Vector2i.ZERO), "occupied destination rejected")
	_check(game.storage.get_entry("run.storage.base.armor.qinglin.0")["units"].size() == 1, "failed placement keeps item")
	_check(game.unequip(1, sword_key), "equipment can return to storage")
	game.start_battle()
	_check(not game.can_adjust() and not game.set_adjustment(true), "running battle locks adjustment")
	game.simulation.advance(1)
	game.toggle_pause()
	game.set_adjustment(true)
	_check(game.move_item(1, GameManager.sword_instance(1), Vector2i(3, 0)), "paused adjustment moves equipment")
	_check(game.simulation.cooling_remaining_usec(GameManager.sword_instance(1)) == 2_000_000, "battle move adds two-second cooldown")
	_check(game.equip(sword_key, 1, Vector2i.ZERO), "paused battle equips new weapon")
	var due: int = game.simulation.state.item_runtime[sword_key]["next_activation_usec"]
	_check(due == 6_000_000, "one second insertion starts weapon at six seconds")
	game.simulation.advance(10)
	_check(game.simulation.state.time_usec == 1_000_000, "pause freezes new cooldown")
	_check(game.move_item(1, sword_key, Vector2i.ZERO) and game.simulation.state.item_runtime[sword_key]["next_activation_usec"] == due, "same-cell placement preserves progress")
	game.toggle_pause()
	_check(not game.adjustment_open, "resume closes storage")
	game.simulation.advance(2)
	_check(game.simulation.state.item_runtime[GameManager.sword_instance(1)]["activation_count"] == 0, "old three-second event invalidated")
	game.simulation.advance(3)
	_check(game.simulation.state.item_runtime[GameManager.sword_instance(1)]["activation_count"] == 1, "moved weapon activates after cooldown plus rotation")
	game.free()
	for resource in ["hp", "spirit", "stamina"]:
		for speed in [0.5, 1.0, 2.0]:
			var sim := _medicine_fixture(resource, 50, 2)
			var hero: PartyMemberState = sim.state.teams[0][0]
			sim.clock.set_speed(speed)
			sim.start()
			for frame in 3 * 60:
				sim.advance(1.0 / (60.0 * speed))
			_check(hero.get(resource) == 50, "restoration starts after rotation: " + resource)
			_check(hero.inventory.get_instance("test.pill")["units"][0]["uses_left"] == 1, "first use leaves one charge")
			sim.advance(3.0 / speed)
			_check(hero.get(resource) == 55, "three-second effect restores exact five: " + resource)
			_check(hero.inventory.get_instance("test.pill")["units"].size() == 1, "second use consumes one bottle")
			sim.advance(3.0 / speed)
			_check(hero.get(resource) == 60, "both uses restore ten total")
			_check(hero.inventory.get_instance("test.pill")["units"][0]["uses_left"] == 1, "next bottle continues regular rotation without insertion cooldown")
	var full := _medicine_fixture("spirit", 100, 2)
	full.start()
	full.advance(6)
	_check(full.state.teams[0][0].inventory.get_instance("test.pill")["units"][0]["uses_left"] == 2, "full resource never opens bottle")
	var nearly := _medicine_fixture("spirit", 99, 2)
	nearly.start()
	nearly.advance(12)
	var entry: Dictionary = nearly.state.teams[0][0].inventory.get_instance("test.pill")
	_check(nearly.state.teams[0][0].spirit == 100, "restoration cannot exceed maximum")
	_check(entry["units"].size() == 1 and entry["units"][0]["uses_left"] == 2, "opened bottle finishes even at full; next bottle waits")
	var moved := _medicine_fixture("spirit", 50, 2)
	moved.start()
	moved.advance(3)
	var member: PartyMemberState = moved.state.teams[0][0]
	var returned := member.inventory.take("test.pill")
	moved.detach("test.pill")
	var stash := SharedStorage.new()
	stash.put(returned)
	_check(stash.peek_one("test.pill")["units"][0]["uses_left"] == 1, "return retains opened bottle charge")
	moved.advance(3)
	_check(member.spirit == 55, "already activated restoration survives item removal")
	var reentry := stash.take_one("test.pill")
	member.inventory.put(reentry, Vector2i(3, 0))
	moved.attach(member, 0, reentry["instance_id"], true)
	moved.advance(5)
	_check(member.inventory.get_instance(reentry["instance_id"]).is_empty(), "reinserted partial bottle consumes on its final use")
	var revive := _medicine_fixture("stamina", 0, 1)
	var tired: PartyMemberState = revive.state.teams[0][0]
	tired.inventory.add_item("tired.sword", GameManager.ITEM_ID, Vector2i.ZERO)
	revive.attach(tired, 0, "tired.sword", false)
	revive.start()
	revive.advance(9)
	_check(revive.state.activation_counts[0] > 0, "stamina restoration wakes exhausted weapon without premature draw")
	var invalid: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/huichun.json"))
	invalid["effects"][0]["resource"] = "mana"
	_check(not ContentRegistry.new().register_item(invalid), "unsupported restoration resource rejected")

func _medicine_fixture(resource: String, initial: int, bottles: int) -> BattleSimulation:
	var sim := _fixture(1, 10000)
	var hero: PartyMemberState = sim.state.teams[0][0]
	hero.inventory.take(GameManager.SWORD_INSTANCE)
	sim.detach(GameManager.SWORD_INSTANCE)
	hero.set(resource, initial)
	var item_id: String = {"hp": "base.pill.huichun", "spirit": "base.pill.yunling", "stamina": "base.pill.yiqi"}[resource]
	var units: Array = []
	for index in bottles:
		units.append({"id": "test.unit.%d" % index, "uses_left": 2})
	hero.inventory.put({"instance_id": "test.pill", "item_id": item_id, "units": units}, Vector2i(3, 0))
	sim.attach(hero, 0, "test.pill", false)
	# Enemy keeps a future offensive event so full-resource fixtures do not end immediately.
	sim._definitions[GameManager.CLAW_INSTANCE] = ItemData.new({"id": GameManager.CLAW_ID, "name": "测试爪", "type": "weapon", "tags": [], "size": [1, 2], "cooldown": 1000, "effects": [{"trigger": "on_activate", "effect": "damage", "value": 5}]})
	sim.state.item_runtime[GameManager.CLAW_INSTANCE]["ready_at_usec"] = 1_000_000_000
	return sim

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + description)
