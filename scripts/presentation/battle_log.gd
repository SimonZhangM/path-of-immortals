class_name BattleLog
extends RefCounted
## One row per source, target and independent settlement.

const RESOURCE_NAMES := {"hp": "气血", "stamina": "体力", "spirit": "灵力", "armor": "护甲", "spiritual_armor": "灵甲", "barrier": "灵盾", "thunder_shield": "雷盾", "sword_screen": "剑幕"}
const COLORS := {"normal": "d9e2e3", "damage": "f07968", "recovery": "7edc8a", "buff": "68b8f0", "debuff": "bd8bef"}
var rows: Array[Dictionary] = []
var status_details: Array[Dictionary] = []
var revision := 0
var actors: Dictionary = {}
var _indices: Dictionary = {}
var _pending: Dictionary = {}
var _consumptions: Dictionary = {}
var _registry: ContentRegistry

func reset() -> void:
	rows.clear()
	status_details.clear()
	_indices.clear()
	_pending.clear()
	_consumptions.clear()
	revision += 1

func bind(teams: Array, companions: Array = []) -> void:
	actors.clear()
	for side in teams.size():
		for member: PartyMemberState in teams[side]:
			actors[member.id] = {"id": member.id, "name": member.definition.name, "side": side, "portrait": member.definition.get("portrait", ""), "rank": member.cultivation_rank_id, "player": side == 0, "portrait_region": member.definition.get("portrait_region", [])}
		if companions.size() <= side: continue
		for member: CompanionState in companions[side]:
			actors[member.id] = {"id": member.id, "name": member.definition.name, "side": side, "portrait": member.definition.get("portrait", ""), "rank": "", "player": false, "portrait_region": member.definition.get("portrait_region", [])}

func consume(events: Array[Dictionary], registry: ContentRegistry, format_text := true) -> String:
	_registry = registry
	for original: Dictionary in events:
		var event := _identify(original)
		var kind: String = event.get("kind", "")
		if kind in ["started", "finished", "effect_error"]:
			_system(event)
			continue
		if kind == "status_expired":
			status_details.append(event)
			continue
		if kind == "status_consumed":
			var key := _group(event)
			if not _consumptions.has(key): _consumptions[key] = []
			_consumptions[key].append(event)
			if _pending.has(key): _apply(rows[_pending[key]], event)
			continue
		if kind == "fallen":
			for index in range(rows.size() - 1, -1, -1):
				var row := rows[index]
				if row.target_id == event.get("target_id", "") and "damage" in row.tags:
					row.defeated = true
					break
			continue
		if kind not in ["item_activated", "resource_cost", "trait_activated", "attack_started", "damage", "counter_damage", "miss", "immune", "status_damage", "toxin_damage", "restore", "shield_created", "barrier_changed", "shield_broken", "shield_interrupted", "armor_only", "status_applied", "status_failed", "status_removed", "control", "temporary_buff", "item_passive", "attack_primed", "cooldown_delayed", "cooldown_changed", "resource_drained", "pill_used", "cast_interrupted", "status_consumed"]:
			continue
		if kind == "restore" and event.get("owner_id", "").is_empty() and event.get("item_id", "").is_empty():
			continue
		if kind == "restore" and float(event.get("value", 0)) == 0 and event.get("resource", "") != "hp":
			# Explain a real activation's zero result without adding idle callbacks.
			if not _pending.has(_group(event)): continue
		var row := _row(event)
		_apply(row, event)
		for consumed: Dictionary in _consumptions.get(_group(event), []): _apply(row, consumed)
	if not events.is_empty(): revision += 1
	return text() if format_text else ""

func filtered(filter_id := "all") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row: Dictionary in rows:
		if filter_id == "all" or filter_id == "me" and row.side == 0 or filter_id == "enemy" and row.side == 1 or filter_id in row.tags:
			result.append(row)
	return result

func _identify(original: Dictionary) -> Dictionary:
	var event := original.duplicate(true)
	for prefix in ["owner", "target"]:
		var id: String = event.get(prefix + "_id", "")
		if id.is_empty():
			for candidate: Dictionary in actors.values():
				if candidate.name == event.get(prefix + "_name", ""):
					id = candidate.id
					break
		if actors.has(id):
			event[prefix + "_id"] = id
			event[prefix + "_name"] = actors[id].name
			if prefix == "owner": event.side = actors[id].side
	return event

