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
	_test_defense_triggers()
	_test_board_mapping()
	_test_transfer_rules()
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
	_check(front_two.state.teams[0][0].hp == 100 and front_two.state.teams[0][1].hp == 96, "formation target receives damage after one defense")

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
	_check(battle.state.teams[1][0].hp == 70 and battle.state.teams[0][0].hp == 96, "swords cause 30; iron armor reduces claw to four")
	for member in battle.state.teams[0] + battle.state.teams[1]:
		_check(member.stamina == 95, "each attacker pays five stamina")
	_check(battle.state.teams[0][1].hp == 100 and battle.state.teams[0][2].hp == 100, "rear allies protected")
	var events := battle.drain_events().filter(func(e): return e["kind"] == "damage")
	_check(events.size() == 4 and events[0]["owner_id"] == GameManager.PARTY_IDS[0] and events[3]["owner_id"] == GameManager.ENEMY_ID, "stable same-time ownership order")
	battle.advance(100)
	_check(battle.state.result == "victory" and battle.state.finished_at_usec == 12_000_000, "default battle victory at twelve seconds")
	_check(battle.state.activation_counts == [10, 3] and battle.state.teams[0][0].hp == 88, "dead dog cannot retaliate at lethal timestamp")
	_check(battle.state.teams[0][0].stamina == 80 and battle.state.teams[1][0].stamina == 85, "only successful activations cost stamina")
	_check(battle.queue.size() == 0 and battle.activation_progress(GameManager.SWORD_INSTANCE) == 1, "finish clears queue and reveals equipment")
	battle.advance(100)
	_check(battle.state.time_usec == 12_000_000, "finished time frozen")
	var fallen := _fixture(3, 1000)
	fallen.state.teams[0][0].hp = 4
	fallen.start()
	fallen.advance(6)
	_check(fallen.state.teams[0][0].hp == 0 and fallen.state.teams[0][1].hp == 96, "dog switches to rear after front dies")
	_check(fallen.state.item_runtime[GameManager.SWORD_INSTANCE]["activation_count"] == 1, "fallen actor stops scheduled attacks")
	var lost := _fixture(1, 100, 4)
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
			_check(battle.state.damage_totals == [600, 80] and battle.state.result == "draw", "speed/fps invariant damage with iron armor and exhaustion")
			var events := battle.drain_events().filter(func(e): return e["kind"] == "damage")
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
	_check(control.drain_events().size() == 8 and control.drain_events().is_empty(), "damage and visual activation events drain once")
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
	_check(game.can_edit_inventory() and game.can_adjust(), "preparation permits direct array editing")
	_check(game.move_item(0, GameManager.SWORD_INSTANCE, Vector2i(3, 0)), "prebattle move without opening storage")
	_check(game.simulation.cooling_remaining_usec(GameManager.SWORD_INSTANCE) == 0, "direct prebattle move has no insertion cooldown")
	game.move_item(0, GameManager.SWORD_INSTANCE, Vector2i.ZERO)
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
	_check(game.simulation.cooling_remaining_usec(GameManager.sword_instance(1)) == 0, "battle move preserves rotation without insertion cooldown")
	_check(game.equip(sword_key, 1, Vector2i.ZERO), "paused battle equips new weapon")
	var due: int = game.simulation.state.item_runtime[sword_key]["next_activation_usec"]
	_check(due == 7_000_000, "one second insertion starts weapon at seven seconds")
	game.simulation.advance(10)
	_check(game.simulation.state.time_usec == 1_000_000, "pause freezes new cooldown")
	_check(game.move_item(1, sword_key, Vector2i.ZERO) and game.simulation.state.item_runtime[sword_key]["next_activation_usec"] == due, "same-cell placement preserves progress")
	game.toggle_pause()
	_check(not game.adjustment_open, "resume closes storage")
	game.simulation.advance(2)
	_check(game.simulation.state.item_runtime[GameManager.sword_instance(1)]["activation_count"] == 1, "moved weapon keeps its original three-second event")
	game.simulation.advance(3)
	_check(game.simulation.state.item_runtime[GameManager.sword_instance(1)]["activation_count"] == 2, "moving never changes regular rotation")
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
	var returned := member.inventory.take_returnable("test.pill")
	var stash := SharedStorage.new()
	stash.put(returned)
	_check(returned["units"].size() == 1 and member.inventory.get_instance("test.pill")["units"][0]["uses_left"] == 1, "return leaves opened bottle and takes only unopened bottle")
	_check(member.inventory.take_returnable("test.pill").is_empty(), "opened bottle cannot be returned")
	moved.advance(3)
	_check(member.spirit == 55 and member.inventory.get_instance("test.pill").is_empty(), "opened bottle completes and is consumed in place")
	var reentry := stash.take_one(returned["instance_id"])
	member.inventory.put(reentry, Vector2i(3, 0))
	moved.attach(member, 0, reentry["instance_id"], true)
	moved.advance(6)
	_check(member.inventory.get_instance(reentry["instance_id"])["units"][0]["uses_left"] == 1, "returned unopened bottle waits three seconds then rotates before first use")
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

