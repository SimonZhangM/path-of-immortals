class_name QuestTracking
extends RefCounted
## One active tracked task; an unfinished main quest is the default fallback.
const LIMIT := 1
const LEGACY_LIMIT := 3
static var presentation: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/task_list.json"))
static var sidebar: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/task_sidebar.json"))

static func initial() -> Dictionary:
	return {"ids":[QuestState.ID],"shown":false}

static func valid(raw: Variant, allow_legacy := false) -> bool:
	if not raw is Dictionary or not raw.get("shown") is bool or not raw.get("ids") is Array: return false
	if raw.ids.size()>(LEGACY_LIMIT if allow_legacy else LIMIT): return false
	var seen := {}
	for id: Variant in raw.ids:
		if not id is String or not id.begins_with("quest.") or seen.has(id): return false
		seen[id] = true
	return true

static func entries(state: MapLoadoutState) -> Array:
	var result := []
	for entry: Dictionary in presentation.display_entries:
		if entry.id==QuestState.ID: result.append(QuestState.display_entry(state,entry))
		elif entry.id==RiverQuest.ID and not RiverQuest.story(state).accepted_location.is_empty(): result.append(RiverQuest.display_entry(state,entry))
		elif entry.id==HerbQuest.ID and HerbQuest.accepted(state): result.append(HerbQuest.display_entry(state,entry))
		elif entry.id not in [QuestState.ID,RiverQuest.ID,HerbQuest.ID]: result.append(entry.duplicate(true))
	return result

static func category_index(id: String) -> int:
	for i in sidebar.categories.size():
		if sidebar.categories[i].id==id: return i
	return sidebar.categories.size()

static func ordered(tracking: Dictionary, available: Array) -> Array:
	var current := normalized(tracking,available)
	for entry: Dictionary in available:
		if entry.id in current.ids: return [entry]
	return []

static func latest_main(available: Array) -> String:
	var selected := ""
	var latest := -1
	for entry: Dictionary in available:
		if entry.get("category","")!="main" or entry.get("stage_id","")=="completed": continue
		var accepted := int(entry.get("accepted_at",0))
		# Content order resolves quests accepted on the same game day.
		if accepted>=latest:
			latest = accepted
			selected = entry.id
	return selected

static func normalized(tracking: Dictionary, available: Array) -> Dictionary:
	var next := {"ids":[],"shown":bool(tracking.shown)}
	# Old multi-task saves keep their most recently added active task.
	for id: String in tracking.ids:
		for entry: Dictionary in available:
			if entry.id==id and entry.get("stage_id","")!="completed": next.ids = [id]
	if next.ids.is_empty():
		var main := latest_main(available)
		if not main.is_empty(): next.ids = [main]
	return next

static func objectives(entry: Dictionary) -> Array:
	var result := []
	for row: Dictionary in entry.get("objectives",[]):
		if row.get("completed",false): continue
		# A single collection objective can have independently counted materials.
		for requirement: Dictionary in row.get("requirements",[row]):
			if not requirement.get("completed",false): result.append(requirement)
	return result

static func targets(entry: Dictionary) -> Array:
	var result := []
	var seen := {}
	for row: Dictionary in objectives(entry):
		for target: Dictionary in row.get("targets",[]):
			var key: String = target.map_id+":"+target.point_id
			if not seen.has(key):
				seen[key] = true
				result.append(target)
	return result

static func toggle(tracking: Dictionary, id: String, available: Array) -> Dictionary:
	var next := normalized(tracking,available)
	for entry: Dictionary in available:
		if entry.id==id and entry.get("stage_id","")!="completed":
			if id in next.ids:
				if entry.get("category","")=="main": return {"error":"当前追踪的主线任务不能取消追踪。"}
				next.ids.clear()
				next = normalized(next,available)
			else:
				next.ids = [id]
			next.shown = true
			return {"error":"","tracking":next}
	return {"error":"当前任务不可追踪。"}

static func commit(state: MapLoadoutState, next: Dictionary, path: String) -> String:
	if not valid(next): return "任务追踪数据无效。"
	var prepared := MapLoadoutStore.candidate(state)
	if not prepared.error.is_empty(): return prepared.error
	prepared.state.quest_tracking = normalized(next,entries(prepared.state))
	var error := MapLoadoutStore.save(prepared.state,path)
	if not error.is_empty(): return error
	return state.restore(prepared.state.snapshot())
