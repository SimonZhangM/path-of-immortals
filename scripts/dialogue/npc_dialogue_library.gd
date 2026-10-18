class_name NpcDialogueLibrary
extends RefCounted

var definition: Dictionary = {}
var segments: Dictionary = {}
var topics: Dictionary = {}

func load_file(path: String) -> String:
	if not FileAccess.file_exists(path): return "对话文件不存在。"
	return configure(JSON.parse_string(FileAccess.get_file_as_string(path)))

func configure(raw: Variant) -> String:
	if not raw is Dictionary or not raw.get("id") is String or not raw.id.begins_with("base.npc."): return "对话人物ID无效。"
	for key in ["name","portrait","portrait_frame","welcome"]:
		if not raw.get(key) is String or raw[key].is_empty(): return "对话人物配置缺失："+key
	for key in ["portrait","portrait_frame"]:
		if not ResourceLoader.exists(raw[key],"Texture2D"): return "对话头像素材不存在："+key
	if raw.has("portrait_region"):
		var region: Variant = raw.portrait_region
		if not region is Array or region.size()!=4: return "头像区域无效。"
		for value: Variant in region:
			if not ContentRegistry._nonnegative_integer(value): return "头像区域无效。"
		var texture: Texture2D = load(raw.portrait)
		if region[2]<=0 or region[3]<=0 or region[0]+region[2]>texture.get_width() or region[1]+region[3]>texture.get_height(): return "头像区域超出图片。"
	if not raw.get("address_rules",[]) is Array: return "人物称呼规则无效。"
	for rule: Variant in raw.get("address_rules",[]):
		if not rule is Dictionary or not rule.get("text") is String or rule.text.is_empty() or not DialogueConditions.error(rule).is_empty(): return "人物称呼规则无效。"
	if not raw.get("segments") is Dictionary or not raw.get("topics") is Array or raw.topics.size()!=3 or not raw.get("clues",{}) is Dictionary: return "对话段落／话题配置无效。"
	var checked_topics := {}
	var references := {raw.welcome:"welcome"}
	for topic: Variant in raw.topics:
		if not topic is Dictionary or not topic.get("id") is String or topic.id.is_empty() or topic.id=="welcome" or checked_topics.has(topic.id) or not topic.get("label") is String or topic.label.is_empty(): return "对话话题无效。"
		for key in ["revisit_interval_days","revisit_batch_size"]:
			if topic.has(key) and not WorldCalendar.integer_between(topic[key],1,10000): return "回访周期或批量无效。"
		for group in ["initial","revisits","story"]:
			if not topic.get(group) is Array: return "对话话题段落列表无效。"
			for id: Variant in topic[group]:
				if not id is String or references.has(id): return "对话段落重复归属。"
				references[id] = topic.id
		if topic.has("revisit_added_revision") and (not WorldCalendar.integer_between(topic.revisit_added_revision,3,3) or not WorldCalendar.integer_between(raw.get("content_revision",1),3,3) or topic.revisits.is_empty()): return "新增回访版本无效。"
		checked_topics[topic.id] = topic
	if references.size()!=raw.segments.size(): return "对话段落存在遗漏引用。"
	for id: Variant in references:
		if not id.begins_with("base.dialogue.") or not raw.segments.get(id) is Dictionary: return "对话段落引用不存在。"
		var segment: Dictionary = raw.segments[id]
		var condition_error := DialogueConditions.error(segment)
		if not condition_error.is_empty(): return condition_error
		if not segment.get("variants",[]) is Array: return "对话分支列表无效。"
		var variant_ids := {}
		for variant: Variant in segment.get("variants",[]):
			if not variant is Dictionary or not variant.get("id") is String or variant.id.is_empty() or variant_ids.has(variant.id) or not variant.get("lines") is Array or variant.lines.is_empty(): return "对话分支无效。"
			variant_ids[variant.id] = true
			condition_error = DialogueConditions.error(variant)
			if not condition_error.is_empty(): return condition_error
			for line: Variant in variant.lines:
				if not line is Dictionary or line.get("speaker") not in ["player","npc"] or not line.get("text") is String or line.text.strip_edges().is_empty() or line.text.length()>1000: return "对话分支台词无效。"
		if segment.get("topic")!=references[id] or not segment.get("label") is String or segment.label.is_empty() or not segment.get("lines") is Array or segment.lines.is_empty(): return "对话段落配置无效。"
		for line: Variant in segment.lines:
			if not line is Dictionary or line.get("speaker") not in ["player","npc"] or not line.get("text") is String or line.text.strip_edges().is_empty() or line.text.length()>1000: return "对话台词无效。"
		for group in ["requires_flags","clues"]:
			if not segment.get(group,[]) is Array: return "对话条件或线索无效。"
			for value: Variant in segment.get(group,[]):
				if not value is String or not value.begins_with("base.story." if group=="requires_flags" else "base.clue."): return "对话条件或线索ID无效。"
		for clue: String in segment.get("clues",[]):
			if not raw.get("clues",{}).get(clue) is String: return "对话线索缺少名称。"
		if not segment.get("requires_points",[]) is Array: return "对话探索条件无效。"
		for point: Variant in segment.get("requires_points",[]):
			if not point is Dictionary or not point.get("map_id") is String or not point.get("point_id") is String or not point.point_id.begins_with(point.map_id+".point."): return "对话探索条件无效。"
	var greeting_error := DialogueGreetings.configuration_error(raw.get("greetings",{}),raw.segments,raw.get("clues",{}))
	if not greeting_error.is_empty(): return greeting_error
	if not WorldCalendar.integer_between(raw.get("content_revision",1),1,3): return "对话内容版本无效。"
	for key in ["legacy_seen_maps","legacy_greeting_seen_maps"]:
		if not raw.get(key,{}) is Dictionary: return "旧对话映射无效。"
		var entries: Dictionary = raw.segments if key=="legacy_seen_maps" else raw.get("greetings",{}).get("entries",{})
		for id: Variant in raw.get(key,{}):
			var mapping: Variant = raw[key][id]
			if raw.get("content_revision",1)<2 or not entries.has(id) or not mapping is Array or mapping.is_empty(): return "旧对话映射引用无效。"
			var last := 0
			var count: int = entries[id].lines.size()
			for i in mapping.size():
				if not WorldCalendar.integer_between(mapping[i],1,count) or int(mapping[i])<last or (i<mapping.size()-1 and int(mapping[i])==count): return "旧对话映射顺序无效。"
				last = int(mapping[i])
			if last!=count: return "旧对话完成映射无效。"
	definition = raw.duplicate(true)
	segments = definition.segments
	topics.clear()
	for topic: Dictionary in definition.topics: topics[topic.id] = topic
	return ""

