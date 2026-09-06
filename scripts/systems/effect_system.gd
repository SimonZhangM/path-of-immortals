class_name EffectSystem
extends RefCounted

static func validate_definition(effect: Dictionary) -> bool:
	if effect.get("trigger") != "on_activate" or effect.get("effect") != "damage":
		return false
	var value: Variant = effect.get("value")
	return (value is int or value is float) and is_finite(float(value)) and float(value) > 0.0 and float(value) <= 1_000_000_000.0 and floor(float(value)) == float(value)

func apply(effect: Dictionary, state: GameState, target: PartyMemberState, at_usec: int, source: Dictionary) -> Dictionary:
	if state.is_finished() or target.hp <= 0 or not validate_definition(effect):
		return {}
	var dealt := mini(target.hp, int(effect["value"]))
	target.hp -= dealt
	state.damage_totals[source["side"]] += dealt
	state.revision += 1
	var event := source.duplicate()
	event.merge({"kind": "damage", "at_usec": at_usec, "target_id": target.id, "target_name": target.definition["name"], "value": dealt, "hp_after": target.hp})
	return event
