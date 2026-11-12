class_name OldBenchQuest
extends RefCounted
## Actual arrivals, borrowed tools and dialogue cursors share the save transaction.
const ID := "quest.prologue.shuxiajiudeng"
const PREFIX := "base.map_event.quest.shuxiajiudeng."
static var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/quests/old_bench.json"))

static func initial() -> Dictionary:
	return {"visits":0,"last_arrival":{},"offered":false,"active":"","line":0,"location":{},"choice_pending":false,"reward_pending":false,"accepted_at":0,"updated_at":0,"accepted_location":"","tools_received":false,"iron_used":false,"repaired":false,"tools_returned":false,"completed":false}

static func story(state: MapLoadoutState) -> Dictionary:
	return state.quests[ID]

static func accepted(state: MapLoadoutState) -> bool:
	return not story(state).accepted_location.is_empty()

static func available(state: MapLoadoutState) -> bool:
	# Already accepted legacy quests remain playable; new offers use the merchant ending.
	return accepted(state) or MerchantRoadQuest.story(state).stage=="completed"

static func configuration_error() -> String:
	if data.get("quest_id")!=ID: return "树下旧凳任务配置无效。"
	for location: Dictionary in [data.tree,data.smith]:
		if not MapLoadoutState.valid_map_location(location): return "树下旧凳地点无效。"
	for scene: Dictionary in data.scenes.values():
		if scene.lines.is_empty() or scene.lines.size()!=scene.line_speakers.size(): return "树下旧凳对白与说话人不匹配。"
		for i in scene.lines.size():
			if scene.lines[i].is_empty() or not data.speakers.has(scene.line_speakers[i]): return "树下旧凳对白无效。"
	return ""

static func valid(raw: Variant) -> bool:
	if not raw is Dictionary: return false
	for key in ["active","accepted_location"]:
		if not raw.get(key) is String: return false
	for key in ["offered","choice_pending","reward_pending","tools_received","iron_used","repaired","tools_returned","completed"]:
		if not raw.get(key) is bool: return false
	for key in ["accepted_at","updated_at"]:
		if not WorldCalendar.integer_between(raw.get(key),0,WorldCalendar.MAX_DAY): return false
	if not WorldCalendar.integer_between(raw.get("visits"),0,2) or not WorldCalendar.integer_between(raw.get("line"),0,1000): return false
	if not raw.get("location") is Dictionary or not raw.get("last_arrival") is Dictionary: return false
	if not raw.last_arrival.is_empty() and not MapLoadoutState.valid_map_location(raw.last_arrival): return false
	if raw.accepted_location not in ["",data.accepted_location]: return false
	if raw.tools_received and raw.accepted_location.is_empty(): return false
	if raw.iron_used and not raw.tools_received: return false
	if raw.repaired and not raw.iron_used: return false
	if raw.tools_returned and not raw.repaired: return false
	if raw.completed and not raw.tools_returned: return false
	if raw.active.is_empty(): return raw.line==0 and raw.location.is_empty() and not raw.reward_pending and not raw.choice_pending
	if not data.scenes.has(raw.active) or raw.line>=data.scenes[raw.active].lines.size(): return false
	if raw.location!=(data.smith if raw.active in ["collect","returning","smith_reminder"] else data.tree): return false
	if raw.choice_pending and (raw.active not in ["intro","offer"] or raw.line!=data.scenes[raw.active].lines.size()-1): return false
	if raw.reward_pending:
		if raw.choice_pending: return false
		if raw.active=="collect":
			if raw.line!=5 or raw.tools_received: return false
		elif raw.active=="returning":
			if not ((raw.line==0 and not raw.tools_returned) or (raw.line==data.scenes.returning.lines.size()-1 and raw.tools_returned)): return false
		else: return false
	match raw.active:
		"intro","offer","decline": return raw.accepted_location.is_empty()
		"accepting": return not raw.accepted_location.is_empty() and not raw.tools_received
		"collect": return not raw.accepted_location.is_empty() and not raw.repaired and (raw.line<=5 or raw.tools_received)
		"repair": return raw.tools_received and not raw.repaired and (raw.line==0 or raw.iron_used)
		"returning": return raw.repaired and not raw.completed and (raw.line==0 or raw.tools_returned)
		"tree_reminder": return not raw.accepted_location.is_empty() and not raw.tools_received
		"smith_reminder": return raw.tools_received and not raw.repaired
		"after": return raw.repaired
	return false

