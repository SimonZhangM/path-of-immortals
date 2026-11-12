class_name DeerRestQuest
extends RefCounted
## One optional story encounter, with durable completion and a one-time day-later coda.
const ID := "quest.prologue.lumianchu"
const PREFIX := "base.map_event.quest.lumianchu."
const REST_FLAG := "base.story.lumianchu.rest_unlocked"
static var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/quests/deer_rest.json"))
static var common_speakers: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogues/common_speakers.json"))

static func initial() -> Dictionary:
	return {"stage":"unseen","active":"","line":0,"location":{},"choice_pending":false,"battle_started":false,"accepted_location":"","accepted_at":0,"updated_at":0,"completed_day":0,"epilogue_done":false}

static func story(state: MapLoadoutState) -> Dictionary:
	return state.quests[ID]

static func accepted(state: MapLoadoutState) -> bool:
	return not story(state).accepted_location.is_empty()

static func normalized(raw: Dictionary) -> Dictionary:
	var result := raw.duplicate(true)
	for key in ["line","accepted_at","updated_at","completed_day"]: result[key] = int(result[key])
	return result

static func valid(raw: Variant) -> bool:
	if not raw is Dictionary: return false
	if raw.get("stage") not in ["unseen","inspect","battle","cleared","completed"]: return false
	if not raw.get("active") is String or not raw.get("location") is Dictionary: return false
	if raw.get("accepted_location") not in ["",data.accepted_location]: return false
	for key in ["choice_pending","battle_started","epilogue_done"]:
		if not raw.get(key) is bool: return false
	for key in ["accepted_at","updated_at","completed_day"]:
		if not WorldCalendar.integer_between(raw.get(key),0,WorldCalendar.MAX_DAY): return false
	if not WorldCalendar.integer_between(raw.get("line"),0,1000): return false
	if (raw.stage=="unseen")!=raw.accepted_location.is_empty(): return false
	if raw.stage=="unseen" and (raw.accepted_at!=0 or raw.battle_started): return false
	if raw.stage=="inspect" and raw.battle_started: return false
	if raw.stage in ["cleared","completed"] and not raw.battle_started: return false
	if raw.stage!="completed" and (raw.completed_day!=0 or raw.epilogue_done): return false
	if raw.active.is_empty(): return raw.line==0 and raw.location.is_empty() and not raw.choice_pending
	if not data.scenes.has(raw.active) or raw.line>=data.scenes[raw.active].lines.size(): return false
	if raw.location!=(data.deer if raw.active=="deer" else data.tree): return false
	if raw.choice_pending and (raw.active not in ["inspect","decision"] or raw.line!=data.scenes[raw.active].lines.size()-1 or raw.stage!="battle"): return false
	match raw.active:
		"deer": return raw.stage=="unseen" and not raw.choice_pending
		"inspect": return raw.stage==("battle" if raw.choice_pending else "inspect")
		"decision": return raw.stage=="battle" and raw.choice_pending
		"decline": return raw.stage=="battle" and not raw.choice_pending
		"clear": return raw.stage=="cleared" and not raw.choice_pending
		"epilogue": return raw.stage=="completed" and not raw.epilogue_done and not raw.choice_pending
	return false

static func configuration_error() -> String:
	if data.get("quest_id")!=ID: return "鹿眠处任务配置无效。"
	for location: Dictionary in [data.deer,data.tree]:
		if not MapLoadoutState.valid_map_location(location): return "鹿眠处地点配置无效。"
	if data.battle.id!=PREFIX+"battle" or data.battle.point_id!=data.tree.point_id or data.battle.enemy_id!="base.enemy.biyetengling": return "鹿眠处任务战配置无效。"
	var error := MapEventRegistry.new().configure([data.battle],[data.tree.point_id])
	if not error.is_empty(): return error
	for scene: String in data.scenes:
		var value := event(scene)
		if value.lines.is_empty() or value.lines.size()!=value.line_speakers.size(): return "鹿眠处对白与说话人不匹配。"
		for i in value.lines.size():
			if value.lines[i].is_empty() or not value.speakers.has(value.line_speakers[i]): return "鹿眠处对白配置无效。"
	return ""

static func event(scene: String) -> Dictionary:
	var result: Dictionary = data.scenes[scene].duplicate(true)
	var speakers: Dictionary = common_speakers.duplicate(true)
	speakers.merge(data.speakers,true)
	result.merge({"id":PREFIX+scene,"type":"dialogue","speaker_id":"base.map_player.chen_yu","presentation":data.presentation.duplicate(true),"speakers":speakers})
	var pending: Dictionary = result.get("pending_illustration",{})
	if not pending.is_empty() and ResourceLoader.exists(pending.image,"Texture2D"):
		result.illustration = pending.duplicate(true)
	return result

static func epilogue_available(state: MapLoadoutState) -> bool:
	var saved := story(state)
	return saved.stage=="completed" and not saved.epilogue_done and WorldCalendar.current_day(state.calendar)>int(saved.completed_day)

