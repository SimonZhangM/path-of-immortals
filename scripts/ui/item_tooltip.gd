class_name ItemTooltip
extends PanelContainer

var description: String = ""

static func chip(text: String, color := Color("a7b8c5")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", color)
	var box := StyleBoxFlat.new()
	box.bg_color = Color("1b242f")
	box.border_color = Color(color, 0.35)
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.content_margin_left = 7
	box.content_margin_right = 7
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	label.add_theme_stylebox_override("normal", box)
	return label

static func effect_text(item: ItemData) -> String:
	var lines: PackedStringArray = []
	if item.defense > 0:
		lines.append("基础属性  ·  防御 +%d" % item.defense)
	for effect in item.effects:
		match effect["trigger"]:
			"on_enter":
				lines.append("进场  ·  为佩戴者增加 %d 防御；卸下移除，不重复累加。" % effect["value"])
			"on_attacked":
				lines.append("即刻  ·  受到普通攻击后，向攻击者反击 %d 点伤害，无视防御。" % effect["value"])
				lines.append("抵挡至0伤害也反击；致死攻击不反击，反击不引发反击。")
			"on_activate":
				if effect["effect"] == "damage":
					lines.append("轮转 %s秒  ·  对敌方主角造成 %d 点伤害，每次消耗 %d 体力。" % [str(item.cooldown_usec / 1_000_000.0), effect["value"], item.stamina_cost])
				else:
					lines.append("轮转 %s秒  ·  随后 %d秒内回复自身 %d 点%s，每瓶可使用 %d次。" % [str(item.cooldown_usec / 1_000_000.0), effect["duration"], effect["value"], {"hp": "气血", "stamina": "体力", "spirit": "灵力"}[effect["resource"]], item.uses_per_unit])
					lines.append("满值等待下一瓶；已开瓶不可收回，须用完；回复不超过上限。")
	if item.defense == 0 and item.effects.is_empty():
		lines.append("暂无战斗效果。")
	return "\n\n".join(lines)

func configure(item: ItemData, entry: Dictionary = {}, owner_defense: int = -1, cooling_usec: int = 0) -> void:
	custom_minimum_size = Vector2(600, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color("0d1520", 0.99)
	box.border_color = Color("566777")
	box.set_border_width_all(1)
	box.set_corner_radius_all(14)
	for edge in ["left", "right", "top", "bottom"]:
		box.set("content_margin_" + edge, 20)
	add_theme_stylebox_override("panel", box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 15)
	column.add_child(header)
	var icon := TextureRect.new()
	if not item.icon_path.is_empty():
		icon.texture = load(item.icon_path)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(70, 84)
	header.add_child(icon)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	var title := Label.new()
	title.text = item.display_name
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", Color("f0d59e"))
	heading.add_child(title)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 8)
	heading.add_child(chips)
	chips.add_child(chip(StoragePanel.CATEGORIES[item.category]))
	chips.add_child(chip(item.quality, Color("c6acdf")))
	chips.add_child(chip("%d×%d格" % [item.grid_size.x, item.grid_size.y]))
	var shape := ItemFootprint.new()
	shape.dimensions = item.grid_size
	shape.custom_minimum_size = Vector2(50, 50)
	header.add_child(shape)
	column.add_child(HSeparator.new())
	description = effect_text(item)
	var body := Label.new()
	body.text = description
	body.custom_minimum_size.x = 560
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 19)
	body.add_theme_color_override("font_color", Color("d3e1eb"))
	column.add_child(body)
	if not entry.is_empty() or owner_defense >= 0:
		var state := Label.new()
		state.add_theme_font_size_override("font_size", 15)
		state.add_theme_color_override("font_color", Color("9bcab5"))
		if item.is_consumable() and not entry.is_empty():
			state.text = "数量 %d瓶 · 当前瓶剩余 %d次" % [entry["units"].size(), entry["units"][0]["uses_left"]]
		elif not entry.is_empty():
			state.text = "数量 %d" % entry["units"].size()
		if owner_defense >= 0:
			state.text += "  ·  佩戴者当前总防御 %d" % owner_defense
		if cooling_usec > 0:
			state.text += "  ·  冷却中 %ds" % ceili(cooling_usec / 1_000_000.0)
		column.add_child(state)
	var hint := Label.new()
	hint.text = "战前放入无冷却；战中从储物袋放入等待3秒。阵盘内移动保留进度。"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color("8796a7"))
	column.add_child(hint)
