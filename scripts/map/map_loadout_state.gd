class_name MapLoadoutState
extends RefCounted

const RESPAWN_RULES = preload("res://scripts/map/map_respawn_rules.gd")

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
var battle_rewards: Dictionary = {}
var chest_offers: Dictionary = {}
var chest_cooldowns: Dictionary = {}
var gathering_offers: Dictionary = {}
var map_visited: Dictionary = {}
var map_location: Dictionary = {}
var content_grants: Dictionary = {"t01.115.v1": true, "qinglan.boards.v1": true, "starter.bag.v1": true}
var calendar: Dictionary = {}
var narrative: Dictionary = DialogueJournal.initial()
var encounter_cooldowns: Dictionary = {}
var storage_capacity_rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/storage_capacity.json"))
var bag_capacity: int = int(storage_capacity_rules.starting_capacity)
var spirit_stones: int = int(JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/status_header.json")).spirit_stones)
var purchase_serial := 0
var warehouses: Dictionary = {} # warehouse_id -> {unit_id: item_id}; owned, not carried.
var warehouse_rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/warehouses.json"))
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

static func valid_map_location(value: Variant) -> bool:
	if not value is Dictionary: return false
	if value.is_empty(): return true
	return value.size() == 2 and value.get("map_id") is String and value.get("point_id") is String and value.map_id.begins_with("base.map.") and value.map_id.length() <= 128 and value.point_id.begins_with(value.map_id + ".point.") and value.point_id.length() > value.map_id.length() + 7 and value.point_id.length() <= 256

func set_map_location(map_id: String, point_id: String) -> bool:
	var value := {"map_id": map_id, "point_id": point_id}
	if not valid_map_location(value) or map_location == value: return false
	map_location = value
	revision += 1
	return true

func visit_map_point(map_id: String, point_id: String) -> bool:
	if not point_id.begins_with(map_id + ".point."): return false
	var points: Array = map_visited.get(map_id, [])
	if point_id in points: return false
	points.append(point_id)
	map_visited[map_id] = points
	revision += 1
	# No inventory geometry changed; leave inventory UI rebuild signals alone.
	return true

func configure(content: ContentRegistry, layout: BoardLayout, definitions: Array) -> String:
	var calendar_error := WorldCalendar.configuration_error()
	if not calendar_error.is_empty(): return calendar_error
	calendar = WorldCalendar.initial()
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
		if record.category not in ["weapon", "armor", "artifact", "pill", "throwable", "plant", "beast", "mineral", "board"]:
			return "此物品尚未接入行囊战斗：" + String(record.name)
		if record.get("rule_version", 0) == 0 and record.category in ["artifact", "pill"] and (not record.get("effects") is Array or not ContentRegistry._positive_number(record.get("cooldown"))):
			return "法器／丹药缺少战斗效果或轮转：" + String(record.name)
		var raw := {
			"id": record.id, "name": record.name, "type": record.category, "category": record.category,
			"quality": record.quality, "tags": [record.get("subcategory", "")],
			"size": [record.footprint_columns, record.footprint_rows], "icon": record.icon,
			"cooldown": record.cooldown, "stamina_cost": record.get("base_stamina_cost", 0),
			"effects": []
		}
		if record.get("rule_version", 0) == 1:
			raw = T01Definition.item_record(record)
		elif record.category == "armor":
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
		if record.category == "board":
			if registry.get_board(record.get("board_layout", "")) == null or registry.get_cultivation(record.get("required_cultivation", "")).is_empty():
				return "阵盘引用或境界无效。"
			raw.combat = {"description": board_description(record, registry.get_board(record.board_layout), registry.get_cultivation(record.required_cultivation))}
			raw.tags = [record.get("board_level", registry.get_cultivation(record.required_cultivation).name)]
			if not String(record.get("faction", "")).is_empty(): raw.tags.append(record.faction)
		if not registry.register_item(raw):
			return "行囊物品无效：" + String(record.name) + "\n" + "\n".join(registry.errors)
		records[record.id] = record.duplicate(true)
		for index in (int(record.quantity) if record.get("grant_on_start", true) else 0):
			var id := "owned.%s.%d" % [record.id, index]
			_owned[id] = String(record.id)
			storage.put(_unit(id, record.id))
	_seed_owned = _owned.duplicate()
	return ""

static func board_description(record: Dictionary, layout: BoardLayout, rank: Dictionary) -> String:
	var lines: PackedStringArray = [record.get("origin_description", record.get("description", "")), "适用境界：%s及以上。" % rank.name]
	var resources: PackedStringArray = []
	var resource_names := {"hp": "气血", "stamina": "体力", "spirit": "灵力"}
	for key: String in resource_names:
		var bonus := layout.resource_bonus(key)
		if bonus != 0: resources.append("%s+%s" % [resource_names[key], EffectSystem.number_text(bonus)])
	if not resources.is_empty(): lines.append("上限：%s。" % "，".join(resources))
	var buffs: PackedStringArray = []
	var debuffs: PackedStringArray = []
	for status: String in layout.status_capacity_bonuses:
		var bonus := layout.status_capacity_bonus(status)
		if bonus <= 0: continue
		var target := buffs if T01Definition.is_buff(status) else debuffs
		target.append("%s+%d" % [status, bonus])
	if not buffs.is_empty(): lines.append("自身增益上限：%s。" % "，".join(buffs))
	if not debuffs.is_empty(): lines.append("施加减益上限：%s。" % "，".join(debuffs))
	return "\n".join(lines)

func has_reward(reward_id: String) -> bool:
	return granted_rewards.has(reward_id)

func buff_bonus_totals(rank: Dictionary = {}) -> Dictionary:
	var equipped: Array = []
	for entry: Dictionary in inventory.get_instances():
		equipped.append(records[entry.item_id])
	var totals := preload("res://scripts/map/map_buff_bonuses.gd").sum_sources(rank, board.buff_bonuses, equipped)
	totals.armor += T01CombatRules.inventory_link_bonus(inventory, registry).capacity
	return totals

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
	var test_replay: bool = reward.get("test_replay_on_restart", false)
	if has_reward(reward.get("id", "")) and not test_replay:
		return ""
	if test_replay and (not ContentRegistry._positive_integer(reward.get("test_storage_limit")) or reward.test_storage_limit > 10000):
		return "剧情奖励测试储物袋限额无效。"
	var next := snapshot()
	var grants: Dictionary = granted_rewards.duplicate(true)
	grants[reward.get("id", "")] = {"item_id": reward.get("item_id"), "quantity": reward.get("quantity")}
	next.granted_rewards = grants
	if records.has(reward.get("item_id")) and ContentRegistry._positive_integer(reward.get("quantity")) and reward.quantity <= 10000:
		var amount := int(reward.quantity)
		if test_replay:
			var stored := 0
			for entry: Dictionary in storage.entries():
				if entry.item_id == reward.item_id:
					stored += entry.units.size()
			amount = mini(amount, maxi(0, int(reward.test_storage_limit) - stored))
		var index := 0
		for unused in amount:
			# Existing reward units may be equipped; never overwrite their IDs.
			if test_replay:
				while next.owned_units.has("reward.%s.%d" % [reward.id, index]):
					index += 1
			next.owned_units["reward.%s.%d" % [reward.id, index]] = reward.item_id
			index += 1
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
		if record.category == "board": record.active_board = record.board_layout == board.id
		result.append(record)
	return result

func storage_capacity_limit() -> int:
	var test_limit := int(storage_capacity_rules.get("test_capacity_override", 0))
	return test_limit if test_limit > 0 else bag_capacity

func warehouse_records(id: String) -> Array:
	var grouped := SharedStorage.new()
	for unit_id: String in warehouses.get(id, {}):
		grouped.put(_unit(unit_id, warehouses[id][unit_id]))
	var result: Array = []
	for entry: Dictionary in grouped.entries():
		var record: Dictionary = records[entry.item_id].duplicate(true)
		record.quantity = entry.units.size()
		record.storage_id = entry.instance_id
		record.identified = can_use_item(entry.item_id)
		result.append(record)
	return result

func warehouse_capacity_limit(id: String) -> int:
	return int(warehouse_rules.get(id, {}).get("test_capacity", 99))

func carried_owned() -> Dictionary:
	var result := _owned.duplicate()
	for units: Dictionary in warehouses.values():
		for unit_id: String in units: result.erase(unit_id)
	return result

func transfer_warehouse(id: String, item_id: String, withdraw: bool, all_items: bool = false, quantity: int = -1) -> String:
	if not warehouse_rules.has(id) or (not all_items and not records.has(item_id)): return "仓库或物品无效。"
	if inventory.locked: return "当前不能存取仓库。"
	if not all_items and not withdraw and records[item_id].get("board_layout", "") == board.id: return "正在使用的阵盘不能存入仓库。"
	if not all_items:
		if quantity == 0 or quantity < -1: return "转移数量无效。"
		var available := 0
		var source := warehouse_records(id) if withdraw else storage_records()
		for record: Dictionary in source:
			if record.id == item_id: available += int(record.quantity)
		if quantity > available: return "转移数量超过该侧当前拥有数量。"
	var next := snapshot()
	if not next.has("warehouses"): next.warehouses = {}
	if not next.warehouses.has(id): next.warehouses[id] = {}
	var moved := 0
	if withdraw:
		for unit_id: String in next.warehouses[id].keys():
			if not all_items and quantity > 0 and moved >= quantity: break
			if all_items or next.warehouses[id][unit_id] == item_id:
				next.warehouses[id].erase(unit_id)
				moved += 1
	else:
		for entry: Dictionary in storage.entries():
			if not all_items and entry.item_id != item_id: continue
			# Only loose bag stacks move; the active board stays with the player.
			if records[entry.item_id].get("board_layout", "") == board.id: continue
			for unit: Dictionary in entry.units:
				if not all_items and quantity > 0 and moved >= quantity: break
				next.warehouses[id][unit.id] = entry.item_id
				moved += 1
	if moved == 0: return "该侧已没有此物品。"
	if next.warehouses[id].is_empty(): next.warehouses.erase(id)
	return restore(next)

func storage_used_slots() -> int:
	var kinds := {}
	for entry: Dictionary in storage.entries():
		kinds[entry.item_id] = true
	return kinds.size()

# Better bags update this durable value; the test override is not saved.
# Capacity enforcement is deferred during testing.
func set_bag_capacity(value: int) -> String:
	if value <= 0: return "储物袋容量须为正整数。"
	if bag_capacity == value: return ""
	bag_capacity = value
	revision += 1
	changed.emit()
	return ""

func can_use_item(item_id: String) -> bool:
	var item := registry.get_item(item_id)
	if item != null and item.category == "board":
		var required := registry.get_cultivation(records[item_id].required_cultivation)
		return int(registry.get_cultivation(cultivation_rank_id).get("order", -1)) >= int(required.order)
	return item != null and MapItemQuality.usable(item.quality, registry.get_cultivation(cultivation_rank_id))

func select_board(item_id: String) -> String:
	if inventory.locked: return "当前不能更换阵盘。"
	var record: Dictionary = records.get(item_id, {})
	if record.get("category") != "board" or item_id not in carried_owned().values(): return "未随身携带此阵盘。"
	if not can_use_item(item_id): return "尚未达到此阵盘要求的境界。"
	var selected := registry.get_board(record.board_layout)
	if selected == board: return ""
	var next_inventory := InventoryState.new(registry, selected.grid_size)
	var next_storage := SharedStorage.new()
	for entry: Dictionary in storage.entries(): next_storage.put(entry)
	for entry: Dictionary in inventory.get_instances():
		if next_inventory.put(entry, entry.cell).is_empty(): next_storage.put(entry)
	board = selected
	inventory = next_inventory
	storage = next_storage
	revision += 1
	changed.emit()
	return ""

func drag_data(source: String, id: String, quantity: int = 1) -> Dictionary:
	var entry := storage.get_entry(id) if source == "storage" else inventory.get_instance(id)
	if entry.is_empty():
		return {}
	return {"kind": "map_loadout", "owner": get_instance_id(), "revision": revision, "source": source, "id": id, "quantity": quantity}

func valid_drag(data: Variant) -> bool:
	return data is Dictionary and data.get("kind") == "map_loadout" and data.get("owner") == get_instance_id() and data.get("revision") == revision and data.get("source") in ["storage", "board"] and not drag_data(data.source, data.get("id", "")).is_empty()

func drag_entry(data: Variant) -> Dictionary:
	if not valid_drag(data):
		return {}
	return storage.peek_units(data.id, int(data.get("quantity", 1))) if data.source == "storage" else inventory.get_instance(data.id)

func can_place(data: Variant, cell: Vector2i) -> bool:
	return placement_kind(data, cell) != "invalid"

func placement_kind(data: Variant, cell: Vector2i) -> String:
	var entry := drag_entry(data)
	if entry.is_empty() or inventory.locked or not can_use_item(entry.item_id):
		return "invalid"
	if data.source == "board":
		if not inventory.swap_target(data.id, cell).is_empty(): return "swap"
		return "place" if inventory.can_move(data.id, cell) else "invalid"
	var item := registry.get_item(entry.item_id)
	if item.category in ["plant", "beast", "mineral", "board"]: return "invalid"
	if item.is_consumable():
		var matching := inventory.matching_stack(item.id)
		if entry.units.size() > 10:
			return "invalid"
		if not matching.is_empty():
			return "stack" if inventory.get_instance(matching).units.size() + entry.units.size() <= 10 else "invalid"
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
		var entry := drag_entry(data)
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
			storage.take_units(data.id, entry.units.size())
			storage.put(displaced)
		else:
			if inventory.put(entry, cell).is_empty():
				return false
			storage.take_units(data.id, entry.units.size())
	_commit()
	return true

func equip_random(id: String, quantity: int = 1) -> bool:
	var data := drag_data("storage", id, quantity)
	var entry := drag_entry(data)
	if entry.is_empty():
		return false
	if not inventory.matching_stack(entry.item_id).is_empty():
		return place(data, Vector2i.ZERO)
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
	result.version = 2
	result.bag_capacity = bag_capacity
	result.spirit_stones = spirit_stones
	result.purchase_serial = purchase_serial
	result.respawn_rules_version = RESPAWN_RULES.VERSION
	if not calendar.is_empty(): result.calendar = calendar.duplicate(true)
	result.narrative = narrative.duplicate(true)
	if not encounter_cooldowns.is_empty(): result.encounter_cooldowns = encounter_cooldowns.duplicate(true)
	result.owned_units = {}
	if not warehouses.is_empty(): result.warehouses = warehouses.duplicate(true)
	for units: Dictionary in warehouses.values():
		result.owned_units.merge(units)
	for entry: Dictionary in storage.entries() + inventory.get_instances():
		for unit: Dictionary in entry.units:
			result.owned_units[unit.id] = entry.item_id
	result.content_grants = content_grants.duplicate()
	if not battle_rewards.is_empty(): result.battle_rewards = battle_rewards.duplicate(true)
	if not chest_offers.is_empty(): result.chest_offers = chest_offers.duplicate(true)
	if not chest_cooldowns.is_empty(): result.chest_cooldowns = chest_cooldowns.duplicate(true)
	if not gathering_offers.is_empty(): result.gathering_offers = gathering_offers.duplicate(true)
	if not map_visited.is_empty(): result.map_visited = map_visited.duplicate(true)
	if not map_location.is_empty(): result.map_location = map_location.duplicate()
	if not granted_rewards.is_empty():
		result.granted_rewards = granted_rewards.duplicate(true)
	if not formations.is_empty():
		result.formations = formations.duplicate(true)
	return result

func layout_snapshot() -> Dictionary:
	return {"version": 1, "board_id": board.id, "placements": formation_snapshot().placements}

func advance_days(days: int, source_id: String) -> String:
	var error := WorldCalendar.advance(calendar,days,source_id)
	if not error.is_empty(): return error
	for cooldown: Dictionary in chest_cooldowns.values():
		cooldown.remaining_days = maxi(0,int(cooldown.ready_day)-WorldCalendar.current_day(calendar))
	revision += 1
	return ""

func formation_snapshot() -> Dictionary:
	var placements: Array = []
	for entry in inventory.get_instances():
		placements.append({"instance_id": entry.instance_id, "item_id": entry.item_id, "cell": [entry.cell.x, entry.cell.y], "unit_ids": entry.units.map(func(unit: Dictionary): return unit.id)})
	_sort_placements(placements)
	return {"placements": placements}

func restore(raw: Variant) -> String:
	if not raw is Dictionary:
		return "行囊存档格式无效。"
	var saved_stones: Variant = raw.get("spirit_stones", int(JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/status_header.json")).spirit_stones))
	var saved_serial: Variant = raw.get("purchase_serial", 0)
	if not WorldCalendar.integer_between(saved_stones,0,1000000000) or not WorldCalendar.integer_between(saved_serial,0,1000000000): return "灵石或交易流水存档无效。"
	var saved_capacity: Variant = raw.get("bag_capacity", storage_capacity_rules.starting_capacity)
	if not ContentRegistry._positive_integer(saved_capacity): return "储物袋容量存档无效。"
	var saved_calendar: Variant = raw.get("calendar",WorldCalendar.initial())
	if not WorldCalendar.valid_record(saved_calendar): return "游戏日历存档无效。"
	var saved_narrative: Variant = raw.get("narrative",DialogueJournal.initial())
	if not DialogueJournal.valid_record(saved_narrative): return "人物姓名或对话存档无效。"
	var enemy_waiting: Variant = raw.get("encounter_cooldowns",{})
	if not enemy_waiting is Dictionary: return "怪物重生日期无效。"
	for event_id: Variant in enemy_waiting:
		if not event_id is String or not event_id.begins_with("base.map_event.") or not WorldCalendar.integer_between(enemy_waiting[event_id],0,WorldCalendar.MAX_DAY): return "怪物重生日期无效。"
	var grants: Variant = raw.get("granted_rewards", {})
	var battle_receipts: Variant = raw.get("battle_rewards", {})
	var offers: Variant = raw.get("chest_offers", {})
	var chest_waiting: Variant = raw.get("chest_cooldowns", {})
	if not MapChestRewards.validate_cooldowns(chest_waiting,grants): return "宝箱等待记录无效。"
	var migrated := RESPAWN_RULES.migrate(raw.get("respawn_rules_version",0),WorldCalendar.current_day(saved_calendar),enemy_waiting,chest_waiting)
	if not migrated.error.is_empty(): return migrated.error
	enemy_waiting = migrated.encounters
	chest_waiting = migrated.chests
	var gathered: Variant = raw.get("gathering_offers", {})
	if not MapGatheringRewards.validate_offers(gathered, records): return "采集结果存档无效。"
	var explored: Variant = raw.get("map_visited", {})
	if not MapExplorationState.valid_record(explored): return "地图探索存档无效。"
	var location: Variant = raw.get("map_location", {})
	if not valid_map_location(location): return "地图落点存档无效。"
	if not MapChestRewards.validate_offers(offers,records): return "宝箱选项存档无效。"
	if not BattleLoot.validate_receipts(battle_receipts, records, registry):
		return "战斗掉落凭证无效。"
	if not grants is Dictionary:
		return "剧情奖励存档格式无效。"
	var owned := _seed_owned.duplicate()
	var receipts: Variant = raw.get("content_grants", {})
	if not receipts is Dictionary:
		return "内容补发凭证无效。"
	if raw.get("version", 1) == 2:
		if not raw.get("owned_units") is Dictionary:
			return "持有单位账本无效。"
		owned = raw.owned_units.duplicate()
		for unit_id: Variant in owned:
			if not unit_id is String or unit_id.is_empty() or not owned[unit_id] is String or not records.has(owned[unit_id]):
				return "持有单位引用未知物品。"
		if not receipts.get("t01.115.v1", false):
			for unit_id: String in _seed_owned:
				if _seed_owned[unit_id] not in owned.values():
					owned[unit_id] = _seed_owned[unit_id]
	for reward_id: Variant in grants:
		var grant: Variant = grants[reward_id]
		if not reward_id is String or not reward_id.begins_with("base.map_reward.") or not grant is Dictionary:
			return "剧情奖励存档标识无效。"
		if not grant.get("item_id") is String or not records.has(grant.item_id) or not ContentRegistry._nonnegative_integer(grant.get("quantity")) or grant.quantity < 1 or grant.quantity > 10000:
			return "剧情奖励存档物品或数量无效。"
		if raw.get("version", 1) == 1:
			for index in int(grant.quantity):
				owned["reward.%s.%d" % [reward_id, index]] = grant.item_id
	if not receipts.get("qinglan.boards.v1", false):
		for unit_id: String in _seed_owned:
			if records[_seed_owned[unit_id]].category == "board" and _seed_owned[unit_id] not in owned.values():
				owned[unit_id] = _seed_owned[unit_id]
	var selected := registry.get_board(raw.get("board_id", ""))
	if not receipts.get("starter.bag.v1", false):
		for unit_id: String in _seed_owned:
			if _seed_owned[unit_id] == "base.map_item.bag_board" and _seed_owned[unit_id] not in owned.values():
				owned[unit_id] = _seed_owned[unit_id]
	if selected == null: return "存档阵盘不存在。"
	if not selected.required_cultivation.is_empty() and int(registry.get_cultivation(cultivation_rank_id).get("order", -1)) < int(registry.get_cultivation(selected.required_cultivation).get("order", 0)):
		return "尚未达到存档阵盘要求的境界。"
	if selected.id != board.id and selected.id != "base.board.bag":
		var owned_board := false
		for item_id: String in owned.values():
			if records[item_id].get("board_layout", "") == selected.id: owned_board = true
		if not owned_board: return "未持有存档中的阵盘。"
	var saved_warehouses: Variant = raw.get("warehouses", {})
	if not saved_warehouses is Dictionary: return "仓库账本无效。"
	var carried := owned.duplicate()
	for id: Variant in saved_warehouses:
		if not id is String or not warehouse_rules.has(id) or not saved_warehouses[id] is Dictionary: return "仓库引用无效。"
		for unit_id: Variant in saved_warehouses[id]:
			if not unit_id is String or carried.get(unit_id, "") != saved_warehouses[id][unit_id]: return "仓库物品缺失或重复。"
			carried.erase(unit_id)
	if selected.id != "base.board.bag":
		var board_carried := false
		for item_id: String in carried.values():
			if records[item_id].get("board_layout", "") == selected.id: board_carried = true
		if not board_carried: return "当前阵盘必须随身携带。"
	var checked := _validate_layout(raw, carried, true, selected)
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
	warehouses = saved_warehouses.duplicate(true)
	content_grants = receipts.duplicate()
	content_grants["t01.115.v1"] = true
	content_grants["qinglan.boards.v1"] = true
	content_grants["starter.bag.v1"] = true
	granted_rewards = grants.duplicate(true)
	battle_rewards = battle_receipts.duplicate(true)
	chest_offers = offers.duplicate(true)
	chest_cooldowns = chest_waiting.duplicate(true)
	calendar = WorldCalendar.normalized(saved_calendar)
	narrative = DialogueJournal.normalized(saved_narrative)
	bag_capacity = int(saved_capacity)
	spirit_stones = int(saved_stones)
	purchase_serial = int(saved_serial)
	encounter_cooldowns = enemy_waiting.duplicate(true)
	for event_id: String in encounter_cooldowns: encounter_cooldowns[event_id]=int(encounter_cooldowns[event_id])
	for cooldown: Dictionary in chest_cooldowns.values():
		# Legacy waits start at adoption; never infer offline elapsed time.
		if not cooldown.has("ready_day"): cooldown.ready_day = WorldCalendar.current_day(calendar)+int(cooldown.remaining_days)
		if not cooldown.has("cycle"): cooldown.cycle = 1
		for key in ["cycle","ready_day","delay_days"]: cooldown[key]=int(cooldown[key])
		cooldown.remaining_days = maxi(0,int(cooldown.ready_day)-WorldCalendar.current_day(calendar))
	gathering_offers = gathered.duplicate(true)
	for offer: Dictionary in gathering_offers.values():
		offer.quantity = int(offer.quantity)
		offer.days = int(offer.days)
	map_visited = explored.duplicate(true)
	map_location = location.duplicate()
	for grant: Dictionary in granted_rewards.values():
		grant.quantity = int(grant.quantity)
	formations = restored_formations
	board = selected
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
		if not entry.get("unit_ids", [entry.instance_id]) is Array:
			return {"error": "阵型叠内单位无效。"}
		placements.append({"instance_id": entry.instance_id, "item_id": entry.item_id, "cell": [int(cell[0]), int(cell[1])], "unit_ids": entry.get("unit_ids", [entry.instance_id]).duplicate()})
	_sort_placements(placements)
	return {"error": "", "layout": {"placements": placements}}

func _validate_layout(raw: Variant, available_owned: Variant = null, return_unusable: bool = false, selected: BoardLayout = null) -> Dictionary:
	var owned: Dictionary = carried_owned() if available_owned == null else available_owned
	if selected == null: selected = board
	if not raw is Dictionary or (raw.get("version") != 1 and raw.get("version") != 2) or raw.get("board_id") != selected.id or not raw.get("placements") is Array:
		return {"error": "行囊存档格式、阵盘或版本无效。"}
	var restored := InventoryState.new(registry, selected.grid_size)
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
		var units: Array = []
		var unit_ids: Variant = entry.get("unit_ids", [entry.instance_id])
		if not unit_ids is Array or unit_ids.is_empty() or unit_ids[0] != entry.instance_id:
			return {"error": "行囊叠内单位无效。"}
		for unit_id: Variant in unit_ids:
			if not unit_id is String or owned.get(unit_id) != entry.item_id or used.has(unit_id):
				return {"error": "行囊叠内单位缺失或重复。"}
			units.append(_unit(unit_id, entry.item_id).units[0])
			used[unit_id] = true
		if restored.put({"instance_id": entry.instance_id, "item_id": entry.item_id, "units": units}, Vector2i(int(cell[0]), int(cell[1]))).is_empty():
			var item := registry.get_item(entry.item_id)
			var oversized := item.rule_version == 1 and item.is_consumable() and units.size() > 10
			if return_unusable and (oversized or not restored.equipment_allowed(item)):
				for unit: Dictionary in units: used.erase(unit.id)
				push_warning("旧阵型受新部位或数量限制，已将原单位保留在储物袋：" + entry.item_id)
				continue
			return {"error": "行囊存档物品越界或重叠。"}
		placements.append({"instance_id": entry.instance_id, "item_id": entry.item_id, "cell": [int(cell[0]), int(cell[1])], "unit_ids": unit_ids.duplicate()})
	var remaining := SharedStorage.new()
	for id: String in owned:
		if not used.has(id):
			remaining.put(_unit(id, owned[id]))
	return {"error": "", "inventory": restored, "storage": remaining, "layout": {"version": 1, "board_id": selected.id, "placements": placements}}

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
		placement.unit_ids = placement.unit_ids.filter(func(unit_id): return carried_owned().get(unit_id) == placement.item_id)
		if not placement.unit_ids.is_empty():
			placement.instance_id = placement.unit_ids[0]
			if not can_use_item(placement.item_id):
				return "阵型含有超出当前境界的物品，原布局保持不变。"
			placements.append(placement)
	var checked := _validate_layout({"version": 1, "board_id": board.id, "placements": placements})
	if not checked.error.is_empty():
		return "当前阵盘无法容纳此阵型，原布局保持不变。"
	_apply_checked_layout(checked)
	return ""
