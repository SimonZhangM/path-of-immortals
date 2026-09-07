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
			"restore":
				_lines.append("%s %s · %s +%d" % [stamp, event["target_name"], {"hp": "气血", "stamina": "体力", "spirit": "灵力"}[event["resource"]], event["value"]])
			"pill_used":
				_lines.append("%s %s使用%s%s" % [stamp, event["owner_name"], registry.get_item(event["item_id"]).display_name, "，消耗1瓶" if event["consumed"] else "，本瓶剩余1次"])
			"damage":
				_lines.append("%s %s·%s → %s，伤害%d，体力-%d" % [stamp, event["owner_name"], registry.get_item(event["item_id"]).display_name, event["target_name"], event["value"], event["stamina_cost"]])
			"fallen":
				_lines.append("%s %s阵亡。" % [stamp, event["target_name"]])
			"finished":
				_lines.append("%s %s" % [stamp, {"victory": "战斗胜利", "defeat": "战斗失败", "draw": "体力耗尽，平局"}[event["result"]]])
	while _lines.size() > MAX_LINES:
		_lines.remove_at(0)
	return "\n".join(_lines)