func _system(event: Dictionary) -> void:
	var title := "战斗开始"
	if event.kind == "finished": title = "战斗结束 · " + {"victory": "胜利", "defeat": "失败", "retreat": "失败（撤退）", "draw": "平局"}.get(event.result, str(event.result))
	if event.kind == "effect_error": title = "结算错误 · " + event.message
	var row := _new_row({"at_usec": event.at_usec, "side": -1})
	row.source_name = "系统"
	row.event_name = title
	row.system = true
	rows.append(row)

func _group(event: Dictionary) -> String:
	return "%s/%s/%s" % [event.get("record_group_id", event.get("instance_id", event.get("item_id", event.get("label", "event")))), event.get("at_usec", 0), event.get("owner_id", event.get("owner_name", ""))]

func _row(event: Dictionary) -> Dictionary:
	var group := _group(event)
	var target: String = event.get("target_id", event.get("target_name", ""))
	var key := group + "/" + target
	if _indices.has(key): return rows[_indices[key]]
	if target.is_empty() and _pending.has(group): return rows[_pending[group]]
	if not target.is_empty() and _pending.has(group) and rows[_pending[group]].target_id.is_empty():
		var index: int = _pending[group]
		var row := rows[index]
		row.target_id = target
		row.target_name = event.get("target_name", target)
		_indices.erase(group + "/")
		_indices[key] = index
		return row
	var row := _new_row(event)
	_indices[key] = rows.size()
	if not _pending.has(group): _pending[group] = rows.size()
	rows.append(row)
	return row

func _new_row(event: Dictionary) -> Dictionary:
	return {"at_usec": int(event.get("at_usec", 0)), "source_id": event.get("owner_id", ""), "source_name": event.get("owner_name", "—"), "side": int(event.get("side", -1)), "item_id": event.get("item_id", ""), "event_name": _source_name(event), "target_id": event.get("target_id", event.get("target_name", "")), "target_name": event.get("target_name", ""), "action_id": event.get("record_action_id", 0), "parent_id": event.get("record_parent_id", 0), "mode": event.get("record_mode", ""), "tags": [], "damage": {}, "restores": {}, "effects": [], "notes": [], "cost": Vector2.ZERO, "critical": false, "defeated": false, "miss": "", "system": false, "status_names": [], "applications": {}}

func _source_name(event: Dictionary) -> String:
	var item := _registry.get_item(event.get("item_id", "")) if _registry != null else null
	var name: String = item.display_name if item != null else event.get("label", event.get("status", event.get("recovery_status", "事件")))
	if name.is_empty(): name = event.get("status", "攻击")
	if event.has("trait_id") and _registry != null: name = str(_registry.get_trait(event.trait_id).get("name", name))
	var mode: String = event.get("record_mode", "")
	if mode == "followup" and item != null: name += "·追击"
	elif mode == "counter" and item != null: name += "·反击"
	elif mode == "dot": name = event.get("label", event.get("status", event.get("recovery_status", name)))
	elif mode == "derived" and not str(event.get("label", "")).is_empty(): name = event.label
	return name

func _tag(row: Dictionary, tag: String) -> void:
	if tag not in row.tags: row.tags.append(tag)

func _add_amount(values: Dictionary, key: String, amount: float) -> void:
	values[key] = float(values.get(key, 0)) + amount

func _note(row: Dictionary, note: String) -> void:
	if note not in row.notes: row.notes.append(note)