static func arrival(state: MapLoadoutState, map_id: String, point_id: String) -> String:
	var saved := story(state)
	var location := {"map_id":map_id,"point_id":point_id}
	if not saved.active.is_empty(): return saved.active if saved.location==location else ""
	# Only interrupted dialogue and the post-battle cleanup start automatically.
	if location==data.tree and saved.stage=="cleared": return "clear"
	return ""

static func interaction(state: MapLoadoutState, map_id: String, point_id: String) -> String:
	var resume := arrival(state,map_id,point_id)
	if not resume.is_empty(): return resume
	var saved := story(state)
	var location := {"map_id":map_id,"point_id":point_id}
	if location==data.deer and saved.stage=="unseen": return "deer"
	if location==data.tree:
		if saved.stage=="inspect": return "inspect"
		if saved.stage=="battle": return "decision"
		if epilogue_available(state): return "epilogue"
	return ""

static func marker_points(state: MapLoadoutState, map_id: String) -> Array[String]:
	var result: Array[String] = []
	if map_id!=data.tree.map_id: return result
	var saved := story(state)
	if saved.stage=="unseen": result.append(data.deer.point_id)
	elif saved.stage!="completed": result.append(data.tree.point_id)
	return result

static func battle_ready(state: MapLoadoutState) -> bool:
	var saved := story(state)
	return saved.stage=="battle" and saved.battle_started and saved.active.is_empty() and state.map_location==data.tree

static func record_victory(state: MapLoadoutState, event_id: String) -> void:
	if event_id!=data.battle.id or not battle_ready(state): return
	story(state).stage = "cleared"
	story(state).updated_at = WorldCalendar.current_day(state.calendar)
	# Ordinary vine encounters and all their cooldowns stay untouched.

static func _finish(saved: Dictionary) -> void:
	saved.active = ""
	saved.line = 0
	saved.location = {}
	saved.choice_pending = false

static func command(state: MapLoadoutState, path: String, action: String, scene := "") -> String:
	var prepared := MapLoadoutStore.candidate(state)
	if not prepared.error.is_empty(): return prepared.error
	var next: MapLoadoutState = prepared.state
	var saved := story(next)
	match action:
		"begin":
			if not saved.active.is_empty(): return "" if saved.active==scene else "请先完成当前对白。"
			if next.map_location.is_empty() or scene.is_empty() or interaction(next,next.map_location.map_id,next.map_location.point_id)!=scene: return "当前地点或进度不能开始这段对白。"
			saved.active = scene
			saved.location = next.map_location.duplicate(true)
			saved.choice_pending = scene=="decision"
		"advance":
			if saved.active.is_empty() or saved.choice_pending: return ""
			if saved.line+1<data.scenes[saved.active].lines.size(): saved.line += 1
			elif saved.active=="inspect":
				saved.stage = "battle"
				saved.choice_pending = true
			else:
				match saved.active:
					"deer":
						saved.stage = "inspect"
						saved.accepted_location = data.accepted_location
						saved.accepted_at = WorldCalendar.current_day(next.calendar)
					"clear":
						saved.stage = "completed"
						saved.completed_day = WorldCalendar.current_day(next.calendar)
						next.narrative.flags[REST_FLAG] = true
					"epilogue": saved.epilogue_done = true
				_finish(saved)
		"fight","leave":
			if not saved.choice_pending or saved.location!=data.tree or next.map_location!=data.tree: return "当前不能处理这处藤灵。"
			_finish(saved)
			if action=="fight": saved.battle_started = true
			else:
				saved.active = "decline"
				saved.location = data.tree.duplicate(true)
		_: return "未知鹿眠处指令。"
	saved.updated_at = WorldCalendar.current_day(next.calendar)
	next.quest_tracking = QuestTracking.normalized(next.quest_tracking,QuestTracking.entries(next))
	var error := MapLoadoutStore.save(next,path)
	if not error.is_empty(): return error
	error = state.restore(next.snapshot())
	if error.is_empty(): preload("res://scripts/entry/save_checkpoints.gd").after_action(state,path,"deer_rest")
	return error

static func display_entry(state: MapLoadoutState, presentation: Dictionary) -> Dictionary:
	var result := presentation.duplicate(true)
	var saved := story(state)
	result.merge(saved,true)
	result.stage_id = saved.stage
	result.objectives = data.objectives.duplicate(true)
	var stage_index: int = ["inspect","battle","cleared","completed"].find(saved.stage)
	for i in result.objectives.size(): result.objectives[i].completed = stage_index>i
	result.objectives.resize(mini(3,stage_index+1))
	result.has_locked_next = stage_index<2
	result.people = []
	result.rewards = data.rewards.duplicate(true)
	result.location = {"name":"叠翠峰·古树盘根","image":"res://assets/map-worldmap-diecuifeng.webp"}
	return result
