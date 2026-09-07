class_name InventoryState
extends RefCounted

const GRID_SIZE := Vector2i(4, 4)
var locked: bool = false
var revision: int = 0
var _registry: ContentRegistry
var _instances: Dictionary = {}

func _init(registry: ContentRegistry) -> void:
	_registry = registry

func add_item(instance_id: String, item_id: String, cell: Vector2i) -> bool:
	if locked or instance_id.is_empty() or _instances.has(instance_id):
		return false
	var item := _registry.get_item(item_id)
	if item == null or not _fits(cell, item.grid_size, ""):
		return false
	_instances[instance_id] = {"instance_id": instance_id, "item_id": item_id, "cell": cell, "units": [{"id": instance_id, "uses_left": item.uses_per_unit}]}
	revision += 1
	return true

func get_instances() -> Array:
	return _instances.values().duplicate(true)

func get_instance(instance_id: String) -> Dictionary:
	return _instances.get(instance_id, {}).duplicate(true)

func item_at(cell: Vector2i) -> String:
	for instance_id in _instances:
		var instance: Dictionary = _instances[instance_id]
		var item := _registry.get_item(instance["item_id"])
		if Rect2i(instance["cell"], item.grid_size).has_point(cell):
			return instance_id
	return ""

func can_move(instance_id: String, cell: Vector2i) -> bool:
	if locked or not _instances.has(instance_id):
		return false
	var item := _registry.get_item(_instances[instance_id]["item_id"])
	return _fits(cell, item.grid_size, instance_id)

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
		for y in 4:
			for x in 4:
				if _fits(Vector2i(x, y), item.grid_size, ""):
					result.append(Vector2i(x, y))
	return result

func put(entry: Dictionary, cell: Vector2i) -> String:
	if locked or entry.is_empty():
		return ""
	var matching := matching_stack(entry["item_id"])
	if not matching.is_empty():
		_instances[matching]["units"].append_array(entry["units"].duplicate(true))
		revision += 1
		return matching
	if not add_item(entry["instance_id"], entry["item_id"], cell):
		return ""
	_instances[entry["instance_id"]]["units"] = entry["units"].duplicate(true)
	return entry["instance_id"]

func take(id: String) -> Dictionary:
	if locked or not _instances.has(id):
		return {}
	var entry := get_instance(id)
	_instances.erase(id)
	revision += 1
	return entry

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
	if not Rect2i(Vector2i.ZERO, GRID_SIZE).encloses(target):
		return false
	for instance_id in _instances:
		if instance_id == ignore_id:
			continue
		var instance: Dictionary = _instances[instance_id]
		var item := _registry.get_item(instance["item_id"])
		if target.intersects(Rect2i(instance["cell"], item.grid_size)):
			return false
	return true
