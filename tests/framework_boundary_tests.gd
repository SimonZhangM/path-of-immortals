extends SceneTree

const Files = preload("res://scripts/entry/save_file.gd")
const Slots = preload("res://scripts/entry/save_slot_policy.gd")
const Session = preload("res://scripts/entry/game_save_session.gd")
const Meta = preload("res://scripts/entry/save_metadata.gd")
const PILL := "base.map_item.t01_0026"
var checks := 0
var failures: Array[String] = []
var directory := "res://artifacts/framework-repair-20261110/run-%d/" % Time.get_ticks_usec()
var registry := ContentRegistry.new()

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func make_state() -> MapLoadoutState:
	var content := ContentRegistry.new()
	check(content.load_base_content(), "independent inventory registry loads")
	var created := MapLoadoutStore.create_state(content, content.get_board("base.board.bag"))
	check(created.error.is_empty(), "inventory configured: " + created.error)
	return created.state

func test_rules() -> void:
	check(registry.get_item("base.map_item.t01_0002") == null, "fresh base registry has no map inventory sentinel")
	var paid := 0
	for slug: String in ["biyetengling", "xiwenlingyuan", "taibeishiling", "lanlinglingsun", "qingfenglingtang", "yanbilingyuan_huguo", "yanbilingyuan_shouxue"]:
		var hero := PartyMemberState.new(registry.get_character(GameManager.PARTY_IDS[0]), registry)
		var enemy := PartyMemberState.new(registry.get_enemy("base.enemy." + slug), registry)
		enemy.equip_definition_loadout()
		var sim := BattleSimulation.new([hero], [enemy], registry)
		check(sim.start() and sim.t01 != null, "current rules start without map: " + slug)
		for entry: Dictionary in enemy.inventory.get_instances():
			var item := registry.get_item(entry.item_id)
			for resource: String in ["stamina", "spirit"]:
				if item.get(resource + "_cost") <= 0: continue
				paid += 1
				enemy.stamina = enemy.maximum("stamina")
				enemy.spirit = enemy.maximum("spirit")
				enemy.set(resource, 0)
				check(not sim._can_activate(entry.instance_id), "insufficient " + resource + ": " + item.id)
				var before: int = sim.state.item_runtime[entry.instance_id].activation_count
				sim._activate({"instance_id":entry.instance_id, "version":sim._versions[entry.instance_id]}, 0)
				check(sim.state.item_runtime[entry.instance_id].activation_count == before and enemy.get(resource) == 0, "failed action has no effect/payment: " + item.id)
			if item.id == "base.organ.biyetengling_biwenlingye":
				enemy.spirit = item.spirit_cost - 0.1
				check(not sim._can_activate(entry.instance_id), "fraction below spirit fee rejected")
				enemy.spirit = item.spirit_cost
				check(sim._can_activate(entry.instance_id), "exact spirit fee accepted")
				sim._activate({"instance_id":entry.instance_id, "version":sim._versions[entry.instance_id]}, 0)
				check(enemy.spirit == 0 and sim.state.item_runtime[entry.instance_id].activation_count == 1, "exact spirit fee paid once")
	check(paid == 24, "all 24 current paid resource requirements covered")
	var player := PartyMemberState.new(registry.get_character(GameManager.PARTY_IDS[0]), registry)
	var dog := PartyMemberState.new(registry.get_enemy(GameManager.ENEMY_ID), registry)
	var library := registry.library
	registry.library = null
	var missing := BattleSimulation.new([player], [dog], registry)
	check(not missing.start() and not missing.configuration_error.is_empty(), "missing current dependency refuses start")
	var error := missing.configuration_error
	check(not missing.start() and missing.configuration_error == error, "initialization error survives repeated start")
	var legacy := BattleSimulation.new([player], [dog], registry, [], [], true)
	check(legacy.start() and legacy.t01 == null and legacy.state.legacy_fixed_defense, "explicit historical simulation remains available")
	registry.library = library
	var invalid := BattleSimulation.new([], [dog], registry)
	check(not invalid.start() and not invalid.configuration_error.is_empty(), "invalid team rejected without calling current rule checks")