func _apply(row: Dictionary, event: Dictionary) -> void:
	var kind: String = event.kind
	match kind:
		"item_activated", "resource_cost", "trait_activated":
			row.cost += Vector2(float(event.get("stamina_cost", 0)), float(event.get("spirit_cost", 0)))
		"attack_started":
			_tag(row, "damage")
			if event.get("record_mode", "") == "followup": _note(row, "失衡触发" if event.get("label", "") == "失衡追击" else "法术触发")
		"damage", "counter_damage", "status_damage", "toxin_damage", "armor_only", "shield_interrupted":
			_tag(row, "damage")
			if kind == "armor_only": _add_amount(row.damage, "armor", event.value)
			elif kind == "shield_interrupted":
				_add_amount(row.damage, event.get("resource", "barrier"), event.value)
				_note(row, "盾反击败攻击者，余伤中止")
			else:
				_add_amount(row.damage, "hp", float(event.get("value", 0)))
				_add_amount(row.damage, "armor", float(event.get("armor_absorbed", 0)))
				_add_amount(row.damage, event.get("shield_resource", "barrier"), float(event.get("shield_absorbed", 0)))
			row.critical = row.critical or event.get("critical", false)
			if event.get("armor_depleted", false): _note(row, "护甲耗尽")
			for status: String in event.get("record_statuses", []):
				if status not in row.status_names: row.status_names.append(status)
		"miss", "immune":
			_tag(row, "damage")
			row.miss = "免疫" if kind == "immune" else "未命中"
			var reason: String = event.get("reason", "")
			if not reason.is_empty() and reason != row.miss: row.miss += "（%s）" % reason
		"restore", "shield_created", "barrier_changed":
			var resource: String = event.get("resource", "thunder_shield" if kind == "shield_created" else "barrier")
			_add_amount(row.restores, resource, float(event.get("value", 0)))
			if float(event.get("value", 0)) == 0 and event.has("restore_reason"):
				if not row.has("restore_details"): row.restore_details = {}
				row.restore_details[resource] = {"reason": event.restore_reason, "before": event.get("resource_before", 0), "limit": event.get("restore_limit", 0)}
			if resource == "hp": _tag(row, "recovery")
		"shield_broken": _note(row, RESOURCE_NAMES.get(event.get("resource", "barrier"), "护盾") + "破裂")
		"status_applied", "status_failed", "status_removed": _status(row, event)
		"control":
			_tag(row, "debuff")
			var changed: bool = event.until > maxi(event.at_usec, event.get("previous_expiry", 0))
			var description: String = ("刷新" if event.get("previous_expiry", 0) > event.at_usec else "施加") + event.status + "，持续%s秒" % _number(maxf(0, float(event.until - event.at_usec) / 1000000.0)) if changed else event.status + "未延长（已有同等或更长效果）"
			row.effects.append({"tag": "debuff", "kind": "description", "text": description})
			if changed: row.applications[event.status] = 1
		"temporary_buff", "item_passive", "attack_primed":
			_tag(row, "buff")
			var description: String = event.get("label", "攻击强化")
			if kind == "attack_primed": description = "下次攻击提高%s点" % _number(event.value)
			elif event.has("value"): description += "%s%%" % _number(float(event.value) * 100)
			if event.has("duration"): description += "，持续%s秒" % _number(event.duration)
			row.effects.append({"tag": "buff", "kind": "description", "text": description})
			row.applications[description] = 1
		"cooldown_delayed", "cooldown_changed":
			var seconds: float = event.get("seconds", 0)
			var tag := "debuff" if seconds > 0 else "buff"
			_tag(row, tag)
			row.effects.append({"tag": tag, "kind": "description", "text": "%s冷却%s%s秒" % [event.get("target_item_name", ""), "延长" if seconds > 0 else "缩短", _number(absf(seconds))]})
		"resource_drained":
			row.effects.append({"tag": "debuff", "kind": "description", "text": "%s减少%s" % [RESOURCE_NAMES.get(event.resource, event.resource), _number(event.value)]})
		"pill_used": pass
		"cast_interrupted": _note(row, "发动被%s截断" % event.get("label", "效果"))
		"status_consumed": _note(row, "%s消耗%s层" % [event.status, _number(event.value)])

func _status(row: Dictionary, event: Dictionary) -> void:
	var status: String = event.status
	var tag := "buff" if T01Definition.is_buff(status) or event.get("removal", "") == "驱散" else "debuff"
	_tag(row, tag)
	var effect := {"tag": tag, "status": status, "kind": event.kind, "before": event.get("layers_before", 0), "after": event.get("layers", 0), "value": event.get("value", 0), "reason": event.get("reason", ""), "expires": event.get("expires", 0), "previous_expiry": event.get("previous_expiry", 0), "removal": event.get("removal", "")}
	var merged := false
	for existing: Dictionary in row.effects:
		if existing.kind == event.kind and existing.get("status", "") == status:
			existing.after = effect.after
			existing.value += effect.value
			existing.expires = maxi(existing.expires, effect.expires)
			merged = true
			break
	if not merged: row.effects.append(effect)
	if event.kind == "status_applied": row.applications[status] = 1

