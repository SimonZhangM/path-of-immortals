class_name ItemTooltip
extends PanelContainer

const UI_SCALE := 4.0 / 3.0
const WIDTH := 720.0
const RESOURCES := {"hp": "气血", "stamina": "体力", "spirit": "灵力"}
const RESOURCE_STYLES := {
	"气血": {"color": "bf5d6d", "icon": "res://assets/player-status-health.webp"},
	"体力": {"color": "a3db7a", "icon": "res://assets/player-status-stamina.webp"},
	"灵力": {"color": "77adef", "icon": "res://assets/player-status-spirit.webp"},
}
const DEFENSE_ICONS := {
	"护甲": "res://assets/player-status-armor.webp",
	"护盾": "res://assets/player-status-sheild.webp",
}
const KEY_COLOR := "a3f3cd"
const HARD_BREAK_GAP := 11
const STATUS_KEYWORDS_PATH := "res://data/ui/combat_status_keywords.json"
const GENERAL_KEYWORDS_PATH := "res://data/ui/tooltip_keywords.json"
const GLOSSARY_EXCLUDED := ["斩击", "穿刺", "钝击", "法术型", "命中", "轻甲", "重甲", "无甲", "灵甲"]
static var _tooltip_theme: Theme
static var _keyword_theme: Theme
static var _body_font: SystemFont
static var _term_font: SystemFont
static var _bold_term_font: FontVariation
static var _status_keyword_definitions: Array = []
static var _status_keywords_loaded := false
static var _general_keyword_definitions: Array = []
static var _resource_regions: Dictionary = {}
var description: String = ""

static func _px(design_pixels: float) -> int:
	# Native 1440p geometry and integer font sizes, with no scaled tooltip texture.
	return roundi(design_pixels * UI_SCALE)

static func _ensure_fonts() -> void:
	if _body_font == null:
		_body_font = SystemFont.new()
		_body_font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	if _term_font == null:
		_term_font = SystemFont.new()
		_term_font.font_names = PackedStringArray(["SimSun", "宋体", "Noto Serif CJK SC", "serif"])
	if _bold_term_font == null:
		_bold_term_font = FontVariation.new()
		_bold_term_font.base_font = _term_font
		_bold_term_font.variation_embolden = 0.8

static func _ensure_status_keywords() -> void:
	if _status_keywords_loaded:
		return
	_status_keywords_loaded = true
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STATUS_KEYWORDS_PATH))
	if parsed is Array:
		_status_keyword_definitions = parsed
	var general: Variant = JSON.parse_string(FileAccess.get_file_as_string(GENERAL_KEYWORDS_PATH))
	if general is Array:
		_general_keyword_definitions = general

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
	if RESOURCE_STYLES.has(word):
		return RESOURCE_STYLES[word].color
	if EffectSystem.ARMOR_MULTIPLIERS.has(word):
		return "ffffff"
	_ensure_status_keywords()
	for definition: Dictionary in _general_keyword_definitions:
		if definition.name == word:
			return definition.color
	return String(status_keyword_colors().get(word, KEY_COLOR))

static func _status_meanings_in(text: String) -> Dictionary:
	var result := {}
	var meanings := status_keyword_meanings()
	for word: String in meanings:
		if text.contains(word):
			result[word] = meanings[word]
	return result

static func general_keyword_meanings() -> Dictionary:
	_ensure_status_keywords()
	var result := {
		"轻甲": "护甲类型，护甲耗尽后仍保留。",
		"护甲": "优先抵扣伤害，抵扣后消耗。",
		"持续": "效果按说明保持一段时间，或按指定间隔分次生效。",
	}
	for attack_type: String in EffectSystem.ARMOR_MULTIPLIERS:
		result[attack_type] = EffectSystem.damage_type_meaning(attack_type)
	for definition: Dictionary in _general_keyword_definitions:
		result[definition.name] = definition.description
	return result

static func highlighted_keywords() -> Dictionary:
	var result := general_keyword_meanings()
	result.merge(status_keyword_meanings())
	for word: String in ["冷却", "消耗"] + RESOURCES.values():
		result[word] = ""
	return result

