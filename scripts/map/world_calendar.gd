class_name WorldCalendar
extends RefCounted

# Pure game-day arithmetic; independent of scene, wall clock and battle clock.
const RULES_PATH := "res://data/world/calendar.json"
const DAYS_PER_YEAR := 360
const YEARS_PER_CYCLE := 12
const MAX_DAY := 4_000_000_000
static var _rules: Dictionary = {}

static func rules() -> Dictionary:
	if _rules.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
		if raw is Dictionary: _rules = raw
	return _rules

static func configuration_error() -> String:
	var data := rules()
	if data.get("id") != "base.calendar.canglan" or data.get("months_per_year") != 12 or data.get("days_per_month") != 30:
		return "苍澜界历法配置无效。"
	if not data.get("world_name") is String or not data.get("year_names") is Array or data.year_names.size() != 12:
		return "灵兽纪年配置无效。"
	var names := {}
	for value: Variant in data.year_names:
		if not value is String or value.strip_edges().is_empty() or names.has(value): return "灵兽年名称缺失或重复。"
		names[value] = true
	if not data.get("month_names") is Array or data.month_names.size() != 12: return "月份名称配置无效。"
	var months := {}
	for value: Variant in data.month_names:
		if not value is String or value.strip_edges().is_empty() or months.has(value): return "月份名称缺失或重复。"
		months[value] = true
	if not integer_between(data.get("initial_cycle"),1,900000) or not integer_between(data.get("initial_year_index"),0,11): return "开局纪年无效。"
	if not valid_birthday(data.get("default_birthday")): return "默认生日无效。"
	return ""

static func integer_between(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and value>=minimum and value<=maximum

static func valid_birthday(value: Variant) -> bool:
	return value is Array and value.size()==2 and integer_between(value[0],1,12) and integer_between(value[1],1,30)

# Character creation supplies [month, day]; the current default is January 1.
static func initial(birthday: Array = []) -> Dictionary:
	if not configuration_error().is_empty(): return {}
	var birth: Array = rules().default_birthday if birthday.is_empty() else birthday
	if not valid_birthday(birth): return {}
	var first_year := (int(rules().initial_cycle)-1)*YEARS_PER_CYCLE+int(rules().initial_year_index)
	return {"version":1,"birthday":birth.duplicate(),"start_day":first_year*DAYS_PER_YEAR+(int(birth[0])-1)*30+int(birth[1])-1,"elapsed_days":0}

static func valid_record(value: Variant) -> bool:
	if not value is Dictionary or value.get("version")!=1 or not valid_birthday(value.get("birthday")): return false
	if not integer_between(value.get("start_day"),0,MAX_DAY) or not integer_between(value.get("elapsed_days"),0,MAX_DAY): return false
	if int(value.start_day)+int(value.elapsed_days)>MAX_DAY: return false
	if int(value.start_day)%DAYS_PER_YEAR!=(int(value.birthday[0])-1)*30+int(value.birthday[1])-1: return false
	if value.has("last_action"):
		var action: Variant=value.last_action
		if not action is Dictionary or not action.get("source_id") is String or action.source_id.is_empty(): return false
		if not integer_between(action.get("days"),1,MAX_DAY) or action.get("end_day")!=current_day(value): return false
	return true

static func current_day(record: Dictionary) -> int:
	return int(record.start_day)+int(record.elapsed_days)

static func normalized(record: Dictionary) -> Dictionary:
	var result := record.duplicate(true)
	for key in ["version","start_day","elapsed_days"]: result[key]=int(result[key])
	result.birthday=[int(result.birthday[0]),int(result.birthday[1])]
	if result.has("last_action"):
		result.last_action.days=int(result.last_action.days)
		result.last_action.end_day=int(result.last_action.end_day)
	return result

static func advance(record: Dictionary, days: int, source_id: String) -> String:
	if not valid_record(record) or days<=0 or source_id.is_empty() or days>MAX_DAY-current_day(record): return "游戏耗时无效。"
	record.elapsed_days=int(record.elapsed_days)+days
	record.last_action={"source_id":source_id,"days":days,"end_day":current_day(record)}
	return ""

static func date_parts(record: Dictionary) -> Dictionary:
	var day := current_day(record)
	var year := day / DAYS_PER_YEAR
	return {"cycle":year/YEARS_PER_CYCLE+1,"year_index":year%YEARS_PER_CYCLE,"month":(day%DAYS_PER_YEAR)/30+1,"day":day%30+1}

static func chinese_number(value: int, leading := true) -> String:
	var digits := ["零","一","二","三","四","五","六","七","八","九"]
	if value<10: return digits[value]
	if value<20: return ("" if leading else "一")+"十"+(digits[value%10] if value%10 else "")
	if value<100: return digits[value/10]+"十"+(digits[value%10] if value%10 else "")
	if value<10000:
		var divisor := 1000 if value>=1000 else 100
		var remainder := value%divisor
		return digits[value/divisor]+("千" if divisor==1000 else "百")+("" if remainder==0 else (("零" if remainder<divisor/10 else "")+chinese_number(remainder,false)))
	var remainder := value%10000
	return chinese_number(value/10000)+"万"+("" if remainder==0 else (("零" if remainder<1000 else "")+chinese_number(remainder,false)))

static func month_day(month: int, day: int) -> String:
	var month_name: String = rules().month_names[month-1]
	var day_name := "初"+chinese_number(day) if day<=10 else ("廿"+chinese_number(day-20) if day>20 and day<30 else chinese_number(day))
	return month_name+day_name

static func date_text(record: Dictionary, full := false) -> String:
	var parts := date_parts(record)
	var prefix: String=rules().world_name+"·"
	if full: prefix+="第"+chinese_number(parts.cycle)+"纪·"
	return prefix+str(rules().year_names[parts.year_index])+"年·"+month_day(parts.month,parts.day)
