extends RefCounted

# Two independent, exact-unit receipts for the current warehouse visit only.
# Undo never restores an old inventory snapshot or substitutes a newer same-kind unit.
var history: Array[Dictionary] = []
var _next_id := 1

func clear() -> void:
	history.clear()

func transfer(state: MapLoadoutState, id: String, item_id: String, withdraw: bool, path: String, all_items: bool = false, quantity: int = -1) -> String:
	var result := perform(state,id,item_id,withdraw,path,all_items,quantity)
	if not result.error.is_empty(): return result.error
	var receipt: Dictionary = result.receipt
	receipt.operation_id = _next_id
	_next_id += 1
	history.push_front(receipt)
	if history.size() > 2: history.resize(2)
	return ""

func revert(state: MapLoadoutState, operation_id: int, path: String) -> String:
	for index in history.size():
		if int(history[index].operation_id) != operation_id: continue
		var error := undo(state,history[index],path)
		if error.is_empty(): history.remove_at(index)
		return error
	return "该转移记录已不存在。"

func view_history(state: MapLoadoutState) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for receipt: Dictionary in history:
		var row := receipt.duplicate(true)
		row.error = undo_error(state,receipt)
		result.append(row)
	return result

## Save both sides atomically before publishing any inventory change.
static func execute(state: MapLoadoutState, id: String, item_id: String, withdraw: bool, path: String, all_items: bool = false, quantity: int = -1) -> String:
	return perform(state,id,item_id,withdraw,path,all_items,quantity).error

static func perform(state: MapLoadoutState, id: String, item_id: String, withdraw: bool, path: String, all_items: bool = false, quantity: int = -1) -> Dictionary:
	if state.inventory.locked: return {"error":"当前不能存取仓库。"}
	var before: Dictionary = state.warehouses.get(id,{}).duplicate()
	var prepared := MapLoadoutStore.candidate(state)
	var error: String = prepared.error
	if not error.is_empty(): return {"error":error}
	var candidate: MapLoadoutState = prepared.state
	error = candidate.transfer_warehouse(id,item_id,withdraw,all_items,quantity)
	if not error.is_empty(): return {"error":error}
	var after: Dictionary = candidate.warehouses.get(id,{})
	var units := {}
	for unit_id: String in (before if withdraw else after):
		if not (after if withdraw else before).has(unit_id):
			units[unit_id] = (before if withdraw else after)[unit_id]
	error = MapLoadoutStore.save(candidate,path)
	if not error.is_empty(): return {"error":error}
	error = state.restore(candidate.snapshot())
	return {"error":error,"receipt":{"warehouse_id":id,"item_id":item_id,"withdraw":withdraw,"all_items":all_items,"units":units}}

static func undo_error(state: MapLoadoutState, receipt: Dictionary) -> String:
	if state.inventory.locked: return "当前不能存取仓库。"
	var id: String = receipt.get("warehouse_id","")
	var units: Dictionary = receipt.get("units",{})
	if not state.warehouse_rules.has(id) or units.is_empty(): return "转移记录无效。"
	var destination: Dictionary = state.warehouses.get(id,{})
	if receipt.get("withdraw",false):
		destination = {}
		for entry: Dictionary in state.storage.entries():
			for unit: Dictionary in entry.units: destination[unit.id] = entry.item_id
	for unit_id: String in units:
		if destination.get(unit_id,"") != units[unit_id]: return "相关物品已被消耗、上阵或再次转移，暂时无法撤销。"
		if receipt.get("withdraw",false) and state.records[units[unit_id]].get("board_layout","") == state.board.id:
			return "相关阵盘正在使用，暂时无法撤销。"
	if not receipt.get("withdraw",false):
		var additions: Array = []
		for unit_id: String in units: additions.append(state._unit(unit_id,units[unit_id]))
		var capacity_issue := state.storage_capacity_error(MapLoadoutState.projected_storage(state.storage,additions))
		if not capacity_issue.is_empty(): return capacity_issue
	return ""

static func undo(state: MapLoadoutState, receipt: Dictionary, path: String) -> String:
	var error := undo_error(state,receipt)
	if not error.is_empty(): return error
	var prepared := MapLoadoutStore.candidate(state)
	if not prepared.error.is_empty(): return prepared.error
	var candidate: MapLoadoutState = prepared.state
	var next := candidate.snapshot()
	var id: String = receipt.warehouse_id
	if not next.has("warehouses"): next.warehouses = {}
	if not next.warehouses.has(id): next.warehouses[id] = {}
	for unit_id: String in receipt.units:
		if receipt.withdraw: next.warehouses[id][unit_id] = receipt.units[unit_id]
		else: next.warehouses[id].erase(unit_id)
	if next.warehouses[id].is_empty(): next.warehouses.erase(id)
	error = candidate.restore(next, true)
	if not error.is_empty(): return error
	error = MapLoadoutStore.save(candidate,path)
	if not error.is_empty(): return error
	return state.restore(candidate.snapshot())

static func preview(state: MapLoadoutState, id: String, item_id: String, withdraw: bool) -> Dictionary:
	var source := state.warehouse_records(id) if withdraw else state.storage_records()
	var destination := state.storage_records() if withdraw else state.warehouse_records(id)
	var available := 0
	for record: Dictionary in source:
		if record.id == item_id: available += int(record.quantity)
	var used := state.storage_used_slots() if withdraw else destination.size()
	var extra := 0 if item_id.is_empty() or destination.any(func(record: Dictionary): return record.id == item_id) else 1
	if withdraw and state.records.get(item_id, {}).get("category") == "spell": extra = 0
	var capacity := state.storage_capacity_limit() if withdraw else state.warehouse_capacity_limit(id)
	var blocked: bool = not withdraw and state.records.get(item_id,{}).get("board_layout","") == state.board.id
	if withdraw and used+extra > maxi(used,capacity): blocked = true
	return {"available":available,"used":used,"projected":used+extra,"capacity":capacity,"sufficient":used+extra <= capacity,"blocked":blocked}
