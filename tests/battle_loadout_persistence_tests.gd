extends SceneTree

const Files = preload("res://scripts/entry/save_file.gd")
const Session = preload("res://scripts/entry/game_save_session.gd")
var checks := 0
var failures: Array[String] = []
var directory := "res://artifacts/battle-loadout-20261110/run-%d/" % Time.get_ticks_usec()
var path := directory + "loadout.json"

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func stored(game: GameManager, item_id: String) -> String:
	for entry: Dictionary in game.storage.entries():
		if entry.item_id == item_id: return entry.instance_id
	return ""

func open_battle() -> GameManager:
	var game := GameManager.new()
	game.use_saved_loadout = true
	game.loadout_save_path = path
	root.add_child(game)
	game.set_process(false)
	check(game.startup_error.is_empty(), "saved battle entry initializes")
	return game

func check_reload(game: GameManager) -> void:
	var next := open_battle()
	check(next.party[0].board.id == game.party[0].board.id, "next battle uses selected board")
	check(next._durable_snapshot.placements == game._durable_snapshot.placements, "next battle reads latest saved placements")
	for entry: Dictionary in game.party[0].inventory.get_instances():
		# A consumed leading unit changes the durable stack ID on reload.
		var restored := next.party[0].inventory.get_instance(entry.units[0].id)
		check(not restored.is_empty() and restored.cell == entry.cell and restored.units.map(func(unit: Dictionary): return unit.id) == entry.units.map(func(unit: Dictionary): return unit.id), "next battle restores live item location and units")
	next.free()

func run() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
	DirAccess.make_dir_recursive_absolute(directory)
	Session.clear_selection()
	Session.index_path = directory + "session.json"
	root.get_node("SavePlaytime").set_process(false)
	var content := ContentRegistry.new()
	check(content.load_base_content(), "base content loads")
	var created := MapLoadoutStore.create_state(content, content.get_board("base.board.bag"))
	check(created.error.is_empty(), "inventory fixture created")
	var seed: Dictionary = created.state.snapshot()
	seed.owned_units["test.extra_pill"] = "base.map_item.t01_0026"
	check(created.state.restore(seed).is_empty(), "seed second consumable unit")
	check(MapLoadoutStore.save(created.state, path).is_empty(), "isolated initial save")
	var game := open_battle()
	var original := game._durable_snapshot.duplicate(true)
	game.set_adjustment(true)
	var sword := stored(game, "base.map_item.qingshi_short_sword")
	var bow := stored(game, "base.map_item.hunting_bow")
	var big := stored(game, "base.map_item.qinglan_board_6")
	var bag := stored(game, "base.map_item.bag_board")
	check(game.equip(sword, 0, Vector2i.ZERO), "preparation equip succeeds")
	game.start_battle()
	game.pause_battle()
	game.set_adjustment(true)
	check(game.move_item(0, sword, Vector2i(1, 0)), "battle item move succeeds")
	check_reload(game)
	check(game.equip(bow, 0, Vector2i.ZERO), "battle equip succeeds")
	check(game.move_item(0, sword, Vector2i.ZERO), "occupied same-size swap succeeds")
	check_reload(game)
	check(game.unequip(0, bow), "battle return to bag succeeds")
	check(game.change_board(big), "battle larger board succeeds")
	check(game.equip(bow, 0, Vector2i(5, 4)), "large board outer placement succeeds")
	check_reload(game)
	var runtime: Dictionary = game.simulation.state.item_runtime[sword].duplicate(true)
	var timer: Dictionary = game.simulation.timeline.timers[sword].duplicate(true)
	check(game.change_board(bag), "battle smaller board succeeds")
	check(game.party[0].inventory.get_instance(bow).is_empty() and stored(game, "base.map_item.hunting_bow") == bow, "overflow returns to bag")
	check(game.simulation.state.item_runtime[sword] == runtime and game.simulation.timeline.timers[sword] == timer, "saving keeps live cooldown and runtime")
	check_reload(game)
	for key: String in ["owned_units", "formations", "warehouses", "quests", "battle_rewards", "growth"]:
		check(game._durable_snapshot.get(key) == original.get(key), "layout save preserves " + key)
	var before := game._durable_snapshot.duplicate(true)
	var hash_before := FileAccess.get_sha256(path)
	check(not game.move_item(0, sword, Vector2i(99, 99)) and FileAccess.get_sha256(path) == hash_before, "rejected edit does not save")
	var blocker := path + ".tmp"
	check(DirAccess.make_dir_absolute(blocker) == OK, "obstruct save for retry check")
	check(game.move_item(0, sword, Vector2i(2, 0)), "successful live edit retained on write failure")
	check(game.simulation.clock.paused and not game.can_edit_inventory() and not game._pending_consumption.is_empty(), "failed layout save freezes battle and further edits")
	check(game._durable_snapshot == before and FileAccess.get_sha256(path) == hash_before, "failed save preserves committed file")
	check(not game.request_retreat(), "cannot exit with unsaved layout")
	check(DirAccess.remove_absolute(blocker) == OK, "remove save obstruction")
	check(game.persist_consumption() and game._pending_consumption.is_empty(), "retry commits frozen latest layout")
	check_reload(game)
	# Consuming an owned unit must not revert the newly saved board/placements.
	var entry: Dictionary = game.storage.get_entry(stored(game, "base.map_item.hunting_bow"))
	var consumed: String = entry.units[0].id
	game.storage.take_one(entry.instance_id)
	var layout: Array = game._durable_snapshot.placements.duplicate(true)
	check(game.persist_consumption() and not game._durable_snapshot.owned_units.has(consumed), "consumption still persists")
	check(game._durable_snapshot.placements == layout, "consumption retains latest layout")
	check(game.request_retreat(), "retreat succeeds after saved adjustment")
	check_reload(game)
	game.free()
	game = open_battle()
	game.set_adjustment(true)
	check(game.unequip(0, sword), "next battle can replace prior equipment")
	var pill := stored(game, "base.map_item.t01_0026")
	check(game.equip(pill, 0, Vector2i.ZERO, 2), "equip two consumable units")
	check_reload(game)
	game.start_battle()
	game.party[0].hp -= 20
	game._process(0.5)
	check(game.party[0].inventory.get_instance(pill).units.size() == 1, "real simulation consumes one equipped unit")
	check(game._durable_snapshot.placements[0].unit_ids.size() == 1 and not game._durable_snapshot.owned_units.has(pill), "latest saved stack loses exactly consumed unit")
	check_reload(game)
	game.free()
	Session.clear_selection()
	Files.write(directory + "validation.json", {"checks": checks, "failures": failures})
	print("BATTLE LOADOUT: %d checks, %d failures; %s" % [checks, failures.size(), directory])
	quit(0 if failures.is_empty() else 1)