func _test_transfer_rules() -> void:
	var game := GameManager.new()
	game._ready()
	game.enemies[0].hp = 10000
	game.start_battle()
	game.simulation.advance(1)
	game.toggle_pause()
	game.set_adjustment(true)
	var sim := game.simulation
	var sword := GameManager.SWORD_INSTANCE
	var armor := GameManager.ARMOR_INSTANCE
	var before: Dictionary = sim.state.item_runtime[sword].duplicate(true)
	_check(game.move_item(0, sword, Vector2i(3, 0)) and sim.state.item_runtime[sword] == before, "different-cell move preserves every runtime field")
	_check(game.move_item(0, armor, Vector2i(1, 2)) and game.party[0].defense == 1, "armor move retains defense without reentry")
	var inserted := "run.storage.base.weapon.qingfeng.0"
	_check(game.equip(inserted, 0, Vector2i.ZERO), "insert fresh sword at one second")
	_check(sim.cooling_remaining_usec(inserted) == 3_000_000, "default entry cooldown is three seconds")
	before = sim.state.item_runtime[inserted].duplicate(true)
	_check(game.move_item(0, inserted, Vector2i(0, 1)) and sim.state.item_runtime[inserted] == before, "moving cooling item neither resets nor bypasses deadline")
	game.toggle_pause()
	sim.advance(1)
	game.toggle_pause()
	game.set_adjustment(true)
	_check(sim.cooling_remaining_usec(inserted) == 2_000_000, "one second elapsed from entry cooldown")
	_check(game.unequip(0, inserted) and game.equip(inserted, 0, Vector2i.ZERO), "cooling item can return and reenter")
	_check(sim.cooling_remaining_usec(inserted) == 3_000_000 and sim.state.item_runtime[inserted]["next_activation_usec"] == 8_000_000, "return and reentry starts full three seconds again")
	game.toggle_pause()
	sim.advance(3)
	_check(sim.state.item_runtime[inserted]["entered"] and sim.state.item_runtime[inserted]["activation_count"] == 0, "stale entry and activation events cannot bypass replacement cooldown")
	game.toggle_pause()
	game.set_adjustment(true)
	_check(game.unequip(0, inserted) and game.equip(inserted, 0, Vector2i.ZERO) and sim.cooling_remaining_usec(inserted) == 3_000_000, "already entered item also restarts cooldown when reequipped")
	game.free()
	# Exercise the same public commands used by right-click and drag-to-storage.
	var medicine := _medicine_fixture("spirit", 50, 3)
	game = GameManager.new()
	game.registry = registry
	game.party.assign(medicine.state.teams[0])
	game.enemies.assign(medicine.state.teams[1])
	game.simulation = medicine
	medicine.start()
	medicine.advance(2)
	game.toggle_pause()
	game.set_adjustment(true)
	var pill := "test.pill"
	before = medicine.state.item_runtime[pill].duplicate(true)
	_check(game.unequip(0, pill, true), "unopened rotating bottle is returnable")
	_check(game.party[0].inventory.get_instance(pill)["units"].size() == 2 and game.storage.entries()[0]["units"].size() == 1, "right-click returns exactly one bottle")
	_check(medicine.state.item_runtime[pill] == before, "partial return retains original stack schedule")
	game.toggle_pause()
	medicine.advance(1)
	game.toggle_pause()
	game.set_adjustment(true)
	_check(game.unequip(0, pill) and game.party[0].inventory.get_instance(pill)["units"].size() == 1, "drag returns unopened remainder and leaves opened bottle")
	_check(not game.can_unequip(0, pill) and not game.unequip(0, pill, true) and not game.unequip(0, pill), "both return commands reject opened-only stack")
	_check(game.storage.entries()[0]["units"].size() == 2, "rejected return conserves bottle count")
	game.toggle_pause()
	medicine.advance(2)
	game.toggle_pause()
	game.set_adjustment(true)
	var storage_id: String = game.storage.entries()[0]["instance_id"]
	before = medicine.state.item_runtime[pill].duplicate(true)
	_check(game.equip(storage_id, 0, Vector2i.ZERO) and medicine.state.item_runtime[pill] == before, "top-up preserves opened bottle rotation")
	game.toggle_pause()
	medicine.advance(1)
	_check(game.party[0].inventory.get_instance(pill)["units"].size() == 1 and medicine.cooling_remaining_usec(pill) == 2_000_000, "newly topped-up bottle has its own admission cooldown")
	medicine.advance(4.999999)
	_check(game.party[0].inventory.get_instance(pill)["units"][0]["uses_left"] == 2, "new bottle cannot activate before admission plus rotation")
	medicine.advance(0.000001)
	_check(game.party[0].inventory.get_instance(pill)["units"][0]["uses_left"] == 1, "new bottle starts at exact admission plus rotation deadline")
	game.free()

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

