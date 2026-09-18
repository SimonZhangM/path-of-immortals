class_name MapLoadoutState
extends RefCounted

signal changed
signal interaction(kind: String)

var registry: ContentRegistry
var board: BoardLayout
var inventory: InventoryState
var storage := SharedStorage.new()
var records: Dictionary = {}
var revision := 0
var _owned: Dictionary = {}
var _rng := RandomNumberGenerator.new()

func configure(content: ContentRegistry, layout: BoardLayout, definitions: Array) -> String:
	registry = content
	board = layout
	inventory = InventoryState.new(registry, board.grid_size)
	_rng.randomize()
	for record: Dictionary in definitions:
		if record.category not in ["weapon", "armor"]:
			return "此物品尚未接入行囊战斗：" + String(record.name)
		var raw := {
			"id": record.id, "name": record.name, "type": record.category, "category": record.category,
			"quality": record.quality, "tags": [record.get("subcategory", "")],
			"size": [record.footprint_columns, record.footprint_rows], "icon": record.icon,
			"cooldown": record.cooldown, "stamina_cost": record.get("base_stamina_cost", 0),
			"effects": []
		}
		if record.category == "armor":
			raw.armor_capacity = record.armor_capacity
			raw.armor_type = record.get("armor_type", "")
			raw.armor_slot = record.subcategory
			raw.effects.append({"trigger": "on_activate", "effect": "restore_armor", "value": record.armor_gain})
		else:
			raw.tags.append(record.damage_type)
			raw.effects.append({"trigger": "on_activate", "effect": "damage", "value": record.base_damage})
		if not registry.register_item(raw):
			return "行囊物品无效：" + String(record.name)
		records[record.id] = record.duplicate(true)
		for index in int(record.quantity):
			var id := "owned.%s.%d" % [record.id, index]
			_owned[id] = String(record.id)
			storage.put(_unit(id, record.id))
	return ""

func _unit(id: String, item_id: String) -> Dictionary:
	return {"instance_id": id, "item_id": item_id, "units": [{"id": id, "uses_left": 0}]}

func storage_records() -> Array:
	var result: Array = []
	for entry in storage.entries():
		var record: Dictionary = records[entry.item_id].duplicate(true)
		record.quantity = entry.units.size()
		record.storage_id = entry.instance_id
		result.append(record)
	return result

func drag_data(source: String, id: String) -> Dictionary:
	var entry := storage.get_entry(id) if source == "storage" else inventory.get_instance(id)
	if entry.is_empty():
		return {}
	return {"kind": "map_loadout", "owner": get_instance_id(), "revision": revision, "source": source, "id": id}

func valid_drag(data: Variant) -> bool:
	return data is Dictionary and data.get("kind") == "map_loadout" and data.get("owner") == get_instance_id() and data.get("revision") == revision and data.get("source") in ["storage", "board"] and not drag_data(data.source, data.get("id", "")).is_empty()

func drag_entry(data: Variant) -> Dictionary:
	if not valid_drag(data):
		return {}
	return storage.peek_one(data.id) if data.source == "storage" else inventory.get_instance(data.id)

func can_place(data: Variant, cell: Vector2i) -> bool:
	var entry := drag_entry(data)
	if entry.is_empty():
		return false
	return inventory.can_move(data.id, cell) if data.source == "board" else cell in inventory.available_cells(entry.item_id)

func place(data: Variant, cell: Vector2i) -> bool:
	if not can_place(data, cell):
		interaction.emit("invalid")
		return false
	if data.source == "board":
		inventory.move_item(data.id, cell)
	else:
		var entry := storage.peek_one(data.id)
		if inventory.put(entry, cell).is_empty():
			return false
		storage.take_one(data.id)
	_commit()
	return true

func equip_random(id: String) -> bool:
	var data := drag_data("storage", id)
	var entry := drag_entry(data)
	if entry.is_empty():
		return false
	var cells := inventory.available_cells(entry.item_id)
	if cells.is_empty():
		interaction.emit("invalid")
		return false
	return place(data, cells[_rng.randi_range(0, cells.size() - 1)])

func take_back(data: Variant) -> bool:
	if not valid_drag(data) or data.source != "board":
		return false
	storage.put(inventory.take(data.id))
	_commit()
	return true

func _commit() -> void:
	revision += 1
	changed.emit()
	interaction.emit("place")

func snapshot() -> Dictionary:
	var placements: Array = []
	for entry in inventory.get_instances():
		placements.append({"instance_id": entry.instance_id, "item_id": entry.item_id, "cell": [entry.cell.x, entry.cell.y]})
	return {"version": 1, "board_id": board.id, "placements": placements}

func restore(raw: Variant) -> String:
	if not raw is Dictionary or raw.get("version") != 1 or raw.get("board_id") != board.id or not raw.get("placements") is Array:
		return "行囊存档格式或版本无效。"
	var restored := InventoryState.new(registry, board.grid_size)
	var used := {}
	for entry: Variant in raw.placements:
		if not entry is Dictionary or not entry.get("instance_id") is String or not entry.get("item_id") is String:
			return "行囊存档物品信息无效。"
		if _owned.get(entry.instance_id) != entry.item_id or used.has(entry.instance_id):
			return "行囊存档含未知或重复物品。"
		var cell: Variant = entry.get("cell")
		if not cell is Array or cell.size() != 2 or not ContentRegistry._nonnegative_integer(cell[0]) or not ContentRegistry._nonnegative_integer(cell[1]):
			return "行囊存档格位无效。"
		if not restored.add_item(entry.instance_id, entry.item_id, Vector2i(int(cell[0]), int(cell[1]))):
			return "行囊存档物品越界或重叠。"
		used[entry.instance_id] = true
	var remaining := SharedStorage.new()
	for id: String in _owned:
		if not used.has(id):
			remaining.put(_unit(id, _owned[id]))
	inventory = restored
	storage = remaining
	revision += 1
	changed.emit()
	return ""
