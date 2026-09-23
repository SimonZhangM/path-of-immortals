extends SceneTree

var checks := 0
var failures := 0
const RANKS := ["mortal", "qi_refining", "foundation", "golden_core", "nascent_soul", "spirit_transformation"]

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func _fixture_records() -> Array:
	var records: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/inventory_items.json"))
	var result: Array = []
	for index in 7:
		var record: Dictionary = records[0].duplicate(true)
		record.id = "test.rank.item_%d" % index
		record.name = "境界测试剑%d" % index
		record.quality = MapItemQuality.QUALITIES[index]
		record.quantity = 1
		record.acquired_at = index
		result.append(record)
	return result

func _unit_id(index: int) -> String:
	return "owned.test.rank.item_%d.0" % index

func _settle() -> void:
	for frame in 8:
		await process_frame

func _run() -> void:
	var registry := ContentRegistry.new()
	_check(registry.load_base_content(), "base content loads with explicit quality")
	var records := _fixture_records()
	var state := MapLoadoutState.new()
	_check(state.configure(registry, registry.get_board("base.board.bag"), records).is_empty(), "seven test ranks register")
	_check(state.cultivation_rank_id == "base.cultivation.nascent_soul", "testing protagonist is nascent soul")
	for rank_index in 6:
		state.cultivation_rank_id = "base.cultivation." + RANKS[rank_index]
		for item_index in 7:
			var allowed := item_index <= rank_index + 1
			var item := registry.get_item(records[item_index].id)
			_check(item.quality_level == item_index + 1, "quality resolves to one-based level")
			_check(state.can_use_item(item.id) == allowed, "six-rank seven-quality access matrix")
			var before := state.snapshot()
			_check(state.place(state.drag_data("storage", _unit_id(item_index)), Vector2i.ZERO) == allowed, "direct placement enforces rank boundary")
			if allowed:
				_check(state.take_back(state.drag_data("board", _unit_id(item_index))), "allowed item returns to storage")
			else:
				_check(state.snapshot() == before and not state.equip_random(_unit_id(item_index)), "blocked direct/random placement preserves ownership and layout")
	state.cultivation_rank_id = "base.cultivation.nascent_soul"
	_check(state.equip_random(_unit_id(5)), "nascent soul can equip mystic quality")
	var before_swap := state.snapshot()
	var equipped_cell: Vector2i = state.inventory.get_instance(_unit_id(5)).cell
	_check(state.placement_kind(state.drag_data("storage", _unit_id(6)), equipped_cell) == "invalid", "over-level item cannot exchange with one occupant")
	_check(not state.place(state.drag_data("storage", _unit_id(6)), equipped_cell) and state.snapshot() == before_swap, "rejected exchange is atomic")
	state.take_back(state.drag_data("board", _unit_id(5)))
	state.cultivation_rank_id = "base.cultivation.spirit_transformation"
	_check(state.place(state.drag_data("storage", _unit_id(6)), Vector2i.ZERO), "highest rank can equip immortal quality")
	_check(state.save_formation("仙品记录", state.formation_icons[0]).is_empty(), "formation records high quality")
	var high_save := state.snapshot()
	state.cultivation_rank_id = "base.cultivation.nascent_soul"
	_check(state.restore(high_save).is_empty(), "lower-rank save restore succeeds")
	_check(state.inventory.get_instances().is_empty() and state.storage.entries().size() == 7, "over-level saved gear returns to storage without loss")
	var lower_save := state.snapshot()
	_check(not state.apply_formation(state.formations[0].id).is_empty() and state.snapshot() == lower_save, "formation cannot bypass restriction or disturb layout")
	var duplicate_save := high_save.duplicate(true)
	duplicate_save.placements.append(high_save.placements[0].duplicate(true))
	_check(not state.restore(duplicate_save).is_empty(), "duplicate forbidden items still invalidate save")
	var candidate := state.reward_candidate({"id": "base.map_reward.rank_test", "item_id": records[6].id, "quantity": 1})
	_check(candidate.error.is_empty() and candidate.state.cultivation_rank_id == state.cultivation_rank_id and not candidate.state.can_use_item(records[6].id), "reward candidate preserves access context and allows collection")
	var catalog := MapInventoryCatalog.new()
	catalog.configure(JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/map_inventory.json")))
	_check(catalog.replace_entries(state.storage_records()).is_empty(), "masked storage retains valid item metadata")
	catalog.search_text = records[6].name
	_check(catalog.visible_entries().is_empty(), "search does not expose hidden name")
	catalog.search_text = "？"
	_check(catalog.visible_entries().size() == 1, "unknown item can be searched by visible name")
	var invalid_records := records.duplicate(true)
	invalid_records[0].quality = "未知品级"
	_check(not catalog.replace_entries(invalid_records).is_empty(), "unrecognized quality is rejected")
	for path in DirAccess.get_files_at("res://data/items"):
		if path.ends_with(".json"):
			var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/" + path))
			_check(raw.has("quality") and MapItemQuality.level(raw.quality) > 0, "production item explicitly declares quality: " + path)
	var game := GameManager.new()
	root.add_child(game)
	game.set_process(false)
	var high_raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/test_fire_sword.json"))
	high_raw.id = "test.rank.battle_sword"
	high_raw.quality = "仙品"
	_check(game.registry.register_item(high_raw), "battle high-quality fixture registers")
	game.party[0].inventory = InventoryState.new(game.registry, game.party[0].board.grid_size)
	game.restart()
	game.storage.put({"instance_id": "rank.battle", "item_id": high_raw.id, "units": [{"id": "rank.battle", "uses_left": 0}]})
	_check(not game.can_equip("rank.battle", 0, Vector2i.ZERO) and not game.equip_random("rank.battle"), "battle equip and quick-equip enforce rank despite sufficient space")
	_check(game.party[0].inventory.add_item("rank.injected", high_raw.id, Vector2i.ZERO), "test injects forbidden saved equipment")
	game.simulation.attach(game.party[0], 0, "rank.injected", false)
	_check(not game.simulation.state.item_runtime.has("rank.injected"), "invalid preloaded gear cannot enter combat runtime")
	_check(game.enemies[0].can_use_item(game.registry.get_item(GameManager.CLAW_ID)), "unranked creature innate attack is unaffected")
	game.party[0].set_cultivation_rank("base.cultivation.spirit_transformation")
	game.simulation.attach(game.party[0], 0, "rank.injected", false)
	_check(game.simulation.state.item_runtime.has("rank.injected"), "sufficient cultivation permits combat runtime")
	game.party[0].set_cultivation_rank("base.cultivation.nascent_soul")
	_check(not game.simulation._can_activate("rank.injected"), "activation rechecks cultivation")
	var battle_card := StorageItemCard.new()
	battle_card.configure(game, game.storage.get_entry("rank.battle"))
	var battle_tip := battle_card._make_custom_tooltip("") as ItemTooltip
	_check(battle_tip.description == MapItemQuality.UNKNOWN_DESCRIPTION, "battle storage uses restricted tooltip")
	battle_tip.free()
	battle_card.free()
	game.queue_free()
	root.size = Vector2i(1920, 1080)
	var map = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path = ""
	root.add_child(map)
	map.set_inventory_open(true)
	await _settle()
	_check(map.player_status.rank_name == "元婴", "map header uses authoritative nascent soul rank")
	_check(map.loadout.storage.entries().size() == 10, "temporary fixtures do not enter production roster")
	var preview_layer := CanvasLayer.new()
	preview_layer.layer = 100
	root.add_child(preview_layer)
	var veil := ColorRect.new()
	veil.color = Color("08111bef")
	veil.position = Vector2(320, 210)
	veil.size = Vector2(1490, 730)
	preview_layer.add_child(veil)
	for index in [5, 6]:
		var offset := float(index - 5) * 720
		var card := MapInventoryItemCard.new()
		card.configure(records[index], "武器")
		card.bind_loadout(state, null)
		preview_layer.add_child(card)
		card.position = Vector2(360 + offset, 240)
		var title := card.canvas.get_node("ItemName") as Label
		_check(title.text == (records[index].name if index == 5 else "？"), "card title respects boundary")
		var tip := card._make_custom_tooltip("") as ItemTooltip
		preview_layer.add_child(tip)
		tip.position = Vector2(360 + offset, 530)
		if index == 6:
			_check(tip.find_child("ItemTitle", true, false).text == "？", "tooltip name is hidden")
			_check(tip.find_child("KeywordPanel", true, false) == null and tip.get_child(0).get_child_count() == 1, "only first summary container remains")
			_check(tip.description == MapItemQuality.UNKNOWN_DESCRIPTION and not tip.description.contains("冷却"), "restricted text replaces all item effects")
			var chips := tip.find_child("CategoryTags", true, false)
			_check(chips.get_child_count() == 1 and chips.get_child(0).text == "？", "tooltip classification and footprint details are hidden")
		else:
			_check(tip.find_child("KeywordPanel", true, false) != null and tip.description.contains("冷却"), "accessible item retains normal effects and glossary")
	await _settle()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/item_cultivation_access.png")
	for child in root.get_children():
		child.queue_free()
	await _settle()
	ItemTooltip._tooltip_theme = null
	ItemTooltip._keyword_theme = null
	ItemTooltip._body_font = null
	ItemTooltip._term_font = null
	print("ITEM CULTIVATION ACCESS: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
