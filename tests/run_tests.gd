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
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _new_battle(hp: int = 100) -> BattleSimulation:
	var enemy := registry.get_enemy("base.test.dummy")
	enemy["max_hp"] = hp
	return BattleSimulation.new(registry.get_item("base.test.fire_sword"), enemy)

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
			_check(battle.state.time_usec == 60_000_000, "%dx @%dfps time" % [speed, fps])
			_check(battle.state.activation_count == 20, "%dx @%dfps 20 attacks in 60s" % [speed, fps])
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
	battle.clock.set_speed(8)
	battle.advance(10)
	_check(battle.state.time_usec == 1_000_000, "speed change while paused stays paused")
	battle.clock.paused = false
	battle.advance(0.25)
	_check(battle.state.time_usec == 3_000_000 and battle.state.enemy_hp == 90, "resume at new speed preserves cooldown")
	battle.clock.set_speed(3)
	_check(battle.clock.speed_multiplier == 8, "unsupported speed ignored")
	battle.advance(-1)
	battle.advance(NAN)
	_check(battle.state.time_usec == 3_000_000, "invalid deltas ignored")
	_check(battle.drain_events().size() == 1 and battle.drain_events().is_empty(), "presentation events drained once")
	var fresh := _new_battle()
	_check(fresh.state.enemy_hp == 100 and fresh.state.time_usec == 0 and fresh.clock.speed_multiplier == 1 and not fresh.clock.paused, "fresh run resets state")
