class_name QinglanDepartureQuest
extends RefCounted
## Main quest four, currently implemented through the town farewells and outpost.
const ID := "quest.prologue.qinglanchujie"
const PREFIX := "base.map_event.quest.qinglanchujie."
const ACCEPTED_FLAG := "base.story.qinglanchujie.accepted"
const TOKEN_FLAG := "base.story.qinglanchujie.token_received"
const NAME_FLAG := "base.story.xieyunshu.name_known"
static var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/quests/qinglan_departure.json"))

static func initial() -> Dictionary:
	return {"active":"","line":0,"location":{},"reward_pending":false,"done":[],"token_received":false,"accepted_at":0,"updated_at":0,"accepted_location":""}

static func story(state: MapLoadoutState) -> Dictionary:
	return state.quests[ID]

static func accepted(state: MapLoadoutState) -> bool:
	return not story(state).accepted_location.is_empty()

static func available(state: MapLoadoutState) -> bool:
	return HomecomingQuest.completed(state) and int(state.growth.realm)>=1

static func configuration_error() -> String:
	if data.get("quest_id")!=ID: return "青岚初阶配置无效。"
	for location: Dictionary in data.locations.values():
		if not MapLoadoutState.valid_map_location(location): return "青岚初阶地点无效。"
	for scene: Dictionary in data.scenes.values():
		if scene.lines.is_empty() or scene.lines.size()!=scene.line_speakers.size(): return "青岚初阶对白与说话人不匹配。"
		for i in scene.lines.size():
			if scene.lines[i].is_empty() or not data.speakers.has(scene.line_speakers[i]): return "青岚初阶对白无效。"
	return ""

static func valid(raw: Variant) -> bool:
	if not raw is Dictionary: return false
	for key in ["active","accepted_location"]:
		if not raw.get(key) is String: return false
	for key in ["accepted_at","updated_at"]:
		if not WorldCalendar.integer_between(raw.get(key),0,WorldCalendar.MAX_DAY): return false
	if not raw.get("location") is Dictionary or not raw.get("done") is Array or not raw.get("token_received") is bool or raw.get("reward_pending")!=false: return false
	if not WorldCalendar.integer_between(raw.get("line"),0,1000): return false
	var seen := {}
	for step: Variant in raw.done:
		if step not in ["mother","pharmacy","clinic","outpost"] or seen.has(step): return false
		seen[step] = true
	if raw.accepted_location not in ["",data.accepted_location]: return false
	if raw.accepted_location.is_empty():
		# JSON decodes numbers as floats; validate values instead of dictionary types.
		return raw.active.is_empty() and raw.line==0 and raw.location.is_empty() and raw.done.is_empty() and not raw.token_received and raw.accepted_at==0 and raw.updated_at==0
	if not raw.done.is_empty() and "mother" not in raw.done: return false
	if raw.token_received!=("outpost" in raw.done): return false
	if raw.active.is_empty(): return raw.line==0 and raw.location.is_empty() and "mother" in raw.done
	if not data.scenes.has(raw.active): return false
	var entry: Dictionary = data.scenes[raw.active]
	if raw.line>=entry.lines.size() or entry.step in raw.done or raw.location!=data.locations[entry.step]: return false
	return entry.step=="mother" or "mother" in raw.done

static func normalized(raw: Dictionary) -> Dictionary:
	var result := raw.duplicate(true)
	for key in ["line","accepted_at","updated_at"]: result[key] = int(result[key])
	return result

static func arrival(state: MapLoadoutState, map_id: String, point_id: String) -> String:
	var location := {"map_id":map_id,"point_id":point_id}
	var saved := story(state)
	if not saved.active.is_empty(): return saved.active if saved.location==location else ""
	if not available(state): return ""
	if not accepted(state): return "mother" if location==data.locations.mother else ""
	if "mother" not in saved.done: return ""
	for step: String in ["pharmacy","clinic","outpost"]:
		if location==data.locations[step] and step not in saved.done:
			if step=="outpost": return "outpost_known" if state.narrative.flags.get(NAME_FLAG,false) else "outpost_new"
			return step
	return ""

static func interaction(state: MapLoadoutState, map_id: String, point_id: String) -> String:
	return arrival(state,map_id,point_id)

static func marker_points(state: MapLoadoutState, map_id: String) -> Array[String]:
	var points: Array[String] = []
	for location: Dictionary in data.locations.values():
		if location.map_id==map_id and not arrival(state,map_id,location.point_id).is_empty(): points.append(location.point_id)
	return points

