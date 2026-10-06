class_name BattleStoragePanel
extends MapInventoryScreen

var manager: GameManager
var target_board: InventoryView
var cards: Dictionary = {}
var _dirty := true

func configure_battle(game: GameManager) -> void:
	manager = game
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/map_inventory.json"))
	catalog = MapInventoryCatalog.new()
	catalog.configure(config)
	theme = _theme()
	name = "BattleStoragePanel"
	texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	body = HBoxContainer.new()
	add_child(body)
	body.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_build_storage()
	var close := _compact_button(search.get_parent(), "×", 30)
	close.name = "CloseBattleStorage"
	close.tooltip_text = "关闭储物袋"
	close.pressed.connect(func(): manager.set_adjustment(false))
	catalog.changed.connect(_refresh)
	manager.inventory_changed.connect(func(): _dirty = true)
	manager.adjustment_changed.connect(func():
		visible = manager.adjustment_open
		_dirty = true
		if not visible and get_viewport().gui_is_dragging():
			get_viewport().gui_cancel_drag()
	)
	manager.battle_restarted.connect(func(): _dirty = true)
	visible = manager.adjustment_open
	# Defer the full card catalog until the panel is actually opened, so battle
	# entry does not wait for 115 hidden cards and their fonts/artwork.
	_refresh()

func _sync_records() -> void:
	var records := manager._durable_loadout.storage_records()
	for record: Dictionary in records:
		record.identified = manager._durable_loadout.can_use_item(record.id) if record.category == "board" else manager.party[0].can_use_item(manager.registry.get_item(record.id))
	var error := catalog.replace_entries(records)
	if not error.is_empty():
		push_error(error)
	_dirty = false

func _process(_delta: float) -> void:
	if _dirty and visible:
		_sync_records()

func _refresh() -> void:
	super._refresh()
	cards.clear()
	for card in grid.get_children():
		cards[card.entry.storage_id] = card

func _add_item_card(entry: Dictionary) -> void:
	var card := BattleInventoryItemCard.new()
	card.configure(entry, catalog.category_names[entry.category])
	card.bind_battle(manager, target_board)
	grid.add_child(card)

func _enable_storage_drop(node: Node) -> void:
	if node is Control:
		node.set_drag_forwarding(Callable(), _can_drop_data, _drop_data)
	for child in node.get_children():
		_enable_storage_drop(child)

func _can_drop_data(_point: Vector2, data: Variant) -> bool:
	if not manager.can_edit_inventory() or not data is Dictionary or data.get("kind") != "inventory" or data.get("epoch") != manager.interaction_epoch:
		return false
	return manager.can_unequip(int(data.get("member_index", -1)), data.get("instance_id", ""))

func _drop_data(point: Vector2, data: Variant) -> void:
	if _can_drop_data(point, data):
		manager.unequip(data.member_index, data.instance_id)

func _input(_event: InputEvent) -> void:
	# Map formation shortcuts are not part of this storage-only view.
	pass

func _layout() -> void:
	_size_item_cards()
