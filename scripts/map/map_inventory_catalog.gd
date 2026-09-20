class_name MapInventoryCatalog
extends RefCounted

const TextureMetrics = preload("res://scripts/map/map_texture_metrics.gd")

signal changed

var category_names: Dictionary = {}
var collection_names: Dictionary = {}
var category_groups: Dictionary = {}
var collection := "all"
var category := "all"
var quality := ""
var search_text := ""
var newest_first := true
var sort_key := "acquired_at"
var level_descending := true
var _entries: Array[Dictionary] = []

func configure(config: Dictionary) -> void:
	category_names = config.categories.duplicate()
	collection_names = config.collections.duplicate()
	category_groups = config.category_groups.duplicate(true)

func subcategories() -> Array:
	if collection == "all":
		var children: Array = []
		for group: Array in category_groups.values():
			children.append_array(group)
		return children
	return category_groups.get(collection, []).duplicate()

func replace_entries(records: Array) -> String:
	var validated: Array[Dictionary] = []
	var ids := {}
	for raw: Variant in records:
		if not raw is Dictionary:
			return "物品记录必须为对象。"
		if not preload("res://scripts/map/map_buff_bonuses.gd").valid(raw.get("buff_bonuses", {})):
			return "物品常驻增益加成无效。"
		for key in ["id", "name", "category", "quality"]:
			if not raw.get(key) is String or raw[key].strip_edges().is_empty():
				return "物品字段无效：" + key
		if ids.has(raw.id) or raw.category == "all" or not category_names.has(raw.category):
			return "物品ID重复或类别无效。"
		if raw.has("subcategory"):
			if not raw.subcategory is String or raw.subcategory.strip_edges().is_empty():
				return "物品细分类须为非空文字。"
		if not ContentRegistry._nonnegative_integer(raw.get("enhancement_level", 0)):
			return "强化等级须为非负整数。"
		for key in ["acquired_at", "quantity"]:
			var value: Variant = raw.get(key)
			if not (value is int or value is float) or not is_finite(float(value)) or value < 0 or float(value) != floorf(float(value)):
				return "物品数值无效：" + key
		if raw.quantity == 0:
			return "物品数量须大于零。"
		for key in ["favorite", "common", "recipe"]:
			if not raw.get(key, false) is bool:
				return "物品标签须为布尔值。"
		var icon_path: Variant = raw.get("icon", "")
		if not icon_path is String:
			return "物品图片须为有效资源路径。"
		var icon_path_text := String(icon_path)
		if icon_path_text.strip_edges().is_empty() or not ResourceLoader.exists(icon_path_text, "Texture2D"):
			return "物品图片须为有效资源路径。"
		var icon_texture := load(icon_path_text) as Texture2D
		if not TextureMetrics.inspect(icon_texture).has_mipmaps:
			return "物品图片必须启用mipmap。"
		if not raw.get("card_frame", "") is String:
			return "物品底框须为资源路径。"
		if raw.has("art_outline_px") and not ContentRegistry._positive_integer(raw.art_outline_px):
			return "物品图片描边须为正整数。"
		if raw.has("footprint_rows") or raw.has("footprint_columns"):
			for key in ["footprint_rows", "footprint_columns"]:
				if not ContentRegistry._positive_integer(raw.get(key)):
					return "物品占格须包含正整数行数和列数。"
		if raw.has("damage_type"):
			if raw.damage_type not in ["斩击", "穿刺", "钝击"]:
				return "未知的武器攻击类型。"
			for key in ["base_damage", "base_stamina_cost"]:
				if not ContentRegistry._nonnegative_integer(raw.get(key)):
					return "基础伤害及耗体须为非负整数。"
			if not ContentRegistry._positive_number(raw.get("cooldown")):
				return "轮转CD须大于零。"
		if raw.category == "armor" and (raw.has("armor_gain") or raw.has("armor_capacity") or raw.has("armor_type")):
			if raw.get("subcategory") not in ["衣甲", "头盔", "盾"]:
				return "未知的防具部位。"
			if not ContentRegistry._positive_number(raw.get("cooldown")):
				return "防具轮转CD须大于零。"
			for key in ["armor_gain", "armor_capacity"]:
				if not ContentRegistry._nonnegative_integer(raw.get(key)):
					return "护甲恢复和上限须为非负整数。"
			if raw.has("armor_type") and (raw.subcategory != "衣甲" or raw.armor_type not in ["轻甲", "重甲", "灵甲"]):
				return "只有衣甲可以设置甲型。"
		ids[raw.id] = true
		if raw.category in ["artifact", "pill"] and (raw.has("effects") or raw.has("cooldown") or raw.has("uses_per_unit")):
			if not ContentRegistry._positive_number(raw.get("cooldown")) or not ContentRegistry._nonnegative_integer(raw.get("uses_per_unit", 0)):
				return "法器／丹药轮转或使用次数无效。"
			if not raw.get("effects") is Array or raw.effects.is_empty():
				return "法器／丹药须有有效效果。"
			for effect: Variant in raw.effects:
				if not effect is Dictionary or not EffectSystem.validate_definition(effect) or effect.trigger != "on_activate":
					return "法器／丹药效果无效。"
		validated.append(raw.duplicate(true))
	_entries = validated
	if quality not in qualities():
		quality = ""
	changed.emit()
	return ""