static func event(scene: String, state: MapLoadoutState = null) -> Dictionary:
	var result: Dictionary = data.scenes[scene].duplicate(true)
	result.merge({"id":PREFIX+scene,"type":"dialogue","speaker_id":"base.map_player.chen_yu","presentation":data.presentation.duplicate(true),"speakers":data.speakers.duplicate(true)})
	if state!=null:
		var realm: String = state.registry.get_cultivation(CultivationGrowth.rank_id(state.growth)).name
		var cultivation := realm+WorldCalendar.chinese_number(int(state.growth.layer))+"层"
		for i in result.lines.size(): result.lines[i] = result.lines[i].replace("{player.cultivation}",cultivation)
	return result

static func command(state: MapLoadoutState, path: String, action: String, scene := "") -> String:
	var prepared := MapLoadoutStore.candidate(state)
	if not prepared.error.is_empty(): return prepared.error
	var next: MapLoadoutState = prepared.state
	var saved := story(next)
	match action:
		"begin":
			if not saved.active.is_empty(): return "" if saved.active==scene else "请先完成当前对白。"
			if next.map_location.is_empty() or scene.is_empty() or arrival(next,next.map_location.map_id,next.map_location.point_id)!=scene: return "当前地点或进度不能开始这段对白。"
			saved.active = scene
			saved.location = next.map_location.duplicate(true)
			if scene=="mother":
				saved.accepted_at = WorldCalendar.current_day(next.calendar)
				saved.accepted_location = data.accepted_location
				DialogueConditions.apply_flags(next.narrative,[ACCEPTED_FLAG])
			next.quest_tracking.ids = [ID]
			next.quest_tracking.shown = true
		"advance":
			if saved.active.is_empty(): return ""
			var entry: Dictionary = data.scenes[saved.active]
			DialogueConditions.apply_facts(next.narrative,entry.get("facts_after",{}).get(str(saved.line),[]))
			if saved.line+1<entry.lines.size(): saved.line += 1
			else:
				saved.done.append(entry.step)
				if entry.step=="mother": DialogueConditions.apply_flags(next.narrative,["base.story.qinglan.departure_ready"])
				if entry.step=="outpost":
					saved.token_received = true
					DialogueConditions.apply_flags(next.narrative,[TOKEN_FLAG])
				DialogueConditions.apply_facts(next.narrative,["base.story.qinglanchujie."+entry.step+"_done"])
				saved.active = ""
				saved.line = 0
				saved.location = {}
		_: return "未知青岚初阶指令。"
	story(next).updated_at = WorldCalendar.current_day(next.calendar)
	next.quest_tracking = QuestTracking.normalized(next.quest_tracking,QuestTracking.entries(next))
	var error := MapLoadoutStore.save(next,path)
	if not error.is_empty(): return error
	error = state.restore(next.snapshot())
	if error.is_empty(): preload("res://scripts/entry/save_checkpoints.gd").after_action(state,path,"qinglan_departure")
	return error

static func display_entry(state: MapLoadoutState, presentation: Dictionary) -> Dictionary:
	var result := presentation.duplicate(true)
	var saved := story(state)
	result.merge(saved,true)
	result.stage_id = "mother" if "mother" not in saved.done else ("road" if saved.done.size()==4 else ("farewells_token" if saved.token_received else ("outpost" if "pharmacy" in saved.done and "clinic" in saved.done else "farewells")))
	result.objectives = data.objectives.duplicate(true)
	for row: Dictionary in result.objectives: row.completed = row.id in saved.done
	if "mother" not in saved.done: result.objectives.resize(1)
	elif saved.done.size()<4: result.objectives.resize(4)
	result.has_locked_next = true
	result.people = []
	if result.stage_id=="mother": result.people.append(data.people.mother.duplicate(true))
	elif result.stage_id=="road":
		for person: String in ["outpost","shen"]: result.people.append(data.people[person].duplicate(true))
	else:
		for person: String in ["pharmacy","clinic","outpost"]: result.people.append(data.people[person].duplicate(true))
	# Later registration rewards are not granted by these four conversations.
	result.rewards = data.rewards.duplicate(true)
	var location_name := "白沙村·母亲的家" if result.stage_id=="mother" else "青石镇"
	result.location = {"name":location_name,"image":"res://assets/map-baishacun.webp" if result.stage_id=="mother" else "res://assets/map-qingshizhen.webp"}
	return result
