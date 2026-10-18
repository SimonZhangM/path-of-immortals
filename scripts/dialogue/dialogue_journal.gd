class_name DialogueJournal
extends RefCounted

# Pure serializable story state. No scene, inventory or wall-clock dependency.
static func initial() -> Dictionary:
	return {"version":1,"identity":{"surname":"张","given_name":"辰宇"},"flags":{},"story_revision":0,"clues":{},"npcs":{}}

static func valid_name(value: Variant) -> bool:
	if not value is Dictionary or not value.get("surname") is String or not value.get("given_name") is String: return false
	for key in ["surname","given_name"]:
		var text: String = value[key]
		if text.strip_edges()!=text or text.is_empty() or text.length()>12: return false
		for forbidden in ["\n","\r","\t","{","}"]:
			if forbidden in text: return false
	return true

static func valid_record(raw: Variant) -> bool:
	if not raw is Dictionary or raw.get("version")!=1 or not valid_name(raw.get("identity")): return false
	if not WorldCalendar.integer_between(raw.get("story_revision"),0,1000000000): return false
	for key in ["flags","clues","npcs"]:
		if not raw.get(key) is Dictionary: return false
	for id: Variant in raw.flags:
		if not id is String or not id.begins_with("base.story.") or not raw.flags[id] is bool: return false
	for id: Variant in raw.clues:
		if not id is String or not id.begins_with("base.clue.") or not raw.clues[id] is String: return false
	for id: Variant in raw.npcs:
		if not id is String or not id.begins_with("base.npc.") or not raw.npcs[id] is Dictionary: return false
		var npc: Dictionary = raw.npcs[id]
		if not WorldCalendar.integer_between(npc.get("content_revision",1),1,10000): return false
		if not npc.get("variants",{}) is Dictionary: return false
		if not npc.get("addresses",{}) is Dictionary: return false
		for sid: Variant in npc.get("addresses",{}):
			if not sid is String or not npc.addresses[sid] is Array: return false
			for address: Variant in npc.addresses[sid]:
				if not address is String or address.length()>100: return false
		for sid: Variant in npc.get("variants",{}):
			if not sid is String or not npc.variants[sid] is String: return false
		if npc.has("greeting") and not DialogueGreetings.valid_record(npc.greeting): return false
		if not npc.get("selected") is String: return false
		for key in ["seen","cursor","visits"]:
			if not npc.get(key) is Dictionary: return false
		for key in ["done","order"]:
			if not npc.get(key) is Array: return false
			var unique := {}
			for sid: Variant in npc[key]:
				if not sid is String or not npc.seen.has(sid) or unique.has(sid): return false
				unique[sid] = true
		if npc.order.size()!=npc.seen.size(): return false
		for sid: Variant in npc.seen:
			if not sid is String or not sid.begins_with("base.dialogue.") or not WorldCalendar.integer_between(npc.seen[sid],1,10000): return false
		for topic: Variant in npc.cursor:
			if not topic is String or not npc.cursor[topic] is String or not npc.seen.has(npc.cursor[topic]): return false
		for topic: Variant in npc.visits:
			var visit: Variant = npc.visits[topic]
			if not topic is String or not visit is Dictionary or not WorldCalendar.integer_between(visit.get("unlocked"),0,10000) or not WorldCalendar.integer_between(visit.get("last_day"),-1,WorldCalendar.MAX_DAY) or not WorldCalendar.integer_between(visit.get("story_revision"),-1,1000000000): return false
	return true

static func full_name(narrative: Dictionary) -> String:
	return narrative.identity.surname+narrative.identity.given_name

static func normalized(raw: Dictionary) -> Dictionary:
	var result := raw.duplicate(true)
	result.version = int(result.version)
	result.story_revision = int(result.story_revision)
	for npc: Dictionary in result.npcs.values():
		if npc.has("content_revision"): npc.content_revision = int(npc.content_revision)
		if npc.has("greeting"):
			for key in ["seen","daily_turn","ordinary_index","close_index"]: npc.greeting[key] = int(npc.greeting[key])
			for id: String in npc.greeting.get("once_seen",{}): npc.greeting.once_seen[id] = int(npc.greeting.once_seen[id])
		for id: String in npc.seen: npc.seen[id] = int(npc.seen[id])
		for visit: Dictionary in npc.visits.values():
			for key in ["unlocked","last_day","story_revision"]: visit[key] = int(visit[key])
	return result