func load_entries(path: String) -> String:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not raw is Array:
		return "储物袋物品数据必须为数组。"
	return replace_entries(raw)

func set_filter(key: String, value: String) -> void:
	match key:
		"collection":
			if not collection_names.has(value):
				return
			collection = value
			category = "all"
		"category":
			if value != "all" and value not in subcategories():
				return
			category = value
		"quality":
			if not value.is_empty() and value not in qualities():
				return
			quality = value
		"search":
			search_text = value
		_:
			return
	changed.emit()

func set_newest_first(value: bool) -> void:
	newest_first = value
	sort_key = "acquired_at"
	changed.emit()

func set_level_descending(value: bool) -> void:
	level_descending = value
	sort_key = "enhancement_level"
	changed.emit()

func reset_filters() -> void:
	collection = "all"
	category = "all"
	quality = ""
	search_text = ""
	newest_first = true
	sort_key = "acquired_at"
	level_descending = true
	changed.emit()

func total_count() -> int:
	return _entries.size()

func qualities() -> Array[String]:
	var values: Array[String] = []
	for entry in _entries:
		if entry.quality not in values:
			values.append(entry.quality)
	values.sort()
	return values

func _in_collection(entry: Dictionary, key: String) -> bool:
	if key == "all":
		return true
	if key == "favorite":
		return entry.get("favorite", false)
	if key in ["key", "misc"]:
		return entry.category == key
	return entry.category in category_groups.get(key, [])

func collection_count(key: String) -> int:
	var count := 0
	for entry in _entries:
		if _in_collection(entry, key):
			count += 1
	return count

func visible_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in _entries:
		if not _in_collection(entry, collection):
			continue
		if category != "all" and entry.category != category:
			continue
		if not quality.is_empty() and entry.quality != quality:
			continue
		if not search_text.strip_edges().is_empty() and not search_text.strip_edges().to_lower() in String(entry.name).to_lower():
			continue
		result.append(entry.duplicate(true))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if sort_key == "enhancement_level":
			var a_level: int = a.get("enhancement_level", 0)
			var b_level: int = b.get("enhancement_level", 0)
			if a_level != b_level:
				return a_level > b_level if level_descending else a_level < b_level
		if a.acquired_at == b.acquired_at:
			return String(a.id) < String(b.id)
		return a.acquired_at > b.acquired_at if newest_first else a.acquired_at < b.acquired_at
	)
	return result
