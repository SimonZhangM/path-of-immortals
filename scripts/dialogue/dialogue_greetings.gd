class_name DialogueGreetings
extends RefCounted

# Optional, pure state for visit greetings. Formal topic journals remain untouched.
static func initial() -> Dictionary:
	return {"last":"","active":"","seen":0,"daily_turn":0,"ordinary_index":0,"close_index":0,"phase":"","phase_next":true,"pending_treatment":false,"treatment_used":false}

static func valid_record(raw: Variant) -> bool:
	if not raw is Dictionary: return false
	for key in ["last","active","phase"]:
		if not raw.get(key) is String: return false
	for key in ["seen","daily_turn","ordinary_index","close_index"]:
		if not WorldCalendar.integer_between(raw.get(key),0,10000): return false
	for key in ["phase_next","pending_treatment","treatment_used"]:
		if not raw.get(key) is bool: return false
	if not raw.get("once_done",[]) is Array: return false
	var unique := {}
	for id: Variant in raw.get("once_done",[]):
		if not id is String or unique.has(id): return false
		unique[id] = true
	if not raw.get("once_seen",{}) is Dictionary: return false
	for id: Variant in raw.get("once_seen",{}):
		if not id is String or not WorldCalendar.integer_between(raw.once_seen[id],1,10000): return false
	return true

static func configuration_error(raw: Variant, segments: Dictionary, clues: Dictionary) -> String:
	if not raw is Dictionary: return "欢迎词配置无效。"
	if raw.is_empty(): return ""
	if not raw.get("entries") is Dictionary or not raw.get("phases") is Array: return "欢迎词库缺失。"
	if not raw.get("low_ratio") is float and not raw.get("low_ratio") is int: return "欢迎状态阈值无效。"
	if not is_finite(float(raw.low_ratio)) or float(raw.low_ratio)<=0 or float(raw.low_ratio)>1: return "欢迎状态阈值无效。"
	if not WorldCalendar.integer_between(raw.get("close_interval"),0,100) or raw.close_interval==1: return "欢迎轮换间隔无效。"
	var refs := {}
	for group in ["ordinary","close"]:
		if not raw.get(group) is Array or (raw[group].is_empty() and (group=="ordinary" or raw.close_interval>0)): return "日常欢迎列表无效。"
		for id: Variant in raw[group]:
			if not id is String or refs.has(id): return "日常欢迎引用重复或无效。"
			refs[id] = true
	for key in ["injured","tired","treated"]:
		if not raw.has(key): continue
		if not raw.get(key) is String or refs.has(raw[key]): return "状态欢迎引用无效。"
		refs[raw[key]] = true
	var phase_ids := {}
	if not raw.get("once",[]) is Array: return "特殊欢迎列表无效。"
	for entry: Variant in raw.get("once",[]):
		if not entry is Dictionary or not entry.get("entry") is String or refs.has(entry.entry) or not DialogueConditions.error(entry).is_empty(): return "特殊欢迎条件无效。"
		if entry.has("low_resource") and entry.low_resource not in ["hp","stamina"]: return "特殊欢迎资源条件无效。"
		for id: String in entry.get("excludes_seen",[]):
			if not segments.has(id): return "特殊欢迎引用未知对话。"
		refs[entry.entry] = true
	for phase: Variant in raw.phases:
		if not phase is Dictionary or not phase.get("id") is String or phase.id.is_empty() or phase_ids.has(phase.id) or not phase.get("entry") is String or refs.has(phase.entry): return "阶段欢迎配置无效。"
		phase_ids[phase.id] = true
		refs[phase.entry] = true
		var condition_count := 0
		for key in ["requires_done","requires_clues"]:
			if not phase.get(key,[]) is Array: return "阶段欢迎条件无效。"
			for value: Variant in phase.get(key,[]):
				if not value is String or not (segments.has(value) if key=="requires_done" else clues.has(value)): return "阶段欢迎引用未知条件。"
				condition_count += 1
		if condition_count==0: return "阶段欢迎缺少解锁条件。"
	if refs.size()!=raw.entries.size(): return "欢迎词存在遗漏引用。"
	for id: String in refs:
		if not id.begins_with("base.dialogue.") or segments.has(id) or not raw.entries.get(id) is Dictionary: return "欢迎词ID无效。"
		var entry: Dictionary = raw.entries[id]
		if not DialogueConditions.error(entry).is_empty(): return "欢迎词条件无效。"
		if entry.has("archive_topic") and (not entry.archive_topic is String or not segments.values().any(func(segment): return segment.topic==entry.archive_topic and segment.topic!="welcome")): return "欢迎归档话题无效。"
		if entry.has("followup") and (not entry.followup is String or entry.followup==id or not raw.get("once",[]).any(func(item): return item.entry==entry.followup)): return "欢迎后续引用无效。"
		if not entry.get("lines") is Array or entry.lines.is_empty(): return "欢迎台词缺失。"
		for line: Variant in entry.lines:
			if not line is Dictionary or line.get("speaker") not in ["npc","player"] or not line.get("text") is String or line.text.strip_edges().is_empty() or line.text.length()>1000: return "欢迎台词无效。"
	return ""

