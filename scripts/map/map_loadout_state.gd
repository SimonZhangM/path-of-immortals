class_name MapLoadoutState
extends RefCounted

signal changed
signal interaction(kind: String)
signal formations_changed

var registry: ContentRegistry
var cultivation_rank_id := "base.cultivation.mortal"
var board: BoardLayout
var inventory: InventoryState
var storage := SharedStorage.new()
var records: Dictionary = {}
var revision := 0
var formations: Array[Dictionary] = []
var formation_icons: Array[String] = []
var _owned: Dictionary = {}
var _seed_owned: Dictionary = {}
var granted_rewards: Dictionary = {}
var _rng := RandomNumberGenerator.new()

# Explicitly retired test definitions only; unrelated unknown save IDs still fail.
const RETIRED_VARIANT_BASES := ["qingshi_short_sword", "hunting_bow", "short_iron_hammer", "coarse_cloth_armor", "old_iron_helmet", "round_wood_shield"]

static func is_retired_variant(instance_id: String, item_id: String) -> bool:
	for base in RETIRED_VARIANT_BASES:
		for suffix in ["a", "b", "c"]:
			var retired := "base.map_item.%s_%s" % [base, suffix]
			if item_id == retired and instance_id == "owned.%s.0" % retired:
				return true
	return false

func configure(content: ContentRegistry, layout: BoardLayout, definitions: Array) -> String:
	registry = content
	cultivation_rank_id = registry.get_character("base.character.chen_yu").get("cultivation_rank", "base.cultivation.mortal")
	board = layout
	inventory = InventoryState.new(registry, board.grid_size)
	var ui: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/map_inventory.json"))
	for option: Dictionary in ui.get("formation_icons", []):
		formation_icons.append(option.icon)
	_rng.randomize()
	for record: Dictionary in definitions:
		if not preload("res://scripts/map/map_buff_bonuses.gd").valid(record.get("buff_bonuses", {})):
			return "物品常驻增益加成无效。"
		if record.category not in ["weapon", "armor", "artifact", "pill"]:
			return "此物品尚未接入行囊战斗：" + String(record.name)
		if record.category in ["artifact", "pill"] and (not record.get("effects") is Array or not ContentRegistry._positive_number(record.get("cooldown"))):
			return "法器／丹药缺少战斗效果或轮转：" + String(record.name)
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
		elif record.category == "weapon":
			raw.tags.append(record.damage_type)
			raw.effects.append({"trigger": "on_activate", "effect": "damage", "value": record.base_damage, "damage_type": record.damage_type})
		else:
			raw.effects = record.effects.duplicate(true)
			raw.uses_per_unit = record.get("uses_per_unit", 0)
		if not registry.register_item(raw):
			return "行囊物品无效：" + String(record.name)
		records[record.id] = record.duplicate(true)
		for index in int(record.quantity):
			var id := "owned.%s.%d" % [record.id, index]
			_owned[id] = String(record.id)
			storage.put(_unit(id, record.id))
	_seed_owned = _owned.duplicate()
	return ""

func has_reward(reward_id: String) -> bool:
	return granted_rewards.has(reward_id)

func reward_candidate(reward: Dictionary) -> Dictionary:
	var candidate := MapLoadoutState.new()
	candidate.registry = registry
	candidate.cultivation_rank_id = cultivation_rank_id
	candidate.board = board
	candidate.records = records.duplicate(true)
	candidate._seed_owned = _seed_owned.duplicate()
	candidate.formation_icons = formation_icons.duplicate()
	var error := candidate.restore(snapshot())
	if error.is_empty():
		error = candidate.add_reward(reward)
	return {"state": candidate, "error": error}

func add_reward(reward: Dictionary) -> String:
	if has_reward(reward.get("id", "")):
		return ""
	var next := snapshot()
	var grants: Dictionary = granted_rewards.duplicate(true)
	grants[reward.get("id", "")] = {"item_id": reward.get("item_id"), "quantity": reward.get("quantity")}
	next.granted_rewards = grants
	return restore(next)

func _unit(id: String, item_id: String) -> Dictionary:
	return {"instance_id": id, "item_id": item_id, "units": [{"id": id, "uses_left": registry.get_item(item_id).uses_per_unit}]}

func storage_records() -> Array:
	var result: Array = []
	for entry in storage.entries():
		var record: Dictionary = records[entry.item_id].duplicate(true)
		record.quantity = entry.units.size()
		record.storage_id = entry.instance_id
		record.identified = can_use_item(entry.item_id)
		result.append(record)
	return result

func can_use_item(item_id: String) -> bool:
	var item := registry.get_item(item_id)
	return item != null and MapItemQuality.usable(item.quality, registry.get_cultivation(cultivation_rank_id))

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
	return placement_kind(data, cell) != "invalid"