static func chip(text: String, color := Color("a7b8c5"), ui_scale: float = 1.0) -> Label:
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", roundi(14 * ui_scale))
	label.add_theme_color_override("font_color", color)
	var box := _box(Color("1b242f"), Color(color, 0.35), roundi(4 * ui_scale), roundi(7 * ui_scale))
	# Center the visible CJK strokes, compensating for the font's baseline space.
	var optical_offset := ceili(ui_scale)
	box.content_margin_top = roundi(3 * ui_scale) - optical_offset
	box.content_margin_bottom = roundi(3 * ui_scale) + optical_offset
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
	if item.category == "board": return ""
	if item.category == "beast": return item.combat.get("description", "兽材，仅作材料，不能放入战斗阵盘。")
	if item.category == "book":
		var pending := "连携相关分支本轮暂缓。" if item.combat.has("deferred_branches") else ""
		return "%s，共%d重。%s%s" % [item.combat.role,int(item.combat.max_level),item.combat.get("deferred","分支按已学重数生效；修炼进度另行接入。"),pending]
	if item.category == "spell": return CultivationDescription.spell(item.combat)
	var lines: PackedStringArray = []
	if item.armor_capacity > 0:
		lines.append("上限：护甲+%d。" % item.armor_capacity)
	if item.defense > 0:
		lines.append("基础属性：防御 +%d。" % item.defense)
	var active: PackedStringArray = []
	var capped: PackedStringArray = []
	if item.rule_version == 1 and item.spirit_cost > 0:
		active.append("每次实际发动消耗%s灵力。" % EffectSystem.number_text(item.spirit_cost))
	if item.rule_version == 1 and item.is_consumable():
		lines.append("同一具体物品仅一叠，每叠最多10份。" + ("首瓶开战就绪，条件满足才使用；使用后消耗一瓶并进入CD。" if item.category == "pill" else "暗器首轮从完整CD开始，发动后消耗一件。"))
	for effect: Dictionary in item.effects:
		match effect.effect:
			"prime_item_attack":
				active.append("竖鬃蓄势：耗体%s，使下次%s的基础伤害增加%s，最多保留1次强化。" % [EffectSystem.number_text(item.stamina_cost), effect.target_name, EffectSystem.number_text(effect.value)])
			"apply_status":
				var target := "自身" if effect.target == "self" else "敌方"
				var gate: String = {"always": "发动时", "hit": "命中后", "hp_damage": "实际伤及气血后"}[effect.gate]
				if effect.trigger == "on_attacked":
					lines.insert(0, "冷却：独立9秒准备，合格受击时为自身施加%d层%s；成功施加后重开9秒。" % [effect.value, effect.status])
				else:
					active.append("%s向%s施加%d层%s。" % [gate, target, effect.value, effect.status])
			"restore_instant":
				active.append("立即恢复%d点%s。" % [effect.value, RESOURCES[effect.resource]])
			"barrier":
				active.append("增加%d普通灵盾，受当前上限限制；满值停用，受攻击减值后重开完整CD。" % effect.value)
			"resistance":
				active.append("对应%s直接伤害降低%d%%，持续%s秒；不减少持续跳伤。" % [{"fire":"火", "water":"水", "metal":"金", "wood":"木", "earth":"土"}[String(effect.element).trim_prefix("base.element.")], roundi(effect.value * 100), EffectSystem.number_text(effect.duration)])
			"damage":
				var damage_type: String = effect.get("damage_type", "")
				for tag in item.tags:
					if tag in ["斩击", "穿刺", "钝击"]:
						damage_type = tag
				var cost := "耗费%s点体力，" % EffectSystem.number_text(item.stamina_cost) if item.stamina_cost > 0 else ""
				active.append("%s对敌方造成%d点%s伤害。" % [cost, effect.value, damage_type])
			"restore_armor":
				active.append("恢复%d点护甲。" % effect.value)
			"apply_toxin":
				active.append("对敌方施加%d层毒蚀。" % effect.value)
			"restore_capped":
				capped.append("%d点%s" % [effect.value, RESOURCES[effect.resource]])
			"restore_ticks":
				active.append(("使用后消耗一瓶。\n" if item.rule_version == 0 else "") + "持续：每%s秒恢复%d点%s，共%d次，总计%d点。" % [String.num(float(effect.interval), 2), effect.value, RESOURCES[effect.resource], effect.ticks, effect.value * effect.ticks])
			"cleanse_toxin":
				active.append(("使用后消耗一瓶，" if item.rule_version == 0 else "") + "清除当前毒蚀，%s秒内免除毒蚀效果。" % String.num(float(effect.duration), 2))
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
		lines.insert(0, "冷却：%s秒，%s" % [str(item.cooldown_usec / 1_000_000.0), "\n".join(active)])
	if item.combat.has("resource_threshold"):
		var threshold: Dictionary = item.combat.resource_threshold
		lines.insert(0, "%s不高于上限的%d/%d时启动；启动后每%s秒恢复，超过阈值停用，不耗体。" % [RESOURCES[threshold.resource], threshold.numerator, threshold.denominator, EffectSystem.number_text(item.cooldown_usec / 1000000.0)])
	if not String(item.combat.get("equipment_note", "")).is_empty():
		lines.append(item.combat.equipment_note)
	if lines.is_empty():
		lines.append("暂无战斗效果。")
	return "\n".join(lines)

