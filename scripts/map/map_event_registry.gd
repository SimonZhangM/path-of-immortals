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
		if not raw is Dictionary or not raw.has_all(["id", "type", "point_id", "presentation"]):
			return "地图事件字段不完整。"
		if not raw.id is String or not raw.id.begins_with("base.map_event.") or loaded.has(raw.id):
			return "地图事件ID无效或重复。"
		if raw.type not in ["dialogue", "encounter", "chest", "gathering", "rest", "shop", "clinic", "inn", "cultivation"] or raw.point_id not in point_ids or point_index.has(raw.point_id):
			return "地图事件类型、节点或节点绑定无效。"
		if raw.get("trigger", "click") not in ["arrival", "click"]:
			return "地图事件触发方式无效。"
		if not raw.get("enabled", true) is bool:
			return "地图事件启用开关必须为布尔值。"
		if not raw.get("story_flags_on_complete",[]) is Array: return "剧情完成标记无效。"
		for flag: Variant in raw.get("story_flags_on_complete",[]):
			if raw.type!="dialogue" or not flag is String or not flag.begins_with("base.story."): return "剧情完成标记引用无效。"
		if raw.type in ["clinic","inn"]:
			if raw.has("treatment"):
				var treatment_error := MapClinicTreatment.configuration_error(raw.treatment)
				if not treatment_error.is_empty(): return treatment_error
			if raw.has("dialogue"):
				if not raw.dialogue is String: return "医馆对话路径无效。"
				var library := NpcDialogueLibrary.new()
				var dialogue_error := library.load_file(raw.dialogue)
				if not dialogue_error.is_empty(): return dialogue_error
			for key in ["title","description","leave_label"]:
				if raw.type=="inn" and key=="description" and raw.get(key) is String: continue
				if not raw.get(key) is String or raw[key].strip_edges().is_empty(): return "医馆文案缺失："+key
			if not raw.presentation is Dictionary: return "医馆展示配置无效。"
			var title_center: Variant = raw.presentation.get("title_center_y",133.0)
			if (not title_center is float and not title_center is int) or not is_finite(float(title_center)) or float(title_center)<100 or float(title_center)>165: return "医馆标题中心位置无效。"
			for key in ["background","illustration","frame"]:
				if not raw.presentation.get(key) is String or not ResourceLoader.exists(raw.presentation[key],"Texture2D"): return "医馆素材不存在："+key
			if raw.presentation.has("treatment_background") and (not raw.presentation.treatment_background is String or not ResourceLoader.exists(raw.presentation.treatment_background,"Texture2D")): return "医馆诊治底图不存在。"
			if raw.type=="inn":
				if raw.has("food_catalog") and (not raw.food_catalog is String or not FileAccess.file_exists(raw.food_catalog)): return "客栈菜品目录不存在。"
				if raw.has("treatment"): return "客栈不可配置医馆诊治。"
				if raw.has("lodging"):
					var lodging_error := MapInnLodging.configuration_error(raw.lodging)
					if not lodging_error.is_empty(): return lodging_error
				for key in ["food_background","lodging_background","conversation_portrait"]:
					if not raw.presentation.get(key) is String or not ResourceLoader.exists(raw.presentation[key],"Texture2D"): return "客栈素材不存在："+key
			loaded[raw.id] = raw.duplicate(true)
			point_index[raw.point_id] = raw.id
			continue
		if raw.type == "shop":
			if not raw.presentation is Dictionary: return "商铺展示配置无效。"
			if raw.presentation.has("conversation_background") and (not raw.presentation.conversation_background is String or not ResourceLoader.exists(raw.presentation.conversation_background,"Texture2D")): return "商铺交谈底图无效。"
			if raw.presentation.has("crafting_background") and (not raw.presentation.crafting_background is String or not ResourceLoader.exists(raw.presentation.crafting_background,"Texture2D")): return "商铺生产分页底图无效。"
			if raw.presentation.has("conversation_portrait") and (not raw.presentation.conversation_portrait is String or not ResourceLoader.exists(raw.presentation.conversation_portrait,"Texture2D")): return "商铺交谈头像无效。"
			if raw.has("dialogue"):
				if not raw.dialogue is String or not raw.presentation.get("conversation_background") is String or not ResourceLoader.exists(raw.presentation.conversation_background,"Texture2D"): return "商铺对话素材无效。"
				var library := NpcDialogueLibrary.new()
				var error := library.load_file(raw.dialogue)
				if not error.is_empty(): return error
			if not raw.get("catalog") is String or not FileAccess.file_exists(raw.catalog): return "商铺目录不存在。"
			var title_center: Variant = raw.presentation.get("title_center_y",133.0)
			if (not title_center is float and not title_center is int) or not is_finite(float(title_center)) or float(title_center)<100 or float(title_center)>165: return "商铺标题中心位置无效。"
			for key in ["background","illustration","frame"]:
				if not raw.presentation.get(key) is String or not ResourceLoader.exists(raw.presentation[key],"Texture2D"): return "商铺素材不存在："+key
			loaded[raw.id] = raw.duplicate(true)
			point_index[raw.point_id] = raw.id
			continue
		if raw.type == "cultivation":
			var error := _validate_cultivation(raw)
			if not error.is_empty(): return error
			loaded[raw.id]=raw.duplicate(true)
			point_index[raw.point_id]=raw.id
			continue
		if raw.type == "rest":
			if not raw.get("allow_food",false) is bool: return "休息进食开关无效。"
			if raw.get("rest_kind") not in ["indoor","outdoor"]: return "休息地点类型无效。"
			for key in ["title","description","note","action_label"]:
				if not raw.get(key) is String or raw[key].strip_edges().is_empty(): return "休息文案缺失："+key
			if not ContentRegistry._positive_integer(raw.get("recovery_percent")) or raw.recovery_percent>100: return "休息恢复比例无效。"
			if not ContentRegistry._positive_integer(raw.get("duration_days")): return "休息耗时无效。"
			if raw.has("warehouse_id") and (not raw.warehouse_id is String or not raw.warehouse_id.begins_with("base.warehouse.") or raw.warehouse_id.trim_prefix("base.warehouse.").is_empty()): return "休息地点仓储标识无效。"
			if not raw.presentation is Dictionary: return "休息展示配置无效。"
			for key in ["background","illustration"]:
				if not raw.presentation.get(key) is String or not ResourceLoader.exists(raw.presentation[key],"Texture2D"): return "休息图片不存在："+key
			loaded[raw.id]=raw.duplicate(true)
			point_index[raw.point_id]=raw.id
			continue
		if raw.type == "gathering":
			if not raw.get("title") is String or raw.title.is_empty() or not raw.presentation is Dictionary: return "采集地点展示配置无效。"
			if not raw.get("item_id") is String or (not raw.item_id.begins_with("base.material.") and raw.item_id != MapGatheringRewards.SPIRIT_STONE_ID): return "采集材料引用无效。"
			if raw.presentation.has("illustration") and (not raw.presentation.illustration is String or (not raw.presentation.illustration.is_empty() and not ResourceLoader.exists(raw.presentation.illustration,"Texture2D"))): return "采集场景图无效。"
			if raw.presentation.has("description") and not raw.presentation.description is String: return "采集地点描述无效。"
			if raw.presentation.has("notes"):
				if not raw.presentation.notes is Dictionary: return "采集方式说明无效。"
				for note: Variant in raw.presentation.notes.values():
					if not note is String: return "采集方式说明无效。"
			if raw.get("reward_prefix") != raw.id.replace("base.map_event.","base.map_reward."): return "采集奖励前缀无效。"
			loaded[raw.id] = raw.duplicate(true)
			point_index[raw.point_id] = raw.id
			continue
		if raw.type == "chest":
			if raw.get("quality") not in ["下品", "凡品"] or not raw.get("reward_id") is String or not raw.reward_id.begins_with("base.map_reward."):
				return "宝箱品级或奖励标识无效。"
			if not raw.presentation is Dictionary: return "宝箱展示配置无效。"
			if raw.has("respawn_days") and not ContentRegistry._positive_integer(raw.respawn_days): return "宝箱重新开启天数无效。"
			if raw.has("observation"):
				if not raw.observation is Dictionary: return "宝箱观察文案无效。"
				for key in ["location_name", "location_description", "chest_name", "description", "result_description"]:
					if not raw.observation.get(key) is String or raw.observation[key].strip_edges().is_empty():
						return "宝箱观察文案缺失：" + key
				for key in ["illustration", "chest_image", "result_illustration"]:
					var picture: Variant = raw.presentation.get(key, "")
					if not picture is String or (not picture.is_empty() and not ResourceLoader.exists(picture, "Texture2D")):
						return "宝箱图片不存在：" + key
			for previous: Dictionary in loaded.values():
				if previous.get("reward_id",previous.get("reward",{}).get("id","")) == raw.reward_id: return "宝箱奖励标识重复。"
			loaded[raw.id] = raw.duplicate(true)
			point_index[raw.point_id] = raw.id
			continue
		if raw.type == "encounter":
			var encounter_error := _validate_encounter(raw)
			if not encounter_error.is_empty():
				return encounter_error
			loaded[raw.id] = raw.duplicate(true)
			point_index[raw.point_id] = raw.id
			continue
		if not raw.has_all(["speaker_id", "lines"]):
			return "地图对话字段不完整。"
		if not raw.speaker_id is String or raw.speaker_id.is_empty():
			return "地图对话说话者无效。"
		if not raw.lines is Array or raw.lines.is_empty():
			return "地图对话内容不能为空。"
		for line in raw.lines:
			if not line is String or line.strip_edges().is_empty():
				return "地图对话段落无效。"
		if raw.has("reward"):
			var reward: Variant = raw.reward
			if not reward is Dictionary or not reward.has_all(["id", "item_id", "quantity", "after_line"]):
				return "剧情奖励配置不完整。"
			if not reward.id is String or not reward.id.begins_with("base.map_reward.") or not reward.item_id is String:
				return "剧情奖励标识无效。"
			if not ContentRegistry._nonnegative_integer(reward.after_line) or reward.after_line >= raw.lines.size() or not ContentRegistry._nonnegative_integer(reward.quantity) or reward.quantity < 1 or reward.quantity > 10000:
				return "剧情奖励时机或数量无效。"
			for previous: Dictionary in loaded.values():
				# Reward IDs still stay unique while test replay is enabled.
				if previous.get("reward", {}).get("id", "") == reward.id:
					return "剧情奖励标识重复。"
			if not reward.get("test_replay_on_restart", false) is bool:
				return "剧情奖励测试重播开关必须为布尔值。"
			if reward.has("test_storage_limit") and (not ContentRegistry._positive_integer(reward.test_storage_limit) or reward.test_storage_limit > 10000):
				return "剧情奖励测试储物袋限额无效。"
			if reward.get("test_replay_on_restart", false) and not reward.has("test_storage_limit"):
				return "剧情奖励测试重播必须配置储物袋限额。"
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
	var reward_ids := {}
	for event: Dictionary in loaded.values():
		var reward_id: String = event.get("reward_id",event.get("reward",{}).get("id",""))
		if not reward_id.is_empty():
			if reward_ids.has(reward_id): return "地图奖励标识重复。"
			reward_ids[reward_id] = true
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

