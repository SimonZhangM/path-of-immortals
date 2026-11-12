class_name BattleAttribution
extends RefCounted
## Read-only provenance. Weights never participate in combat calculations.

static func sources(context: Dictionary) -> Array:
	if context.has("replay_sources"):
		return context.replay_sources.duplicate(true) if not context.replay_sources.is_empty() else [{"owner_id":context.get("owner_id",""),"side":context.get("side",-1),"instance_id":"","item_id":"","weight":1.0}]
	return [{"owner_id": context.get("owner_id", ""), "side": context.get("side", -1), "instance_id": context.get("instance_id", ""), "item_id": context.get("item_id", ""), "weight": 1.0}]

static func normalized(entries: Array) -> Array:
	var merged: Dictionary = {}
	var total := 0.0
	for entry: Dictionary in entries:
		var weight := maxf(0, float(entry.get("weight", 0)))
		if weight <= 0: continue
		var key := "%s/%s/%s" % [entry.get("owner_id", ""), entry.get("instance_id", ""), entry.get("item_id", "")]
		if not merged.has(key):
			merged[key] = entry.duplicate(true)
			merged[key].weight = 0.0
		merged[key].weight += weight
		total += weight
	var result: Array = merged.values()
	for entry: Dictionary in result: entry.weight /= total
	return result

static func pool(member: PartyMemberState, status: String, limit := -1) -> Array:
	var entries: Array = []
	var remaining := limit
	for batch: Dictionary in member.combat_statuses.get(status, {}).get("batches", []):
		var count := int(batch.count) if limit < 0 else mini(int(batch.count), remaining)
		if count <= 0: break
		for origin: Dictionary in sources(batch.get("origin", {"owner_id": batch.get("source", "")})):
			origin.weight *= count
			entries.append(origin)
		remaining -= count
	return normalized(entries)

static func status_context(member: PartyMemberState, status: String, limit := -1) -> Dictionary:
	var context: Dictionary = member.combat_statuses.get(status, {}).get("feedback_source", {}).duplicate(true)
	context.replay_sources = pool(member, status, limit)
	return context