static func keyword_meanings(item: ItemData, displayed_description: String = "") -> Dictionary:
	var meanings := {}
	var text := effect_text(item) if displayed_description.is_empty() else displayed_description
	for tag in item.tags:
		if EffectSystem.ARMOR_MULTIPLIERS.has(tag):
			meanings[tag] = EffectSystem.damage_type_meaning(tag)
	if item.armor_capacity > 0:
		meanings["护甲"] = "优先抵扣伤害，抵扣后消耗。"
	for effect: Dictionary in item.effects:
		match effect.effect:
			"restore_armor":
				meanings["护甲"] = "优先抵扣伤害，抵扣后消耗。"
			"restore_ticks", "restore_over_time":
				meanings["持续"] = general_keyword_meanings()["持续"]
	var general := general_keyword_meanings()
	for word: String in general:
		if text.contains(word):
			meanings[word] = general[word]
	var status_meanings := _status_meanings_in(text)
	for word: String in status_meanings:
		meanings[word] = status_meanings[word]
	# Include only explicitly linked explanations, without recursive glossary expansion.
	for definition: Dictionary in _status_keyword_definitions:
		if meanings.has(definition.name):
			for related: String in definition.get("related_keywords", []):
				if general.has(related):
					meanings[related] = general[related]
	for word: String in GLOSSARY_EXCLUDED:
		meanings.erase(word)
	return meanings

static func _resource_image(word: String, font_size: int) -> String:
	var icon_path: String = DEFENSE_ICONS[word] if DEFENSE_ICONS.has(word) else RESOURCE_STYLES[word].icon
	if not _resource_regions.has(word):
		var texture := load(icon_path) as Texture2D
		var used := texture.get_image().get_used_rect()
		# Fit the visible artwork in a font-sized square without distorting it.
		var side := maxi(used.size.x, used.size.y)
		_resource_regions[word] = Rect2i(used.position + (used.size - Vector2i(side, side)) / 2, Vector2i(side, side))
	var region: Rect2i = _resource_regions[word]
	return "[img width=%d height=%d region=%d,%d,%d,%d]%s[/img]" % [font_size, font_size, region.position.x, region.position.y, region.size.x, region.size.y, icon_path]

