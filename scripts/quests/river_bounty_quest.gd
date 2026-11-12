class_name RiverBountyQuest
extends RefCounted
## One-time commission; notice-board entry and inventory delivery are separate facts.
const ID := "quest.prologue.hewanchuhuan"
const PREFIX := "base.map_event.quest.hewanchuhuan."
static var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/quests/river_bounty.json"))
static var boards: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/quests/notice_boards.json"))

static func initial() -> Dictionary:
	return {"active":"","line":0,"location":{},"choice_pending":false,"reward_pending":false,"accepted_location":"","accepted_at":0,"updated_at":0,"informed":false,"delivery_revealed":false,"completed":false}

static func story(state: MapLoadoutState) -> Dictionary:
	return state.quests[ID]

static func board() -> Dictionary:
	return boards[data.board_id].location

static func accepted(state: MapLoadoutState) -> bool:
	return not story(state).accepted_location.is_empty()

static func available(state: MapLoadoutState) -> bool:
	return MerchantRoadQuest.story(state).stage=="completed"

static func quantity(state: MapLoadoutState, item_id: String) -> int:
	return state.carried_owned().values().count(item_id)

static func ready(state: MapLoadoutState) -> bool:
	for requirement: Dictionary in data.materials:
		if quantity(state,requirement.item_id)<int(requirement.quantity): return false
	return true

static func refresh_objectives(state: MapLoadoutState) -> void:
	if accepted(state) and story(state).informed and ready(state): story(state).delivery_revealed = true

static func configuration_error() -> String:
	if data.get("quest_id")!=ID or not boards.has(data.get("board_id","")): return "河湾除患配置无效。"
	if ID not in boards[data.board_id].commissions: return "公告板未登记河湾除患。"
	for location: Dictionary in [board(),data.mayor]:
		if not MapLoadoutState.valid_map_location(location): return "河湾除患地点无效。"
	for scene: Dictionary in data.scenes.values():
		if scene.lines.is_empty() or scene.lines.size()!=scene.line_speakers.size(): return "河湾除患对白配置无效。"
		for i in scene.lines.size():
			if scene.lines[i].is_empty() or not data.speakers.has(scene.line_speakers[i]): return "河湾除患说话人无效。"
	return ""

static func valid(raw: Variant) -> bool:
	if not raw is Dictionary or not raw.get("active") is String or not raw.get("location") is Dictionary: return false
	if raw.get("accepted_location") not in ["",data.accepted_location]: return false
	for key in ["line","accepted_at","updated_at"]:
		if not WorldCalendar.integer_between(raw.get(key),0,WorldCalendar.MAX_DAY): return false
	for key in ["choice_pending","reward_pending","informed","delivery_revealed","completed"]:
		if not raw.get(key) is bool: return false
	if raw.accepted_location.is_empty() and (raw.informed or raw.delivery_revealed or raw.completed or raw.accepted_at!=0): return false
	if (raw.completed or raw.delivery_revealed) and not raw.informed: return false
	if raw.active.is_empty(): return raw.line==0 and raw.location.is_empty() and not raw.reward_pending and not raw.choice_pending
	if raw.completed or not data.scenes.has(raw.active): return false
	if raw.line>=data.scenes[raw.active].lines.size(): return false
	if raw.location!=(board() if raw.active in ["notice","accepting","decline"] else data.mayor): return false
	if raw.choice_pending and (raw.active!="notice" or raw.line!=data.scenes.notice.lines.size()-1): return false
	if raw.reward_pending and (raw.active!="delivery" or raw.line!=data.scenes.delivery.lines.size()-1): return false
	if raw.choice_pending and raw.reward_pending: return false
	match raw.active:
		"notice","decline": return raw.accepted_location.is_empty()
		"accepting","details": return not raw.accepted_location.is_empty() and not raw.informed
		"delivery","reminder": return raw.informed
	return false

static func normalized(raw: Dictionary) -> Dictionary:
	var result := raw.duplicate(true)
	for key in ["line","accepted_at","updated_at"]: result[key] = int(result[key])
	return result

static func arrival(state: MapLoadoutState, map_id: String, point_id: String) -> String:
	var location := {"map_id":map_id,"point_id":point_id}
	var saved := story(state)
	if not saved.active.is_empty(): return saved.active if saved.location==location else ""
	if saved.completed: return ""
	if not accepted(state): return "notice" if available(state) and location==board() else ""
	if location!=data.mayor: return ""
	if not saved.informed: return "details"
	return "delivery" if ready(state) else ""

static func interaction(state: MapLoadoutState, map_id: String, point_id: String) -> String:
	var scene := arrival(state,map_id,point_id)
	if not scene.is_empty(): return scene
	if accepted(state) and story(state).informed and not story(state).completed and {"map_id":map_id,"point_id":point_id}==data.mayor: return "reminder"
	return ""

static func marker_points(state: MapLoadoutState, map_id: String) -> Array[String]:
	var points: Array[String] = []
	for location: Dictionary in [board(),data.mayor]:
		if location.map_id==map_id and not arrival(state,map_id,location.point_id).is_empty(): points.append(location.point_id)
	return points