static func normalized(raw: Dictionary) -> Dictionary:
	var result := raw.duplicate(true)
	for key in ["visits","line","accepted_at","updated_at"]: result[key] = int(result[key])
	return result

static func arrival(state: MapLoadoutState, map_id: String, point_id: String) -> String:
	var location := {"map_id":map_id,"point_id":point_id}
	var saved := story(state)
	if not saved.active.is_empty(): return saved.active if saved.location==location else ""
	if not available(state): return ""
	if saved.completed: return ""
	if location==data.tree:
		if not accepted(state): return "offer" if saved.offered else "intro"
		if saved.tools_received and not saved.repaired: return "repair"
	if location==data.smith and accepted(state):
		if not saved.tools_received: return "collect"
		if saved.repaired: return "returning"
	return ""

static func interaction(state: MapLoadoutState, map_id: String, point_id: String) -> String:
	var scene := arrival(state,map_id,point_id)
	if not scene.is_empty(): return scene
	if not available(state): return ""
	var location := {"map_id":map_id,"point_id":point_id}
	var saved := story(state)
	if location==data.tree:
		if saved.repaired: return "after"
		if saved.offered and not accepted(state): return "offer"
		if accepted(state) and not saved.tools_received: return "tree_reminder"
	if location==data.smith and saved.tools_received and not saved.repaired: return "smith_reminder"
	return ""

static func marker_points(state: MapLoadoutState, map_id: String) -> Array[String]:
	var points: Array[String] = []
	if map_id!=data.tree.map_id or story(state).completed or not available(state): return points
	for location: Dictionary in [data.tree,data.smith]:
		if not arrival(state,map_id,location.point_id).is_empty(): points.append(location.point_id)
	if story(state).offered and not accepted(state) and data.tree.point_id not in points: points.append(data.tree.point_id)
	return points

static func event(scene: String) -> Dictionary:
	var result: Dictionary = data.scenes[scene].duplicate(true)
	result.merge({"id":PREFIX+scene,"type":"dialogue","speaker_id":"base.map_player.chen_yu","presentation":data.presentation.duplicate(true),"speakers":data.speakers.duplicate(true)})
	return result

static func handing_over(state: MapLoadoutState) -> bool:
	return story(state).active=="returning" and not story(state).tools_returned

static func reward_record(state: MapLoadoutState) -> Dictionary:
	var coins: bool = story(state).active=="returning" and story(state).tools_returned
	var record: Dictionary = MapGatheringRewards.record_for(state.records,MapGatheringRewards.SPIRIT_STONE_ID).duplicate(true) if coins else state.records[data.item_id].duplicate(true)
	record.quantity = int(data.rewards[0].quantity) if coins else 1
	return record

static func tool_unit(state: MapLoadoutState) -> String:
	for entry: Dictionary in state.storage.entries():
		if entry.item_id==data.item_id and not entry.units.is_empty(): return str(entry.units[0].id)
	return ""

static func _finish(saved: Dictionary) -> void:
	saved.active = ""
	saved.line = 0
	saved.location = {}
	saved.reward_pending = false
	saved.choice_pending = false