func journal_error(journal: Dictionary) -> String:
	if int(journal.get("content_revision",1))!=int(definition.get("content_revision",1)): return "对话记录需要更新内容版本。"
	for id: String in journal.get("variants",{}):
		if not segments.has(id) or not journal.seen.has(id) or not segments[id].get("variants",[]).any(func(v): return v.id==journal.variants[id]): return "对话分支存档无效。"
	for id: String in journal.get("addresses",{}):
		if not journal.seen.has(id) or journal.addresses[id].size()!=int(journal.seen[id]): return "逐句称呼记录无效。"
	if journal.has("greeting"):
		var error := DialogueGreetings.journal_error(journal.greeting,definition.get("greetings",{}))
		if not error.is_empty(): return error
	for id: String in journal.seen:
		if not segments.has(id) or int(journal.seen[id])>segment_for(journal,id).lines.size(): return "对话存档引用无效台词。"
		if (id in journal.done)!=(int(journal.seen[id])==segment_for(journal,id).lines.size()): return "对话完成记录不一致。"
	for topic: String in journal.cursor:
		var id: String = journal.cursor[topic]
		if not segments.has(id) or segments[id].topic!=topic or not journal.seen.has(id): return "对话段落游标无效。"
	if journal.selected!="welcome" and not topics.has(journal.selected): return "对话选中话题无效。"
	for topic: String in journal.visits:
		if not topics.has(topic) or int(journal.visits[topic].unlocked)>topics[topic].revisits.size(): return "回访进度无效。"
	for topic: Dictionary in topics.values():
		if not topic.revisits.is_empty() and topic.initial.all(func(id): return id in journal.done) and not journal.visits.has(topic.id): return "回访日期缺失。"
	return ""

# Migration only changes counters in a candidate journal. Completed and unread
# stages, clue ownership, cursors, visit cadence and other NPCs are preserved.
func upgrade_journal(journal: Dictionary, day := 0, story_revision := 0) -> String:
	var revision := int(journal.get("content_revision",1))
	var current := int(definition.get("content_revision",1))
	if revision==current: return ""
	if revision<1 or revision>current: return "对话内容版本无法迁移。"
	var updated := journal.duplicate(true)
	if revision==1:
		for id: String in definition.get("legacy_seen_maps",{}):
			if not updated.seen.has(id): continue
			var mapping: Array = definition.legacy_seen_maps[id]
			var count := int(updated.seen[id])
			if count<1 or count>mapping.size() or (id in updated.done)!=(count==mapping.size()): return "旧对话进度无效。"
			updated.seen[id] = int(mapping[count-1])
		var greeting: Dictionary = updated.get("greeting",{})
		var active: String = greeting.get("active","")
		if definition.get("legacy_greeting_seen_maps",{}).has(active):
			var mapping: Array = definition.legacy_greeting_seen_maps[active]
			var count := int(greeting.seen)
			if count<1 or count>mapping.size(): return "旧欢迎进度无效。"
			greeting.seen = int(mapping[count-1])
	# Only explicitly introduced revisit tracks receive a new clock. Existing
	# unlocked batches and timestamps survive changes to the ordinary cadence.
	for topic: Dictionary in topics.values():
		if revision>=int(topic.get("revisit_added_revision",0)) or updated.visits.has(topic.id): continue
		if topic.initial.all(func(id):return id in updated.done):
			updated.visits[topic.id] = {"unlocked":0,"last_day":day,"story_revision":story_revision}
	updated.content_revision = current
	var error := journal_error(updated)
	if not error.is_empty(): return error
	journal.assign(updated)
	return ""

func segment_for(journal: Dictionary, id: String) -> Dictionary:
	var segment: Dictionary = segments[id]
	var selected: String = journal.get("variants",{}).get(id,"")
	for variant: Dictionary in segment.get("variants",[]):
		if variant.id==selected:
			var result := segment.duplicate(true)
			result.lines = variant.lines
			result.set_flags = variant.get("set_flags",[])
			result.set_facts = variant.get("set_facts",segment.get("set_facts",[]))
			return result
	return segment
