class_name SharedStorage
extends RefCounted

var revision: int = 0
var _entries: Dictionary = {}

func entries() -> Array:
	return _entries.values().duplicate(true)

func get_entry(id: String) -> Dictionary:
	return _entries.get(id, {}).duplicate(true)

func put(entry: Dictionary) -> void:
	var copy := entry.duplicate(true)
	copy.erase("cell")
	# Each returned bottle keeps its stable identity when merged.
	for id in _entries:
		if _entries[id]["item_id"] == copy["item_id"]:
			_entries[id]["units"].append_array(copy["units"])
			revision += 1
			return
	_entries[copy["instance_id"]] = copy
	revision += 1

func peek_one(id: String) -> Dictionary:
	var entry := get_entry(id)
	if entry.is_empty():
		return {}
	var unit: Dictionary = entry["units"][0]
	entry["units"] = [unit]
	entry["instance_id"] = unit["id"]
	return entry

func take_one(id: String) -> Dictionary:
	var entry := peek_one(id)
	if not entry.is_empty():
		_entries[id]["units"].pop_front()
		if _entries[id]["units"].is_empty():
			_entries.erase(id)
		revision += 1
	return entry
