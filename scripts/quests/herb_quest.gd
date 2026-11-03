class_name HerbQuest
extends RefCounted
## Clinic errand facts and atomic delivery, independent of the river rescue.
const ID := "quest.prologue.yiguanbeiyao"
const PREFIX := "base.map_event.quest.yiguanbeiyao."
static var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/quests/clinic_herbs.json"))

static func initial() -> Dictionary:
	return {
		"active":"", "line":0, "location":{}, "reward_pending":false,
		"accepted_at":0, "updated_at":0, "accepted_location":"",
		"completed":false, "delivery_revealed":false
	}

static func story(state: MapLoadoutState) -> Dictionary:
	return state.quests[ID]

static func accepted(state: MapLoadoutState) -> bool:
	return not story(state).accepted_location.is_empty()

static func quantity(state: MapLoadoutState) -> int:
	return state.carried_owned().values().count(data.item_id)

static func refresh_objectives(state: MapLoadoutState) -> void:
	if accepted(state) and quantity(state)>0:
		story(state).delivery_revealed = true

static func configuration_error() -> String:
	if data.get("quest_id")!=ID or not MapLoadoutState.valid_map_location(data.clinic):
		return "医馆备药配置无效。"
	for scene: Dictionary in data.scenes.values():
		if scene.lines.is_empty() or scene.lines.size()!=scene.line_speakers.size():
			return "医馆备药对白与说话人不匹配。"
		for i in scene.lines.size():
			if scene.lines[i].is_empty() or not data.speakers.has(scene.line_speakers[i]):
				return "医馆备药对白内容无效。"
	return ""

static func valid(raw: Variant) -> bool:
	if not raw is Dictionary:
		return false
	for key in ["active", "accepted_location"]:
		if not raw.get(key) is String:
			return false
	for key in ["completed", "reward_pending", "delivery_revealed"]:
		if not raw.get(key) is bool:
			return false
	for key in ["accepted_at", "updated_at"]:
		if not WorldCalendar.integer_between(raw.get(key),0,WorldCalendar.MAX_DAY):
			return false
	if not raw.get("location") is Dictionary or not WorldCalendar.integer_between(raw.get("line"),0,1000):
		return false
	if raw.completed and raw.accepted_location.is_empty():
		return false
	if raw.delivery_revealed and raw.accepted_location.is_empty():
		return false
	if raw.active.is_empty():
		return raw.line==0 and raw.location.is_empty() and not raw.reward_pending
	if raw.completed or not data.scenes.has(raw.active) or raw.location!=data.clinic:
		return false
	if raw.line>=data.scenes[raw.active].lines.size():
		return false
	if (raw.active=="intro")!=raw.accepted_location.is_empty():
		return false
	return not raw.reward_pending or (raw.active=="delivery" and raw.line==data.scenes.delivery.lines.size()-1)

static func clinic_available(state: MapLoadoutState) -> bool:
	return accepted(state) and not story(state).completed and not RiverQuest.doctor_away(state)

static func delivery_error(state: MapLoadoutState) -> String:
	if quantity(state)>0 and state.spirit_stones>1000000000-int(data.rewards[0].quantity):
		return "灵石已达持有上限，请先处理后再交药。"
	return ""

static func arrival(state: MapLoadoutState, map_id: String, point_id: String) -> String:
	var saved := story(state)
	if not saved.active.is_empty():
		return saved.active if saved.location=={"map_id":map_id,"point_id":point_id} else ""
	if {"map_id":map_id,"point_id":point_id}!=data.clinic:
		return ""
	if state.quests[QuestState.ID].counts.deliver==0 or accepted(state):
		return ""
	if RiverQuest.doctor_away(state) or not RiverQuest.arrival(state,map_id,point_id).is_empty():
		return ""
	# An existing rescue continues first; its emergency takes priority over errands.
	if not RiverQuest.story(state).accepted_location.is_empty() and not RiverQuest.done(state,"closing"):
		return ""
	return "intro"

static func has_clinic_marker(state: MapLoadoutState) -> bool:
	return not arrival(state,data.clinic.map_id,data.clinic.point_id).is_empty() or (clinic_available(state) and quantity(state)>0)

static func interaction(state: MapLoadoutState, map_id: String, point_id: String) -> String:
	var scene := arrival(state,map_id,point_id)
	if not scene.is_empty(): return scene
	if {"map_id":map_id,"point_id":point_id}!=data.clinic: return ""
	if clinic_available(state) and quantity(state)>0 and delivery_error(state).is_empty() and RiverQuest.arrival(state,map_id,point_id).is_empty():
		return "delivery"
	return ""

static func exit_blocked(state: MapLoadoutState, map_id: String, point_id: String) -> bool:
	if map_id!=data.clinic.map_id or point_id!=data.river_exit:
		return false
	# Previously accepted rescue saves retain their open return route.
	return not accepted(state) and RiverQuest.story(state).accepted_location.is_empty()

