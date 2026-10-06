class_name BattleInventoryItemCard
extends MapInventoryItemCard

# Map artwork/layout, battle commands. Never route combat edits through MapLoadoutState.
var manager: GameManager
var battle_board: InventoryView
var _battle_drag_active := false

func bind_battle(game: GameManager, board_view: InventoryView) -> void:
	manager = game
	battle_board = board_view
	set_identified(manager._durable_loadout.can_use_item(entry.id) if entry.category == "board" else manager.party[0].can_use_item(manager.registry.get_item(entry.id)))
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func drag_data() -> Dictionary:
	var storage_id: String = entry.get("storage_id", "")
	if not manager.can_edit_inventory() or not identified or manager.storage.get_entry(storage_id).is_empty():
		return {}
	return {"kind": "battle_board" if entry.category == "board" else "storage", "storage_id": storage_id, "quantity": selected_quantity(), "epoch": manager.interaction_epoch}

func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed or drag_data().is_empty():
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if entry.category == "board":
			if is_instance_valid(battle_board): battle_board.request_board_change(drag_data())
		else:
			manager.equip_random(entry.storage_id, selected_quantity())
		accept_event()
	elif event.button_index == MOUSE_BUTTON_LEFT:
		_begin_drag.call_deferred(drag_data())
		accept_event()

func _begin_drag(data: Dictionary) -> void:
	if not is_visible_in_tree() or data.is_empty() or data.get("epoch") != manager.interaction_epoch or drag_data().is_empty() or get_viewport().gui_is_dragging():
		return
	if not is_instance_valid(battle_board):
		return
	var item := manager.registry.get_item(entry.id)
	var units := manager.storage.peek_units(entry.storage_id, selected_quantity())
	_battle_drag_active = true
	manager.inventory_interaction.emit("pick")
	if entry.category == "board":
		var holder := Control.new()
		var art := TextureRect.new()
		art.texture = load(item.icon_path)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		art.mouse_filter = MOUSE_FILTER_IGNORE
		art.size = Vector2(180, 180) * battle_board.get_global_transform().get_scale().abs()
		art.position = -art.size * 0.5
		holder.add_child(art)
		force_drag(data, holder)
	else:
		force_drag(data, battle_board.make_drag_preview(item, units))
	modulate.a = 0.4

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _battle_drag_active:
		_battle_drag_active = false
		modulate.a = 1.0
		if not get_viewport().gui_is_drag_successful():
			manager.inventory_interaction.emit("invalid")

func _make_custom_tooltip(_for_text: String) -> Object:
	var tooltip := ItemTooltip.new()
	tooltip.configure(manager.registry.get_item(entry.id), manager.storage.get_entry(entry.storage_id), -1, 0, identified)
	return tooltip
