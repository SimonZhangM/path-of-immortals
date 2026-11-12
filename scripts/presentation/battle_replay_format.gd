class_name BattleReplayFormat
extends RefCounted
const METRICS := {
	"damage_total":[1,"造成伤害"],"hp_restored":[2,"恢复气血"],"stamina_restored":[3,"恢复体力"],"stamina_spent":[3,"消耗体力"],
	"spirit_restored":[4,"恢复灵力"],"spirit_spent":[4,"消耗灵力"],"armor_granted":[5,"提供护甲"],"shield_generated":[6,"生成护盾"],
	"buff_apply":[7,"施加增益"],"debuff_apply":[8,"施加减益"],"rotation":[9,"转轮次数"],"damage_assist":[10,"增伤贡献"],
	"damage_mitigated":[11,"减伤贡献"],"shield_absorbed":[12,"护盾承伤"],"trigger":[13,"参与触发"]}
static var _icons: Dictionary = {}

static func icon(metric: String) -> Texture2D:
	var id: int = METRICS.get(metric,[13,""])[0]
	if not _icons.has(id): _icons[id] = load("res://assets/UI-battle-icon-%02d.webp" % id)
	return _icons[id]

static func number(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) else ("%.1f" % value)

static func formatted(_metric: String, value: float) -> String:
	return number(absf(value))

static func profile(item: ItemData) -> String:
	# Classify from content, never from this battle's largest result.
	var override: String = item.combat.get("replay_profile", "")
	if override in ["attack","recovery","shield","armor","buff","debuff"]: return override
	var opcode: String = item.combat.get("opcode", "")
	if item.category == "weapon" or opcode in ["attack","command_weapon","weapon_union","followup","armor_counter"] or item.effects.any(func(e): return e.effect == "damage"): return "attack"
	if opcode == "heal" or item.combat.has("periodic_restore") or item.effects.any(func(e): return e.effect in ["restore_capped","restore_instant","restore_ticks"]): return "recovery"
	if opcode in ["sword_screen","weapon_barrier"] or item.effects.any(func(e): return e.effect == "barrier"): return "shield"
	if item.effects.any(func(e): return e.effect == "restore_armor") or item.armor_capacity > 0: return "armor"
	var statuses: Array = item.combat.get("statuses", [])
	for effect: Dictionary in item.effects:
		if effect.effect == "apply_status": statuses = statuses + [effect]
	if statuses.any(func(e): return e.get("status","") in ["毒蚀","流血","灼烧","锋痕","反锋","雷印","连环"]): return "attack"
	if statuses.any(func(e): return e.get("status","") in ["生机","润脉"]): return "recovery"
	if statuses.any(func(e): return not T01Definition.is_buff(e.get("status",""))): return "debuff"
	return "buff"

static func rotates(item: ItemData) -> bool:
	return item.cooldown_usec > 0 and (item.category == "spell" or not item.effects_for("on_activate").is_empty())

static func lines(item: ItemData, row: Dictionary, mode := "all") -> Array:
	var m: Dictionary = row.get("metrics", {})
	var keys: Array = []
	var kind := profile(item)
	if mode == "damage":
		if kind == "attack" or m.get("damage_total",0)>0: keys.append("damage_total")
		if m.get("damage_assist",0)>0: keys.append("damage_assist")
	elif mode == "recovery" or mode == "all" and kind == "recovery":
		for key in ["hp_restored","stamina_restored","spirit_restored"]:
			if m.get(key,0)>0: keys.append(key)
	elif mode == "defense":
		for key in ["armor_granted","shield_generated","damage_mitigated"]:
			if m.get(key,0)>0: keys.append(key)
	elif mode == "trigger":
		for key in ["buff_apply","debuff_apply","trigger"]:
			if m.get(key,0)>0: keys.append(key)
	else:
		var primary: String = {"attack":"damage_total","armor":"armor_granted","shield":"shield_generated","buff":"buff_apply","debuff":"debuff_apply"}.get(kind,"buff_apply")
		if kind == "buff" and m.has("damage_assist"): primary="damage_assist"
		if kind == "buff" and m.has("damage_mitigated"): primary="damage_mitigated"
		if kind in ["attack","armor","shield"] or m.get(primary,0)>0: keys.append(primary)
		var cost := "spirit_spent" if item.spirit_cost > 0 else "stamina_spent"
		if m.get(cost,0)<=0: cost="stamina_spent" if cost=="spirit_spent" else "spirit_spent"
		if m.get(cost,0)>0: keys.append(cost)
		elif kind in ["armor","shield"]:
			var other := "shield_generated" if kind=="armor" else "armor_granted"
			if m.get(other,0)>0: keys.append(other)
		elif m.get("trigger",0)>0: keys.append("trigger")
	var limit := 4 if kind=="recovery" else 3
	var rotating := rotates(item)
	keys = keys.slice(0,limit-1 if rotating else limit)
	if rotating: keys.append("rotation")
	var result: Array = []
	for key: String in keys: result.append({"key":key,"value":float(m.get(key,0)),"text":formatted(key,float(m.get(key,0)))})
	return result
