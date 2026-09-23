class_name ItemTooltip
extends PanelContainer

const WIDTH := 540.0
const RESOURCES := {"hp": "气血", "stamina": "体力", "spirit": "灵力"}
const KEY_COLOR := "9de3c3"
const HARD_BREAK_GAP := 8
const STATUS_KEYWORDS_PATH := "res://data/ui/combat_status_keywords.json"
static var _tooltip_theme: Theme
static var _keyword_theme: Theme
static var _body_font: SystemFont
static var _term_font: SystemFont
static var _status_keyword_definitions: Array = []
static var _status_keywords_loaded := false
var description: String = ""

static func _ensure_fonts() -> void:
	if _body_font == null:
		_body_font = SystemFont.new()
		_body_font.font_names = PackedStringArray(["KaiTi", "楷体", "Noto Serif CJK SC", "serif"])
	if _term_font == null:
		_term_font = SystemFont.new()
		_term_font.font_names = PackedStringArray(["SimSun", "宋体", "Noto Serif CJK SC", "serif"])

static func _ensure_status_keywords() -> void:
	if _status_keywords_loaded:
		return
	_status_keywords_loaded = true
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STATUS_KEYWORDS_PATH))
	if parsed is Array:
		_status_keyword_definitions = parsed

static func status_keyword_meanings() -> Dictionary:
	_ensure_status_keywords()
	var result := {}
	for definition: Dictionary in _status_keyword_definitions:
		result[String(definition.name)] = String(definition.description)
	return result

static func status_keyword_kinds() -> Dictionary:
	_ensure_status_keywords()
	var result := {}
	for definition: Dictionary in _status_keyword_definitions:
		result[String(definition.name)] = String(definition.kind)
	return result

static func status_keyword_icons() -> Dictionary:
	_ensure_status_keywords()
	var result := {}
	for definition: Dictionary in _status_keyword_definitions:
		result[String(definition.name)] = String(definition.icon)
	return result

static func status_keyword_colors() -> Dictionary:
	_ensure_status_keywords()
	var result := {}
	for definition: Dictionary in _status_keyword_definitions:
		result[String(definition.name)] = String(definition.color)
	return result

static func _keyword_color(word: String) -> String:
	return String(status_keyword_colors().get(word, KEY_COLOR))

static func _status_meanings_in(text: String) -> Dictionary:
	var result := {}
	var meanings := status_keyword_meanings()
	for word: String in meanings:
		if text.contains(word):
			result[word] = meanings[word]
	return result