func _validate_cultivation(raw: Dictionary) -> String:
	for key in ["title","description","leave_label"]:
		if not raw.get(key) is String or raw[key].strip_edges().is_empty(): return "修炼地点文案无效："+key
	if not raw.presentation is Dictionary: return "修炼地点美术无效。"
	for key in ["background","illustration"]:
		if not raw.presentation.get(key) is String or not ResourceLoader.exists(raw.presentation[key],"Texture2D"): return "修炼地点素材缺失："+key
	if not raw.get("modes") is Array or raw.modes.size()!=3: return "修炼方式需要三种。"
	var ids: Array[String]=[]
	for mode: Variant in raw.modes:
		if not mode is Dictionary: return "修炼方式无效。"
		for key in ["id","name","description","image","selected_image"]:
			if not mode.get(key) is String or mode[key].strip_edges().is_empty(): return "修炼方式字段无效："+key
		if ids.has(mode.id): return "修炼方式ID重复。"
		ids.append(mode.id)
		for key in ["image","selected_image"]:
			if not ResourceLoader.exists(mode[key],"Texture2D"): return "修炼方式图片不存在。"
	if not raw.get("default_mode") is String or raw.default_mode not in ids: return "默认修炼方式无效。"
	if not raw.get("durations") is Array or raw.durations.size()!=3: return "修炼时间需要三档。"
	var days: Array[int]=[]
	for value: Variant in raw.durations:
		if not ContentRegistry._positive_integer(value) or days.has(int(value)): return "修炼时间无效或重复。"
		days.append(int(value))
	if not ContentRegistry._positive_integer(raw.get("default_days")) or int(raw.default_days) not in days: return "默认修炼时间无效。"
	var stage: Variant=raw.get("stage_two")
	if not stage is Dictionary: return "修炼第二阶段配置缺失。"
	for key in ["background","illustration"]:
		if not stage.get(key) is String or not ResourceLoader.exists(stage[key],"Texture2D"): return "修炼第二阶段素材缺失："+key
	if not stage.get("description") is String or stage.description.strip_edges().is_empty(): return "修炼状态描述缺失。"
	if not ContentRegistry._positive_integer(stage.get("status_interval_days")): return "修炼状态轮换天数无效。"
	for key in ["cultivation_statuses","technique_statuses"]:
		if not stage.get(key) is Array or stage[key].is_empty(): return "修炼状态文案库缺失："+key
		for line in stage[key]:
			if not line is String or line.strip_edges().is_empty(): return "修炼状态文案无效："+key
	return ""