static func exit_hint(state: MapLoadoutState) -> String:
	return "先去医馆找苏清禾。" if state.quests[QuestState.ID].counts.deliver>0 else "先完成药铺的事情。"

static func event(scene: String) -> Dictionary:
	var result: Dictionary = data.scenes[scene].duplicate(true)
	result.merge({"id":PREFIX+scene,"type":"dialogue","speaker_id":"base.map_player.chen_yu",
		"presentation":data.presentation.duplicate(true),"speakers":data.speakers.duplicate(true)})
	return result

static func reward_record(state: MapLoadoutState) -> Dictionary:
	var record := MapGatheringRewards.record_for(state.records,MapGatheringRewards.SPIRIT_STONE_ID).duplicate(true)
	record.quantity = int(data.rewards[0].quantity)
	return record

static func _finish(saved: Dictionary) -> void:
	saved.active = ""
	saved.line = 0
	saved.location = {}
	saved.reward_pending = false

static func command(state: MapLoadoutState, path: String, action: String, scene := "") -> String:
	var prepared := MapLoadoutStore.candidate(state)
	if not prepared.error.is_empty():
		return prepared.error
	var next: MapLoadoutState = prepared.state
	var saved := story(next)
	match action:
		"begin":
			if not data.scenes.has(scene):
				return "医馆备药对白未配置。"
			if not saved.active.is_empty():
				return "" if saved.active==scene else "请先完成当前对白。"
			if next.map_location!=data.clinic:
				return "请到青石镇医馆找苏清禾。"
			if scene=="intro":
				if arrival(next,data.clinic.map_id,data.clinic.point_id)!="intro":
					return "当前不能接取医馆备药。"
			else:
				if not clinic_available(next) or not RiverQuest.arrival(next,data.clinic.map_id,data.clinic.point_id).is_empty():
					return "请先处理医馆当前的事情。"
				if (scene=="delivery")!=(quantity(next)>0):
					return "药材数量已变化，请重新查看。"
				if scene=="delivery" and not delivery_error(next).is_empty():
					return delivery_error(next)
			saved.active = scene
			saved.line = 0
			saved.location = next.map_location.duplicate(true)
		"advance":
			if saved.active.is_empty() or saved.reward_pending:
				return ""
			if saved.line+1<data.scenes[saved.active].lines.size():
				saved.line += 1
			elif saved.active=="delivery":
				saved.reward_pending = true
			else:
				if saved.active=="intro":
					saved.accepted_location = data.accepted_location
					saved.accepted_at = WorldCalendar.current_day(next.calendar)
					if QuestTracking.latest_main(QuestTracking.entries(next)).is_empty():
						next.quest_tracking.ids = [ID]
				_finish(saved)
		"accept":
			if not saved.reward_pending:
				return ""
			var unit_id := ""
			for entry: Dictionary in next.storage.entries():
				if entry.item_id==data.item_id and not entry.units.is_empty():
					unit_id = str(entry.units[0].id)
					break
			if unit_id.is_empty():
				return "行囊中需要止血草1株，请备齐后继续交付。"
			var payment := int(data.rewards[0].quantity)
			if next.spirit_stones>1000000000-payment:
				return "灵石已达持有上限，暂不能结算。"
			var snapshot := next.snapshot()
			snapshot.owned_units.erase(unit_id)
			snapshot.spirit_stones += payment
			snapshot.quests[ID].completed = true
			snapshot.quests[ID].delivery_revealed = true
			_finish(snapshot.quests[ID])
			var error := next.restore(snapshot)
			if not error.is_empty():
				return error
		_: return "未知医馆备药指令。"
	story(next).updated_at = WorldCalendar.current_day(next.calendar)
	next.quest_tracking = QuestTracking.normalized(next.quest_tracking,QuestTracking.entries(next))
	var error := MapLoadoutStore.save(next,path)
	if not error.is_empty():
		return error
	error = state.restore(next.snapshot())
	if error.is_empty():
		preload("res://scripts/entry/save_checkpoints.gd").after_action(state,path,"clinic_herbs")
	return error

static func display_entry(state: MapLoadoutState, presentation: Dictionary) -> Dictionary:
	var result := presentation.duplicate(true)
	var saved := story(state)
	var ready := quantity(state)>0
	result.merge(saved,true)
	result.stage_id = "completed" if saved.completed else ("returning" if ready else "gathering")
	result.objectives = data.objectives.duplicate(true)
	result.objectives[0].current = 1 if saved.completed else mini(quantity(state),1)
	result.objectives[0].completed = saved.completed or ready
	if saved.delivery_revealed or ready or saved.completed:
		result.objectives[1].completed = saved.completed
	else:
		result.objectives.resize(1)
	result.has_locked_next = result.objectives.size()==1
	result.rewards = data.rewards.duplicate(true)
	result.people = data.people.duplicate(true)
	result.location = data.locations[result.stage_id].duplicate(true)
	return result
