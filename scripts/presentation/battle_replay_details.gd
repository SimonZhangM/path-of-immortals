class_name BattleReplayDetails
extends RefCounted

const Format = preload("res://scripts/presentation/battle_replay_format.gd")
const COUNTS := ["rotation", "trigger", "buff_apply", "debuff_apply", "attack_hits", "attack_crits", "attack_misses", "attack_immune", "status_removed"]
const EXTRA := {
	"attack_hits": [14, "命中次数"], "attack_crits": [15, "暴击次数"],
	"attack_misses": [16, "未命中"], "attack_immune": [20, "免疫"],
	"damage_direct": [1, "直接伤害"], "damage_status": [1, "状态伤害"],
	"damage_counter": [1, "反击／追击"], "shield_discarded": [6, "替换失效盾量"],
	"generated_barrier": [6, "生成灵盾"], "generated_thunder_shield": [24, "生成雷盾"],
	"generated_sword_screen": [6, "生成剑幕"], "absorbed_barrier": [12, "灵盾承伤"],
	"absorbed_thunder_shield": [24, "雷盾承伤"], "absorbed_sword_screen": [12, "剑幕承伤"],
	"stamina_drained": [18, "削减体力"], "spirit_drained": [19, "削减灵力"], "status_removed": [8, "主动解除"],
	"hp_restored_direct": [2, "直接回血"], "hp_restored_periodic": [2, "持续回血"],
	"stamina_restored_direct": [3, "直接回体"], "stamina_restored_periodic": [3, "持续回体"],
	"spirit_restored_direct": [4, "直接回灵"], "spirit_restored_periodic": [4, "持续回灵"]
}

static func primary_metric(item: ItemData) -> String:
	var configured: String = item.combat.get("replay_primary", "")
	if Format.METRICS.has(configured): return configured
	if Format.profile(item) == "buff" and item.effects.any(func(effect): return effect.effect == "cleanse_toxin"):
		return "status_removed"
	match Format.profile(item):
		"attack": return "damage_total"
		"armor": return "armor_granted"
		"shield": return "shield_absorbed"
		"debuff": return "debuff_apply"
		"recovery":
			var resources: Array = []
			for effect: Dictionary in item.effects:
				if effect.effect.begins_with("restore"):
					resources.append(effect.get("resource", "hp"))
			resources.append_array(item.combat.get("periodic_restore", {}).get("resources", {}).keys())
			for status: Dictionary in item.combat.get("statuses", []):
				if status.get("status") == "润脉": resources.append("spirit")
				if status.get("status") == "生机": resources.append("hp")
			if "hp" in resources or item.combat.get("opcode") == "heal": return "hp_restored"
			if "stamina" in resources: return "stamina_restored"
			if "spirit" in resources: return "spirit_restored"
			return "hp_restored"
	return "buff_apply"

static func share(item: ItemData, row: Dictionary, snapshot: Dictionary) -> Dictionary:
	return metric_share(primary_metric(item), row, snapshot)

