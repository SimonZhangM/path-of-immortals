class_name BattleRecordTrace
extends RefCounted
## Presentation metadata only. Scopes never affect scheduling or combat state.

var _serial := 0
var _sequence := 0
var _scopes: Array[Dictionary] = []

func current() -> Dictionary:
	return _scopes.back() if not _scopes.is_empty() else {}

func begin(source: Dictionary, at: int, mode := "action") -> void:
	var parent := current()
	_serial += 1
	var scope := source.duplicate(true)
	scope.record_group_id = _serial
	scope.record_action_id = int(source.get("record_action_id", _serial)) if mode == "segment" else _serial
	scope.record_parent_id = int(source.get("record_action_id", parent.get("record_action_id", 0)))
	scope.record_at = at
	scope.record_mode = mode
	scope.erase("stamina_cost")
	scope.erase("spirit_cost")
	_scopes.append(scope)

func begin_attack(source: Dictionary, at: int) -> void:
	var parent := current()
	if not parent.is_empty() and not parent.get("record_attack_started", false) and parent.get("owner_id", "") == source.get("owner_id", ""):
		parent.record_attack_started = true
		var scope := parent.duplicate(true)
		scope.merge(source, true)
		_scopes.append(scope)
	else:
		begin(source, at, "segment")

func end() -> void:
	_scopes.pop_back()

func capture(source: Dictionary) -> Dictionary:
	var result := source.duplicate(true)
	var scope := current()
	if scope.get("owner_id", "") == source.get("owner_id", ""):
		for key in ["owner_name", "side", "item_id", "instance_id", "trait_id", "label", "record_mode", "record_at"]:
			if scope.has(key) and not result.has(key): result[key] = scope[key]
	for key in ["record_action_id", "record_group_id", "record_parent_id"]:
		if scope.has(key): result[key] = scope[key]
	return result

func resume(source: Dictionary) -> void:
	_scopes.append(source.duplicate(true))

func annotate(values: Dictionary) -> Dictionary:
	var result := values.duplicate(true)
	var scope := current()
	var same_owner: bool = not result.has("owner_id") or result.owner_id == scope.get("owner_id", "")
	for key in ["owner_id", "owner_name", "side", "item_id", "instance_id", "trait_id", "label"]:
		if same_owner and scope.has(key) and not result.has(key): result[key] = scope[key]
	if same_owner and scope.has("record_mode"): result.record_mode = scope.record_mode
	for key in ["record_action_id", "record_group_id", "record_parent_id"]:
		if scope.has(key): result[key] = scope[key]
	_sequence += 1
	result.record_sequence = _sequence
	return result