static func render_text(text: String, narrative: Dictionary) -> String:
	var given: String = narrative.identity.given_name
	var familiar := "阿"+given if given.length()==1 else given
	# Legacy authored literals are normalized too; player labels never use this path.
	return text.replace("张辰宇","{player.full_name}").replace("辰宇","{player.familiar_name}").replace("{player.full_name}",full_name(narrative)).replace("{player.surname}",narrative.identity.surname).replace("{player.given_name}",given).replace("{player.familiar_name}",familiar)

static func _eligible(narrative: Dictionary, segment: Dictionary, explored: Dictionary, npc_id: String) -> bool:
	if not DialogueConditions.eligible(narrative,segment,npc_id): return false
	for point: Dictionary in segment.get("requires_points",[]):
		if point.point_id not in explored.get(point.map_id,[]): return false
	return true

# Retiring unread material never marks it read or removes its earlier history.
static func retired(narrative: Dictionary, segment: Dictionary) -> bool:
	return segment.get("retire_flags",[]).any(func(flag): return narrative.flags.get(flag,false))

static func welcome_finished(narrative: Dictionary, library: NpcDialogueLibrary) -> bool:
	return library.definition.welcome in narrative.npcs[library.definition.id].done or retired(narrative,library.segments[library.definition.welcome])

static func address(narrative: Dictionary, library: NpcDialogueLibrary) -> String:
	for rule: Dictionary in library.definition.get("address_rules",[]):
		if DialogueConditions.eligible(narrative,rule,library.definition.id): return rule.text
	return ""

static func next_segment(narrative: Dictionary, library: NpcDialogueLibrary, topic_id: String, explored: Dictionary) -> String:
	var npc: Dictionary = narrative.npcs[library.definition.id]
	if not welcome_finished(narrative,library): return ""
	var topic: Dictionary = library.topics[topic_id]
	# A story branch takes priority without discarding any interrupted ordinary line.
	for id: String in topic.story:
		if retired(narrative,library.segments[id]): continue
		if id not in npc.done and (npc.seen.has(id) or _eligible(narrative,library.segments[id],explored,library.definition.id)): return id
	for id: String in topic.initial:
		if retired(narrative,library.segments[id]): continue
		if id not in npc.done:
			return id if npc.seen.has(id) or _eligible(narrative,library.segments[id],explored,library.definition.id) else ""
	var unlocked: int = int(npc.visits.get(topic_id,{}).get("unlocked",0))
	for id: String in topic.revisits.slice(0,unlocked):
		if not retired(narrative,library.segments[id]) and id not in npc.done and (npc.seen.has(id) or _eligible(narrative,library.segments[id],explored,library.definition.id)): return id
	return ""

static func visit(narrative: Dictionary, library: NpcDialogueLibrary, day: int) -> String:
	var id: String = library.definition.id
	if not narrative.npcs.has(id):
		narrative.npcs[id] = {"seen":{},"done":[],"order":[],"cursor":{},"selected":"welcome","visits":{}}
		if library.definition.has("content_revision"): narrative.npcs[id].content_revision = int(library.definition.content_revision)
	var npc: Dictionary = narrative.npcs[id]
	var migration_error := library.upgrade_journal(npc,day,int(narrative.story_revision))
	if not migration_error.is_empty(): return migration_error
	var error := library.journal_error(npc)
	if not error.is_empty(): return error
	if not npc.seen.has(library.definition.welcome) and not retired(narrative,library.segments[library.definition.welcome]): _reveal(narrative,library,library.definition.welcome,day)
	for topic: Dictionary in library.topics.values():
		if topic.revisits.is_empty() or not topic.initial.all(func(sid): return sid in npc.done): continue
		var entry: Dictionary = npc.visits[topic.id]
		var count := int(entry.unlocked)
		var pending: bool = topic.revisits.slice(0,count).any(func(sid): return sid not in npc.done)
		var elapsed := day-int(entry.last_day)>=int(topic.get("revisit_interval_days",1))
		var story_changed: bool = not topic.has("revisit_interval_days") and int(narrative.story_revision)>int(entry.story_revision)
		if not pending and count<topic.revisits.size() and (elapsed or story_changed):
			entry.unlocked = mini(count+int(topic.get("revisit_batch_size",1)),topic.revisits.size())
			entry.last_day = day
			entry.story_revision = narrative.story_revision
	return ""