static func chip(text: String, color := Color("a7b8c5")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", color)
	var box := _box(Color("1b242f"), Color(color, 0.35), 4, 7)
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	label.add_theme_stylebox_override("normal", box)
	return label

static func _box(fill: Color, border: Color, radius: int, padding: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.anti_aliasing = true
	for edge in ["left", "right", "top", "bottom"]:
		box.set("content_margin_" + edge, padding)
	return box

static func effect_text(item: ItemData) -> String:
	var lines: PackedStringArray = []
	if item.armor_capacity > 0:
		lines.append("装备后，护甲上限 +%d。" % item.armor_capacity)
	if item.defense > 0:
		lines.append("基础属性：防御 +%d。" % item.defense)
	var active: PackedStringArray = []
	var capped: PackedStringArray = []
	for effect: Dictionary in item.effects:
		match effect.effect:
			"damage":
				var damage_type := ""
				for tag in item.tags:
					if tag in ["斩击", "穿刺", "钝击"]:
						damage_type = tag
				var cost := "耗费%d点体力，" % item.stamina_cost if item.stamina_cost > 0 else ""
				active.append("%s对敌方造成%d点%s伤害。" % [cost, effect.value, damage_type])
			"restore_armor":
				active.append("恢复%d点护甲。" % effect.value)
			"apply_toxin":
				active.append("对敌方施加%d层毒蚀。" % effect.value)
			"restore_capped":
				capped.append("%d点%s" % [effect.value, RESOURCES[effect.resource]])
			"restore_ticks":
				active.append("使用后消耗一瓶。\n持续：每%s秒恢复%d点%s，共%d次，总计%d点。" % [String.num(float(effect.interval), 2), effect.value, RESOURCES[effect.resource], effect.ticks, effect.value * effect.ticks])
			"cleanse_toxin":
				active.append("使用后消耗一瓶，清除当前毒蚀，%s秒内免除毒蚀效果。" % String.num(float(effect.duration), 2))
			"restore_over_time":
				active.append("使用药瓶，在%d秒内恢复%d点%s；每瓶可使用%d次，用完后消耗。" % [effect.duration, effect.value, RESOURCES[effect.resource], item.uses_per_unit])
			"defense":
				lines.append("进场时增加 %d 防御，卸下后移除。" % effect.value)
			"counter_damage":
				lines.append("受到普通攻击后反击 %d 点伤害，无视防御；反击不引发反击。" % effect.value)
	if not capped.is_empty():
		var cap: Dictionary = item.effects.filter(func(effect: Dictionary): return effect.effect == "restore_capped")[0]
		active.append("同时恢复%s。\n恢复上限：各自最大值的%d/%d（向下取整）。" % ["、".join(capped), cap.cap_numerator, cap.cap_denominator])
	if not active.is_empty():
		lines.append("冷却：%s秒，%s" % [str(item.cooldown_usec / 1_000_000.0), "\n".join(active)])
	if lines.is_empty():
		lines.append("暂无战斗效果。")
	return "\n".join(lines)

static func keyword_meanings(item: ItemData) -> Dictionary:
	var meanings := {}
	for tag in item.tags:
		if EffectSystem.ARMOR_MULTIPLIERS.has(tag):
			meanings[tag] = EffectSystem.damage_type_meaning(tag)
	if item.armor_type == "轻甲":
		meanings["轻甲"] = "护甲类型，护甲耗尽后仍保留。"
	if item.armor_capacity > 0:
		meanings["护甲"] = "优先抵扣伤害，抵扣后消耗。"
	for effect: Dictionary in item.effects:
		match effect.effect:
			"restore_armor":
				meanings["护甲"] = "优先抵扣伤害，抵扣后消耗。"
			"restore_ticks", "restore_over_time":
				meanings["持续"] = "按指定间隔多次生效，直至效果结束。"
	var status_meanings := _status_meanings_in(effect_text(item))
	for word: String in status_meanings:
		meanings[word] = status_meanings[word]
	return meanings

static func _colored(text: String, words: Dictionary) -> String:
	# Longest first avoids nested tags when registered terms overlap.
	var keys: Array[String] = []
	for candidate: String in words:
		if candidate.ends_with("上限") or candidate == "毒蚀免疫":
			continue
		keys.append(candidate)
	keys.sort_custom(func(a: String, b: String): return a.length() > b.length())
	var result := ""
	var cursor := 0
	while cursor < text.length():
		var matched := false
		for word: String in keys:
			if text.substr(cursor, word.length()) == word:
				result += "[b][color=#%s]%s[/color][/b]" % [_keyword_color(word), word]
				cursor += word.length()
				matched = true
				break
		if not matched:
			result += "[lb]" if text[cursor] == "[" else text[cursor]
			cursor += 1
	return result

func _rich(parent: Node, text: String, font_size: int) -> RichTextLabel:
	_ensure_fonts()
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.text = text
	label.fit_content = true
	label.scroll_active = false
	label.custom_minimum_size.x = WIDTH - 44
	label.add_theme_font_override("normal_font", _body_font)
	label.add_theme_font_override("bold_font", _term_font)
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_font_size_override("bold_font_size", font_size)
	label.add_theme_color_override("default_color", Color("d8dee7"))
	parent.add_child(label)
	return label

func _rich_paragraphs(parent: Node, text: String, words: Dictionary, font_size: int) -> VBoxContainer:
	var paragraphs := VBoxContainer.new()
	paragraphs.name = "EffectDescription"
	paragraphs.add_theme_constant_override("separation", HARD_BREAK_GAP)
	parent.add_child(paragraphs)
	var lines := text.split("\n", true)
	for index in lines.size():
		var line := _rich(paragraphs, _colored(lines[index], words), font_size)
		line.name = "EffectDescriptionLine%d" % index
	return paragraphs

func configure_description(text: String, terms: Dictionary = {}) -> void:
	name = "BuffTooltip"
	custom_minimum_size.x = WIDTH
	add_theme_stylebox_override("panel", _box(Color("0b101b", 0.98), Color("424955"), 18, 22))
	description = text
	var highlighted := terms.duplicate()
	for word: String in _status_meanings_in(text):
		highlighted[word] = ""
	_rich_paragraphs(self, text, highlighted, 23)
	_ignore(self)

func configure(item: ItemData, _entry: Dictionary = {}, _owner_defense: int = -1, cooling_usec: int = 0, identified: bool = true) -> void:
	name = "ItemTooltip"
	custom_minimum_size.x = WIDTH
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_ensure_fonts()
	if _tooltip_theme == null:
		_tooltip_theme = Theme.new()
		_tooltip_theme.default_font = _body_font
	theme = _tooltip_theme
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	add_child(column)
	var main := PanelContainer.new()
	main.name = "SummaryPanel"
	main.add_theme_stylebox_override("panel", _box(Color("0b101b", 0.98), Color("424955"), 18, 22))
	column.add_child(main)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 20)
	main.add_child(content)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	content.add_child(header)
	var slot := PanelContainer.new()
	slot.name = "ItemPortrait"
	slot.custom_minimum_size = Vector2(96, 96)
	slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	slot.add_theme_stylebox_override("panel", _box(Color("171e29"), Color("4b5260"), 10, 0))
	header.add_child(slot)
	var canvas := Control.new()
	slot.add_child(canvas)
	var art := MapItemArtwork.new()
	art.name = "PortraitArtwork"
	art.configure({"icon": item.icon_path, "quality": item.quality, "art_outline_px": 1}, true)
	canvas.add_child(art)
	art.position = Vector2(10, 10)
	art.size = Vector2(76, 76)
	var glow := art.get_node("ItemGlow") as ColorRect
	glow.offset_left = -46
	glow.offset_top = -46
	glow.offset_right = 46
	glow.offset_bottom = 46
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_constant_override("separation", 10)
	header.add_child(heading)
	var title := Label.new()
	title.name = "ItemTitle"
	title.text = item.display_name if identified else "？"
	title.add_theme_font_override("font", _term_font)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("f9f8c8"))
	heading.add_child(title)
	var chips := HFlowContainer.new()
	chips.name = "CategoryTags"
	chips.add_theme_constant_override("h_separation", 7)
	chips.add_theme_constant_override("v_separation", 5)
	heading.add_child(chips)
	var tags := [StoragePanel.CATEGORIES.get(item.category, item.category)]
	for tag: String in item.tags:
		if not tag.is_empty() and tag not in tags and tag not in ["斩击", "穿刺", "钝击", "weapon", "armor", "pill", "item", "hp", "stamina", "spirit"]:
			tags.append(tag)
	if item.category == "weapon":
		for tag: String in item.tags:
			if tag in ["斩击", "穿刺", "钝击"]:
				tags.append(tag)
				break
	if not item.armor_type.is_empty():
		tags.append(item.armor_type)
	tags.append("占格 %d×%d" % [item.grid_size.x, item.grid_size.y])
	if not identified:
		tags = ["？"]
	for tag: String in tags:
		var label := chip(tag)
		label.add_theme_font_size_override("font_size", 16)
		chips.add_child(label)
	var divider := HSeparator.new()
	var line := StyleBoxLine.new()
	line.color = Color("303846")
	line.thickness = 1
	divider.add_theme_stylebox_override("separator", line)
	content.add_child(divider)
	description = effect_text(item) if identified else MapItemQuality.UNKNOWN_DESCRIPTION
	var meanings := keyword_meanings(item) if identified else {}
	var highlighted := meanings.duplicate()
	highlighted["冷却"] = ""
	highlighted["消耗"] = ""
	for resource_name: String in RESOURCES.values():
		highlighted[resource_name] = ""
	_rich_paragraphs(content, description, highlighted, 23)
	if identified and cooling_usec > 0:
		_rich(content, "入场等待：%.1f秒" % (cooling_usec / 1_000_000.0), 17)
	if not meanings.is_empty():
		var inset := MarginContainer.new()
		inset.add_theme_constant_override("margin_left", 18)
		inset.add_theme_constant_override("margin_right", 18)
		column.add_child(inset)
		var glossary := PanelContainer.new()
		glossary.name = "KeywordPanel"
		if _keyword_theme == null:
			_keyword_theme = Theme.new()
			_keyword_theme.default_font = _term_font
		glossary.theme = _keyword_theme
		glossary.add_theme_stylebox_override("panel", _box(Color("3a2719", 0.98), Color("66503a"), 14, 18))
		inset.add_child(glossary)
		var words := VBoxContainer.new()
		words.name = "KeywordRows"
		words.add_theme_constant_override("separation", HARD_BREAK_GAP)
		glossary.add_child(words)
		var caption := Label.new()
		caption.text = "关键词含义"
		caption.add_theme_font_size_override("font_size", 22)
		caption.add_theme_color_override("font_color", Color("f1d4a2"))
		words.add_child(caption)
		for word: String in meanings:
			var row := _rich(words, "[b][color=#%s]%s[/color][/b]：%s" % [_keyword_color(word), word, meanings[word]], 18)
			row.custom_minimum_size.x = WIDTH - 74
	_ignore(self)

func _ignore(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore(child)
