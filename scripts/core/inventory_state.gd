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
	_instances[instance_id] = {"instance_id": instance_id, "item_id": item_id, "cell": cell}
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
