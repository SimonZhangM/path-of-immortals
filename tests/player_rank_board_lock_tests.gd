extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	create_timer(25).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0, true)
	var scene = load("res://scenes/main/main.tscn").instantiate()
	var game: GameManager = scene.get_node("GameManager")
	game.use_saved_loadout = true
	game.loadout_save_path = ""
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(scene)
	check(game.startup_error.is_empty(), "actual battle starts without errors")
	check(game.party[0].cultivation_rank_id == "base.cultivation.spirit_transformation", "battle player is spirit transformation")
	var status := MapPlayerStatus.new()
	check(status.configure(game.registry, JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/status_header.json"))).is_empty(), "map status loads")
	check(status.rank_name == "化神", "map displays spirit transformation")
	for n in range(1, 7):
		check(game._durable_loadout.can_use_item("base.map_item.qinglan_board_%d" % n), "realm unlocks board %d" % n)
	var record: Dictionary
	for row: Dictionary in game._durable_loadout.storage_records():
		if row.id == "base.map_item.qinglan_board_6": record = row
	var card := BattleInventoryItemCard.new()
	card.configure(record, "阵盘")
	card.bind_battle(game, null)
	root.add_child(card)
	var before := game.party[0].board.id
	for phase in ["preparation", "running", "paused"]:
		if phase == "running": game.start_battle()
		if phase == "paused":
			game.pause_battle()
			game.set_adjustment(true)
		check(card.drag_data().is_empty() == (phase == "running"), phase + " board drag follows adjustment rules")
		var right := InputEventMouseButton.new()
		right.button_index = MOUSE_BUTTON_RIGHT
		right.pressed = true
		card._gui_input(right)
		check(game.party[0].board.id == before and game._durable_loadout.board.id == before, phase + " right-click cannot bypass confirmation")
		check(not game.equip(record.storage_id, 0, Vector2i.ZERO), phase + " equip command rejects board")
	card.queue_free()
	scene.queue_free()
	for i in 8: await process_frame
	print("PLAYER RANK / BOARD LOCK: %d checks; %d failures" % [checks, failures])
	quit(1 if failures else 0)