static func _colored(text: String, words: Dictionary, font_size: int = 23) -> String:
	# Longest first avoids nested tags when registered terms overlap.
	var keys: Array[String] = []
	for candidate: String in words:
		if candidate.ends_with("上限") or candidate == "毒蚀免疫":
			continue
		keys.append(candidate)
	# Inline artwork does not add glossary entries or change the word's styling.
	for word: String in DEFENSE_ICONS:
		if word not in keys:
			keys.append(word)
	keys.sort_custom(func(a: String, b: String): return a.length() > b.length())
	var result := ""
	var cursor := 0
	while cursor < text.length():
		var matched := false
		for word: String in keys:
			if text.substr(cursor, word.length()) == word:
				var shown_word := word
				if RESOURCE_STYLES.has(word) or DEFENSE_ICONS.has(word):
					# Leave room for font hinting so each gap stays below half a normal space.
					var gap_size := maxi(1, floori(font_size * 0.4))
					result += "[font_size=%d] [/font_size]%s[font_size=%d]\u00a0[/font_size]" % [gap_size, _resource_image(word, font_size), gap_size]
					shown_word = word.left(1) + "\u2060" + word.substr(1)
				result += "[b][color=#%s]%s[/color][/b]" % [_keyword_color(word), shown_word] if words.has(word) else shown_word
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
	label.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	label.bbcode_enabled = true
	label.text = text
	label.fit_content = true
	label.scroll_active = false
	label.custom_minimum_size.x = WIDTH - _px(44)
	label.add_theme_font_override("normal_font", _body_font)
	label.add_theme_font_override("bold_font", _bold_term_font)
	label.add_theme_font_size_override("normal_font_size", _px(font_size))
	label.add_theme_font_size_override("bold_font_size", _px(font_size))
	label.add_theme_color_override("default_color", Color("d8dee7"))
	parent.add_child(label)
	return label

func _rich_paragraphs(parent: Node, text: String, words: Dictionary, font_size: int, body_font_size: int = -1) -> VBoxContainer:
	var paragraphs := VBoxContainer.new()
	paragraphs.name = "EffectDescription"
	paragraphs.add_theme_constant_override("separation", HARD_BREAK_GAP)
	parent.add_child(paragraphs)
	var lines := text.split("\n", true)
	for index in lines.size():
		var line := _rich(paragraphs, _colored(lines[index], words, _px(font_size)), font_size)
		if body_font_size > 0:
			line.add_theme_font_size_override("normal_font_size", _px(body_font_size))
		line.name = "EffectDescriptionLine%d" % index
	return paragraphs

