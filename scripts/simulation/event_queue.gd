class_name EventQueue
extends RefCounted

# Min-heap: stable insertion order breaks ties at the same simulation time.
var _heap: Array[Dictionary] = []
var _sequence: int = 0

func schedule(due_usec: int, kind: String, payload: Dictionary) -> void:
	var event := {"due_usec": due_usec, "sequence": _sequence, "kind": kind, "payload": payload.duplicate(true)}
	_sequence += 1
	_heap.append(event)
	var index := _heap.size() - 1
	while index > 0:
		var parent := (index - 1) >> 1
		if not _before(_heap[index], _heap[parent]):
			break
		var swap := _heap[parent]
		_heap[parent] = _heap[index]
		_heap[index] = swap
		index = parent

func has_due(target_usec: int) -> bool:
	return not _heap.is_empty() and int(_heap[0]["due_usec"]) <= target_usec

func pop_next() -> Dictionary:
	if _heap.is_empty():
		return {}
	var result := _heap[0]
	var tail: Dictionary = _heap.pop_back()
	if _heap.is_empty():
		return result
	_heap[0] = tail
	var index := 0
	while index * 2 + 1 < _heap.size():
		var child := index * 2 + 1
		if child + 1 < _heap.size() and _before(_heap[child + 1], _heap[child]):
			child += 1
		if not _before(_heap[child], _heap[index]):
			break
		var swap := _heap[index]
		_heap[index] = _heap[child]
		_heap[child] = swap
		index = child
	return result

func clear() -> void:
	_heap.clear()
	_sequence = 0

func size() -> int:
	return _heap.size()

func _before(a: Dictionary, b: Dictionary) -> bool:
	if a["due_usec"] == b["due_usec"]:
		return a["sequence"] < b["sequence"]
	return a["due_usec"] < b["due_usec"]
