class_name QuestStory
extends RefCounted
## Persisted story commands. Presentation never owns quest progress or rewards.
const ID := "quest.prologue.yaoxiangruchang"
const PREFIX := "base.map_event.quest.yaoxiangruchang."
static var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/quests/prologue_story.json"))

static func configuration_error() -> String:
	if data.get("quest_id")!=ID: return "任务剧情ID无效。"
	for key in ["home","shop"]:
		if not data.get(key) is Dictionary or not MapLoadoutState.valid_map_location(data[key]) or data[key].is_empty(): return "任务剧情地点无效。"
	if not data.get("scenes") is Dictionary or not data.get("speakers") is Dictionary or not data.get("presentation") is Dictionary: return "任务剧情配置不完整。"
	for id in ["wake","morning","returning","slope","see_kuaiye","kuaiye_only","see_xilutai","xilutai_only","both","waterfall"]:
		var scene: Variant = data.scenes.get(id)
		if not scene is Dictionary or not scene.get("lines") is Array or not scene.get("line_speakers") is Array: return "任务对白段落无效："+id
		if scene.lines.is_empty() or scene.lines.size()!=scene.line_speakers.size(): return "任务对白与说话人不匹配："+id
		for i in scene.lines.size():
			if not scene.lines[i] is String or scene.lines[i].strip_edges().is_empty() or not data.speakers.has(scene.line_speakers[i]): return "任务对白内容或说话人无效："+id
	return ""

static func initial() -> Dictionary:
	return {"done":[],"active":"","line":0,"wake_pending":false,"reward_pending":false,"pending":[],"location":{}}

static func migrated(quest: Dictionary) -> Dictionary:
	if quest.has("story"):
		var saved: Dictionary = quest.story.duplicate(true)
		var herb_ready := QuestState.objective_complete(quest.counts,"kuaiye")
		var moss_ready := QuestState.objective_complete(quest.counts,"xilutai")
		var requirements := {"kuaiye_only":herb_ready,"xilutai_only":moss_ready,"both":herb_ready and moss_ready,"returning":herb_ready and moss_ready}
		# Older counters were capped at one. Resume gathering before replaying
		# any completion remark or accepting a previously pending payment.
		for scene: String in requirements:
			if requirements[scene]: continue
			saved.done.erase(scene)
			saved.pending.erase(scene)
			if saved.active==scene:
				saved.active = ""
				saved.line = 0
				saved.location = {}
				saved.reward_pending = false
		if saved.active=="returning" and saved.reward_pending:
			saved.line = data.scenes.returning.lines.size()-1
		return saved
	var result := initial()
	# An existing save keeps its position; only an explicit opening requests wake.
	result.done.append("wake")
	if quest.counts.talk>0: result.done.append("morning")
	if quest.counts.visit>0: result.done.append("slope")
	if quest.counts.deliver>0: result.done.append("returning")
	return result

static func valid(value: Variant) -> bool:
	if not value is Dictionary: return false
	for key in ["wake_pending","reward_pending"]:
		if not value.get(key) is bool: return false
	for key in ["done","pending"]:
		if not value.get(key) is Array: return false
		var seen := {}
		for id: Variant in value[key]:
			if not id is String or not data.scenes.has(id) or seen.has(id): return false
			seen[id] = true
	if not value.get("active") is String or not value.get("location") is Dictionary: return false
	if not WorldCalendar.integer_between(value.get("line"),0,1000): return false
	if value.active.is_empty():
		if value.line!=0 or value.reward_pending: return false
	else:
		if not data.scenes.has(value.active) or value.active in value.done: return false
		if value.line>=data.scenes[value.active].lines.size(): return false
		if not MapLoadoutState.valid_map_location(value.location) or value.location.is_empty(): return false
		if value.reward_pending and (value.active!="returning" or (value.line!=12 and value.line!=data.scenes.returning.lines.size()-1)): return false
	return true

static func event(scene: String) -> Dictionary:
	var result: Dictionary = data.scenes[scene].duplicate(true)
	result.merge({"id":PREFIX+scene,"type":"dialogue","speaker_id":"base.map_player.chen_yu",
		"presentation":data.presentation.duplicate(true),"speakers":data.speakers.duplicate(true)})
	return result

static func story(state: MapLoadoutState) -> Dictionary:
	return state.quests[ID].story

static func unfinished(state: MapLoadoutState, scene: String) -> bool:
	return scene not in story(state).done

static func actionable_shop(state: MapLoadoutState) -> bool:
	var counts: Dictionary = state.quests[ID].counts
	return counts.deliver==0 and (counts.talk==0 or (QuestState.stage(state.quests)=="returning" and not QuestState.delivery_units(state).is_empty()))

