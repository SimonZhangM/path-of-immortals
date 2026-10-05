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
			"item_activated":
				if event.has("spirit_cost"):
					_lines.append("%s %s·%s发动（耗体%s／耗灵%s）" % [stamp,event.owner_name,_source_name(event,registry),EffectSystem.number_text(event.stamina_cost),EffectSystem.number_text(event.spirit_cost)])
			"effect_error":
				_lines.append(stamp + " 结算错误：" + event.message)
			"shield_created":
				_lines.append("%s %s · 生成雷盾%s" % [stamp, event.target_name, EffectSystem.number_text(event.value)])
			"barrier_changed":
				_lines.append("%s %s · 灵盾现值%s" % [stamp, event.target_name, EffectSystem.number_text(event.value)])
			"status_applied":
				_lines.append("%s %s · %s＋%d，现%d层" % [stamp, event.target_name, event.status, event.value, event.layers])
			"status_tick", "status_damage":
				_lines.append("%s %s · %s结算%s" % [stamp, event.target_name, event.status, EffectSystem.number_text(event.value)])
			"control":
				_lines.append("%s %s · %s至%.2f秒" % [stamp, event.target_name, event.status, event.until / 1000000.0])
			"shield_interrupted":
				_lines.append("%s %s · 本击扣盾%s；盾反击败攻击者，余伤中止" % [stamp,event.target_name,EffectSystem.number_text(event.value)])
			"armor_only":
				_lines.append("%s %s · %s额外扣甲%s" % [stamp,event.target_name,event.label,EffectSystem.number_text(event.value)])
			"cast_interrupted":
				_lines.append("%s %s · 发动被%s截断，重开CD" % [stamp,event.target_name,event.label])
			"miss":
				_lines.append("%s %s攻击%s未命中" % [stamp, event.owner_name, event.target_name])
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
				_lines.append("%s %s使用%s%s" % [stamp, event["owner_name"], _source_name(event, registry), "，消耗1件" if event["consumed"] else "，本件剩余1次"])
			"damage":
				_lines.append("%s %s·%s → %s，气血-%s%s" % [stamp, event["owner_name"], _source_name(event, registry), event["target_name"], EffectSystem.number_text(event["value"]), "（暴击）" if event.get("critical", false) else ""])
				if event.get("blocked", 0) > 0:
					_lines[-1] += "（盾-%s，甲-%s）" % [EffectSystem.number_text(event.get("shield_absorbed", 0)), EffectSystem.number_text(event.get("armor_absorbed", event.blocked))]
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
	if not event.has("trait_id") and not event.has("item_id"):
		return event.get("label", "攻击")
	return str(registry.get_trait(event["trait_id"])["name"]) if event.has("trait_id") else registry.get_item(event["item_id"]).display_name
