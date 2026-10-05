extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var registry := ContentRegistry.new()
	check(registry.load_base_content(), "registry loads")
	var created := MapLoadoutStore.create_state(registry, registry.get_board("base.board.bag"))
	check(created.error.is_empty(), "loadout loads")
	var state: MapLoadoutState = created.state
	# Every authored accessory slot accepts multiple independent copies.
	var slots := {}
	for record: Dictionary in state.records.values():
		var item := registry.get_item(record.id)
		if item.category != "armor" or not item.armor_slot.begins_with("护具·"):
			continue
		slots[item.armor_slot] = true
		var inventory := InventoryState.new(registry, Vector2i(12, 12))
		check(inventory.add_item("first", item.id, Vector2i.ZERO), "first " + item.display_name)
		check(inventory.add_item("second", item.id, Vector2i(4, 0)), "duplicate accessory " + item.display_name)
		check(inventory.add_item("third", item.id, Vector2i(8, 0)), "third accessory " + item.display_name)
	check(slots.size() == 4, "arm/leg/shoulder/waist covered")
	var body := InventoryState.new(registry, Vector2i(6, 6))
	check(body.add_item("cloth", "base.map_item.coarse_cloth_armor", Vector2i.ZERO), "first body armor")
	check(not body.add_item("iron", "base.map_item.t01_0011", Vector2i(3, 0)), "second body armor rejected despite space")
	check(body.move_item("cloth", Vector2i(1, 0)), "existing body armor may move")
	body.take("cloth")
	check(body.add_item("iron", "base.map_item.t01_0011", Vector2i.ZERO), "body armor replacement allowed")
	for request in [{"name":"布护腿", "cell":Vector2i(0,0)}, {"name":"铁护腿", "cell":Vector2i(1,0)}, {"name":"布护臂", "cell":Vector2i(0,1)}, {"name":"铁护臂", "cell":Vector2i(1,1)}]:
		var record: Dictionary = state.storage_records().filter(func(r): return r.name == request.name)[0]
		var data := state.drag_data("storage", record.storage_id)
		check(state.can_place(data, request.cell), "preview permits " + request.name)
		check(state.place(data, request.cell), "placement permits " + request.name)
	var snapshot := state.snapshot()
	var reload_registry := ContentRegistry.new()
	check(reload_registry.load_base_content(), "fresh registry loads")
	var reload_result := MapLoadoutStore.create_state(reload_registry, reload_registry.get_board("base.board.bag"))
	check(reload_result.error.is_empty(), "fresh loadout loads")
	var reloaded: MapLoadoutState = reload_result.state
	var restore_error := reloaded.restore(JSON.parse_string(JSON.stringify(snapshot)))
	check(restore_error.is_empty(), "multi-accessory save restores: " + restore_error)
	check(reloaded.inventory.get_instances().size() == 4, "all four accessories remain equipped")
	check(reloaded.snapshot() == snapshot, "ownership and positions survive restore")
	print("Armor equipment limits: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