func placement_kind(data: Variant, cell: Vector2i) -> String:
	var entry := drag_entry(data)
	if entry.is_empty() or inventory.locked or not can_use_item(entry.item_id):
		return "invalid"
	if data.source == "board":
		return "place" if inventory.can_move(data.id, cell) else "invalid"
	var item := registry.get_item(entry.item_id)
	var target := Rect2i(cell, item.grid_size)
	if not Rect2i(Vector2i.ZERO, inventory.grid_size).encloses(target):
		return "invalid"
	var overlaps := _overlapping_items(target)
	return "place" if overlaps.is_empty() else ("swap" if overlaps.size() == 1 else "invalid")

func _overlapping_items(target: Rect2i) -> Array[String]:
	var result: Array[String] = []
	for entry in inventory.get_instances():
		if target.intersects(Rect2i(entry.cell, registry.get_item(entry.item_id).grid_size)):
			result.append(entry.instance_id)
	return result

func place(data: Variant, cell: Vector2i) -> bool:
	var kind := placement_kind(data, cell)
	if kind == "invalid":
		interaction.emit("invalid")
		return false
	if data.source == "board":
		inventory.move_item(data.id, cell)
	else:
		var entry := storage.peek_one(data.id)
		if kind == "swap":
			# Build the entire exchange before replacing live state or consuming storage.
			var target := Rect2i(cell, registry.get_item(entry.item_id).grid_size)
			var displaced := inventory.get_instance(_overlapping_items(target)[0])
			var replacement := InventoryState.new(registry, inventory.grid_size)
			for equipped in inventory.get_instances():
				if equipped.instance_id != displaced.instance_id and replacement.put(equipped, equipped.cell).is_empty():
					return false
			if replacement.put(entry, cell).is_empty():
				return false
			inventory = replacement
			storage.take_one(data.id)
			storage.put(displaced)
		else:
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
	var result := layout_snapshot()
	if not granted_rewards.is_empty():
		result.granted_rewards = granted_rewards.duplicate(true)
	if not formations.is_empty():
		result.formations = formations.duplicate(true)
	return result

func layout_snapshot() -> Dictionary:
	return {"version": 1, "board_id": board.id, "placements": formation_snapshot().placements}

func formation_snapshot() -> Dictionary:
	var placements: Array = []
	for entry in inventory.get_instances():
		placements.append({"instance_id": entry.instance_id, "item_id": entry.item_id, "cell": [entry.cell.x, entry.cell.y]})
	_sort_placements(placements)
	return {"placements": placements}

func restore(raw: Variant) -> String:
	if not raw is Dictionary:
		return "行囊存档格式无效。"
	var grants: Variant = raw.get("granted_rewards", {})
	if not grants is Dictionary:
		return "剧情奖励存档格式无效。"
	var owned := _seed_owned.duplicate()
	for reward_id: Variant in grants:
		var grant: Variant = grants[reward_id]
		if not reward_id is String or not reward_id.begins_with("base.map_reward.") or not grant is Dictionary:
			return "剧情奖励存档标识无效。"
		if not grant.get("item_id") is String or not records.has(grant.item_id) or not ContentRegistry._nonnegative_integer(grant.get("quantity")) or grant.quantity < 1 or grant.quantity > 10000:
			return "剧情奖励存档物品或数量无效。"
		for index in int(grant.quantity):
			owned["reward.%s.%d" % [reward_id, index]] = grant.item_id
	var checked := _validate_layout(raw, owned, true)
	if not checked.error.is_empty():
		return checked.error
	if not raw.get("formations", []) is Array:
		return "阵型存档格式无效。"
	var restored_formations: Array[Dictionary] = []
	var ids := {}
	for entry: Variant in raw.get("formations", []):
		if not entry is Dictionary or not entry.get("id") is String or entry.id.is_empty() or ids.has(entry.id):
			return "阵型存档标识无效或重复。"
		var error := _formation_details_error(entry.get("name"), entry.get("icon"))
		if not error.is_empty():
			return error
		var layout := _validate_formation_layout(entry.get("layout"))
		if not layout.error.is_empty():
			return "阵型「%s」：%s" % [entry.name, layout.error]
		ids[entry.id] = true
		restored_formations.append({"id": entry.id, "name": entry.name, "icon": entry.icon, "layout": layout.layout})
	_owned = owned
	granted_rewards = grants.duplicate(true)
	formations = restored_formations
	_apply_checked_layout(checked)
	formations_changed.emit()
	return ""

func _sort_placements(placements: Array) -> void:
	placements.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.cell[0] < b.cell[0] if a.cell[1] == b.cell[1] else a.cell[1] < b.cell[1])

