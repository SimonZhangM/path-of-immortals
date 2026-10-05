class_name T01Definition
extends RefCounted

const STATUS_GROUPS := {
	"metal": ["反锋", "锋痕", "流血"], "wood": ["生机", "毒蚀", "缠绕"],
	"water": ["润脉", "枯脉", "寒霜"], "fire": ["附炎", "灼烧", "破甲"],
	"earth": ["坚韧", "疲惫", "重伤"], "wind": ["轻灵", "失衡", "驱散"],
	"thunder": ["雷蕴", "雷印", "连环"]
}
const SLOTS := ["身甲", "头具", "护具·臂", "护具·腿", "护具·肩", "护具·腰", "盾"]

static func item_record(record: Dictionary) -> Dictionary:
	return {
		"id": record.id, "name": record.name, "type": record.category, "category": record.category,
		"quality": record.quality, "tags": [record.get("subcategory", ""), record.get("damage_type", "")],
		"size": [record.footprint_columns, record.footprint_rows], "icon": record.icon,
		"cooldown": record.cooldown, "stamina_cost": record.get("base_stamina_cost", 0),
		"spirit_cost": record.get("spirit_cost", 0), "element": record.element,
		"effects": record.effects.duplicate(true), "uses_per_unit": record.get("uses_per_unit", 0),
		"armor_capacity": record.get("armor_capacity", 0), "armor_type": record.get("armor_type", ""),
		"armor_slot": record.subcategory if record.category == "armor" else "",
		"rule_version": 1, "combat": record.duplicate(true)
	}

static func status_element(status: String) -> String:
	for element: String in STATUS_GROUPS:
		if status in STATUS_GROUPS[element]:
			return element
	return ""

static func is_buff(status: String) -> bool:
	var element := status_element(status)
	return not element.is_empty() and STATUS_GROUPS[element][0] == status

static func runtime_error(raw: Dictionary) -> String:
	if raw.get("rule_version", 0) not in [0, 1]:
		return "unsupported rule_version"
	if raw.get("rule_version", 0) == 0:
		return ""
	var combat: Variant = raw.get("combat")
	if not combat is Dictionary or not combat.get("source_location") is String:
		return "T01 combat requires a source_location"
	for cost in [raw.get("stamina_cost", 0), raw.get("spirit_cost", 0)]:
		if not (cost is int or cost is float) or not is_finite(cost) or cost < 0:
			return "T01 costs must be finite nonnegative numbers"
	if raw.get("category") in ["pill", "throwable"] and raw.get("uses_per_unit") != 1:
		return "T01 consumables require one use per unit"
	for flag in ["first_ready", "barrier_full_stop"]:
		if not combat.get(flag, false) is bool:
			return "T01 flag must be boolean: " + flag
	for effect: Dictionary in raw.effects:
		if effect.get("effect") not in ["damage", "apply_status", "restore_capped", "restore_ticks", "restore_instant", "restore_armor", "cleanse_toxin", "barrier", "resistance", "cast_spell"]:
			return "T01 effect is not implemented: " + str(effect.get("effect"))
		if effect.get("effect") == "damage":
			var chance: Variant = combat.get("hit_chance")
			if not (chance is float or chance is int) or not is_finite(chance) or chance < 0 or chance > 1 or effect.get("damage_type") not in EffectSystem.ARMOR_MULTIPLIERS:
				return "T01 attack requires explicit hit chance and damage type"
	return ""

static func valid_effect(e: Dictionary) -> bool:
	if e.get("trigger") not in ["on_activate", "on_attacked"]:
		return false
	if e.get("trigger") == "on_attacked" and (e.get("effect") != "apply_status" or not ContentRegistry._positive_number(e.get("cooldown"))):
		return false
	match e.get("effect"):
		"cast_spell":
			return e.get("trigger") == "on_activate" and e.get("opcode") in CultivationLibrary.OPCODES
		"apply_status":
			return not status_element(e.get("status", "")).is_empty() and ContentRegistry._positive_integer(e.get("value")) and e.get("target") in ["self", "enemy"] and e.get("gate") in ["hit", "hp_damage", "always"]
		"barrier":
			return ContentRegistry._positive_number(e.get("value"))
		"restore_instant":
			return e.get("resource") in ["hp", "stamina", "spirit"] and ContentRegistry._positive_number(e.get("value"))
		"resistance":
			return e.get("element") in ["base.element.metal", "base.element.wood", "base.element.water", "base.element.fire", "base.element.earth"] and ContentRegistry._positive_number(e.get("value")) and e.value <= 1 and ContentRegistry._positive_number(e.get("duration"))
	return false