static func journal_error(record: Dictionary, config: Dictionary) -> String:
	if not valid_record(record): return "欢迎存档无效。"
	if config.is_empty(): return "欢迎词配置已缺失。"
	for key in ["last","active"]:
		if not record[key].is_empty() and not config.entries.has(record[key]): return "欢迎存档引用无效。"
	if record.active.is_empty():
		if int(record.seen)!=0: return "欢迎进度无效。"
	elif int(record.seen)<1 or int(record.seen)>config.entries[record.active].lines.size(): return "欢迎进度无效。"
	if int(record.daily_turn)>=maxi(1,int(config.close_interval)) or int(record.ordinary_index)>=config.ordinary.size() or int(record.close_index)>=maxi(1,config.close.size()): return "欢迎轮换位置无效。"
	for id: String in record.get("once_done",[]):
		if not config.get("once",[]).any(func(entry): return entry.entry==id): return "特殊欢迎存档无效。"
	for id: String in record.get("once_seen",{}):
		if not config.get("once",[]).any(func(entry): return entry.entry==id) or int(record.once_seen[id])>config.entries[id].lines.size(): return "特殊欢迎进度无效。"
	if not record.phase.is_empty() and not config.phases.any(func(phase): return phase.id==record.phase): return "欢迎剧情阶段无效。"
	return ""

static func record(npc: Dictionary) -> Dictionary:
	if not npc.has("greeting"): npc.greeting = initial()
	return npc.greeting

static func start(npc: Dictionary, id: String) -> void:
	var greeting := record(npc)
	greeting.active = id
	greeting.last = id
	greeting.seen = 1

static func arrive(narrative: Dictionary, library: NpcDialogueLibrary, context: Dictionary) -> void:
	var config: Dictionary = library.definition.get("greetings",{})
	if config.is_empty(): return
	var npc: Dictionary = narrative.npcs[library.definition.id]
	var greeting := record(npc)
	var previous_id: String = greeting.active
	var previous_seen: int = greeting.seen
	greeting.active = ""
	greeting.seen = 0
	greeting.pending_treatment = false
	greeting.treatment_used = false
	if not DialogueJournal.welcome_finished(narrative,library): return
	var resources: Dictionary = context.get("resources",{})
	var maxima: Dictionary = context.get("maxima",{})
	if _try_once(narrative,library,context,true,previous_id,previous_seen): return
	for pair in [["hp","injured"],["stamina","tired"]]:
		if not config.has(pair[1]): continue
		if not DialogueConditions.eligible(narrative,config.entries[config[pair[1]]],library.definition.id): continue
		var maximum := float(maxima.get(pair[0],0))
		if maximum>0 and float(resources.get(pair[0],maximum))<maximum*float(config.low_ratio):
			start(npc,config[pair[1]])
			return
	if _try_once(narrative,library,context,false,previous_id,previous_seen): return
	var phase: Dictionary = {}
	for candidate: Dictionary in config.phases:
		if candidate.get("requires_done",[]).all(func(id): return id in npc.done) and candidate.get("requires_clues",[]).all(func(id): return narrative.clues.has(id)):
			phase = candidate
			break
	var phase_id: String = phase.get("id","")
	if greeting.phase!=phase_id:
		greeting.phase = phase_id
		greeting.phase_next = true
	if not phase.is_empty():
		if greeting.phase_next:
			greeting.phase_next = false
			start(npc,phase.entry)
			return
		greeting.phase_next = true
	var next_turn := (int(greeting.daily_turn)+1)%maxi(1,int(config.close_interval))
	var close_turn: bool = int(config.close_interval)>0 and next_turn==0
	var pool: Array = config.close if close_turn else config.ordinary
	var index_key := "close_index" if close_turn else "ordinary_index"
	# Keep stored indexes in the authored pool, so eligibility changes don't shift
	# existing saves or consume additional daily turns.
	var eligible: Array[int] = []
	for step in pool.size():
		var index := (int(greeting[index_key])+step)%pool.size()
		if DialogueConditions.eligible(narrative,config.entries[pool[index]],library.definition.id): eligible.append(index)
	if eligible.is_empty(): return
	var index: int = eligible[0]
	if pool[index]==greeting.last and eligible.size()>1: index = eligible[1]
	greeting.daily_turn = next_turn
	greeting[index_key] = (index+1)%pool.size()
	start(npc,pool[index])

static func _try_once(narrative: Dictionary, library: NpcDialogueLibrary, context: Dictionary, resource_only: bool, previous_id: String, previous_seen: int) -> bool:
	var config: Dictionary = library.definition.greetings
	var npc: Dictionary = narrative.npcs[library.definition.id]
	var greeting: Dictionary = npc.greeting
	for entry: Dictionary in config.get("once",[]):
		if entry.has("low_resource")!=resource_only or entry.entry in greeting.get("once_done",[]): continue
		if not DialogueConditions.eligible(narrative,entry,library.definition.id): continue
		if resource_only:
			var maximum := float(context.get("maxima",{}).get(entry.low_resource,0))
			if maximum<=0 or float(context.get("resources",{}).get(entry.low_resource,maximum))>=maximum*float(config.low_ratio): continue
		start(npc,entry.entry)
		greeting.seen = int(greeting.get("once_seen",{}).get(entry.entry,previous_seen if previous_id==entry.entry else 1))
		_finish_once(narrative,library)
		return true
	return false

