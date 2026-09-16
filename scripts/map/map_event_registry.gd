class_name MapEventRegistry
extends RefCounted

var events: Dictionary = {}
var by_point: Dictionary = {}

func load_files(paths: Array, point_ids: Array) -> String:
	var definitions: Array = []
	for path in paths:
		if not path is String or not FileAccess.file_exists(path):
			return "地图事件文件不存在。"
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not raw is Dictionary:
			return "地图事件JSON无效：" + path
		definitions.append(raw)
	return configure(definitions, point_ids)

func configure(definitions: Array, point_ids: Array) -> String:
	var loaded: Dictionary = {}
	var point_index: Dictionary = {}
	for raw in definitions:
		if not raw is Dictionary or not raw.has_all(["id", "type", "point_id", "speaker_id", "lines", "presentation"]):
			return "地图事件字段不完整。"
		if not raw.id is String or not raw.id.begins_with("base.map_event.") or loaded.has(raw.id):
			return "地图事件ID无效或重复。"
		if raw.type != "dialogue" or raw.point_id not in point_ids or point_index.has(raw.point_id):
			return "地图事件类型、节点或节点绑定无效。"
		if not raw.speaker_id is String or raw.speaker_id.is_empty():
			return "地图对话说话者无效。"
		if not raw.lines is Array or raw.lines.is_empty():
			return "地图对话内容不能为空。"
		for line in raw.lines:
			if not line is String or line.strip_edges().is_empty():
				return "地图对话段落无效。"
		var speakers: Variant = raw.get("speakers", {})
		if not speakers is Dictionary:
			return "地图对话说话者表无效。"
		for speaker_id in speakers:
			var speaker: Variant = speakers[speaker_id]
			if not speaker_id is String or speaker_id.is_empty() or not speaker is Dictionary or not speaker.has_all(["portrait", "portrait_region"]):
				return "地图对话说话者配置无效。"
			if not speaker.portrait is String or not ResourceLoader.exists(speaker.portrait, "Texture2D") or not _valid_rect(speaker.portrait_region):
				return "地图对话说话者头像无效。"
		var line_speakers: Variant = raw.get("line_speakers", [])
		if not line_speakers is Array or (not line_speakers.is_empty() and line_speakers.size() != raw.lines.size()):
			return "地图对话段落与说话者数量不一致。"
		for speaker_id in line_speakers:
			if not speaker_id is String or (speaker_id != raw.speaker_id and not speakers.has(speaker_id)):
				return "地图对话引用了未知说话者。"
		var art: Variant = raw.presentation
		if not art is Dictionary or not art.has_all(["background", "background_region", "portrait", "portrait_region", "portrait_slot", "portrait_max_size", "text_rect"]):
			return "地图对话美术配置不完整。"
		for key in ["background", "portrait"]:
			if not art[key] is String or not ResourceLoader.exists(art[key], "Texture2D"):
				return "地图对话图片不存在：" + key
		for key in ["background_region", "portrait_region", "portrait_slot", "text_rect"]:
			var rect: Variant = art[key]
			if not _valid_rect(rect):
				return "地图对话区域格式无效：" + key
		if art.has("illustration"):
			var illustration: Variant = art.illustration
			if not illustration is Dictionary or not illustration.has_all(["frame", "image", "image_slot"]) or not _valid_rect(illustration.image_slot):
				return "地图事件插画配置无效。"
			for key in ["frame", "image"]:
				if not illustration[key] is String or not ResourceLoader.exists(illustration[key], "Texture2D"):
					return "地图事件插画素材不存在：" + key
		if not (art.portrait_max_size is float or art.portrait_max_size is int) or not is_finite(float(art.portrait_max_size)) or art.portrait_max_size <= 0:
			return "地图对话头像尺寸无效。"
		var background_size := Vector2(art.background_region[2], art.background_region[3])
		for key in ["portrait_slot", "text_rect"]:
			var rect: Array = art[key]
			if not Rect2(Vector2.ZERO, background_size).encloses(Rect2(rect[0], rect[1], rect[2], rect[3])):
				return "地图对话内容超出背景：" + key
		if art.portrait_max_size > minf(art.portrait_slot[2], art.portrait_slot[3]):
			return "地图对话头像超出配置窗口。"
		loaded[raw.id] = raw.duplicate(true)
		point_index[raw.point_id] = raw.id
	for event: Dictionary in loaded.values():
		var requirements: Variant = event.get("requires_completed", [])
		if not requirements is Array:
			return "地图事件前置条件必须为列表。"
		for prerequisite in requirements:
			if not prerequisite is String or not loaded.has(prerequisite) or prerequisite == event.id:
				return "地图事件引用了无效前置条件。"
	var visited: Dictionary = {}
	for event_id in loaded:
		if _has_cycle(event_id, loaded, visited):
			return "地图事件前置条件存在循环。"
	events = loaded
	by_point = point_index
	return ""

func _valid_rect(rect: Variant) -> bool:
	if not rect is Array or rect.size() != 4:
		return false
	for value in rect:
		if not (value is int or value is float) or not is_finite(float(value)) or value < 0:
			return false
	return rect[2] > 0 and rect[3] > 0

func _has_cycle(event_id: String, definitions: Dictionary, visited: Dictionary) -> bool:
	if visited.get(event_id, 0) == 1:
		return true
	if visited.get(event_id, 0) == 2:
		return false
	visited[event_id] = 1
	for prerequisite in definitions[event_id].get("requires_completed", []):
		if _has_cycle(prerequisite, definitions, visited):
			return true
	visited[event_id] = 2
	return false
