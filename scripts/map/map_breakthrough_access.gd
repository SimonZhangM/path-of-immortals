extends RefCounted
## Shared entry/start requirements; test access only permits opening the panel.
static var rule: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/breakthrough_rules.json")).first_qi

static func eligibility_error(state) -> String:
	if state==null or state.growth.is_empty(): return "尚未初始化修为。"
	if int(state.growth.realm)!=int(rule.realm):
		var realm_name: String=state.registry.get_cultivation(state.cultivation_rank_id).name
		return "当前为%s%s层。此处仅开放凡人→炼气的首次突破。"%[realm_name,WorldCalendar.chinese_number(int(state.growth.layer))]
	if not HomecomingQuest.ready_for_practice(state): return "请先完成母亲的修行指导。"
	if not HomecomingQuest.cultivation_full(state): return "请先积累修为至100%，再回母亲家尝试突破。"
	if state.map_location!={"map_id":rule.map_id,"point_id":rule.point_id}: return "请回母亲家进行首次引气。"
	if state.board==null or state.board.id=="base.board.bag": return "基础行囊无法用于突破，请至少装备晓岚阵盘。"
	return ""

static func can_open(state) -> bool:
	if state==null: return false
	if state.is_test_save: return true
	# Retain access to an existing attempt/result for resume, adjustment or confirmation.
	if state.growth.get("breakthrough_attempt",{}).get("phase","") in ["running","paused","succeeded","failed"]: return true
	return eligibility_error(state).is_empty()