static func command(state: MapLoadoutState, path: String, action: String, scene := "") -> String:
	var prepared := MapLoadoutStore.candidate(state)
	if not prepared.error.is_empty(): return prepared.error
	var next: MapLoadoutState = prepared.state
	next.storage_capacity_rules = state.storage_capacity_rules.duplicate(true)
	var saved := story(next)
	match action:
		"visit":
			# Old counters remain loadable but no longer gate or count arrivals.
			return ""
		"begin":
			if not saved.active.is_empty(): return "" if saved.active==scene else "请先完成当前对白。"
			if next.map_location.is_empty() or scene.is_empty() or interaction(next,next.map_location.map_id,next.map_location.point_id)!=scene: return "当前地点或进度不能开始这段对白。"
			if scene in ["repair","returning"] and tool_unit(next).is_empty(): return "请将工具包放回行囊，再来帮忙。"
			saved.active = scene
			saved.location = next.map_location.duplicate(true)
		"choose_yes","choose_later":
			if not saved.choice_pending: return ""
			saved.offered = true
			saved.choice_pending = false
			saved.line = 0
			saved.active = "accepting" if action=="choose_yes" else "decline"
			if action=="choose_yes":
				saved.accepted_location = data.accepted_location
				saved.accepted_at = WorldCalendar.current_day(next.calendar)
		"advance":
			if saved.active.is_empty() or saved.reward_pending or saved.choice_pending: return ""
			if saved.active=="collect" and saved.line==5 and not saved.tools_received:
				saved.reward_pending = true
			elif saved.active=="returning" and saved.line==0 and not saved.tools_returned:
				saved.reward_pending = true
			elif saved.line+1<data.scenes[saved.active].lines.size():
				if saved.active=="repair" and saved.line==0:
					if tool_unit(next).is_empty(): return "请将工具包放回行囊，再来修凳。"
					saved.iron_used = true
				saved.line += 1
			elif saved.active in ["intro","offer"]: saved.choice_pending = true
			elif saved.active=="returning": saved.reward_pending = true
			else:
				if saved.active=="repair": saved.repaired = true
				_finish(saved)
		"accept":
			if not saved.reward_pending: return ""
			if saved.active=="collect":
				var error := next.add_reward(data.tools_reward)
				if not error.is_empty(): return error
				saved = story(next)
				saved.tools_received = true
				saved.reward_pending = false
				saved.line += 1
			elif not saved.tools_returned:
				var unit_id := tool_unit(next)
				if unit_id.is_empty(): return "请将工具包放回行囊，再交给韩师傅。"
				var snapshot := next.snapshot()
				snapshot.owned_units.erase(unit_id)
				snapshot.quests[ID].tools_returned = true
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
		_: return "未知树下旧凳指令。"
	story(next).updated_at = WorldCalendar.current_day(next.calendar)
	next.quest_tracking = QuestTracking.normalized(next.quest_tracking,QuestTracking.entries(next))
	var error := MapLoadoutStore.save(next,path)
	if not error.is_empty(): return error
	error = state.restore(next.snapshot())
	if error.is_empty() and action!="visit": preload("res://scripts/entry/save_checkpoints.gd").after_action(state,path,"old_bench")
	return error

static func display_entry(state: MapLoadoutState, presentation: Dictionary) -> Dictionary:
	var result := presentation.duplicate(true)
	var saved := story(state)
	result.merge(saved,true)
	result.stage_id = "completed" if saved.completed else ("returning" if saved.repaired else ("repair" if saved.tools_received else "collect"))
	result.objectives = data.objectives.duplicate(true)
	result.objectives[0].completed = saved.tools_received
	result.objectives[1].completed = saved.repaired
	result.objectives[2].completed = saved.completed
	result.objectives.resize(3 if saved.repaired else (2 if saved.tools_received else 1))
	result.has_locked_next = not saved.repaired
	result.people = data.people.duplicate(true)
	result.rewards = data.rewards.duplicate(true)
	result.location = {"name":"青石镇·古树" if result.stage_id=="repair" else "青石镇·铁匠铺","image":"res://assets/map-qingshizhen.webp"}
	return result