static func queue_treatment(narrative: Dictionary, library: NpcDialogueLibrary) -> void:
	if library==null or not library.definition.get("greetings",{}).has("treated"): return
	var npc: Dictionary = narrative.npcs.get(library.definition.id,{})
	if npc.is_empty(): return
	var greeting := record(npc)
	if not greeting.treatment_used: greeting.pending_treatment = true

static func after_treatment(narrative: Dictionary, library: NpcDialogueLibrary) -> void:
	var npc: Dictionary = narrative.npcs.get(library.definition.id,{})
	if npc.is_empty() or not npc.has("greeting") or library.definition.welcome not in npc.done: return
	var greeting: Dictionary = npc.greeting
	if not greeting.pending_treatment: return
	greeting.pending_treatment = false
	greeting.treatment_used = true
	start(npc,library.definition.greetings.treated)

static func reading(npc: Dictionary, library: NpcDialogueLibrary) -> bool:
	var greeting: Dictionary = npc.get("greeting",{})
	return not greeting.get("active","").is_empty() and int(greeting.seen)<library.definition.greetings.entries[greeting.active].lines.size()

static func advance(narrative: Dictionary, library: NpcDialogueLibrary) -> bool:
	var npc: Dictionary = narrative.npcs[library.definition.id]
	var greeting: Dictionary = npc.get("greeting",{})
	if greeting.get("pending_treatment",false) and library.definition.welcome in npc.done:
		after_treatment(narrative,library)
		return true
	if greeting.get("active","").is_empty(): return false
	if not reading(npc,library) and not followup(narrative,library).is_empty():
		start(npc,followup(narrative,library))
	elif reading(npc,library): greeting.seen = int(greeting.seen)+1
	_finish_once(narrative,library)
	return true

static func _finish_once(narrative: Dictionary, library: NpcDialogueLibrary) -> void:
	var npc: Dictionary = narrative.npcs[library.definition.id]
	var greeting: Dictionary = npc.greeting
	if not library.definition.greetings.get("once",[]).any(func(entry): return entry.entry==greeting.active): return
	if not greeting.has("once_seen"): greeting.once_seen = {}
	greeting.once_seen[greeting.active] = greeting.seen
	if reading(npc,library): return
	if not greeting.has("once_done"): greeting.once_done = []
	if greeting.active not in greeting.once_done:
		greeting.once_done.append(greeting.active)
		DialogueConditions.apply_flags(narrative,library.definition.greetings.entries[greeting.active].get("set_flags",[]))
		DialogueConditions.apply_facts(narrative,library.definition.greetings.entries[greeting.active].get("set_facts",[]))

static func apply_view(result: Dictionary, narrative: Dictionary, library: NpcDialogueLibrary) -> void:
	var npc: Dictionary = narrative.npcs[library.definition.id]
	var greeting: Dictionary = npc.get("greeting",{})
	var history: Array = []
	for entry: Dictionary in library.definition.get("greetings",{}).get("once",[]):
		var content: Dictionary = library.definition.greetings.entries[entry.entry]
		if content.get("archive_topic","")==result.selected:
			for line: Dictionary in content.lines.slice(0,int(greeting.get("once_seen",{}).get(entry.entry,0))):
				history.append({"speaker":line.speaker,"text":DialogueJournal.render_text(line.text,narrative),"segment_id":entry.entry})
	history.append_array(result.rows)
	result.rows = history
	if not greeting.get("active","").is_empty():
		result.selected = "greeting"
		result.rows = []
		for line: Dictionary in library.definition.greetings.entries[greeting.active].lines.slice(0,int(greeting.seen)):
			result.rows.append({"speaker":line.speaker,"text":DialogueJournal.render_text(line.text,narrative),"segment_id":greeting.active})
		result.can_continue = reading(npc,library)
	if greeting.get("pending_treatment",false) and library.definition.welcome in npc.done: result.can_continue = true
	if not followup(narrative,library).is_empty(): result.can_continue = true
	if reading(npc,library) or greeting.get("pending_treatment",false) or not followup(narrative,library).is_empty(): result.topics = []

# Explicitly authored once-only sequences (for example a missing introduction
# followed by thanks) continue on a fresh click, before the topic gate opens.
static func followup(narrative: Dictionary, library: NpcDialogueLibrary) -> String:
	var npc: Dictionary = narrative.npcs[library.definition.id]
	var greeting: Dictionary = npc.get("greeting",{})
	var active: String = greeting.get("active","")
	if active.is_empty() or reading(npc,library): return ""
	var id: String = library.definition.get("greetings",{}).get("entries",{}).get(active,{}).get("followup","")
	if id.is_empty() or id in greeting.get("once_done",[]): return ""
	for entry: Dictionary in library.definition.greetings.get("once",[]):
		if entry.entry==id and DialogueConditions.eligible(narrative,entry,library.definition.id): return id
	return ""
