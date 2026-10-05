class_name InventoryState
extends RefCounted

# Standalone legacy fixtures use four cells; live actors pass their board dimensions.
var grid_size: Vector2i
var locked: bool = false
var revision: int = 0
var _registry: ContentRegistry
var _instances: Dictionary = {}

func _init(registry: ContentRegistry, dimensions: Vector2i = Vector2i(4, 4)) -> void:
	_registry = registry
	grid_size = dimensions

func add_item(instance_id: String, item_id: String, cell: Vector2i, vertical_book := false) -> bool:
	if locked or instance_id.is_empty() or _instances.has(instance_id):
		return false
	var item := _registry.get_item(item_id)
	if item == null: return false
	if vertical_book and (item.category != "book" or item.grid_size != Vector2i(2,1)): return false
	var dimensions := Vector2i(1,2) if vertical_book else item.grid_size
	if not _fits(cell, dimensions, ""):
		return false
	if not equipment_allowed(item):
		return false
	_instances[instance_id] = {"instance_id": instance_id, "item_id": item_id, "cell": cell, "units": [{"id": instance_id, "uses_left": item.uses_per_unit}]}
	if vertical_book: _instances[instance_id].vertical_book = true
	revision += 1
	return true

func get_instances() -> Array:
	return _instances.values().duplicate(true)

func get_instance(instance_id: String) -> Dictionary:
	return _instances.get(instance_id, {}).duplicate(true)

func instance_size(instance_id: String) -> Vector2i:
	var entry: Dictionary = _instances.get(instance_id,{})
	if entry.is_empty(): return Vector2i.ZERO
	return Vector2i(1,2) if entry.get("vertical_book",false) else _registry.get_item(entry.item_id).grid_size

func item_at(cell: Vector2i) -> String:
	for instance_id in _instances:
		var instance: Dictionary = _instances[instance_id]
		var item := _registry.get_item(instance["item_id"])
		if Rect2i(instance["cell"], instance_size(instance_id)).has_point(cell):
			return instance_id
	return ""

func can_move(instance_id: String, cell: Vector2i) -> bool:
	if locked or not _instances.has(instance_id):
		return false
	var item := _registry.get_item(_instances[instance_id]["item_id"])
	return _fits(cell, instance_size(instance_id), instance_id)

func move_item(instance_id: String, cell: Vector2i) -> bool:
	if not can_move(instance_id, cell):
		return false
	if _instances[instance_id]["cell"] != cell:
		_instances[instance_id]["cell"] = cell
		revision += 1
	return true

func occupied_cells() -> int:
	var count := 0
	for instance in _instances.values():
		var dimensions := _registry.get_item(instance["item_id"]).grid_size
		count += dimensions.x * dimensions.y
	return count

func matching_stack(item_id: String) -> String:
	if not _registry.get_item(item_id).is_consumable():
		return ""
	for id in _instances:
		if _instances[id]["item_id"] == item_id:
			return id
	return ""

func available_cells(item_id: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var item := _registry.get_item(item_id)
	if item != null and not locked:
		for y in grid_size.y:
			for x in grid_size.x:
				if _fits(Vector2i(x, y), item.grid_size, ""):
					result.append(Vector2i(x, y))
	return result

func put(entry: Dictionary, cell: Vector2i) -> String:
	if locked or entry.is_empty():
		return ""
	var matching := matching_stack(entry["item_id"])
	var item := _registry.get_item(entry.item_id)
	if item == null:
		return ""
	if item.rule_version == 1 and item.is_consumable():
		var current: int = 0 if matching.is_empty() else _instances[matching].units.size()
		if current + entry.units.size() > 10:
			return ""
	if not matching.is_empty():
		_instances[matching]["units"].append_array(entry["units"].duplicate(true))
		revision += 1
		return matching
	if not add_item(entry["instance_id"], entry["item_id"], cell, entry.get("vertical_book",false)):
		return ""
	_instances[entry["instance_id"]]["units"] = entry["units"].duplicate(true)
	return entry["instance_id"]

func equipment_allowed(item: ItemData, ignore_id: String = "") -> bool:
	if item.rule_version != 1:
		return true
	for entry: Dictionary in _instances.values():
		if entry.instance_id == ignore_id:
			continue
		var other := _registry.get_item(entry.item_id)
		if (item.is_consumable() or item.category in ["spell", "book"]) and other.id == item.id:
			return false
		if item.category == "armor" and item.armor_slot in ["身甲", "头具"] and other.armor_slot == item.armor_slot:
			return false
	return true

func take(id: String) -> Dictionary:
	if locked or not _instances.has(id):
		return {}
	var entry := get_instance(id)
	_instances.erase(id)
	revision += 1
	return entry

func returnable_count(id: String) -> int:
	var entry := get_instance(id)
	if entry.is_empty():
		return 0
	var item := _registry.get_item(entry["item_id"])
	var count := 0
	for unit in entry["units"]:
		if not item.is_consumable() or int(unit["uses_left"]) == item.uses_per_unit:
			count += 1
	return count

func take_returnable(id: String, single: bool = false) -> Dictionary:
	if locked or returnable_count(id) == 0:
		return {}
	var item := _registry.get_item(_instances[id]["item_id"])
	var units: Array = _instances[id]["units"]
	var returned: Array = []
	# Take from the tail so the current bottle and stack identity stay in place.
	for index in range(units.size() - 1, -1, -1):
		if not item.is_consumable() or int(units[index]["uses_left"]) == item.uses_per_unit:
			returned.push_front(units[index])
			units.remove_at(index)
			if single:
				break
	if units.is_empty():
		_instances.erase(id)
	revision += 1
	return {"instance_id": returned[0]["id"], "item_id": item.id, "units": returned}

# Simulation-only mutation, independent of UI editing locks.
func use_consumable(id: String) -> bool:
	if not _instances.has(id):
		return false
	var units: Array = _instances[id]["units"]
	units[0]["uses_left"] -= 1
	var consumed: bool = units[0]["uses_left"] == 0
	if consumed:
		units.pop_front()
	if units.is_empty():
		_instances.erase(id)
	revision += 1
	return consumed

func _fits(cell: Vector2i, dimensions: Vector2i, ignore_id: String) -> bool:
	var target := Rect2i(cell, dimensions)
	if not Rect2i(Vector2i.ZERO, grid_size).encloses(target):
		return false
	for instance_id in _instances:
		if instance_id == ignore_id:
			continue
		var instance: Dictionary = _instances[instance_id]
		var item := _registry.get_item(instance["item_id"])
		if target.intersects(Rect2i(instance["cell"], instance_size(instance_id))):
			return false
	return true
