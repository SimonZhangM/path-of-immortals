class_name BattleLog
extends RefCounted

const MAX_LINES := 12
var _lines: PackedStringArray = []

func reset() -> void:
	_lines = PackedStringArray(["[00.00]  试炼开始，法器已就位。"])

func consume(events: Array[Dictionary], registry: ContentRegistry) -> String:
	for event in events:
		var stamp := "[%05.2f]" % (int(event["at_usec"]) / 1_000_000.0)
		if event["kind"] == "damage":
			var item := registry.get_item(event["item_id"])
			var target := registry.get_enemy(event["target_id"])
			_lines.append("%s  %s发动 · 造成 %d 伤害 · %s剩余 %d" % [stamp, item.display_name, event["value"], target["name"], event["hp_after"]])
		elif event["kind"] == "defeated":
			_lines.append("%s  %s已击破，试炼完成。" % [stamp, registry.get_enemy(event["target_id"])["name"]])
	while _lines.size() > MAX_LINES:
		_lines.remove_at(0)
	return "\n".join(_lines)
