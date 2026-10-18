class_name MapFood
extends RefCounted

# Food recovery is a rest action; the battle only receives resolved modifiers.
static func valid_definition(raw: Variant) -> bool:
	if not raw is Dictionary: return false
	for key in ["hp_percent","stamina_percent"]:
		if not WorldCalendar.integer_between(raw.get(key),0,100): return false
	if raw.get("bonus_stat") not in ["","accuracy","evasion"]: return false
	return (raw.get("bonus_points")==0 and raw.get("duration_days")==0) if raw.bonus_stat=="" else (WorldCalendar.integer_between(raw.get("bonus_points"),1,100) and raw.get("duration_days")==1)

static func valid_bonus(raw: Variant, records: Dictionary) -> bool:
	if not raw is Dictionary: return false
	if raw.is_empty(): return true
	if raw.size()!=3 or not raw.get("item_id") is String: return false
	var record: Dictionary = records.get(raw.item_id,{})
	if record.get("category")!="food" or not valid_definition(record.get("food")) or record.food.bonus_stat=="": return false
	return WorldCalendar.integer_between(raw.get("start_day"),0,WorldCalendar.MAX_DAY-1) and WorldCalendar.integer_between(raw.get("expires_day"),1,WorldCalendar.MAX_DAY) and raw.expires_day==raw.start_day+1

static func modifiers(state: MapLoadoutState) -> Dictionary:
	var effect := state.food_bonus
	var today := WorldCalendar.current_day(state.calendar)
	if effect.is_empty() or today<int(effect.start_day) or today>=int(effect.expires_day): return {}
	var food: Dictionary = state.records[effect.item_id].food
	return {food.bonus_stat: float(food.bonus_points)/100.0}

static func recovery_text(record: Dictionary) -> String:
	var parts: PackedStringArray = []
	var food: Dictionary = record.food
	if food.hp_percent>0: parts.append("气血+%d%%" % int(food.hp_percent))
	if food.stamina_percent>0: parts.append("体力+%d%%" % int(food.stamina_percent))
	return "  ".join(parts)

static func effect_text(record: Dictionary) -> String:
	var food: Dictionary = record.food
	var text := "休息时食用1份，按上限额外恢复：%s。恢复不超过各上限。" % recovery_text(record)
	if food.bonus_stat!="":
		text += "\n%s：%s+%d%%，休息结束后持续1游戏日。" % ["清神" if food.bonus_stat=="accuracy" else "轻身","命中" if food.bonus_stat=="accuracy" else "闪避",int(food.bonus_points)]
	return text

static func meal_summary(record: Dictionary) -> String:
	var text := "进食效果：额外恢复 "+recovery_text(record).replace("  ","、")
	var food: Dictionary=record.food
	if food.bonus_stat!="":
		text += "，额外增加 %s+%d%%" % ["命中" if food.bonus_stat=="accuracy" else "闪避",int(food.bonus_points)]
	return text

static func carried_unit(state: MapLoadoutState, item_id: String) -> String:
	if state.records.get(item_id,{}).get("category")!="food": return ""
	for entry: Dictionary in state.storage.entries():
		if entry.item_id==item_id and not entry.units.is_empty(): return entry.units[0].id
	return ""

static func apply_to_candidate(candidate: MapLoadoutState, item_id: String, result: Dictionary, maxima: Dictionary) -> String:
	var unit := carried_unit(candidate,item_id)
	if unit.is_empty(): return "储物袋内已没有这道菜品，请重新选择。"
	var food: Dictionary = candidate.records[item_id].food
	var today := WorldCalendar.current_day(candidate.calendar)
	if food.bonus_stat!="" and today>=WorldCalendar.MAX_DAY: return "日期已超出可用范围。"
	var next := candidate.snapshot()
	next.owned_units.erase(unit)
	# Each rest advances a full day, so any previous one-day meal has expired.
	next.food_bonus = {} if food.bonus_stat=="" else {"item_id":item_id,"start_day":today,"expires_day":today+1}
	var error := candidate.restore(next)
	if not error.is_empty(): return error
	for resource in ["hp","stamina"]:
		result.after[resource] = minf(float(maxima[resource]),float(result.after[resource])+float(maxima[resource])*float(food[resource+"_percent"])/100.0)
		result.gains[resource] = result.after[resource]-result.before[resource]
	result.food_item_id = item_id
	return ""