func _test_defense_triggers() -> void:
	var sim := _fixture(1, 1000)
	var hero: PartyMemberState = sim.state.teams[0][0]
	hero.inventory.take(GameManager.ARMOR_INSTANCE)
	sim.detach(GameManager.ARMOR_INSTANCE)
	_add_armor(sim, 0, "base.armor.xuantie", "test.xuantie", Vector2i(0, 2))
	_add_armor(sim, 0, "base.armor.qinglin", "test.qinglin", Vector2i(2, 2))
	sim.start()
	_check(hero.defense == 7, "base plus entry defense sum by equipment source")
	var entry_events := sim.drain_events()
	_check(entry_events.size() == 1 and entry_events[0]["kind"] == "entered", "entry triggers once before attacks")
	sim.advance(3)
	_check(hero.hp == 100, "defense higher than damage reduces attack to zero")
	_check(sim.state.teams[1][0].hp == 989, "zero-damage hit still causes true counter")
	_check(hero.stamina == 95, "counter does not cost stamina")
	sim.detach("test.xuantie")
	hero.inventory.take("test.xuantie")
	_check(hero.defense == 3, "unequip removes both base and entry defense")
	_add_armor(sim, 0, "base.armor.xuantie", "test.xuantie", Vector2i(0, 2), true)
	_check(hero.defense == 3, "inserted armor inactive during three-second cooldown")
	sim.advance(1)
	sim.attach(hero, 0, "test.xuantie", true)
	sim.advance(1)
	_check(hero.defense == 3, "old entry event invalidated by reattaching armor")
	sim.clock.paused = true
	sim.advance(20)
	_check(hero.defense == 3, "paused entry cooldown does not advance")
	sim.clock.paused = false
	sim.advance(2)
	_check(hero.defense == 7, "delayed entry at exact expiry adds defense once")
	sim.advance(3)
	_check(hero.defense == 7, "passive armor has no rotation or repeated entry bonus")
	var duel := _fixture(1, 1000)
	var fighter: PartyMemberState = duel.state.teams[0][0]
	fighter.inventory.take(GameManager.ARMOR_INSTANCE)
	duel.detach(GameManager.ARMOR_INSTANCE)
	_add_armor(duel, 0, "base.armor.qinglin", "ally.counter", Vector2i(1, 1))
	_add_armor(duel, 1, "base.armor.qinglin", "enemy.counter", Vector2i(2, 2))
	duel.start()
	duel.advance(3)
	var reactions := duel.drain_events().filter(func(event): return event["kind"] == "counter_damage")
	_check(reactions.size() == 2, "one counter per normal attack; no counter chain")
	_check(fighter.hp == 97 and duel.state.teams[1][0].hp == 992, "counters ignore both sides' three defense")
	_check(reactions[0]["blocked"] == 0 and reactions[1]["blocked"] == 0, "counter bypass recorded explicitly")
	var lethal := _fixture(1, 1000)
	var fragile: PartyMemberState = lethal.state.teams[0][0]
	fragile.inventory.take(GameManager.ARMOR_INSTANCE)
	lethal.detach(GameManager.ARMOR_INSTANCE)
	_add_armor(lethal, 0, "base.armor.qinglin", "lethal.armor", Vector2i(1, 1))
	fragile.hp = 2
	lethal.start()
	lethal.advance(3)
	_check(lethal.state.result == "defeat" and lethal.drain_events().filter(func(e): return e["kind"] == "counter_damage").is_empty(), "lethal hit does not counterattack")
	var finish := _fixture(1, 1)
	var retaliator: PartyMemberState = finish.state.teams[0][0]
	retaliator.inventory.take(GameManager.ARMOR_INSTANCE)
	finish.detach(GameManager.ARMOR_INSTANCE)
	_add_armor(finish, 0, "base.armor.qinglin", "final.armor", Vector2i(1, 1))
	retaliator.stamina = 0
	finish.start()
	finish.advance(3)
	_check(finish.state.result == "victory" and finish.state.finished_at_usec == 3_000_000, "counter can kill attacker and end battle deterministically")
	var cold := _fixture(1, 1000)
	var cold_owner: PartyMemberState = cold.state.teams[0][0]
	cold_owner.inventory.take(GameManager.ARMOR_INSTANCE)
	cold.detach(GameManager.ARMOR_INSTANCE)
	cold.start()
	cold.advance(2)
	_add_armor(cold, 0, "base.armor.qinglin", "cold.armor", Vector2i(1, 1), true)
	cold.advance(1)
	_check(cold_owner.hp == 95 and cold.state.teams[1][0].hp == 990, "cooling armor neither defends nor counters")
	cold.advance(3)
	_check(cold_owner.hp == 93 and cold.state.teams[1][0].hp == 979, "entered armor defends and counters on next hit")
	var exact := _fixture(1, 1000)
	var exact_owner: PartyMemberState = exact.state.teams[0][0]
	exact_owner.inventory.take(GameManager.ARMOR_INSTANCE)
	exact.detach(GameManager.ARMOR_INSTANCE)
	exact.start()
	_add_armor(exact, 0, "base.armor.xuantie", "exact.armor", Vector2i(1, 1), true)
	exact.advance(3)
	_check(exact_owner.defense == 4 and exact_owner.hp == 99, "cooldown expiry enters before same-timestamp normal attack")
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/xuantie.json"))
	raw["cooldown"] = 3
	_check(not ContentRegistry.new().register_item(raw), "entry-only item rejects nonzero rotation")
	raw["cooldown"] = 0
	raw["effects"][0]["trigger"] = "on_attacked"
	_check(not ContentRegistry.new().register_item(raw), "invalid trigger/effect combination rejected")