func test_growth() -> void:
	var state := make_state()
	var old := state.snapshot()
	old.erase("growth")
	var input := old.duplicate(true)
	check(state.restore(old).is_empty(), "old missing growth restores before quest derivation")
	check(old == input, "migration leaves caller snapshot unchanged")
	check(CultivationGrowth.valid(state.growth) and not state.growth.is_empty(), "legacy growth is complete and valid")
	check(state.growth == state.initial_growth(), "legacy defaults preserve prior realm/full base resources/experience")
	old.growth = {}
	check(state.restore(old).is_empty(), "empty legacy growth also migrates")
	var explicit := CultivationGrowth.initial(1)
	explicit.resources = {"hp":1234, "stamina":567, "spirit":89}
	explicit.experience = 73
	check(state.restore(old, false, explicit).is_empty() and state.growth == explicit, "explicit prior player growth used for legacy save")
	var current := state.snapshot()
	check(state.restore(current, false, state.initial_growth()).is_empty() and state.growth == explicit, "current saved growth takes precedence over fallback")
	var before := state.snapshot()
	var before_rank := state.cultivation_rank_id
	var invalid := current.duplicate(true)
	invalid.growth = {"realm":0}
	check(not state.restore(invalid).is_empty() and state.snapshot() == before, "malformed nonempty growth rejected atomically")
	invalid = old.duplicate(true)
	invalid.board_id = "base.board.missing"
	check(not state.restore(invalid).is_empty() and state.snapshot() == before and state.cultivation_rank_id == before_rank, "later layout rejection rolls back growth/rank/learning")
	var legacy_path := directory + "legacy.json"
	check(Files.write(legacy_path, old) == OK, "legacy disk fixture written")
	check(MapLoadoutStore.load_into(state, legacy_path).is_empty(), "legacy store migration succeeds")
	check(not Files.read(legacy_path).get("growth", {}).is_empty(), "writable legacy migration persisted")
	var fresh := make_state()
	check(MapLoadoutStore.load_into(fresh, "").is_empty() and not fresh.growth.is_empty(), "empty-path entry uses shared growth defaults")

func test_sessions() -> void:
	var state := make_state()
	state.growth = state.initial_growth()
	for path: String in [Slots.auto_path, Slots.quick_path(), directory + "manual.json"]:
		var raw := state.snapshot()
		if path == Slots.auto_path: raw.erase("growth")
		raw.save_info = {"save_kind":"manual" if path.ends_with("manual.json") else "auto", "playtime_ms":4321, "playtime_complete":false}
		check(Files.write(path, raw) == OK, "snapshot fixture written")
		var hash_before := FileAccess.get_sha256(path)
		Session.clear_selection()
		var game := GameManager.new()
		game.use_saved_loadout = true
		game.loadout_save_path = path
		root.add_child(game)
		game.set_process(false)
		check(game.startup_error.is_empty() and game.simulation != null, "standalone snapshot entry initializes")
		check(game.loadout_save_path == Slots.working_path() and Session.active_path == Slots.working_path(), "standalone publishes writable session")
		var saved := Files.read(Slots.working_path())
		check(not saved.get("growth", {}).is_empty(), "legacy/current source has valid growth before entering battle")
		check(saved.save_info.save_kind == "session" and saved.save_info.playtime_ms == 4321, "session keeps source metadata")
		var entry: Dictionary = game.storage.entries()[0]
		game.storage.take_one(entry.instance_id)
		check(game.persist_consumption(), "standalone consumption can commit")
		check(FileAccess.get_sha256(path) == hash_before, "source snapshot remains byte-identical")
		game.free()
	var working_hash := FileAccess.get_sha256(Slots.working_path())
	var adopted := MapLoadoutStore.adopt_session(state, Slots.working_path())
	check(adopted.error.is_empty() and FileAccess.get_sha256(Slots.working_path()) == working_hash, "existing session not overwritten by adoption")
	var live := GameManager.new()
	live.use_saved_loadout = true
	live.loadout_save_path = Slots.auto_path
	root.add_child(live)
	live.set_process(false)
	check(live.startup_error.is_empty() and live.loadout_save_path == Slots.working_path(), "active session retained across battle entry")
	check(FileAccess.get_sha256(Slots.working_path()) == working_hash, "battle entry does not replace active session with older snapshot")
	live.free()
	# An obstructed temporary file fails before replacing the existing working file.
	var blocker := Slots.working_path() + ".tmp"
	check(DirAccess.make_dir_absolute(blocker) == OK, "create deterministic write obstruction")
	Session.active_path = "previous-session"
	adopted = MapLoadoutStore.adopt_session(state, Slots.auto_path)
	check(not adopted.error.is_empty() and adopted.path == Slots.auto_path and Session.active_path == "previous-session", "failed adoption does not publish path")
	check(FileAccess.get_sha256(Slots.working_path()) == working_hash, "failed adoption preserves previous session")
	check(DirAccess.remove_absolute(blocker) == OK, "remove test obstruction")
	Session.clear_selection()

