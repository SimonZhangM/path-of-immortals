class_name EffectSystem
extends RefCounted

# Unlisted types are neutral. Tooltip and combat share this exact matrix.
const ARMOR_MULTIPLIERS := {
	"斩击": {"无甲": 1.2, "轻甲": 1.0, "重甲": 0.8, "灵甲": 1.0},
	"穿刺": {"无甲": 1.0, "轻甲": 1.2, "重甲": 0.8, "灵甲": 1.0},
	"钝击": {"无甲": 1.0, "轻甲": 1.0, "重甲": 1.2, "灵甲": 1.0},
}

static func armor_multiplier(damage_type: String, armor_type: String) -> float:
	return float(ARMOR_MULTIPLIERS.get(damage_type, {}).get(armor_type, 1.0))

static func number_text(value: float) -> String:
	return String.num(value, 6).trim_suffix(".0")

static func damage_type_meaning(damage_type: String) -> String:
	var parts: PackedStringArray = []
	for armor_type: String in ARMOR_MULTIPLIERS.get(damage_type, {}):
		var multiplier := armor_multiplier(damage_type, armor_type)
		if not is_equal_approx(multiplier, 1.0):
			parts.append("对%s伤害%s%d%%" % [armor_type, "提高" if multiplier > 1.0 else "降低", roundi(absf(multiplier - 1.0) * 100)])
	parts.append("对其他甲型伤害100%")
	return "，".join(parts) + "。"

static func validate_definition(effect: Dictionary) -> bool:
	var allowed := {"on_activate": ["damage", "apply_toxin", "restore_over_time", "restore_armor", "restore_capped", "restore_ticks", "cleanse_toxin"], "on_enter": ["defense"], "on_attacked": ["counter_damage"]}
	if not allowed.has(effect.get("trigger")) or effect.get("effect") not in allowed[effect["trigger"]]:
		return false
	if effect.has("damage_type") and (effect.effect != "damage" or effect.damage_type not in ARMOR_MULTIPLIERS):
		return false
	if effect.effect == "cleanse_toxin":
		return ContentRegistry._positive_number(effect.get("duration")) and effect.duration <= 86400
	if effect["effect"] == "restore_over_time":
		if effect.get("resource") not in ["hp", "stamina", "spirit"]:
			return false
		var duration: Variant = effect.get("duration")
		if not ContentRegistry._positive_integer(duration) or float(duration) > 60:
			return false
	if effect["effect"] in ["restore_capped", "restore_ticks"]:
		if effect.get("resource") not in ["hp", "stamina", "spirit"]:
			return false
	if effect["effect"] == "restore_capped":
		if not ContentRegistry._positive_integer(effect.get("cap_numerator")) or not ContentRegistry._positive_integer(effect.get("cap_denominator")) or effect.cap_numerator > effect.cap_denominator:
			return false
	if effect["effect"] == "restore_ticks":
		if not ContentRegistry._positive_integer(effect.get("ticks")) or effect.ticks > 60 or not ContentRegistry._positive_number(effect.get("interval")) or effect.interval > 60:
			return false
	var value: Variant = effect.get("value")
	return (value is int or value is float) and is_finite(float(value)) and float(value) > 0.0 and float(value) <= 1_000_000_000.0 and floor(float(value)) == float(value)

func apply(effect: Dictionary, state: GameState, target: PartyMemberState, at_usec: int, source: Dictionary) -> Dictionary:
	if state.is_finished() or target.hp <= 0 or not validate_definition(effect) or effect["effect"] not in ["damage", "counter_damage"]:
		return {}
	var is_counter: bool = effect["effect"] == "counter_damage"
	var blocked := 0.0
	var armor_absorbed := 0.0
	var damage_type := String(effect.get("damage_type", source.get("damage_type", "")))
	var multiplier := 1.0 if state.legacy_fixed_defense or is_counter else armor_multiplier(damage_type, target.armor_type)
	var damage := float(effect.value) * multiplier
	if state.legacy_fixed_defense:
		blocked = 0 if is_counter else mini(target.defense, int(effect["value"]))
	else:
		armor_absorbed = minf(target.armor, damage)
		target.armor = maxf(0.0, target.armor - armor_absorbed)
		blocked = armor_absorbed
	var dealt := minf(target.hp, maxf(0.0, damage - blocked))
	target.hp = maxf(0.0, target.hp - dealt)
	if is_zero_approx(target.hp):
		target.hp = 0.0
	state.damage_totals[source["side"]] += dealt
	state.revision += 1
	var event := source.duplicate()
	event.merge({"kind": "counter_damage" if is_counter else "damage", "at_usec": at_usec, "target_id": target.id, "target_name": target.definition["name"], "value": dealt, "blocked": blocked, "raw_damage": int(effect["value"]), "hp_after": target.hp})
	event.merge({"damage_type": damage_type, "armor_multiplier": multiplier, "adjusted_damage": damage})
	if not state.legacy_fixed_defense:
		event["armor_absorbed"] = armor_absorbed
		event["armor_after"] = target.armor
	return event

func restore(target: PartyMemberState, resource: String, amount: int, at_usec: int, source: Dictionary, ceiling: int = -1) -> Dictionary:
	if target.hp <= 0:
		return {}
	var before: float = target.get(resource)
	var limit := target.maximum(resource) if ceiling < 0 else mini(ceiling, target.maximum(resource))
	# A recovery ceiling never lowers a resource already above that ceiling.
	var after := minf(before + amount, limit) if ceiling < 0 else before + minf(amount, maxf(0.0, limit - before))
	target.set(resource, after)
	var event := source.duplicate()
	event.merge({"kind": "restore", "at_usec": at_usec, "target_name": target.definition["name"], "resource": resource, "value": after - before})
	return event
