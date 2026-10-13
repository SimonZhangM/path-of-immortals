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
	if not raw.get("segments") is Dictionary or not raw.get("topics") is Array or raw.topics.size()!=3 or not raw.get("clues",{}) is Dictionary: return "对话段落／话题配置无效。"
	var checked_topics := {}
	var references := {raw.welcome:"welcome"}
	for topic: Variant in raw.topics:
		if not topic is Dictionary or not topic.get("id") is String or topic.id.is_empty() or topic.id=="welcome" or checked_topics.has(topic.id) or not topic.get("label") is String or topic.label.is_empty(): return "对话话题无效。"
		for group in ["initial","revisits","story"]:
			if not topic.get(group) is Array: return "对话话题段落列表无效。"
			for id: Variant in topic[group]:
				if not id is String or references.has(id): return "对话段落重复归属。"
				references[id] = topic.id
		checked_topics[topic.id] = topic
	if references.size()!=raw.segments.size(): return "对话段落存在遗漏引用。"
	for id: Variant in references:
		if not id.begins_with("base.dialogue.") or not raw.segments.get(id) is Dictionary: return "对话段落引用不存在。"
		var segment: Dictionary = raw.segments[id]
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
	definition = raw.duplicate(true)
	segments = definition.segments
	topics.clear()
	for topic: Dictionary in definition.topics: topics[topic.id] = topic
	return ""

func journal_error(journal: Dictionary) -> String:
	for id: String in journal.seen:
		if not segments.has(id) or int(journal.seen[id])>segments[id].lines.size(): return "对话存档引用无效台词。"
		if (id in journal.done)!=(int(journal.seen[id])==segments[id].lines.size()): return "对话完成记录不一致。"
	for topic: String in journal.cursor:
		var id: String = journal.cursor[topic]
		if not segments.has(id) or segments[id].topic!=topic or not journal.seen.has(id): return "对话段落游标无效。"
	if journal.selected!="welcome" and not topics.has(journal.selected): return "对话选中话题无效。"
	for topic: String in journal.visits:
		if not topics.has(topic) or int(journal.visits[topic].unlocked)>topics[topic].revisits.size(): return "回访进度无效。"
	for topic: Dictionary in topics.values():
		if not topic.revisits.is_empty() and topic.initial.all(func(id): return id in journal.done) and not journal.visits.has(topic.id): return "回访日期缺失。"
	return ""
