class_name FishingNetQuest
extends RefCounted
## One-time village errand. All gifts, handover and completion commit with the dialogue cursor.
const ID := "quest.prologue.jiuwangdaichao"
const PREFIX := "base.map_event.quest.jiuwangdaichao."
static var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/quests/fishing_net.json"))

static func initial() -> Dictionary:
	return {"active":"","line":0,"location":{},"reward_pending":false,"accepted_at":0,"updated_at":0,"accepted_location":"","net_received":false,"net_returned":false,"completed":false}

static func story(state: MapLoadoutState) -> Dictionary:
	return state.quests[ID]

static func accepted(state: MapLoadoutState) -> bool:
	return not story(state).accepted_location.is_empty()

static func route_open(state: MapLoadoutState) -> bool:
	return accepted(state)

static func reveal_route(state: MapLoadoutState, map_id: String, exploration: MapExplorationState) -> void:
	if map_id!=data.reef.map_id or not route_open(state): return
	# Xu points out the shore path; reveal it without crediting either point as visited.
	exploration.revealed[data.route_start] = true
	exploration.revealed[data.reef.point_id] = true
	exploration.full_routes[data.route_id] = true

static func configuration_error() -> String:
	if data.get("quest_id")!=ID: return "旧网待潮任务配置无效。"
	for location: Dictionary in [data.dock,data.reef]:
		if not MapLoadoutState.valid_map_location(location): return "旧网待潮地点无效。"
	for scene: Dictionary in data.scenes.values():
		if scene.lines.is_empty() or scene.lines.size()!=scene.line_speakers.size(): return "旧网待潮对白与说话人不匹配。"
		for i in scene.lines.size():
			if scene.lines[i].is_empty() or not data.speakers.has(scene.line_speakers[i]): return "旧网待潮对白无效。"
	return ""

static func valid(raw: Variant) -> bool:
	if not raw is Dictionary: return false
	for key in ["active","accepted_location"]:
		if not raw.get(key) is String: return false
	for key in ["reward_pending","net_received","net_returned","completed"]:
		if not raw.get(key) is bool: return false
	for key in ["accepted_at","updated_at"]:
		if not WorldCalendar.integer_between(raw.get(key),0,WorldCalendar.MAX_DAY): return false
	if not raw.get("location") is Dictionary or not WorldCalendar.integer_between(raw.get("line"),0,1000): return false
	if raw.accepted_location not in ["",data.accepted_location]: return false
	if raw.net_received and raw.accepted_location.is_empty(): return false
	if raw.net_returned and not raw.net_received: return false
	if raw.completed and not raw.net_returned: return false
	if raw.active.is_empty(): return raw.line==0 and raw.location.is_empty() and not raw.reward_pending
	if not data.scenes.has(raw.active) or raw.line>=data.scenes[raw.active].lines.size(): return false
	if raw.location!=(data.reef if raw.active=="retrieve" else data.dock): return false
	match raw.active:
		"intro": return raw.accepted_location.is_empty() and not raw.reward_pending
		"retrieve": return not raw.accepted_location.is_empty() and not raw.net_received and (not raw.reward_pending or raw.line==data.scenes.retrieve.lines.size()-1)
		"returning":
			if not raw.net_received or raw.completed: return false
			if raw.line>0 and not raw.net_returned: return false
			return not raw.reward_pending or (raw.line==0 and not raw.net_returned) or (raw.line==data.scenes.returning.lines.size()-1 and raw.net_returned)
		"reminder": return not raw.accepted_location.is_empty() and not raw.net_received and not raw.reward_pending
		"after": return raw.completed and not raw.reward_pending
	return false

static func arrival(state: MapLoadoutState, map_id: String, point_id: String) -> String:
	var location := {"map_id":map_id,"point_id":point_id}
	var saved := story(state)
	if not saved.active.is_empty(): return saved.active if saved.location==location else ""
	if not HomecomingQuest.story(state).home_reunited: return ""
	if location==data.dock:
		if not accepted(state): return "intro"
		if saved.net_received and not saved.completed: return "returning"
	if location==data.reef and accepted(state) and not saved.net_received: return "retrieve"
	return ""

static func interaction(state: MapLoadoutState, map_id: String, point_id: String) -> String:
	var scene := arrival(state,map_id,point_id)
	if not scene.is_empty(): return scene
	if {"map_id":map_id,"point_id":point_id}==data.dock and accepted(state):
		return "after" if story(state).completed else "reminder"
	return ""

