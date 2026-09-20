extends SceneTree

const SAVE := "res://artifacts/formation-persistence-test.json"
const ICON := "res://assets/zhen-xiulian.webp"
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _fresh(board_id: String = "base.board.bag") -> MapLoadoutState:
	var registry := ContentRegistry.new()
	registry.load_base_content()
	return MapLoadoutStore.create_state(registry, registry.get_board(board_id)).state

func _clear() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(SAVE + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))

func _run() -> void:
	_clear()
	var state := _fresh()
	var legacy := state.snapshot()
	var unit: Dictionary = state.storage.entries()[0]
	_check(state.place(state.drag_data("storage", unit.instance_id), Vector2i.ZERO), "equip owned item before capturing formation")
	var arranged := state.layout_snapshot()
	var formation := state.formation_snapshot()
	_check(state.save_formation("攻守阵", ICON).is_empty(), "save named formation")
	var id: String = state.formations[0].id
	_check(state.formations[0].layout == formation and formation.keys() == ["placements"], "formation captures only stable item IDs and cells, without board metadata")
	_check(MapLoadoutStore.save(state, SAVE).is_empty(), "save formation and current loadout atomically")
	var restored := _fresh()
	_check(MapLoadoutStore.load_into(restored, SAVE).is_empty() and restored.snapshot() == state.snapshot(), "fresh model recovers formation and layout from disk")
	_check(restored.take_back(restored.drag_data("board", unit.instance_id)), "return item to storage")
	_check(restored.apply_formation(id).is_empty() and restored.layout_snapshot() == arranged and restored.storage.entries().size() == 9, "restore exact formation without duplicating ownership")
	_check(restored.place(restored.drag_data("board", unit.instance_id), Vector2i(1, 0)), "move live layout independently")
	_check(restored.formations[0].layout == formation, "saved layout is a deep snapshot")
	_check(restored.save_formation("改名阵", "res://assets/zhen-fangyu.webp", id).is_empty() and restored.formations[0].layout == formation, "metadata-only edit preserves snapshot")
	_check(restored.save_formation("更新阵", ICON, id, true).is_empty() and restored.formations[0].layout == restored.formation_snapshot(), "explicit overwrite captures current layout")
	var optional_capture := _fresh()
	var optional_unit: Dictionary = optional_capture.storage.entries()[0]
	optional_capture.place(optional_capture.drag_data("storage", optional_unit.instance_id), Vector2i.ZERO)
	_check(optional_capture.save_formation("空布局阵", ICON, "", false, false).is_empty() and optional_capture.formations[0].layout.placements.is_empty(), "unchecked new-formation option creates an empty saved layout")
	var before := restored.snapshot()
	_check(not restored.save_formation(" ", ICON).is_empty() and not restored.save_formation("无效图标", "res://unknown.webp").is_empty() and restored.snapshot() == before, "invalid metadata does not mutate records")
	var malformed := before.duplicate(true)
	malformed.formations[0].layout.placements[0].cell = [-1, 3]
	_check(not restored.restore(malformed).is_empty() and restored.snapshot() == before, "invalid formation rejects whole restore atomically")
	malformed = before.duplicate(true)
	malformed.formations.append(malformed.formations[0].duplicate(true))
	_check(not restored.restore(malformed).is_empty() and restored.snapshot() == before, "duplicate formation IDs rejected atomically")
	_check(restored.restore(legacy).is_empty() and restored.formations.is_empty(), "legacy version-one saves need no migration")
	_check(restored.save_formation("空阵", ICON).is_empty() and restored.formations[0].layout.placements.is_empty(), "empty layouts are valid saved formations")
	_check(restored.apply_formation(restored.formations[0].id).is_empty(), "empty formation restores")
	_check_portable_formations()
	# Real map callback saves immediately, metadata survives a scene restart.
	_clear()
	var map = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path = SAVE
	root.add_child(map)
	await process_frame
	await process_frame
	map.set_inventory_open(true)
	var panel: MapInventoryScreen = map.inventory_screen
	var map_unit: Dictionary = map.loadout.storage.entries()[0]
	map.loadout.place(map.loadout.drag_data("storage", map_unit.instance_id), Vector2i.ZERO)
	panel._open_formation_dialog()
	panel.formation_name_input.text = "重启阵"
	panel._update_formation_create_enabled()
	panel._create_custom_formation()
	_check(FileAccess.file_exists(SAVE) and not panel.is_formation_dialog_open(), "creation persists immediately without closing inventory")
	map.queue_free()
	await process_frame
	map = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path = SAVE
	root.add_child(map)
	await process_frame
	await process_frame
	_check(map.loadout.formations.size() == 1 and map.loadout.formations[0].name == "重启阵", "new map scene displays saved formation after restart")
	panel = map.inventory_screen
	map.set_inventory_open(true)
	map.loadout.take_back(map.loadout.drag_data("board", map_unit.instance_id))
	for i in 5:
		await process_frame
	var apply_click := InputEventMouseButton.new()
	apply_click.button_index = MOUSE_BUTTON_LEFT
	apply_click.pressed = true
	apply_click.position = panel.formation_cards.get_child(0).get_global_rect().get_center()
	root.push_input(apply_click, true)
	apply_click.pressed = false
	root.push_input(apply_click, true)
	_check(map.loadout.inventory.get_instances().size() == 1 and map.loadout.storage.entries().size() == 9, "clicking the saved card restores owned equipment without duplicates")
	var disk := _fresh()
	_check(MapLoadoutStore.load_into(disk, SAVE).is_empty() and disk.layout_snapshot() == map.loadout.layout_snapshot(), "restoring a formation persists the selected live layout immediately")
	var persisted: Dictionary = map.loadout.snapshot()
	panel.formation_save_callback = func() -> String: return "模拟写入失败"
	panel._open_formation_dialog(map.loadout.formations[0].id)
	panel.formation_name_input.text = "不应保存"
	panel._update_formation_create_enabled()
	panel._create_custom_formation()
	_check(map.loadout.snapshot() == persisted and panel.is_formation_dialog_open() and panel.formation_message.visible and panel.formation_message.text == "模拟写入失败", "failed write restores previous data and keeps error visible")
	panel.close_formation_dialog()
	for index in 8:
		map.loadout.save_formation("测试阵%d" % index, ICON)
	for i in 5:
		await process_frame
	var strip := panel.formation_panel.find_child("FormationScroll", true, false) as ScrollContainer
	_check(panel.formation_cards.get_child_count() == 10 and is_equal_approx(panel.formation_panel.size.x, 718.0) and is_equal_approx(panel.formation_panel.size.y, 174.0), "many records remain scrollable without expanding formation panel")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	strip.gui_input.emit(wheel)
	_check(strip.scroll_horizontal > 0, "formation strip scrolls through overflow")
	var hidden_add := panel.custom_formation_card.get_global_rect().get_center()
	apply_click.position = hidden_add
	apply_click.pressed = true
	root.push_input(apply_click, true)
	_check(not panel.is_formation_dialog_open(), "offscreen cards do not receive clicks outside the strip")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/formation_saved_layouts.png")
	map.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	_clear()
	print("MAP FORMATION RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _check_portable_formations() -> void:
	var source := _fresh()
	var units := source.storage.entries()
	var missing: Dictionary = units[0]
	var retained: Dictionary = units[1]
	# Deliberately insert right before left: serialization must use top-left row order.
	_check(source.place(source.drag_data("storage", retained.instance_id), Vector2i(2, 1)) and source.place(source.drag_data("storage", missing.instance_id), Vector2i.ZERO), "prepare a sparse, reverse-insertion layout")
	source.save_formation("跨盘阵", ICON)
	var saved: Dictionary = source.formations[0].duplicate(true)
	_check(saved.layout.placements[0].instance_id == missing.instance_id and saved.layout.placements[1].cell == [2, 1], "formation records follow top-left row order and preserve empty cells")
	source.take_back(source.drag_data("board", missing.instance_id))
	# Simulate a removed owned unit; the current game has no sell/delete UI yet.
	source.storage.take_one(missing.instance_id)
	source._owned.erase(missing.instance_id)
	var replacement_id: String = missing.instance_id + ".replacement"
	source._owned[replacement_id] = missing.item_id
	source.storage.put(source._unit(replacement_id, missing.item_id))
	_check(source.apply_formation(saved.id).is_empty() and source.inventory.get_instances().size() == 1 and source.inventory.get_instance(retained.instance_id).cell == Vector2i(2, 1), "removed unit leaves its cells empty without compacting remaining items")
	_check(source.inventory.get_instance(missing.instance_id).is_empty() and not source.storage.get_entry(replacement_id).is_empty() and source.formations[0] == saved, "missing unit is neither recreated nor substituted and saved reference survives")
	_check(MapLoadoutStore.save(source, SAVE).is_empty(), "persist a formation with a missing owned unit")
	var reduced := _fresh()
	reduced._owned.erase(missing.instance_id)
	reduced._owned[replacement_id] = missing.item_id
	_check(MapLoadoutStore.load_into(reduced, SAVE).is_empty() and reduced.apply_formation(saved.id).is_empty() and reduced.formations[0] == saved, "restart accepts missing formation references and preserves their holes")
	# Deleted content definitions also need not be available just to keep a saved record.
	var no_definition := MapLoadoutState.new()
	var definitions: Array = []
	for record: Dictionary in source.records.values():
		if record.id != missing.item_id:
			definitions.append(record)
	var registry := ContentRegistry.new()
	registry.load_base_content()
	no_definition.configure(registry, registry.get_board("base.board.bag"), definitions)
	_check(MapLoadoutStore.load_into(no_definition, SAVE).is_empty() and no_definition.apply_formation(saved.id).is_empty(), "removed catalog item does not invalidate formation loading")
	var larger := _fresh("base.board.leather")
	var migrated := larger.snapshot()
	var old_record := saved.duplicate(true)
	old_record.layout.version = 1
	old_record.layout.board_id = "base.board.bag"
	migrated.formations = [old_record]
	_check(larger.restore(migrated).is_empty() and larger.formations[0].layout == saved.layout, "legacy board-bound formation migrates on a different board")
	_check(larger.apply_formation(saved.id).is_empty() and larger.inventory.grid_size == Vector2i(4, 4) and larger.inventory.get_instance(retained.instance_id).cell == Vector2i(2, 1) and larger.inventory.get_instance(missing.instance_id).cell == Vector2i.ZERO, "larger board keeps original top-left coordinates and does not stretch or repack")
	larger.place(larger.drag_data("board", retained.instance_id), Vector2i(3, 2))
	larger.save_formation("大盘阵", ICON, saved.id, true)
	var smaller := _fresh()
	var smaller_save := smaller.snapshot()
	smaller_save.formations = larger.formations.duplicate(true)
	_check(smaller.restore(smaller_save).is_empty(), "records outside current board bounds can still be retained")
	var unchanged := smaller.snapshot()
	_check(not smaller.apply_formation(saved.id).is_empty() and smaller.snapshot() == unchanged, "insufficient board space rejects application atomically without erasing record")
	var overlap := unchanged.duplicate(true)
	overlap.formations[0].layout.placements[1].cell = [0, 0]
	smaller.restore(overlap)
	unchanged = smaller.snapshot()
	_check(not smaller.apply_formation(saved.id).is_empty() and smaller.snapshot() == unchanged, "overlapping available items still reject application atomically")
	var duplicate := unchanged.duplicate(true)
	duplicate.formations[0].layout.placements.append(duplicate.formations[0].layout.placements[0].duplicate(true))
	_check(not smaller.restore(duplicate).is_empty() and smaller.snapshot() == unchanged, "duplicate recorded item identities remain invalid")
