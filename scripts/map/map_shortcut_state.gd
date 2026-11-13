extends RefCounted
## Read receipts and progressive entry availability, independent of any UI instance.
## Content and acquisition facts stay in the loadout; no per-frame inventory scan.
static var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/map_shortcuts.json"))
static var world: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/world_map_locations.json"))

static func valid(raw: Variant) -> bool:
	if not raw is Dictionary: return false
	if raw.is_empty(): return true
	if raw.get("version")!=1 or not raw.get("collapsed") is bool: return false
	for key in ["unlocked","unread"]:
		if not raw.get(key) is Array: return false
		for id: Variant in raw[key]:
			if not id is String or not id.begins_with("base.map_shortcut."): return false
	if not raw.get("observed") is Dictionary: return false
	for source: Variant in raw.observed:
		if not source is String or not raw.observed[source] is Dictionary: return false
		for id: Variant in raw.observed[source]:
			if not id is String or not WorldCalendar.integer_between(raw.observed[source][id],0,1000000000): return false
	return true

static func facts(state) -> Dictionary:
	var result := {"items":{},"books":{},"quests":{},"locations":{}}
	# Count ownership rather than storage geometry: equipping/rearranging is not loot.
	for item_id: String in state._owned.values():
		result.items[item_id] = int(result.items.get(item_id,0))+1
		if state.records.get(item_id,{}).get("category","")=="book": result.books[item_id]=1
	for book_id: String in state.knowledge.learned: result.books[book_id]=1
	# Read accepted gameplay facts, never the task screen's presentation catalog.
	for quest_id: String in state.quests:
		var quest: Dictionary=state.quests[quest_id]
		var accepted: bool=not str(quest.get("accepted_location","")).is_empty()
		if quest_id==QuestState.ID: accepted=int(quest.get("counts",{}).get("talk",0))>0
		elif quest_id==HomecomingQuest.ID: accepted=bool(quest.get("letter_received",false))
		if accepted: result.quests[quest_id]=1
	for location: Dictionary in world.locations.values():
		var map_id: String = location.map_id
		if not state.map_visited.get(map_id,[]).is_empty() or state.map_location.get("map_id","")==map_id:
			result.locations[map_id]=1
	return result

static func sync(state) -> bool:
	if state.registry==null: return false
	var current := facts(state)
	var previous: Dictionary = state.map_shortcuts
	var first := previous.is_empty()
	var next := {"version":1,"collapsed":false,"unlocked":[],"unread":[],"observed":{}} if first else previous.duplicate(true)
	for entry: Dictionary in config.entries:
		var source: String = entry.source
		var values: Dictionary = current.get(source,{})
		var old: Dictionary = next.observed.get(source,{})
		var new_content := false
		if not first and next.observed.has(source):
			for key: String in values:
				if int(values[key])>int(old.get(key,0)): new_content=true
		var available := unlocked_by_progress(entry,state,current)
		if entry.get("dynamic",false) and not available:
			next.unlocked.erase(entry.id)
			next.unread.erase(entry.id)
		if available and entry.id not in next.unlocked:
			next.unlocked.append(entry.id)
			if not first: new_content=true
		if new_content and entry.id not in next.unread: next.unread.append(entry.id)
		next.observed[source]=values.duplicate()
	if next==previous: return false
	state.map_shortcuts=next
	return true

static func unlocked_by_progress(entry: Dictionary, state, current: Dictionary) -> bool:
	match entry.get("unlock","manual"):
		"breakthrough": return preload("res://scripts/map/map_breakthrough_access.gd").can_open(state)
		"always": return true
		"book": return not current.books.is_empty()
		"task": return not current.quests.is_empty()
		"world":
			for id: String in current.locations:
				if id!="base.map.qingshizhen": return true
		"story_flag": return bool(state.narrative.get("flags",{}).get(entry.get("flag",""),false))
	return false

static func entry_for_action(action: String) -> Dictionary:
	for entry: Dictionary in config.entries:
		if entry.action==action: return entry
	return {}