static func event(scene: String) -> Dictionary:
	var result: Dictionary = data.scenes[scene].duplicate(true)
	result.merge({"id":PREFIX+scene,"type":"dialogue","speaker_id":"base.map_player.chen_yu","presentation":data.presentation.duplicate(true),"speakers":data.speakers.duplicate(true)})
	return result

static func handing_over(state: MapLoadoutState) -> bool:
	return story(state).active=="returning" and not story(state).net_returned

static func reward_record(state: MapLoadoutState) -> Dictionary:
	var coins: bool = story(state).active=="returning" and story(state).net_returned
	var record: Dictionary = MapGatheringRewards.record_for(state.records,MapGatheringRewards.SPIRIT_STONE_ID).duplicate(true) if coins else state.records[data.item_id].duplicate(true)
	record.quantity = int(data.rewards[0].quantity) if coins else 1
	return record

static func _finish(saved: Dictionary) -> void:
	saved.active = ""
	saved.line = 0
	saved.location = {}
	saved.reward_pending = false

static func command(state: MapLoadoutState, path: String, action: String, scene := "") -> String:
	var prepared := MapLoadoutStore.candidate(state)
	if not prepared.error.is_empty(): return prepared.error
	var next: MapLoadoutState = prepared.state
	next.storage_capacity_rules = state.storage_capacity_rules.duplicate(true)
	var saved := story(next)
	match action:
		"begin":
			if not saved.active.is_empty(): return "" if saved.active==scene else "请先完成当前对白。"
			if next.map_location.is_empty() or scene.is_empty() or interaction(next,next.map_location.map_id,next.map_location.point_id)!=scene: return "当前地点或进度不能开始这段对白。"
			saved.active = scene
			saved.location = next.map_location.duplicate(true)
		"advance":
			if saved.active.is_empty() or saved.reward_pending: return ""
			if saved.active=="returning" and saved.line==0 and not saved.net_returned:
				saved.reward_pending = true
			elif saved.line+1<data.scenes[saved.active].lines.size(): saved.line += 1
			elif saved.active in ["retrieve","returning"]: saved.reward_pending = true
			else:
				if saved.active=="intro":
					saved.accepted_location = data.accepted_location
					saved.accepted_at = WorldCalendar.current_day(next.calendar)
				_finish(saved)
		"accept":
			if not saved.reward_pending: return ""
			if saved.active=="retrieve":
				var error := next.add_reward(data.net_reward)
				if not error.is_empty(): return error
				saved = story(next)
				saved.net_received = true
				_finish(saved)
			elif not saved.net_returned:
				var unit_id := ""
				for entry: Dictionary in next.storage.entries():
					if entry.item_id==data.item_id and not entry.units.is_empty():
						unit_id = str(entry.units[0].id)
						break
				if unit_id.is_empty(): return "请将渔网放回行囊，再交给许伯。"
				var snapshot := next.snapshot()
				snapshot.owned_units.erase(unit_id)
				snapshot.quests[ID].net_returned = true
				snapshot.quests[ID].reward_pending = false
				snapshot.quests[ID].line = 1
				var error := next.restore(snapshot)
				if not error.is_empty(): return error
			else:
				var payment := int(data.rewards[0].quantity)
				if next.spirit_stones>1000000000-payment: return "灵石已达持有上限，暂不能结算。"
				next.spirit_stones += payment
				saved.completed = true
				_finish(saved)
		_: return "未知旧网待潮指令。"
	story(next).updated_at = WorldCalendar.current_day(next.calendar)
	next.quest_tracking = QuestTracking.normalized(next.quest_tracking,QuestTracking.entries(next))
	var error := MapLoadoutStore.save(next,path)
	if not error.is_empty(): return error
	error = state.restore(next.snapshot())
	if error.is_empty(): preload("res://scripts/entry/save_checkpoints.gd").after_action(state,path,"fishing_net")
	return error

static func display_entry(state: MapLoadoutState, presentation: Dictionary) -> Dictionary:
	var result := presentation.duplicate(true)
	var saved := story(state)
	result.merge(saved,true)
	result.stage_id = "completed" if saved.completed else ("returning" if saved.net_received else "gathering")
	result.objectives = data.objectives.duplicate(true)
	result.objectives[0].completed = saved.net_received or saved.active=="retrieve"
	result.objectives[1].completed = saved.net_received
	result.objectives[2].completed = saved.completed
	if not saved.net_received: result.objectives.resize(2 if saved.active=="retrieve" else 1)
	result.has_locked_next = not saved.net_received
	result.people = data.people.duplicate(true)
	result.rewards = data.rewards.duplicate(true)
	result.location = {"name":"白沙村·码头" if saved.net_received else "白沙村·近岸礁滩","image":"res://assets/map-baishacun.webp"}
	return result