static func shares(item: ItemData, row: Dictionary, snapshot: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = [share(item, row, snapshot)]
	if Format.profile(item) != "recovery": return result
	var resources: Array = item.combat.get("periodic_restore", {}).get("resources", {}).keys()
	if item.combat.get("opcode") == "heal": resources.append("hp")
	var statuses: Array = item.combat.get("statuses", []).duplicate()
	for effect: Dictionary in item.effects:
		if effect.effect.begins_with("restore"):
			resources.append(effect.get("resource", "hp"))
		if effect.effect == "apply_status": statuses.append(effect)
	for status: Dictionary in statuses:
		if status.get("status") == "生机": resources.append("hp")
		if status.get("status") == "润脉": resources.append("spirit")
	for resource: String in ["hp", "stamina", "spirit"]:
		var key := resource + "_restored"
		if key == result[0].key: continue
		if resource in resources or float(row.get("metrics", {}).get(key, 0)) > 0:
			result.append(metric_share(key, row, snapshot))
			break
	return result

static func metric_share(key: String, row: Dictionary, snapshot: Dictionary) -> Dictionary:
	var side := int(row.get("side", -1))
	var totals: Array = snapshot.get("team_metrics", [])
	var total := -1.0
	if side >= 0 and side < totals.size(): total = float(totals[side].get(key, 0))
	var value := float(row.get("metrics", {}).get(key, 0))
	var caption: String = {"damage_total":"伤害", "hp_restored":"气血恢复", "stamina_restored":"体力恢复", "spirit_restored":"灵力恢复", "armor_granted":"补甲", "shield_absorbed":"护盾承伤", "buff_apply":"增益施加", "debuff_apply":"减益施加", "status_removed":"主动解除"}.get(key, "贡献")
	var percent := "—"
	if total > 0:
		percent = "<0.1%" if value > 0 and value / total < 0.001 else "%.1f%%" % (value / total * 100)
	return {"key": key, "value": value, "total": total, "ratio": value / total if total > 0 else 0.0, "percent": percent, "caption": caption, "side": "敌方" if side == 1 else "我方"}

static func icon_path(key: String) -> String:
	var number: int = EXTRA[key][0] if EXTRA.has(key) else Format.METRICS.get(key, [0, ""])[0]
	return "res://assets/UI-battle-icon-%02d.webp" % number if number > 0 else ""

static func metric_row(key: String, value: float, primary := false) -> Dictionary:
	var caption: String = EXTRA[key][1] if EXTRA.has(key) else Format.METRICS[key][1]
	if key == "damage_total": caption = "总伤害"
	if key == "rotation": caption = "发动次数"
	if key == "trigger": caption = "触发次数"
	return {"key": key, "label": caption, "value": Format.number(value) + ("次" if key in COUNTS else ""), "icon": icon_path(key), "primary": primary}

static func rows(item: ItemData, row: Dictionary, registry: ContentRegistry, snapshot: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var metrics: Dictionary = row.get("metrics", {})
	var primary := primary_metric(item)
	result.append(metric_row(primary, float(metrics.get(primary, 0)), true))
	var ordered: Array = []
	match Format.profile(item):
		"attack": ordered = ["attack_hits", "attack_crits", "attack_misses", "attack_immune"]
		"recovery": ordered = ["hp_restored", "stamina_restored", "spirit_restored"]
		"armor": ordered = ["armor_granted", "damage_mitigated", "shield_generated", "shield_absorbed"]
		"shield": ordered = ["shield_generated", "shield_absorbed", "absorbed_barrier", "absorbed_thunder_shield", "absorbed_sword_screen", "shield_discarded"]
		"buff": ordered = ["buff_apply", "damage_assist", "damage_mitigated"]
		"debuff": ordered = ["debuff_apply", "damage_total"]
	ordered.append_array(["rotation", "stamina_spent", "spirit_spent", "trigger"])
	ordered.append_array(["damage_total", "damage_direct", "damage_status", "damage_counter", "hp_restored", "stamina_restored", "spirit_restored", "armor_granted", "shield_generated", "shield_absorbed", "buff_apply", "debuff_apply", "damage_assist", "damage_mitigated", "stamina_drained", "spirit_drained"])
	var effects: Dictionary = row.get("effect_stats", {})
	var shown := {primary: true}
	for key: String in ordered:
		if shown.has(key): continue
		shown[key] = true
		if metrics.get(key, 0) <= 0 and not (key == "rotation" and Format.rotates(item)): continue
		if key == "damage_direct" and is_equal_approx(float(metrics.get(key, 0)), float(metrics.get("damage_total", 0))): continue
		# Exact status rows already show these same subtotals and application counts.
		if key in ["damage_status", "buff_apply", "debuff_apply"]:
			var covered := 0.0
			for effect: Dictionary in effects.values(): covered += float(effect.get("metrics", {}).get(key, 0))
			if is_equal_approx(covered, float(metrics.get(key, 0))): continue
		result.append(metric_row(key, float(metrics.get(key, 0))))
	for resource in ["hp", "stamina", "spirit"]:
		var direct_key: String = resource + "_restored_direct"
		var periodic_key: String = resource + "_restored_periodic"
		if metrics.get(direct_key, 0) > 0 and metrics.get(periodic_key, 0) > 0:
			result.append(metric_row(direct_key, float(metrics[direct_key])))
			result.append(metric_row(periodic_key, float(metrics[periodic_key])))
	var icons: Dictionary = {}
	for definition: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/combat_status_keywords.json")):
		icons[definition.name] = definition.icon
	for label: String in ["毒蚀免疫", "麻痹", "冻结", "定身", "雷盾"]:
		var number: int = {"毒蚀免疫": 20, "麻痹": 21, "冻结": 22, "定身": 23, "雷盾": 24}[label]
		icons[label] = "res://assets/UI-battle-icon-%02d.webp" % number
	var effect_order: Array = []
	for label: String in icons:
		if effects.has(label): effect_order.append(label)
	for label: String in effects:
		if label not in effect_order: effect_order.append(label)
	for label: String in effect_order:
		var values: Dictionary = effects[label].get("metrics", {})
		var fragments: Array[String] = []
		var applications := int(values.get("buff_apply", 0) + values.get("debuff_apply", 0))
		if applications > 0: fragments.append("施加%d次" % applications)
		for key in ["damage_total", "hp_restored", "stamina_restored", "spirit_restored", "shield_absorbed", "damage_assist", "damage_mitigated", "stamina_drained", "spirit_drained"]:
			if values.get(key, 0) > 0:
				var caption: String = EXTRA[key][1] if EXTRA.has(key) else Format.METRICS[key][1]
				fragments.append(caption + Format.number(values[key]))
		if values.get("trigger", 0) > 0: fragments.append("参与%d次" % int(values.trigger))
		if values.get("status_failed", 0) > 0: fragments.append("未生效%d次" % int(values.status_failed))
		if values.get("status_removed", 0) > 0: fragments.append("主动解除%d次" % int(values.status_removed))
		if effects[label].get("unquantified", false): fragments.append("辅助量未量化")
		if not fragments.is_empty():
			result.append({"key": "effect/" + label, "label": label, "value": " · ".join(fragments), "icon": icons.get(label, ""), "primary": false})
	# Older in-memory snapshots can identify a status without a per-status breakdown.
	for label: String in row.get("statuses", {}):
		if not effects.has(label): result.append({"key": "effect/" + label, "label": label, "value": "已参与", "icon": icons.get(label, ""), "primary": false})
	for resource: String in row.get("restore_reasons", {}):
		if metrics.get(resource + "_restored", 0) > 0: continue
		var reason: String = {"item_cap":"已达物品恢复上限", "resource_full":"资源已满", "injury":"受重伤抑制", "reduced":"恢复被抑制"}.get(row.restore_reasons[resource], "实际恢复为0")
		result.append({"key": "restore_reason/" + resource, "label": "恢复结果", "value": reason, "icon": "", "primary": false})
	for id: String in row.get("participants", []):
		var participant: Dictionary = snapshot.get("items", {}).get(id, {})
		var definition := registry.get_item(participant.get("item_id", ""))
		if definition != null:
			result.append({"key": "participant/" + id, "label": "参与武器", "value": definition.display_name, "icon": definition.icon_path, "primary": false})
	return result
