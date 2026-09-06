extends SceneTree

var failures: int = 0
var checks: int = 0
var registry := ContentRegistry.new()

func _initialize() -> void:
	_check(registry.load_base_content(), "base JSON loads and validates")
	if not registry.errors.is_empty():
		for error in registry.errors:
			printerr(error)
		quit(1)
		return
	_test_queue()
	_test_content()
	_test_timing()
	_test_controls()
	_test_inventory()
	_test_preparation()
	_test_party()
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _new_battle(hp: int = 100) -> BattleSimulation:
	var enemy := registry.get_enemy("base.test.dummy")
	enemy["max_hp"] = hp
	var battle := BattleSimulation.new(registry.get_item("base.test.fire_sword"), enemy)
	battle.start()
	return battle

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + description)

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
			_check(int(event["sequence"]) > last_sequence, "heap stable tie order")
		last_time = event["due_usec"]
		last_sequence = event["sequence"]
	_check(queue.pop_next().is_empty(), "empty queue is safe")

func _test_content() -> void:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/test_fire_sword.json"))
	for invalid_value in [0, -1, "three", null, INF]:
		var changed := raw.duplicate(true)
		changed["cooldown"] = invalid_value
		_check(not ContentRegistry.new().register_item(changed), "reject invalid cooldown")
	var unknown := raw.duplicate(true)
	unknown["effects"][0]["effect"] = "not_implemented"
	_check(not ContentRegistry.new().register_item(unknown), "reject unknown effects")
	var invalid_damage := raw.duplicate(true)
	invalid_damage["effects"][0]["value"] = 1.5
	_check(not ContentRegistry.new().register_item(invalid_damage), "reject fractional damage")
	var duplicate_registry := ContentRegistry.new()
	_check(duplicate_registry.register_item(raw), "first registration accepted")
	_check(not duplicate_registry.register_item(raw), "duplicate stable ID rejected")
	_check(not ContentRegistry.new().register_enemy({"id": "base.test.bad", "name": "Bad", "max_hp": 0}), "invalid enemy rejected")
	_check(registry.get_item("missing.item.id") == null, "missing item returns null")
	_check(registry.get_enemy("missing.enemy.id").is_empty(), "missing enemy returns empty")
	var copy := registry.get_enemy("base.test.dummy")
	copy["max_hp"] = 1
	_check(int(registry.get_enemy("base.test.dummy")["max_hp"]) == 100, "enemy definition isolated from instance")

func _test_timing() -> void:
	for speed in SimulationClock.SPEEDS:
		for fps in [30, 60, 144]:
			var battle := _new_battle(10000)
			battle.clock.set_speed(speed)
			for frame in range(int(60 * fps / speed)):
				battle.advance(1.0 / fps)
			_check(battle.state.time_usec == 60_000_000, "%sx @%dfps time" % [str(speed), fps])
			_check(battle.state.activation_count == 20, "%sx @%dfps 20 attacks in 60s" % [str(speed), fps])
			_check(battle.state.enemy_hp == 9800, "same damage across speed and frame rate")
			var events := battle.drain_events()
			_check(events.size() == 20, "all presentation events delivered")
			for index in events.size():
				_check(int(events[index]["at_usec"]) == (index + 1) * 3_000_000, "exact attack timestamp")
		var dummy := _new_battle()
		dummy.clock.set_speed(speed)
		dummy.advance(60.0 / speed)
		_check(dummy.state.activation_count == 10 and dummy.state.enemy_hp == 0, "100HP dummy stops after ten hits")
		_check(dummy.state.defeated_at_usec == 30_000_000, "death is at 30 game seconds")
		_check(dummy.queue.size() == 0, "dead target has no queued attacks")
		dummy.advance(100)
		_check(dummy.state.damage_total == 100 and dummy.state.activation_count == 10, "no postmortem damage")
	var boundary := _new_battle()
	boundary.advance(2.999999)
	_check(boundary.state.enemy_hp == 100, "no early hit")
	boundary.advance(0.000001)
	_check(boundary.state.enemy_hp == 90, "inclusive due-time boundary")
	boundary.advance(3)
	_check(boundary.state.enemy_hp == 80, "second hit at 6 seconds")
	var long_frame := _new_battle(10000)
	long_frame.advance(60)
	_check(long_frame.state.activation_count == 20, "long frames catch up without dropping events")
	var uneven := _new_battle(10000)
	for delta in [0.01, 0.99, 8.2, 0.001, 20.0, 30.799]:
		uneven.advance(delta)
	_check(uneven.state.time_usec == 60_000_000 and uneven.state.activation_count == 20, "uneven frame partition is deterministic")
	var overkill := _new_battle(15)
	overkill.advance(60)
	_check(overkill.state.enemy_hp == 0 and overkill.state.damage_total == 15 and overkill.state.activation_count == 2, "overkill clamps actual damage and HP")

