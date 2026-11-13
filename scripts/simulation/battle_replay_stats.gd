class_name BattleReplayStats
extends RefCounted
## One per simulation. Raw settlements, not formatted log rows, are authoritative.
const Attribution = preload("res://scripts/simulation/battle_attribution.gd")
static var _battle_serial := 0
var battle_id: int
var frozen := false
var result := ""
var duration_usec := 0
var _items: Dictionary = {}
var _seen: Dictionary = {}
var _counts: Dictionary = {}
var unassigned_damage := 0.0
var _team_metrics: Array[Dictionary] = [{}, {}]
var _team_counts: Dictionary = {}
var _actor_sides: Dictionary = {}

func _init() -> void:
	_battle_serial += 1
	battle_id = _battle_serial

func register(teams: Array) -> void:
	if frozen: return
	for row: Dictionary in _items.values(): row.on_board = false
	for side in teams.size():
		for actor: PartyMemberState in teams[side]:
			_actor_sides[actor.id] = side
			for entry: Dictionary in actor.inventory.get_instances():
				var row := _ensure({"instance_id":entry.instance_id,"item_id":entry.item_id,"owner_id":actor.id,"side":side})
				row.entry = entry.duplicate(true)
				_remember_units(row,entry)
				row.on_board = true

func _ensure(source: Dictionary) -> Dictionary:
	var id: String = source.get("instance_id", "")
	if id.is_empty(): return {}
	if not _items.has(id):
		_items[id] = {"instance_id":id,"item_id":source.get("item_id", ""),"owner_id":source.get("owner_id", ""),"side":source.get("side",-1),"entry":{},"unit_ids":[],"on_board":false,"metrics":{},"statuses":{},"effect_stats":{},"restore_reasons":{},"participants":[],"unknown_assist":false}
	for key in ["item_id", "owner_id"]:
		if source.has(key) and str(_items[id][key]).is_empty():
			_items[id][key] = source[key]
	if source.has("side") and int(_items[id].side) < 0:
		_items[id].side = int(source.side)
	return _items[id]

func _remember_units(row: Dictionary, entry: Dictionary) -> void:
	for unit: Dictionary in entry.get("units",[]):
		if unit.id not in row.unit_ids: row.unit_ids.append(unit.id)

func item(id: String) -> Dictionary:
	return _items.get(id, {}).duplicate(true)

func snapshot() -> Dictionary:
	return {"battle_id":battle_id,"result":result,"duration_usec":duration_usec,"items":_items.duplicate(true),"unassigned_damage":unassigned_damage,"team_metrics":_team_metrics.duplicate(true)}

func _side(origin: Dictionary, event: Dictionary) -> int:
	var side := int(origin.get("side", -1))
	if side in [0, 1]: return side
	var owner: String = origin.get("owner_id", event.get("owner_id", ""))
	if _actor_sides.has(owner): return _actor_sides[owner]
	if int(event.get("side", -1)) in [0, 1]: return int(event.side)
	if event.kind in ["restore", "barrier_changed", "shield_created", "replay_shield_absorbed", "replay_shield_discarded"]:
		return _actor_sides.get(event.get("target_id", ""), -1)
	return -1

func _effect_name(event: Dictionary) -> String:
	if event.has("status"): return str(event.status)
	if event.has("replay_status"): return str(event.replay_status)
	if event.get("record_mode", "") in ["dot", "derived"] or event.kind in ["temporary_buff", "attack_primed", "item_passive", "replay_support", "replay_assist"]:
		return str(event.get("label", ""))
	return ""

func _effect(row: Dictionary, label: String) -> Dictionary:
	if not row.effect_stats.has(label):
		row.effect_stats[label] = {"metrics": {}, "unquantified": false}
	return row.effect_stats[label]

func _add(event: Dictionary, metric: String, value: float) -> void:
	for origin: Dictionary in Attribution.sources(event):
		var row := _ensure(origin)
		var amount := value * float(origin.get("weight", 1))
		var side := _side(origin, event)
		if side in [0, 1]:
			_team_metrics[side][metric] = float(_team_metrics[side].get(metric, 0)) + amount
		if row.is_empty():
			if metric == "damage_total": unassigned_damage += amount
			continue
		row.metrics[metric] = float(row.metrics.get(metric, 0)) + amount
		var label := _effect_name(event)
		if not label.is_empty():
			var effect_metrics: Dictionary = _effect(row, label).metrics
			effect_metrics[metric] = float(effect_metrics.get(metric, 0)) + amount

func _count(event: Dictionary, metric: String, key: String) -> void:
	for origin: Dictionary in Attribution.sources(event):
		var side := _side(origin, event)
		var team_key := "%s/%s/%s" % [side, metric, key]
		if side in [0, 1] and not _team_counts.has(team_key):
			_team_counts[team_key] = true
			_team_metrics[side][metric] = float(_team_metrics[side].get(metric, 0)) + 1
		var row := _ensure(origin)
		if row.is_empty(): continue
		var label := _effect_name(event)
		var effect_key := "%s/effect/%s/%s/%s" % [row.instance_id, label, metric, key]
		if not label.is_empty() and not _counts.has(effect_key):
			_counts[effect_key] = true
			var effect_metrics: Dictionary = _effect(row, label).metrics
			effect_metrics[metric] = float(effect_metrics.get(metric, 0)) + 1
		var unique := "%s/%s/%s" % [row.instance_id, metric, key]
		if _counts.has(unique): continue
		_counts[unique] = true
		row.metrics[metric] = float(row.metrics.get(metric, 0)) + 1

