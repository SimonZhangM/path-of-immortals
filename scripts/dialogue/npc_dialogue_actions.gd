class_name NpcDialogueActions
extends RefCounted

static func command(state: MapLoadoutState, library: NpcDialogueLibrary, action: String, path: String, topic := "") -> String:
	var prepared := MapLoadoutStore.candidate(state)
	if not prepared.error.is_empty(): return prepared.error
	var candidate: MapLoadoutState = prepared.state
	var day := WorldCalendar.current_day(candidate.calendar)
	var error := ""
	if action!="visit" and not candidate.narrative.npcs.has(library.definition.id): return "请先进入交谈。"
	match action:
		"visit": error = DialogueJournal.visit(candidate.narrative,library,day)
		"select": error = DialogueJournal.select(candidate.narrative,library,topic,day,candidate.map_visited)
		"advance": error = DialogueJournal.advance(candidate.narrative,library,day)
		_: return "未知对话指令。"
	if not error.is_empty(): return error
	if candidate.narrative==state.narrative: return ""
	return _publish(state,candidate,path)

# Creation screen will pass the two fields directly; never guess surname length.
static func set_player_name(state: MapLoadoutState, surname: String, given_name: String, path: String) -> String:
	var identity := {"surname":surname,"given_name":given_name}
	if not DialogueJournal.valid_name(identity): return "姓名格式无效。"
	var prepared := MapLoadoutStore.candidate(state)
	if not prepared.error.is_empty(): return prepared.error
	prepared.state.narrative.identity = identity
	return _publish(state,prepared.state,path)

# Main-story integration explicitly sets facts; test cultivation rank is not a story fact.
static func set_story_flag(state: MapLoadoutState, flag: String, path: String) -> String:
	if not flag.begins_with("base.story.") or flag.length()>200: return "剧情标记无效。"
	if state.narrative.flags.get(flag,false): return ""
	var prepared := MapLoadoutStore.candidate(state)
	if not prepared.error.is_empty(): return prepared.error
	prepared.state.narrative.flags[flag] = true
	prepared.state.narrative.story_revision += 1
	return _publish(state,prepared.state,path)

static func _publish(state: MapLoadoutState, candidate: MapLoadoutState, path: String) -> String:
	var error := MapLoadoutStore.save(candidate,path)
	if not error.is_empty(): return error
	return state.restore(candidate.snapshot())
