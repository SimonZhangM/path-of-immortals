class_name DialogueConditions
extends RefCounted

static func error(config: Dictionary) -> String:
	# Alternative sources of the same knowledge; other conditions still all apply.
	if config.has("any_of"):
		if not config.any_of is Array or config.any_of.is_empty(): return "可选对话条件无效。"
		for branch: Variant in config.any_of:
			if not branch is Dictionary or branch.is_empty(): return "可选对话条件无效。"
			var branch_error := error(branch)
			if not branch_error.is_empty(): return branch_error
	for key in ["requires_flags","excludes_flags","set_flags","set_facts","retire_flags"]:
		if not config.get(key,[]) is Array: return "剧情标记列表无效。"
		for id: Variant in config.get(key,[]):
			if not id is String or not id.begins_with("base.story."): return "剧情标记ID无效。"
	for key in ["requires_clues","requires_done","excludes_done","excludes_seen","requires_greetings"]:
		if not config.get(key,[]) is Array: return "对话条件列表无效。"
		for id: Variant in config.get(key,[]):
			if not id is String or not id.begins_with("base.clue." if key=="requires_clues" else "base.dialogue."): return "对话条件ID无效。"
	if not config.get("requires_dialogues",[]) is Array: return "人物对话条件无效。"
	for entry: Variant in config.get("requires_dialogues",[]):
		if not entry is Dictionary or not entry.get("npc_id") is String or not entry.npc_id.begins_with("base.npc.") or not entry.get("segment_id") is String or not entry.segment_id.begins_with("base.dialogue."): return "人物对话条件引用无效。"
	return ""

static func eligible(narrative: Dictionary, config: Dictionary, npc_id := "") -> bool:
	if config.has("any_of") and not config.any_of.any(func(branch): return eligible(narrative,branch,npc_id)): return false
	for flag: String in config.get("requires_flags",[]):
		if not narrative.flags.get(flag,false): return false
	for flag: String in config.get("excludes_flags",[]):
		if narrative.flags.get(flag,false): return false
	for clue: String in config.get("requires_clues",[]):
		if not narrative.clues.has(clue): return false
	for id: String in config.get("requires_done",[]):
		if id not in narrative.npcs.get(npc_id,{}).get("done",[]): return false
	for id: String in config.get("excludes_done",[]):
		if id in narrative.npcs.get(npc_id,{}).get("done",[]): return false
	for id: String in config.get("excludes_seen",[]):
		if narrative.npcs.get(npc_id,{}).get("seen",{}).has(id): return false
	for id: String in config.get("requires_greetings",[]):
		var greeting: Dictionary = narrative.npcs.get(npc_id,{}).get("greeting",{})
		if id not in greeting.get("once_done",[]) and not greeting.get("once_seen",{}).has(id): return false
	for entry: Dictionary in config.get("requires_dialogues",[]):
		if entry.segment_id not in narrative.npcs.get(entry.npc_id,{}).get("done",[]): return false
	return true

static func apply_flags(narrative: Dictionary, flags: Array) -> void:
	for flag: String in flags:
		if narrative.flags.get(flag,false): continue
		narrative.flags[flag] = true
		narrative.story_revision += 1

static func apply_facts(narrative: Dictionary, flags: Array) -> void:
	# Knowledge acquired in a conversation is not a new main-story event.
	for flag: String in flags: narrative.flags[flag] = true
