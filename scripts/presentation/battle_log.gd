class_name BattleLog
extends RefCounted

const MAX_LINES := 12
var _lines: PackedStringArray = []

func reset() -> void:
	_lines = PackedStringArray(["[00.00] 战斗开始。"])

func consume(events: Array[Dictionary], registry: ContentRegistry) -> String:
	for event in events:
		var stamp := "[%05.2f]" % (int(event["at_usec"]) / 1_000_000.0)
		match event["kind"]:
			"damage":
				_lines.append("%s %s·%s → %s，伤害%d，体力-%d" % [stamp, event["owner_name"], registry.get_item(event["item_id"]).display_name, event["target_name"], event["value"], event["stamina_cost"]])
			"fallen":
				_lines.append("%s %s阵亡。" % [stamp, event["target_name"]])
			"finished":
				_lines.append("%s %s" % [stamp, {"victory": "战斗胜利", "defeat": "战斗失败", "draw": "体力耗尽，平局"}[event["result"]]])
	while _lines.size() > MAX_LINES:
		_lines.remove_at(0)
	return "\n".join(_lines)