func _add_armor(sim: BattleSimulation, side: int, item_id: String, id: String, cell: Vector2i, cooling: bool = false) -> void:
	var member: PartyMemberState = sim.state.teams[side][0]
	_check(member.inventory.add_item(id, item_id, cell), "armor fixture fits without collision")
	sim.attach(member, side, id, cooling)

func _test_board_mapping() -> void:
	for id in ["base.board.frost", "base.board.roots", "base.board.leather"]:
		var layout := registry.get_board(id)
		_check(layout != null, "board configuration registered")
		for dimensions in [Vector2(548, 548), Vector2(255, 255), Vector2(720, 540)]:
			for y in 4:
				for x in 4:
					var cell := Vector2i(x, y)
					var rect := layout.footprint_rect(cell, Vector2i.ONE, dimensions)
					_check(layout.cell_at(rect.get_center(), dimensions) == cell, "mapped cell center hit tests at all display sizes")
			_check(layout.cell_at(Vector2.ZERO, dimensions) == Vector2i(-100, -100), "decorative border is not inventory space")
			var all := layout.footprint_rect(Vector2i.ZERO, Vector2i(4, 4), dimensions)
			_check(layout.cell_at(all.end, dimensions) == Vector2i(-100, -100), "outside edge is excluded")
	var raw := {"id": "test.board.wide", "name": "宽图", "texture": "", "source_size": [2000, 1000], "x_lines": [400, 650, 1000, 1200, 1700], "y_lines": [100, 300, 500, 700, 900]}
	_check(BoardLayout.validate(raw), "non-square source with nonuniform grid is valid")
	var wide := BoardLayout.new(raw)
	var rect := wide.footprint_rect(Vector2i(1, 2), Vector2i(2, 1), Vector2(600, 600))
	_check(rect.position.is_equal_approx(Vector2(195, 300)) and rect.size.is_equal_approx(Vector2(165, 60)), "source coordinates scale and letterbox together")
	raw["x_lines"][2] = 600
	_check(not BoardLayout.validate(raw), "crossing grid lines rejected")

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + description)
