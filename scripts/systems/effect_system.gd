class_name EffectSystem
extends RefCounted

# The sole effect dispatch boundary. Add reusable handlers here in a later phase.
static func validate_definition(effect: Dictionary) -> bool:
	if effect.get("trigger") != "on_activate" or effect.get("effect") != "damage":
		return false
	var value: Variant = effect.get("value")
	return (value is int or value is float) and is_finite(float(value)) and float(value) > 0.0 and float(value) <= 1_000_000_000.0 and floor(float(value)) == float(value)

func apply(effect: Dictionary, state: GameState, at_usec: int, source: Dictionary = {}) -> Dictionary:
	if state.is_finished() or not validate_definition(effect):
		return {}
	var dealt := mini(state.enemy_hp, int(effect["value"]))
	state.enemy_hp -= dealt
	state.damage_total += dealt
	state.revision += 1
	if state.is_finished():
		state.defeated_at_usec = at_usec
	return {"kind": "damage", "at_usec": at_usec, "item_id": source.get("item_id", state.item_id), "instance_id": source.get("instance_id", state.item_instance_id), "owner_id": source.get("owner_id", ""), "target_id": state.enemy_id, "value": dealt, "hp_after": state.enemy_hp}