func _test_controls() -> void:
	var battle := _new_battle()
	battle.advance(1)
	battle.clock.paused = true
	battle.advance(100)
	_check(battle.state.time_usec == 1_000_000 and battle.state.activation_count == 0, "pause freezes simulation")
	battle.clock.set_speed(2)
	battle.advance(10)
	_check(battle.state.time_usec == 1_000_000, "speed change while paused stays paused")
	battle.clock.paused = false
	battle.advance(1.0)
	_check(battle.state.time_usec == 3_000_000 and battle.state.enemy_hp == 90, "resume at new speed preserves cooldown")
	battle.clock.set_speed(3)
	_check(battle.clock.speed_multiplier == 2, "unsupported speed ignored")
	battle.advance(-1)
	battle.advance(NAN)
	_check(battle.state.time_usec == 3_000_000, "invalid deltas ignored")
	_check(battle.drain_events().size() == 1 and battle.drain_events().is_empty(), "presentation events drained once")
	var fresh := _new_battle()
	_check(fresh.state.enemy_hp == 100 and fresh.state.time_usec == 0 and fresh.clock.speed_multiplier == 1 and not fresh.clock.paused, "fresh run resets state")

func _test_inventory() -> void:
	var bag := InventoryState.new(registry)
	_check(bag.add_item("sword", GameManager.ITEM_ID, Vector2i.ZERO), "add sword 1x2")
	_check(bag.add_item("armor", GameManager.ARMOR_ID, Vector2i(1, 1)), "add armor 2x2")
	_check(bag.occupied_cells() == 6, "six of sixteen cells occupied")
	_check(bag.item_at(Vector2i(0, 1)) == "sword" and bag.item_at(Vector2i(2, 2)) == "armor", "all footprint cells identify their item")
	_check(not bag.add_item("sword", GameManager.ITEM_ID, Vector2i(3, 0)), "duplicate instance rejected")
	_check(not bag.move_item("sword", Vector2i(1, 1)), "overlap rejected")
	_check(not bag.move_item("sword", Vector2i(-1, 0)), "negative cell rejected")
	_check(not bag.move_item("sword", Vector2i(0, 3)), "sword bottom overflow rejected")
	_check(not bag.move_item("armor", Vector2i(3, 0)), "armor right overflow rejected")
	_check(bag.get_instance("sword")["cell"] == Vector2i.ZERO, "invalid moves preserve original position")
	_check(bag.move_item("sword", Vector2i(0, 1)), "movement overlapping its own old footprint accepted")
	_check(bag.move_item("sword", Vector2i(3, 2)), "sword fits bottom-right edge")
	_check(bag.move_item("armor", Vector2i(0, 2)), "armor fits bottom-left edge")
	_check(not bag.move_item("unknown", Vector2i.ZERO), "unknown instance rejected")
	bag.locked = true
	_check(not bag.move_item("sword", Vector2i.ZERO), "locked backpack rejects move")
	_check(not bag.add_item("second", GameManager.ITEM_ID, Vector2i.ZERO), "locked backpack rejects addition")
	bag.locked = false
	_check(bag.add_item("second", GameManager.ITEM_ID, Vector2i.ZERO), "same definition supports distinct layout instances")
	var copy := bag.get_instance("sword")
	copy["cell"] = Vector2i.ZERO
	_check(bag.get_instance("sword")["cell"] == Vector2i(3, 2), "instance reads do not mutate authoritative layout")
	var armor_raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/iron_armor.json"))
	_check(ContentRegistry.new().register_item(armor_raw), "passive armor definition accepted")
	for invalid_size in [null, [], [1], [1, 2, 3], [0, 2], [2.5, 2], [5, 2], ["2", 2], [-1, 2]]:
		var changed := armor_raw.duplicate(true)
		changed["size"] = invalid_size
		_check(not ContentRegistry.new().register_item(changed), "invalid footprint rejected")
	armor_raw["cooldown"] = 3
	_check(not ContentRegistry.new().register_item(armor_raw), "passive item cannot schedule a cooldown")

