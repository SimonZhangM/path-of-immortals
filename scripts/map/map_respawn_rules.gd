class_name MapRespawnRules
extends RefCounted

const VERSION := 1
const PATH := "res://data/world/respawn_rules.json"

# Inputs have already passed save validation. Upgrade waiting deadlines once;
# do not close an already available node, or guess an unrecorded death date.
static func migrate(saved_version: Variant, today: int, encounters: Dictionary, chests: Dictionary) -> Dictionary:
	if not WorldCalendar.integer_between(saved_version,0,VERSION): return {"error":"刷新规则存档版本无效。"}
	var result := {"error":"","encounters":encounters.duplicate(true),"chests":chests.duplicate(true)}
	if int(saved_version)==VERSION: return result
	var rules: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not rules is Dictionary or rules.get("version")!=VERSION or not rules.get("legacy_encounter_days") is Dictionary or not rules.get("chest_reward_ids") is Array: return {"error":"刷新规则配置无效。"}
	if not ContentRegistry._positive_integer(rules.get("encounter_days")) or not ContentRegistry._positive_integer(rules.get("chest_days")): return {"error":"刷新周期无效。"}
	for id: String in result.encounters:
		if not rules.legacy_encounter_days.has(id) or int(result.encounters[id])<=today: continue
		var ready := int(result.encounters[id])-int(rules.legacy_encounter_days[id])+int(rules.encounter_days)
		if not WorldCalendar.integer_between(ready,0,WorldCalendar.MAX_DAY): return {"error":"怪物重生日期超出历法范围。"}
		result.encounters[id] = ready
	for id: String in result.chests:
		if id not in rules.chest_reward_ids: continue
		var wait: Dictionary = result.chests[id]
		var ready := int(wait.get("ready_day",today+int(wait.remaining_days)))
		if ready<=today: continue
		ready += int(rules.chest_days)-int(wait.delay_days)
		if not WorldCalendar.integer_between(ready,0,WorldCalendar.MAX_DAY): return {"error":"宝箱重开日期超出历法范围。"}
		wait.ready_day = ready
		wait.delay_days = int(rules.chest_days)
		wait.remaining_days = maxi(0,ready-today)
	return result
