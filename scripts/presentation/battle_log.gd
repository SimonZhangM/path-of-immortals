class_name BattleLog
extends RefCounted

const MAX_LINES := 500
var _lines: PackedStringArray = []

func reset() -> void:
	_lines = PackedStringArray(["[00.00] 战斗开始。"])

func consume(events: Array[Dictionary], registry: ContentRegistry) -> String:
	for event in events:
		var stamp := "[%05.2f]" % (int(event["at_usec"]) / 1_000_000.0)
		match event["kind"]:
			"trait_activated":
				_lines.append("%s %s·%s发动" % [stamp, event["owner_name"], _source_name(event, registry)])
			"retreat_started":
				_lines.append("%s 开始撤退准备，需3秒。" % stamp)
			"entered":
				_lines.append("%s %s·%s进场，防御+%d" % [stamp, event["owner_name"], _source_name(event, registry), event["defense"]])
			"counter_damage":
				_lines.append("%s %s·%s反击 → %s，伤害%s（无视防御）" % [stamp, event["owner_name"], _source_name(event, registry), event["target_name"], EffectSystem.number_text(event["value"])])
			"restore":
				_lines.append("%s %s · %s +%s" % [stamp, event["target_name"], {"hp": "气血", "stamina": "体力", "spirit": "灵力", "armor": "护甲"}[event["resource"]], EffectSystem.number_text(event["value"])])
			"pill_used":
				_lines.append("%s %s使用%s%s" % [stamp, event["owner_name"], _source_name(event, registry), "，消耗1瓶" if event["consumed"] else "，本瓶剩余1次"])
			"damage":
				_lines.append("%s %s·%s → %s，伤害%s，体力-%d" % [stamp, event["owner_name"], _source_name(event, registry), event["target_name"], EffectSystem.number_text(event["value"]), event["stamina_cost"]])
				if event.get("blocked", 0) > 0:
					_lines[-1] += ("（消耗护甲%s）" if event.has("armor_absorbed") else "（防御抵消%s）") % EffectSystem.number_text(event["blocked"])
			"toxin_applied":
				_lines.append("%s %s · 毒蚀%d层" % [stamp, event.target_name, event.stacks])
			"toxin_damage":
				_lines.append("%s %s · 毒蚀损失%s气血，剩余%d层" % [stamp, event.target_name, EffectSystem.number_text(event.value), event.stacks_after])
			"fallen":
				_lines.append("%s %s阵亡。" % [stamp, event["target_name"]])
			"finished":
				_lines.append("%s %s" % [stamp, {"victory": "战斗胜利", "defeat": "战斗失败", "draw": "体力耗尽，平局", "retreat": "已成功撤退"}[event["result"]]])
	while _lines.size() > MAX_LINES:
		_lines.remove_at(0)
	return "\n".join(_lines)

func _source_name(event: Dictionary, registry: ContentRegistry) -> String:
	return str(registry.get_trait(event["trait_id"])["name"]) if event.has("trait_id") else registry.get_item(event["item_id"]).display_name