func segments(row: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if row.system: return result
	if not row.miss.is_empty(): result.append({"color": COLORS.damage, "text": row.miss + "（实际伤害0）"})
	elif not row.damage.is_empty():
		var total := 0.0
		var components: PackedStringArray = []
		for resource in ["thunder_shield", "sword_screen", "barrier", "armor", "hp"]:
			var value: float = row.damage.get(resource, 0)
			total += value
			if value > 0: components.append(RESOURCE_NAMES[resource] + _number(value))
		var line := "造成%s点伤害" % _number(total)
		if components.size() > 1 or not components.is_empty() and float(row.damage.get("hp", 0)) == 0: line += "（%s）" % "、".join(components)
		if row.critical: line += "〔暴击〕"
		if not row.status_names.is_empty(): line += "〔%s〕" % "、".join(row.status_names)
		if row.defeated: line += "〔击败〕"
		result.append({"color": COLORS.damage, "text": line})
	for resource: String in row.restores:
		var line := "恢复%s点%s" % [_number(row.restores[resource]), RESOURCE_NAMES.get(resource, resource)]
		var detail: Dictionary = row.get("restore_details", {}).get(resource, {})
		if row.restores[resource] == 0 and not detail.is_empty():
			match detail.reason:
				"item_cap": line += "（当前%s，已达本物品恢复上限%s）" % [_number(detail.before), _number(detail.limit)]
				"resource_full": line += "（%s已满）" % RESOURCE_NAMES.get(resource, resource)
				"injury": line += "（治疗被重伤完全抵消）"
				"reduced": line += "（恢复效果被抵消）"
		result.append({"color": COLORS.recovery, "text": line})
	for effect: Dictionary in row.effects:
		var description := ""
		match effect.kind:
			"description": description = effect.text
			"status_failed": description = effect.status + "施加失败（" + effect.reason + "）"
			"status_removed": description = "%s%s%s层" % [effect.removal, effect.status, _number(effect.value)]
			"status_applied":
				description = "施加%s%s层" % [effect.status, _number(effect.after)] if effect.before == 0 else "%s%s层→%s层" % [effect.status, _number(effect.before), _number(effect.after)]
				if effect.after == 0: description = "%s%s层（转化雷盾）" % [effect.status, _number(effect.value)] if effect.status == "雷蕴" and row.restores.has("thunder_shield") else "%s%s层（与相反状态抵消）" % [effect.status, _number(effect.value)]
				elif effect.after == effect.before and effect.expires > effect.previous_expiry: description = "刷新%s%s层" % [effect.status, _number(effect.after)]
				if effect.expires > row.at_usec: description += "，%s%s秒" % ["续时至" if effect.previous_expiry > 0 else "持续", _number(float(effect.expires - row.at_usec) / 1000000.0)]
		result.append({"color": COLORS[effect.tag], "text": description})
	if result.is_empty(): result.append({"color": COLORS.normal, "text": "发动"})
	if not row.notes.is_empty(): result.append({"color": COLORS.normal, "text": "〔%s〕" % "，".join(row.notes)})
	return result

func result_text(row: Dictionary) -> String:
	var parts: PackedStringArray = []
	for part: Dictionary in segments(row):
		var joiner := "" if parts.is_empty() or str(part.text).begins_with("（") or str(part.text).begins_with("〔") else "，"
		parts.append(joiner + part.text)
	return "".join(parts)

func text() -> String:
	var lines: PackedStringArray = []
	for row: Dictionary in rows:
		lines.append("[%05.2f] %s｜%s｜%s｜%s" % [row.at_usec / 1000000.0, row.source_name, row.event_name, row.target_name, result_text(row)])
	return "\n".join(lines)

func details_text(row: Dictionary) -> String:
	var details: PackedStringArray = []
	if row.parent_id != 0:
		for original: Dictionary in rows:
			if original.action_id == row.parent_id:
				details.append("触发来源：%s · %s（%.2f秒）" % [original.source_name, original.event_name, original.at_usec / 1000000.0])
				break
	for effect: Dictionary in row.effects:
		if effect.kind != "status_applied": continue
		for expiry: Dictionary in status_details:
			if expiry.get("target_id", "") == row.target_id and expiry.status == effect.status and expiry.at_usec >= row.at_usec:
				details.append("%s：%.2f秒自然到期" % [effect.status, expiry.at_usec / 1000000.0])
				break
	return "\n".join(details)

static func _number(value: float) -> String:
	return EffectSystem.number_text(value)