func consume(events: Array[Dictionary]) -> void:
	if frozen: return
	for event: Dictionary in events:
		var sequence: int = event.get("record_sequence", -1)
		if sequence >= 0:
			if _seen.has(sequence): continue
			_seen[sequence] = true
		var action := str(event.get("record_action_id", sequence))
		var group := str(event.get("record_group_id", sequence))
		var target: String = event.get("target_id", "")
		match event.kind:
			"item_activated":
				var row := _ensure(event)
				if not row.is_empty() and event.has("entry"):
					row.entry = event.entry.duplicate(true)
					_remember_units(row,event.entry)
				_count(event, "rotation", action)
				_add(event, "stamina_spent", event.get("stamina_cost", 0))
				_add(event, "spirit_spent", event.get("spirit_cost", 0))
			"resource_cost":
				_add(event, "stamina_spent", event.get("stamina_cost", 0))
				_add(event, "spirit_spent", event.get("spirit_cost", 0))
			"damage", "counter_damage", "status_damage", "toxin_damage", "armor_only", "shield_interrupted":
				var amount := float(event.get("value",0))
				if event.kind not in ["armor_only", "shield_interrupted"]: amount += float(event.get("armor_absorbed",0)) + float(event.get("shield_absorbed",0))
				_add(event, "damage_total", amount)
				var mode: String = event.get("record_mode", "")
				var damage_kind := "damage_direct"
				if mode in ["dot", "derived"] or event.kind in ["status_damage", "toxin_damage"]:
					damage_kind = "damage_status"
				elif mode in ["counter", "followup"]:
					damage_kind = "damage_counter"
				damage_kind = event.get("replay_damage_kind", damage_kind)
				_add(event, damage_kind, amount)
				if damage_kind != "damage_status":
					_count(event, "attack_hits", group+"/"+target)
					if event.get("critical", false): _count(event, "attack_crits", group+"/"+target)
				_count(event, "hits", group+"/"+target)
				if event.get("critical",false): _count(event,"crits",group+"/"+target)
				if damage_kind in ["damage_status", "damage_counter"]: _count(event,"trigger",group+"/"+target)
			"miss", "immune":
				_count(event,"misses",group+"/"+target)
				if event.get("record_mode", "") not in ["dot", "derived"]:
					_count(event, "attack_misses" if event.kind == "miss" else "attack_immune", group+"/"+target)
			"restore", "barrier_changed", "shield_created":
				var resource: String = event.get("resource","barrier")
				if float(event.get("value", 0)) <= 0 and event.has("restore_reason"):
					for origin: Dictionary in Attribution.sources(event):
						var restored_item := _ensure(origin)
						if not restored_item.is_empty(): restored_item.restore_reasons[resource] = event.restore_reason
				var metric: String = {"hp":"hp_restored","stamina":"stamina_restored","spirit":"spirit_restored","armor":"armor_granted","barrier":"shield_generated","sword_screen":"shield_generated","thunder_shield":"shield_generated"}.get(resource, "")
				if not metric.is_empty():
					_add(event,metric,float(event.get("value",0)))
					if resource in ["hp", "stamina", "spirit"]:
						_add(event, metric + ("_periodic" if event.get("record_mode", "") == "dot" else "_direct"), float(event.get("value", 0)))
				if resource in ["barrier","sword_screen","thunder_shield"]: _add(event,"generated_"+resource,float(event.get("value",0)))
				if event.get("record_mode", "") == "dot": _count(event,"trigger",group+"/"+target)
			"replay_shield_absorbed":
				_add(event,"shield_absorbed",event.value)
				_add(event,"absorbed_"+event.resource,event.value)
			"replay_shield_discarded": _add(event,"shield_discarded",event.value)
			"status_failed": _count(event, "status_failed", action+"/"+target+"/"+str(event.get("status", "")))
			"status_removed": _count(event, "status_removed", action+"/"+target+"/"+str(event.get("status", "")))
			"resource_drained": _add(event, str(event.resource) + "_drained", float(event.value))
			"status_applied", "control", "temporary_buff", "attack_primed", "item_passive":
				var status: String = event.get("status",event.get("label","增益"))
				var successful := true
				if event.kind == "status_applied": successful = event.get("replay_added_layers",0) > 0 or event.get("layers",0) > event.get("layers_before",0) or event.get("expires",0) > event.get("previous_expiry",0)
				if event.kind == "control": successful = event.get("until",0) > event.get("previous_expiry",0)
				if not successful: continue
				if event.kind == "item_passive": _count(event,"trigger",group+"/"+target)
				var buff: bool = T01Definition.is_buff(status) if event.has("status") else true
				_count(event,"buff_apply" if buff else "debuff_apply",action+"/"+target+"/"+status)
				for origin: Dictionary in Attribution.sources(event):
					var row := _ensure(origin)
					if not row.is_empty(): row.statuses[status] = true
			"replay_trigger": _count(event,"trigger",group+"/"+target)
			"replay_participants":
				var row := _ensure(event)
				if not row.is_empty():
					for id: String in event.items:
						if id not in row.participants: row.participants.append(id)
			"replay_assist": _add(event,event.metric,event.value)
			"replay_support":
				_count(event,"trigger",group+"/"+target)
				for origin: Dictionary in Attribution.sources(event):
					var row := _ensure(origin)
					if row.is_empty(): continue
					row.statuses[event.get("label","辅助效果")] = true
					if not event.get("quantified",false):
						row.unknown_assist = true
						_effect(row, event.get("label", "辅助效果")).unquantified = true
			"finished":
				result = event.result
				duration_usec = event.at_usec
				frozen = true
				return