func _test_preparation() -> void:
	var battle := BattleSimulation.new(registry.get_item(GameManager.ITEM_ID), registry.get_enemy(GameManager.ENEMY_ID))
	battle.advance(60)
	_check(battle.state.phase == GameState.Phase.PREPARATION and battle.state.time_usec == 0 and battle.queue.size() == 0, "preparation never advances or schedules attacks")
	_check(battle.start(), "explicit start begins battle")
	_check(not battle.start() and battle.queue.size() == 1, "double start cannot duplicate schedule")
	battle.advance(60)
	_check(battle.state.phase == GameState.Phase.FINISHED and battle.state.time_usec == 30_000_000, "completion freezes at exact defeat time")
	battle.advance(10)
	_check(battle.state.time_usec == 30_000_000, "finished battle remains frozen")
	var armor := BattleSimulation.new(registry.get_item(GameManager.ARMOR_ID), registry.get_enemy(GameManager.ENEMY_ID))
	_check(not armor.start() and armor.queue.size() == 0, "passive armor cannot create zero-cooldown loop")

func _test_party() -> void:
	var sword := registry.get_item(GameManager.ITEM_ID)
	var loadout: Array = []
	for index in 3:
		loadout.append({"item": sword, "instance_id": GameManager.sword_instance(index), "owner_id": GameManager.PARTY_IDS[index]})
		loadout.append({"item": registry.get_item(GameManager.ARMOR_ID), "instance_id": GameManager.armor_instance(index), "owner_id": GameManager.PARTY_IDS[index]})
	for speed in SimulationClock.SPEEDS:
		for fps in [30, 60, 144]:
			var enemy := registry.get_enemy(GameManager.ENEMY_ID)
			enemy["max_hp"] = 10000
			var battle := BattleSimulation.new(sword, enemy, loadout)
			battle.start()
			_check(battle.queue.size() == 3, "only active party weapons are scheduled")
			battle.clock.set_speed(speed)
			for frame in range(int(60 * fps / speed)):
				battle.advance(1.0 / fps)
			_check(battle.state.time_usec == 60_000_000 and battle.state.activation_count == 60 and battle.state.enemy_hp == 9400, "party timing invariant across speed and fps")
			var events := battle.drain_events()
			for index in events.size():
				_check(events[index]["at_usec"] == (index / 3 + 1) * 3_000_000 and events[index]["owner_id"] == GameManager.PARTY_IDS[index % 3], "stable simultaneous order and owner attribution")
			for index in 3:
				_check(battle.state.item_runtime[GameManager.sword_instance(index)]["activation_count"] == 20, "per-instance attack counts")
	var party := BattleSimulation.new(sword, registry.get_enemy(GameManager.ENEMY_ID), loadout)
	party.start()
	party.advance(1.5)
	_check(party.activation_progress(GameManager.SWORD_INSTANCE) == 0.5, "cooldown halfway")
	party.clock.paused = true
	party.advance(100)
	_check(party.activation_progress(GameManager.SWORD_INSTANCE) == 0.5, "paused cooldown unchanged")
	party.clock.paused = false
	party.advance(60)
	_check(party.state.defeated_at_usec == 12_000_000 and party.state.activation_count == 10 and party.queue.size() == 0, "party stops exactly on tenth lethal hit")
	_check(party.activation_progress(GameManager.SWORD_INSTANCE) == 1, "finished weapon fully visible")
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/test_fire_sword.json"))
	raw["cooldown"] = 2
	raw["id"] = "test.weapon.fast"
	var mixed := BattleSimulation.new(sword, {"id": "test.enemy", "max_hp": 1000}, [loadout[0], {"item": ItemData.new(raw), "instance_id": "fast", "owner_id": GameManager.PARTY_IDS[1]}])
	mixed.start()
	mixed.advance(1.5)
	_check(mixed.activation_progress(GameManager.SWORD_INSTANCE) == 0.5 and mixed.activation_progress("fast") == 0.75, "independent cooldown lengths")
	mixed.advance(4.5)
	_check(mixed.state.item_runtime[GameManager.SWORD_INSTANCE]["activation_count"] == 2 and mixed.state.item_runtime["fast"]["activation_count"] == 3, "independent schedules")
	var character := registry.get_character(GameManager.PARTY_IDS[0])
	_check(character["name"] == "辰宇" and character["realm"] == "炼气初期", "protagonist definition")
	character["max_hp"] = 0
	_check(not ContentRegistry.new().register_character(character), "invalid character resources rejected")
	_check(registry.get_character(GameManager.PARTY_IDS[0])["max_hp"] == 100, "character definition isolated")