static func select(narrative: Dictionary, library: NpcDialogueLibrary, topic: String, day: int, explored: Dictionary) -> String:
	if not library.topics.has(topic): return "对话话题不存在。"
	var npc: Dictionary = narrative.npcs[library.definition.id]
	if not welcome_finished(narrative,library): return "请先听完招呼。"
	if DialogueGreetings.reading(npc,library) or not DialogueGreetings.followup(narrative,library).is_empty() or npc.get("greeting",{}).get("pending_treatment",false): return "请先听完招呼。"
	if npc.has("greeting"):
		npc.greeting.active = ""
		npc.greeting.seen = 0
	npc.selected = topic
	var id := next_segment(narrative,library,topic,explored)
	if not id.is_empty():
		npc.cursor[topic] = id
		if not npc.seen.has(id): _reveal(narrative,library,id,day)
	return ""

static func advance(narrative: Dictionary, library: NpcDialogueLibrary, day: int) -> String:
	if DialogueGreetings.advance(narrative,library): return ""
	var npc: Dictionary = narrative.npcs[library.definition.id]
	var id: String = npc.cursor.get(npc.selected,"")
	if id.is_empty() or id in npc.done or retired(narrative,library.segments[id]): return ""
	_reveal(narrative,library,id,day)
	return ""

static func _reveal(narrative: Dictionary, library: NpcDialogueLibrary, id: String, day: int) -> void:
	var npc: Dictionary = narrative.npcs[library.definition.id]
	if id in npc.done: return
	if not npc.seen.has(id):
		for variant: Dictionary in library.segments[id].get("variants",[]):
			if DialogueConditions.eligible(narrative,variant,library.definition.id):
				if not npc.has("variants"): npc.variants = {}
				npc.variants[id] = variant.id
				break
	var segment: Dictionary = library.segment_for(npc,id)
	if not npc.seen.has(id): npc.order.append(id)
	if library.definition.has("address_rules"):
		if not npc.has("addresses"): npc.addresses = {}
		if not npc.addresses.has(id): npc.addresses[id] = []
		npc.addresses[id].append(address(narrative,library))
	npc.cursor[segment.topic] = id
	npc.seen[id] = int(npc.seen.get(id,0))+1
	if int(npc.seen[id])<segment.lines.size(): return
	npc.done.append(id)
	DialogueConditions.apply_flags(narrative,segment.get("set_flags",[]))
	DialogueConditions.apply_facts(narrative,segment.get("set_facts",[]))
	for clue: String in segment.get("clues",[]): narrative.clues[clue] = library.definition.clues[clue]
	if not library.topics.has(segment.topic): return
	var topic: Dictionary = library.topics[segment.topic]
	if not topic.revisits.is_empty() and topic.initial.all(func(sid): return sid in npc.done):
		if not npc.visits.has(topic.id): npc.visits[topic.id] = {"unlocked":0,"last_day":day,"story_revision":narrative.story_revision}
		elif id in topic.revisits and (not topic.has("revisit_interval_days") or topic.revisits.slice(0,int(npc.visits[topic.id].unlocked)).all(func(sid): return sid in npc.done)):
			npc.visits[topic.id].last_day = day
			npc.visits[topic.id].story_revision = narrative.story_revision

static func view(narrative: Dictionary, library: NpcDialogueLibrary, explored: Dictionary) -> Dictionary:
	var npc: Dictionary = narrative.npcs.get(library.definition.id,{})
	if npc.is_empty(): return {"rows":[],"topics":[],"can_continue":false,"selected":"welcome"}
	var result := {"rows":[],"topics":[],"can_continue":false,"selected":npc.selected}
	for id: String in npc.order:
		if library.segments[id].topic!=npc.selected: continue
		var lines: Array = library.segment_for(npc,id).lines
		for i in int(npc.seen[id]):
			var line: Dictionary = lines[i]
			var saved_address: String = npc.get("addresses",{}).get(id,[])[i] if npc.get("addresses",{}).has(id) else ""
			result.rows.append({"speaker":line.speaker,"text":render_text(line.text.replace("{npc.address}",saved_address),narrative),"segment_id":id})
	var cursor: String = npc.cursor.get(npc.selected,"")
	result.can_continue = not cursor.is_empty() and cursor not in npc.done and not retired(narrative,library.segments[cursor])
	if welcome_finished(narrative,library):
		for topic: Dictionary in library.topics.values():
			var next := next_segment(narrative,library,topic.id,explored)
			result.topics.append({"id":topic.id,"label":topic.label if next.is_empty() else library.segments[next].label,"new":not next.is_empty() and not npc.seen.has(next),"history":next.is_empty()})
	DialogueGreetings.apply_view(result,narrative,library)
	return result