func test_consumption_retry() -> void:
	var state := make_state()
	state.growth = state.initial_growth()
	var unit_id := ""
	for entry: Dictionary in state.storage.entries():
		if entry.item_id == PILL:
			unit_id = entry.units[0].id
			check(state.place(state.drag_data("storage", entry.instance_id), Vector2i.ZERO), "place one real healing consumable")
			break
	check(not unit_id.is_empty(), "consumable exists")
	var path := directory + "consumption.json"
	check(MapLoadoutStore.save(state, path).is_empty(), "consumption fixture committed")
	var game := GameManager.new()
	game.use_saved_loadout = true
	game.loadout_save_path = path
	root.add_child(game)
	game.set_process(false)
	check(game.startup_error.is_empty(), "consumption manager ready")
	game.start_battle()
	game.party[0].hp -= 20
	var before := game._durable_snapshot.duplicate(true)
	var disk_hash := FileAccess.get_sha256(path)
	var blocker := path + ".tmp"
	check(DirAccess.make_dir_absolute(blocker) == OK, "block real save destination")
	game._process(8.5)
	check(game.party[0].inventory.get_instance(unit_id).is_empty(), "real simulation consumes pill")
	check(not game._pending_consumption.is_empty() and game.simulation.clock.paused and not game.consumption_save_error.is_empty(), "failed save latches pause and pending snapshot")
	check(game._durable_snapshot == before and FileAccess.get_sha256(path) == disk_hash, "failed save preserves committed state")
	var at := game.simulation.state.time_usec
	var hp := game.party[0].hp
	var pending := game._pending_consumption.duplicate(true)
	game.toggle_pause()
	game.play_normal()
	game.restart()
	game.start_battle()
	check(game.simulation.clock.paused and game._pending_consumption == pending, "all resume/start entries remain blocked while retry fails")
	check(not game.can_edit_inventory() and not game.request_retreat(), "inventory and retreat cannot bypass pending save")
	game._process(20)
	check(game.simulation.state.time_usec == at and game.party[0].hp == hp, "blocked simulation does not advance or replay effect")
	check(DirAccess.remove_absolute(blocker) == OK, "restore write access")
	game.toggle_pause()
	check(not game.simulation.clock.paused and game._pending_consumption.is_empty() and game.consumption_save_error.is_empty(), "successful retry releases pause")
	check(game.simulation.state.time_usec == at and game.party[0].hp == hp, "retry does not replay consumed pill")
	var saved := Files.read(path)
	check(saved.owned_units.size() == before.owned_units.size()-1 and not saved.owned_units.has(unit_id), "one and only one unit removed durably")
	check(saved.placements.all(func(row: Dictionary): return unit_id not in row.unit_ids), "consumed placement removed durably")
	var committed := FileAccess.get_sha256(path)
	check(game.persist_consumption() and FileAccess.get_sha256(path) == committed, "repeat commit is idempotent")
	game.toggle_pause()
	check(game.simulation.clock.paused, "ordinary pause still works")
	game.toggle_pause()
	game._process(0.5)
	check(not game.simulation.clock.paused and game.simulation.state.time_usec > at, "ordinary resume still advances")
	game.free()

func run() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
	DirAccess.make_dir_recursive_absolute(directory)
	Slots.auto_path = directory + "auto.json"
	Session.index_path = directory + "session.json"
	Session.clear_selection()
	root.get_node("SavePlaytime").set_process(false)
	AudioServer.set_bus_mute(0, true)
	check(registry.load_base_content(), "base registry loads")
	test_rules()
	test_growth()
	test_sessions()
	test_consumption_retry()
	Meta.stop()
	Session.clear_selection()
	Files.write(directory + "validation.json", {"checks":checks, "failures":failures})
	print("FRAMEWORK BOUNDARIES: %d checks, %d failures; %s" % [checks, failures.size(), directory])
	quit(0 if failures.is_empty() else 1)