func _validate_encounter(raw: Dictionary) -> String:
	if raw.has("enemy_sequence"):
		if not raw.enemy_sequence is Array or raw.enemy_sequence.is_empty(): return "遭遇轮换列表不能为空。"
		for id: Variant in raw.enemy_sequence:
			if not id is String or not id.begins_with("base.enemy."): return "遭遇轮换敌人标识无效。"
		if raw.get("enemy_id") != raw.enemy_sequence[0]: return "初始敌人必须对应轮换首项。"
		if raw.enemy_sequence.size() > 1 and not ContentRegistry._positive_integer(raw.get("respawn_days")):
			return "轮换遭遇需要正整数重生天数。"
	if raw.has("respawn_days") and not ContentRegistry._positive_integer(raw.respawn_days): return "重生天数无效。"
	# Empty location copy is intentional while authoring; missing/non-text fields are not.
	for key in ["title", "description"]:
		if not raw.get(key) is String: return "地图遭遇字段无效：" + key
	for key in ["enemy_id", "battle_scene"]:
		if not raw.get(key) is String or raw[key].strip_edges().is_empty():
			return "地图遭遇字段无效：" + key
	if not raw.enemy_id.begins_with("base.enemy.") or not ResourceLoader.exists(raw.battle_scene, "PackedScene"):
		return "地图遭遇敌人标识或战斗场景无效。"
	var art: Variant = raw.presentation
	for key in ["enemy_rank", "enemy_category", "enemy_description"]:
		if raw.has(key): return "怪物资料请配置在敌人主档：" + key
	if not art is Dictionary or not art.has("illustration"):
		return "地图遭遇美术配置不完整。"
	for key in ["illustration"]:
		if not art[key] is String or not ResourceLoader.exists(art[key], "Texture2D"):
			return "地图遭遇图片不存在：" + key
	for key in ["battle_background", "enemy_summary"]:
		if art.has(key): return "怪物展示请配置在敌人主档：" + key
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
