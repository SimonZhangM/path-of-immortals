extends SceneTree

var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func settle() -> void:
	for i in 8: await process_frame
func click(point: Vector2, button: int) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = button
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
func run() -> void:
	create_timer(40).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(2560,1440)
	var registry := ContentRegistry.new()
	check(registry.load_base_content(), "content loads")
	var created := MapLoadoutStore.create_state(registry, registry.get_board("base.board.bag"))
	check(created.error.is_empty(), "board catalog loads")
	var model: MapLoadoutState = created.state
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/map_inventory.json"))
	var catalog := MapInventoryCatalog.new()
	catalog.configure(config)
	catalog.replace_entries(model.storage_records())
	catalog.set_filter("category", "board")
	var ui := MapInventoryScreen.new()
	ui.configure(catalog, config, model.board, model)
	root.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.show()
	await settle()
	var levels := ["入门", "炼气", "筑基", "结丹", "元婴", "化神"]
	var names := ["晓岚", "听风", "凝翠", "流霞", "凌霄", "太虚"]
	var target: MapInventoryItemCard
	for card: MapInventoryItemCard in ui.grid.get_children():
		if card.entry.id == "base.map_item.bag_board": continue
		var n := int(String(card.entry.id).right(1)) - 1
		check(card.entry.name == "青岚 · " + names[n], "new board name")
		var tags := card.canvas.get_node("CategoryTags")
		check(tags.get_child_count() == 2 and tags.get_child(0).text == levels[n] and tags.get_child(1).text == "青岚宗", "level and faction tags")
		check(registry.get_item(card.entry.id).tags == [levels[n], "青岚宗"], "tooltip uses same tags")
		if n == 5: target = card
	for n in [4,5]:
		var texture: Texture2D = load("res://assets/level-%d.webp" % n)
		check(texture.get_image().has_mipmaps(), "updated background has mipmaps")
	var data := model.drag_data("storage", target.entry.storage_id)
	var original := model.snapshot()
	check(ui.loadout_board._can_drop_data(ui.loadout_board.size * 0.5, data), "board accepts owned board drop")
	check(not ui.loadout_board._can_drop_data(Vector2(-1,-1), data), "outside board rejects drop")
	if DisplayServer.get_name() == "headless":
		var source := target.get_global_rect().get_center()
		var destination := ui.loadout_board.get_global_rect().get_center()
		var move := InputEventMouseMotion.new()
		move.position = source
		move.global_position = source
		Input.parse_input_event(move)
		var down := InputEventMouseButton.new()
		down.position = source
		down.global_position = source
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		down.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(down)
		await settle()
		check(root.gui_is_dragging(), "native left-click starts board preview")
		move = InputEventMouseMotion.new()
		move.position = destination
		move.global_position = destination
		move.relative = destination-source
		move.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(move)
		await settle()
		var up := InputEventMouseButton.new()
		up.position = destination
		up.global_position = destination
		up.button_index = MOUSE_BUTTON_LEFT
		Input.parse_input_event(up)
		await settle()
	else:
		ui.loadout_board._drop_data(ui.loadout_board.size * 0.5, data)
		await settle()
	check(ui.is_board_change_dialog_open() and model.snapshot() == original, "drop only prompts, does not mutate")
	check(ui.board_change_dialog.canvas.get_child(0).texture.atlas.resource_path.ends_with("UI-jiaohu-size0.webp"), "shared confirmation artwork")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/board-change-dialog.png")
	ui.board_change_dialog.cancel_button.pressed.emit()
	check(not ui.is_board_change_dialog_open() and model.snapshot() == original, "cancel preserves all inventory")
	ui.loadout_board.request_board_change(data)
	click(Vector2(20,20), MOUSE_BUTTON_RIGHT)
	check(not ui.is_board_change_dialog_open() and model.snapshot() == original, "right-click cancels")
	ui.loadout_board.request_board_change(data)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape, true)
	check(not ui.is_board_change_dialog_open() and ui.visible, "escape cancels without closing inventory")
	ui.loadout_board.request_board_change(data)
	if DisplayServer.get_name() == "headless":
		click(ui.board_change_dialog.confirm_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	else: ui.board_change_dialog.confirm_button.pressed.emit()
	await settle()
	check(model.board.id == "base.board.qinglan_6" and not ui.is_board_change_dialog_open(), "confirm changes selected board")
	check(model.snapshot().owned_units == original.owned_units, "switch consumes no items")
	check(not ui.loadout_board.can_request_board_change(data), "stale drop rejected after switch")
	model.cultivation_rank_id = "base.cultivation.mortal"
	var locked_data := model.drag_data("storage", "owned.base.map_item.qinglan_board_5.0")
	check(not ui.loadout_board.can_request_board_change(locked_data), "realm gate rejects drag")
	model.cultivation_rank_id = "base.cultivation.spirit_transformation"
	model.inventory.locked = true
	check(not ui.loadout_board.can_request_board_change(locked_data), "locked inventory rejects switch")
	model.inventory.locked = false
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/board-cards-renamed.png")
	ui.queue_free()
	await settle()
	print("BOARD CHANGE: %d checks; %d failures" % [checks, failures])
	quit(1 if failures else 0)
