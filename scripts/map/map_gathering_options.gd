class_name MapGatheringOptions
extends RefCounted

var methods: Array[Dictionary] = []
var locations: Dictionary = {}
var profile_path := "res://data/ui/gathering_options.json"
var background := "res://assets/tanchuang-caiji1.webp"
var unit := "株"
var activity := "采集"
var text_buttons := false
var location_font_size := 25
var illustration_frame := ""
var item_name_offset_y := 0.0
var item_tags_offset_y := 0.0
var method_name_offset_y := 0.0
var gathering_animation: Dictionary = {}

static func path_for_record(record: Dictionary) -> String:
	return "res://data/ui/mining_options.json" if record.get("category") == "mineral" else "res://data/ui/gathering_options.json"

func load_options(path := "res://data/ui/gathering_options.json") -> String:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not raw is Dictionary or not raw.get("methods") is Array or raw.methods.size() != 3:
		return "采集方式配置必须包含三种方式。"
	var native_buttons: Variant = raw.get("text_buttons", false)
	if not ContentRegistry._positive_integer(raw.get("location_font_size", 25)): return "地点描述字号无效。"
	for key in ["item_name_offset_y", "item_tags_offset_y", "method_name_offset_y"]:
		var offset: Variant = raw.get(key, 0)
		if not (offset is int or offset is float) or not is_finite(float(offset)): return "采集文字偏移无效：" + key
	if not native_buttons is bool: return "采集按钮类型无效。"
	if not raw.get("gathering_animation", {}) is Dictionary: return "采集动画配置无效。"
	var next_background: Variant = raw.get("background", "res://assets/tanchuang-caiji1.webp")
	if not next_background is String or not ResourceLoader.exists(next_background, "Texture2D"): return "采集底图缺失。"
	var next_frame: Variant = raw.get("illustration_frame", "")
	if not next_frame is String: return "采集场景边框路径无效。"
	if not next_frame.is_empty() and not ResourceLoader.exists(next_frame, "Texture2D"): return "采集场景边框缺失。"
	for key in ["unit", "activity"]:
		if raw.has(key) and (not raw[key] is String or raw[key].is_empty()): return "采集展示配置无效：" + key
	var next: Array[Dictionary] = []
	var ids := {}
	for entry: Variant in raw.methods:
		if not entry is Dictionary: return "采集方式必须为对象。"
		if not entry.get("id") is String or not entry.id.begins_with("base.gathering.") or ids.has(entry.id): return "采集方式标识无效。"
		if not entry.get("name") is String or entry.name.is_empty(): return "采集方式名称无效。"
		for key in ["base", "extra_min", "extra_max", "days"]:
			if not ContentRegistry._nonnegative_integer(entry.get(key)): return "采集数值无效：" + key
		if entry.base < 1 or entry.days < 1 or entry.extra_min > entry.extra_max: return "采集范围无效。"
		if not native_buttons:
			for key in ["button_idle", "button_selected"]:
				if not entry.get(key) is String or not ResourceLoader.exists(entry[key], "Texture2D"): return "采集按钮素材缺失：" + key
		if not entry.get("color") is String or not Color.html_is_valid(entry.color): return "采集配色无效。"
		ids[entry.id] = true
		next.append(entry.duplicate(true))
	var next_locations: Variant = raw.get("locations", {})
	if not next_locations is Dictionary: return "采集地点文案必须为对象。"
	for item_id: Variant in next_locations:
		if not item_id is String or not item_id.begins_with("base.material."): return "采集地点药材标识无效。"
		var location: Variant = next_locations[item_id]
		if not location is Dictionary: return "采集地点文案无效。"
		# A future location can omit its picture; a supplied path must be valid.
		if location.has("illustration"):
			if next_frame.is_empty() or not location.illustration is String or not ResourceLoader.exists(location.illustration, "Texture2D"): return "采集地点场景图片缺失。"
		for key in ["title", "description"]:
			if not location.get(key) is String or location[key].is_empty(): return "采集地点文案缺少：" + key
		if not location.get("notes") is Dictionary or location.notes.size() != next.size(): return "采集方式说明不完整。"
		for method: Dictionary in next:
			if not location.notes.get(method.id) is String or location.notes[method.id].is_empty(): return "采集方式说明缺失：" + method.id
	methods = next
	locations = next_locations.duplicate(true)
	profile_path = path
	background = next_background
	unit = raw.get("unit", "株")
	activity = raw.get("activity", "采集")
	text_buttons = native_buttons
	location_font_size = int(raw.get("location_font_size", 25))
	illustration_frame = next_frame
	item_name_offset_y = float(raw.get("item_name_offset_y", 0))
	item_tags_offset_y = float(raw.get("item_tags_offset_y", 0))
	method_name_offset_y = float(raw.get("method_name_offset_y", 0))
	gathering_animation = raw.get("gathering_animation", {}).duplicate(true)
	return ""

func forecast(index: int) -> Dictionary:
	if index < 0 or index >= methods.size(): return {}
	var method := methods[index]
	return {"method_id": method.id, "name": method.name, "base": int(method.base),
		"extra_min": int(method.extra_min), "extra_max": int(method.extra_max),
		"total_min": int(method.base + method.extra_min), "total_max": int(method.base + method.extra_max), "days": int(method.days)}