static func arrival(state: MapLoadoutState, map_id: String, point_id: String) -> String:
	if not MapEventRegistry.story_allowed(state,point_id): return ""
	var saved := story(state)
	if not saved.active.is_empty(): return saved.active
	if not saved.pending.is_empty(): return saved.pending[0]
	if state.quests[ID].counts.deliver>0: return ""
	if map_id==data.shop.map_id and point_id==data.shop.point_id and actionable_shop(state):
		return "morning" if state.quests[ID].counts.talk==0 else "returning"
	if map_id!=data.slope_map or state.quests[ID].counts.talk==0: return ""
	if unfinished(state,"slope"): return "slope"
	for target: Dictionary in QuestState.definition.objectives:
		if not target.has("item_id") or not unfinished(state,"see_"+target.id): continue
		for location: Dictionary in target.targets:
			if location.map_id==map_id and location.point_id==point_id: return "see_"+target.id
	if point_id==data.waterfall_point and unfinished(state,"waterfall"): return "waterfall"
	return ""

static func gathered(state: MapLoadoutState, offer: Dictionary) -> void:
	if offer.get("quest_id","")!=ID or state.quests[ID].counts.deliver>0: return
	if offer.item_id not in ["base.material.kuaiye","base.material.xilutai"]: return
	var counts: Dictionary = state.quests[ID].counts
	var herb_ready := QuestState.objective_complete(counts,"kuaiye")
	var moss_ready := QuestState.objective_complete(counts,"xilutai")
	if not herb_ready and not moss_ready: return
	var scene := "both" if herb_ready and moss_ready else ("kuaiye_only" if herb_ready else "xilutai_only")
	var saved := story(state)
	if scene not in saved.done and scene not in saved.pending and saved.active!=scene: saved.pending.append(scene)

static func command(state: MapLoadoutState, path: String, action: String, scene := "") -> String:
	var prepared := MapLoadoutStore.candidate(state)
	if not prepared.error.is_empty(): return prepared.error
	var next: MapLoadoutState = prepared.state
	var saved := story(next)
	match action:
		"begin":
			if not data.scenes.has(scene): return "任务对白未配置。"
			if scene in saved.done: return ""
			if not saved.active.is_empty(): return "" if saved.active==scene else "请先完成当前对白。"
			if not MapLoadoutState.valid_map_location(next.map_location) or next.map_location.is_empty(): return "任务对白缺少当前地点。"
			if scene=="wake":
				if not saved.wake_pending or next.map_location!=data.home: return "尚未进入家中开场。"
			elif scene!=arrival(next,next.map_location.map_id,next.map_location.point_id): return "当前地点或任务阶段不能触发这段对白。"
			if scene=="returning" and not actionable_shop(next): return "储物袋中需要苦艾叶、溪露苔各3株。"
			saved.active = scene
			saved.line = 0
			saved.location = next.map_location.duplicate(true)
			saved.pending.erase(scene)
			if scene=="wake": saved.wake_pending = false
		"advance":
			if saved.active.is_empty() or saved.reward_pending: return ""
			if saved.line+1<data.scenes[saved.active].lines.size():
				saved.line += 1
			elif saved.active=="returning":
				saved.reward_pending = true
			else:
				if saved.active=="wake":
					next.quest_tracking.ids = [ID]
					next.quest_tracking.shown = true
				if saved.active=="morning": QuestState.record(next,"talk")
				saved.done.append(saved.active)
				saved.active = ""
				saved.line = 0
				saved.location = {}
		"accept":
			if not saved.reward_pending: return ""
			# Final dialogue, exact herb removal, money and completion share one write.
			saved.reward_pending = false
			saved.done.append("returning")
			saved.active = ""
			saved.line = 0
			saved.location = {}
			var error := QuestState.settle_delivery(next)
			if not error.is_empty(): return error
		_: return "未知任务对白指令。"
	next.quest_tracking = QuestTracking.normalized(next.quest_tracking,QuestTracking.entries(next))
	var error := MapLoadoutStore.save(next,path)
	if not error.is_empty(): return error
	error = state.restore(next.snapshot())
	# Continue chooses visible checkpoints, so retain the dialogue cursor there too.
	# The player's quick-save preference is still respected by the shared policy.
	if error.is_empty():
		preload("res://scripts/entry/save_checkpoints.gd").after_action(state,path,"quest_story")
	return error

static func reward_record(state: MapLoadoutState) -> Dictionary:
	var record := MapGatheringRewards.record_for(state.records,MapGatheringRewards.SPIRIT_STONE_ID).duplicate(true)
	record.quantity = int(QuestState.definition.rewards[0].quantity)
	return record

static func prepare_start(state: MapLoadoutState) -> String:
	# Explicit initializer for the user's current character, and later creation.
	var next := state.snapshot()
	next.quests = QuestState.initial(WorldCalendar.current_day(state.calendar),data.home.map_id)
	next.quests[ID].story = initial()
	next.quests[ID].story.wake_pending = true
	next.map_location = data.home.duplicate(true)
	for offer: Dictionary in next.get("gathering_offers",{}).values(): offer.erase("quest_id")
	return state.restore(next)
