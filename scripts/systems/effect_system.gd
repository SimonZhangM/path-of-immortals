class_name EffectSystem
extends RefCounted

static func validate_definition(effect: Dictionary) -> bool:
	var allowed := {"on_activate": ["damage", "restore_over_time", "restore_armor"], "on_enter": ["defense"], "on_attacked": ["counter_damage"]}
	if not allowed.has(effect.get("trigger")) or effect.get("effect") not in allowed[effect["trigger"]]:
		return false
	if effect["effect"] == "restore_over_time":
		if effect.get("resource") not in ["hp", "stamina", "spirit"]:
			return false
		var duration: Variant = effect.get("duration")
		if not ContentRegistry._positive_integer(duration) or float(duration) > 60:
			return false
	var value: Variant = effect.get("value")
	return (value is int or value is float) and is_finite(float(value)) and float(value) > 0.0 and float(value) <= 1_000_000_000.0 and floor(float(value)) == float(value)

func apply(effect: Dictionary, state: GameState, target: PartyMemberState, at_usec: int, source: Dictionary) -> Dictionary:
	if state.is_finished() or target.hp <= 0 or not validate_definition(effect) or effect["effect"] not in ["damage", "counter_damage"]:
		return {}
	var is_counter: bool = effect["effect"] == "counter_damage"
	var blocked := 0
	var armor_absorbed := 0
	if state.legacy_fixed_defense:
		blocked = 0 if is_counter else mini(target.defense, int(effect["value"]))
	else:
		armor_absorbed = mini(target.armor, int(effect["value"]))
		target.armor -= armor_absorbed
		blocked = armor_absorbed
	var dealt := mini(target.hp, int(effect["value"]) - blocked)
	target.hp -= dealt
	state.damage_totals[source["side"]] += dealt
	state.revision += 1
	var event := source.duplicate()
	event.merge({"kind": "counter_damage" if is_counter else "damage", "at_usec": at_usec, "target_id": target.id, "target_name": target.definition["name"], "value": dealt, "blocked": blocked, "raw_damage": int(effect["value"]), "hp_after": target.hp})
	if not state.legacy_fixed_defense:
		event["armor_absorbed"] = armor_absorbed
		event["armor_after"] = target.armor
	return event

func restore(target: PartyMemberState, resource: String, amount: int, at_usec: int, source: Dictionary) -> Dictionary:
	if target.hp <= 0:
		return {}
	var before: int = target.get(resource)
	var after := mini(before + amount, target.maximum(resource))
	target.set(resource, after)
	var event := source.duplicate()
	event.merge({"kind": "restore", "at_usec": at_usec, "target_name": target.definition["name"], "resource": resource, "value": after - before})
	return event
