class_name BattleLoot
extends RefCounted

# Pure reward selection. Caller owns randomness and persists inventory plus
# receipt together; retries must reuse the same battle ID and sampled rolls.
static func candidate(state: MapLoadoutState, enemy: Dictionary, battle_id: String, rolls: Array) -> Dictionary:
	var snapshot := state.snapshot()
	var receipts: Dictionary = snapshot.get("battle_rewards", {})
	if receipts.has(battle_id): return {"error": "", "snapshot": snapshot, "drops": receipts[battle_id].drops}
	if battle_id.is_empty() or rolls.size() != enemy.get("loot", []).size(): return {"error": "掉落判定参数无效。"}
	var first := true
	for receipt: Dictionary in receipts.values():
		if receipt.enemy_id == enemy.id: first = false
	var drops: Array[String] = []
	var index := 0
	for row: Dictionary in enemy.get("loot", []):
		if not state.records.has(row.item_id) or state.records[row.item_id].category != "beast": return {"error": "未知的掉落材料。"}
		var value: Variant = rolls[index]
		if not (value is float or value is int) or not is_finite(value) or value < 0 or value >= 1: return {"error": "掉落随机数无效。"}
		if first and row.get("first_victory_guaranteed", false) or value < row.chance:
			drops.append(row.item_id)
			snapshot.owned_units["loot.%s.%d" % [battle_id, index]] = row.item_id
		index += 1
	receipts[battle_id] = {"enemy_id": enemy.id, "drops": drops}
	snapshot.battle_rewards = receipts
	return {"error": "", "snapshot": snapshot, "drops": drops}

static func validate_receipts(raw: Variant, records: Dictionary, registry: ContentRegistry) -> bool:
	if not raw is Dictionary: return false
	for key: Variant in raw:
		if not key is String or key.is_empty() or not raw[key] is Dictionary: return false
		var receipt: Dictionary = raw[key]
		if not receipt.get("enemy_id") is String or registry.get_enemy(receipt.enemy_id).is_empty() or not receipt.get("drops") is Array: return false
		var seen := {}
		for item_id: Variant in receipt.drops:
			if not item_id is String or not records.has(item_id) or records[item_id].category != "beast" or seen.has(item_id): return false
			seen[item_id] = true
	return true