func configure_description(text: String, terms: Dictionary = {}) -> void:
	name = "BuffTooltip"
	custom_minimum_size.x = WIDTH
	add_theme_stylebox_override("panel", _box(Color("0b101b", 0.98), Color("424955"), _px(18), _px(22)))
	description = text
	var highlighted := highlighted_keywords()
	highlighted.merge(terms)
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
		_tooltip_theme.default_font_size = _px(16)
	theme = _tooltip_theme
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	add_child(column)
	var main := PanelContainer.new()
	main.name = "SummaryPanel"
	main.add_theme_stylebox_override("panel", _box(Color("0b101b", 0.98), Color("424955"), _px(18), _px(22)))
	column.add_child(main)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", _px(20))
	main.add_child(content)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", _px(18))
	content.add_child(header)
	var slot := PanelContainer.new()
	slot.name = "ItemPortrait"
	slot.custom_minimum_size = Vector2(96, 96) * UI_SCALE
	slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	slot.add_theme_stylebox_override("panel", _box(Color("171e29"), Color("4b5260"), _px(10), 0))
	header.add_child(slot)
	var canvas := Control.new()
	slot.add_child(canvas)
	var art := MapItemArtwork.new()
	art.name = "PortraitArtwork"
	art.configure({"icon": item.icon_path, "name":item.display_name if identified else "？", "quality": item.quality, "art_outline_px": 1}, true)
	canvas.add_child(art)
	art.position = Vector2(12, 20) * UI_SCALE
	art.size = Vector2(72, 72) * UI_SCALE
	art.apply_inventory_pose({"category": item.category, "footprint_columns": item.grid_size.x, "footprint_rows": item.grid_size.y})
	# Tooltips share the card's orientation, but center the portrait in its slot.
	art.pivot_offset = art.size * 0.5
	art.set_anchors_preset(Control.PRESET_CENTER)
	art.offset_left = -art.size.x * 0.5
	art.offset_top = -art.size.y * 0.5
	art.offset_right = art.pivot_offset.x
	art.offset_bottom = art.pivot_offset.y
	art.scale *= 0.9
	var center_portrait := func(): art.center_visible_at(canvas.size * 0.5)
	canvas.resized.connect(center_portrait)
	center_portrait.call()
	var glow := art.get_node("ItemGlow") as ColorRect
	# Keep the wash centered on the slot, independent of optical icon offsets.
	art.remove_child(glow)
	canvas.add_child(glow)
	canvas.move_child(glow, 0)
	glow.show_behind_parent = false
	glow.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var glow_radius := 46.0 * UI_SCALE * art.scale.x
	glow.offset_left = -glow_radius
	glow.offset_top = -glow_radius
	glow.offset_right = glow_radius
	glow.offset_bottom = glow_radius
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_constant_override("separation", _px(10))
	header.add_child(heading)
	var title := Label.new()
	title.name = "ItemTitle"
	title.text = item.display_name if identified else "？"
	title.add_theme_font_override("font", _bold_term_font)
	title.add_theme_font_size_override("font_size", _px(30))
	title.add_theme_color_override("font_color", Color("f9f8c8"))
	heading.add_child(title)
	var chips := HFlowContainer.new()
	chips.name = "CategoryTags"
	chips.add_theme_constant_override("h_separation", _px(7))
	chips.add_theme_constant_override("v_separation", _px(5))
	heading.add_child(chips)
	var tags := [{"book":"功法书","spell":"法术","beast":"兽材","board":"阵盘"}.get(item.category,StoragePanel.CATEGORIES.get(item.category,item.category))]
	if item.category == "board": tags = []
	if item.category == "item" and "器官" in item.tags: tags[0] = "器官"
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
	var footprint := Vector2i(1,2) if _entry.get("vertical_book",false) else item.grid_size
	if item.category not in ["plant", "beast", "mineral", "exotic", "material", "board"]:
		tags.append("占格 %d×%d" % [footprint.x, footprint.y])
	if not identified:
		tags = ["？"]
	for tag: String in tags:
		var label := chip(tag, Color("a7b8c5"), UI_SCALE)
		label.add_theme_font_size_override("font_size", _px(16))
		chips.add_child(label)
	var divider := HSeparator.new()
	var line := StyleBoxLine.new()
	line.color = Color("303846")
	line.thickness = 1
	divider.add_theme_stylebox_override("separator", line)
	content.add_child(divider)
	description = str(_entry.get("effect_description",effect_text(item))) if identified else MapItemQuality.UNKNOWN_DESCRIPTION
	if item.category == "board" and identified: description = ""
	var meanings := keyword_meanings(item, description) if identified else {}
	var highlighted := highlighted_keywords()
	if item.category == "board" and identified:
		var reserved := VBoxContainer.new()
		reserved.name = "BoardDescriptionSlot"
		reserved.custom_minimum_size.y = _px(170)
		content.add_child(reserved)
	else:
		_rich_paragraphs(content, description, highlighted, 23, 22)
	if identified and cooling_usec > 0:
		_rich(content, "入场等待：%.1f秒" % (cooling_usec / 1_000_000.0), 17)
	if not meanings.is_empty():
		var inset := MarginContainer.new()
		inset.add_theme_constant_override("margin_left", _px(18))
		inset.add_theme_constant_override("margin_right", _px(18))
		column.add_child(inset)
		var glossary := PanelContainer.new()
		glossary.name = "KeywordPanel"
		if _keyword_theme == null:
			_keyword_theme = Theme.new()
			_keyword_theme.default_font = _term_font
		glossary.theme = _keyword_theme
		glossary.add_theme_stylebox_override("panel", _box(Color("3a2719", 0.98), Color("66503a"), _px(14), _px(18)))
		inset.add_child(glossary)
		var words := VBoxContainer.new()
		words.name = "KeywordRows"
		words.add_theme_constant_override("separation", HARD_BREAK_GAP)
		glossary.add_child(words)
		var caption := Label.new()
		caption.name = "KeywordHeading"
		caption.text = "关键词含义"
		caption.add_theme_font_override("font", _bold_term_font)
		caption.add_theme_font_size_override("font_size", _px(22))
		caption.add_theme_color_override("font_color", Color("f1d4a2"))
		words.add_child(caption)
		for word: String in meanings:
			# Highlight within definitions too, but do not recursively add glossary rows.
			var row := _rich(words, "%s：%s" % [_colored(word, highlighted, _px(18)), _colored(meanings[word], highlighted, _px(18))], 18)
			row.custom_minimum_size.x = WIDTH - _px(74)
	_ignore(self)

func _ignore(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore(child)