func _validate_formation_layout(raw: Variant) -> Dictionary:
	# Legacy formation layouts included version/board_id. Normalize away board metadata.
	if not raw is Dictionary or raw.get("version", 1) != 1 or not raw.get("placements") is Array:
		return {"error": "阵型道具记录格式无效。"}
	var placements: Array = []
	var used := {}
	for entry: Variant in raw.placements:
		if not entry is Dictionary or not entry.get("instance_id") is String or not entry.get("item_id") is String:
			return {"error": "阵型道具信息无效。"}
		if entry.instance_id.is_empty() or entry.item_id.is_empty() or used.has(entry.instance_id):
			return {"error": "阵型道具标识无效或重复。"}
		var cell: Variant = entry.get("cell")
		if not cell is Array or cell.size() != 2 or not ContentRegistry._nonnegative_integer(cell[0]) or not ContentRegistry._nonnegative_integer(cell[1]):
			return {"error": "阵型格位无效。"}
		if cell[0] > 2147483647 or cell[1] > 2147483647:
			return {"error": "阵型格位无效。"}
		used[entry.instance_id] = true
		placements.append({"instance_id": entry.instance_id, "item_id": entry.item_id, "cell": [int(cell[0]), int(cell[1])]})
	_sort_placements(placements)
	return {"error": "", "layout": {"placements": placements}}

func _validate_layout(raw: Variant, available_owned: Variant = null, return_unusable: bool = false) -> Dictionary:
	var owned: Dictionary = _owned if available_owned == null else available_owned
	if not raw is Dictionary or raw.get("version") != 1 or raw.get("board_id") != board.id or not raw.get("placements") is Array:
		return {"error": "行囊存档格式、阵盘或版本无效。"}
	var restored := InventoryState.new(registry, board.grid_size)
	var placements: Array = []
	var used := {}
	var seen := {}
	for entry: Variant in raw.placements:
		if not entry is Dictionary or not entry.get("instance_id") is String or not entry.get("item_id") is String:
			return {"error": "行囊存档物品信息无效。"}
		if not records.has(entry.item_id) and is_retired_variant(entry.instance_id, entry.item_id):
			continue
		if owned.get(entry.instance_id) != entry.item_id or seen.has(entry.instance_id):
			return {"error": "行囊存档含缺失或重复物品。"}
		seen[entry.instance_id] = true
		var cell: Variant = entry.get("cell")
		if not cell is Array or cell.size() != 2 or not ContentRegistry._nonnegative_integer(cell[0]) or not ContentRegistry._nonnegative_integer(cell[1]):
			return {"error": "行囊存档格位无效。"}
		if not can_use_item(entry.item_id):
			if return_unusable:
				continue
			return {"error": "修为不足，暂不可使用此物。"}
		if not restored.add_item(entry.instance_id, entry.item_id, Vector2i(int(cell[0]), int(cell[1]))):
			return {"error": "行囊存档物品越界或重叠。"}
		used[entry.instance_id] = true
		placements.append({"instance_id": entry.instance_id, "item_id": entry.item_id, "cell": [int(cell[0]), int(cell[1])]})
	var remaining := SharedStorage.new()
	for id: String in owned:
		if not used.has(id):
			remaining.put(_unit(id, owned[id]))
	return {"error": "", "inventory": restored, "storage": remaining, "layout": {"version": 1, "board_id": board.id, "placements": placements}}

func _apply_checked_layout(checked: Dictionary) -> void:
	inventory = checked.inventory
	storage = checked.storage
	revision += 1
	changed.emit()

func _formation_details_error(formation_name: Variant, icon: Variant) -> String:
	if not formation_name is String or formation_name.strip_edges().is_empty() or formation_name.length() > 12:
		return "阵型名称须为1至12个字。"
	if not icon is String or icon not in formation_icons:
		return "请选择有效的阵型图标。"
	return ""

func find_formation(id: String) -> Dictionary:
	for entry in formations:
		if entry.id == id:
			return entry.duplicate(true)
	return {}

func save_formation(formation_name: String, icon: String, id: String = "", replace_layout: bool = false, capture_new_layout: bool = true) -> String:
	var error := _formation_details_error(formation_name, icon)
	if not error.is_empty():
		return error
	if id.is_empty():
		var layout := formation_snapshot() if capture_new_layout else {"placements": []}
		formations.append({"id": Crypto.new().generate_random_bytes(12).hex_encode(), "name": formation_name.strip_edges(), "icon": icon, "layout": layout})
	else:
		var index := -1
		for position in formations.size():
			if formations[position].id == id:
				index = position
		if index < 0:
			return "该阵型已不存在。"
		formations[index].name = formation_name.strip_edges()
		formations[index].icon = icon
		if replace_layout:
			formations[index].layout = formation_snapshot()
	revision += 1
	formations_changed.emit()
	return ""

func apply_formation(id: String) -> String:
	var entry := find_formation(id)
	if entry.is_empty():
		return "该阵型已不存在。"
	var saved := _validate_formation_layout(entry.layout)
	if not saved.error.is_empty():
		return saved.error
	var placements: Array = []
	for placement: Dictionary in saved.layout.placements:
		# Ownership includes equipped items. Missing units leave holes; never substitute copies.
		if _owned.get(placement.instance_id) == placement.item_id:
			if not can_use_item(placement.item_id):
				return "阵型含有超出当前境界的物品，原布局保持不变。"
			placements.append(placement)
	var checked := _validate_layout({"version": 1, "board_id": board.id, "placements": placements})
	if not checked.error.is_empty():
		return "当前阵盘无法容纳此阵型，原布局保持不变。"
	_apply_checked_layout(checked)
	return ""