static func event(scene: String) -> Dictionary:
	var result: Dictionary = data.scenes[scene].duplicate(true)
	result.merge({"id":PREFIX+scene,"type":"dialogue","speaker_id":"base.map_player.chen_yu","presentation":data.presentation.duplicate(true),"speakers":data.speakers.duplicate(true)})
	return result

static func reward_record(state: MapLoadoutState) -> Dictionary:
	var record := MapGatheringRewards.record_for(state.records,MapGatheringRewards.SPIRIT_STONE_ID).duplicate(true)
	record.quantity = int(data.rewards[0].quantity)
	return record

static func _finish(saved: Dictionary) -> void:
	saved.active = ""
	saved.line = 0
	saved.location = {}
	saved.choice_pending = false
	saved.reward_pending = false

static func command(state: MapLoadoutState, path: String, action: String, scene := "") -> String:
	var prepared := MapLoadoutStore.candidate(state)
	if not prepared.error.is_empty(): return prepared.error
	var next: MapLoadoutState = prepared.state
	var saved := story(next)
	match action:
		"begin":
			if not saved.active.is_empty(): return "" if saved.active==scene else "请先完成当前对白。"
			if next.map_location.is_empty() or scene.is_empty() or interaction(next,next.map_location.map_id,next.map_location.point_id)!=scene: return "当前不能开始这段委托对白。"
			saved.active = scene
			saved.location = next.map_location.duplicate(true)
		"choose_yes","choose_later":
			if not saved.choice_pending: return ""
			saved.choice_pending = false
			saved.active = "accepting" if action=="choose_yes" else "decline"
			saved.line = 0
			if action=="choose_yes":
				saved.accepted_location = data.accepted_location
				saved.accepted_at = WorldCalendar.current_day(next.calendar)
				if QuestTracking.latest_main(QuestTracking.entries(next)).is_empty(): next.quest_tracking.ids = [ID]
		"advance":
			if saved.active.is_empty() or saved.choice_pending or saved.reward_pending: return ""
			if saved.line+1<data.scenes[saved.active].lines.size(): saved.line += 1
			elif saved.active=="notice": saved.choice_pending = true
			elif saved.active=="delivery": saved.reward_pending = true
			else:
				if saved.active=="details": saved.informed = true
				_finish(saved)
		"accept":
			if not saved.reward_pending: return ""
			if next.map_location!=data.mayor or not saved.informed: return "请到古树下找周秉和交付。"
			if not ready(next): return "行囊中需备齐山狼尖牙2份、赤鬃獠牙1份，请备齐后再交付。"
			var payment := int(data.rewards[0].quantity)
			if next.spirit_stones>1000000000-payment: return "灵石已达持有上限，暂不能结算。"
			var snapshot := next.snapshot()
			for requirement: Dictionary in data.materials:
				var remaining := int(requirement.quantity)
				for unit_id: String in next.carried_owned():
					if next.carried_owned()[unit_id]==requirement.item_id and remaining>0:
						snapshot.owned_units.erase(unit_id)
						remaining -= 1
			snapshot.spirit_stones += payment
			snapshot.quests[ID].completed = true
			snapshot.quests[ID].delivery_revealed = true
			_finish(snapshot.quests[ID])
			var error := next.restore(snapshot)
			if not error.is_empty(): return error
		"defer_delivery":
			if not saved.reward_pending: return ""
			_finish(saved)
		_: return "未知河湾除患指令。"
	refresh_objectives(next)
	story(next).updated_at = WorldCalendar.current_day(next.calendar)
	next.quest_tracking = QuestTracking.normalized(next.quest_tracking,QuestTracking.entries(next))
	var error := MapLoadoutStore.save(next,path)
	if not error.is_empty(): return error
	error = state.restore(next.snapshot())
	if error.is_empty(): preload("res://scripts/entry/save_checkpoints.gd").after_action(state,path,"river_bounty")
	return error

static func display_entry(state: MapLoadoutState, presentation: Dictionary) -> Dictionary:
	var result := presentation.duplicate(true)
	var saved := story(state)
	result.merge(saved,true)
	result.stage_id = "completed" if saved.completed else ("details" if not saved.informed else ("returning" if ready(state) else "gathering"))
	result.objectives = data.objectives.duplicate(true)
	result.objectives[0].completed = saved.informed
	for i in data.materials.size():
		var requirement: Dictionary = data.materials[i]
		result.objectives[i+1].current = int(requirement.quantity) if saved.completed else mini(quantity(state,requirement.item_id),int(requirement.quantity))
		result.objectives[i+1].completed = saved.completed or quantity(state,requirement.item_id)>=int(requirement.quantity)
	result.objectives[3].completed = saved.completed
	if not saved.informed: result.objectives.resize(1)
	elif not saved.delivery_revealed and not ready(state) and not saved.completed: result.objectives.resize(3)
	result.has_locked_next = result.objectives.size()<4
	result.people = data.people.duplicate(true)
	result.rewards = data.rewards.duplicate(true)
	result.location = {"name":"青石河湾" if result.stage_id=="gathering" else "青石镇·古树","image":"res://assets/gamemap-qingshihewan.webp" if result.stage_id=="gathering" else "res://assets/map-qingshizhen.webp"}
	return result
