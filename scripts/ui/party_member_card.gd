class_name PartyMemberCard
extends Button

const BAR_WIDTH := 200.0
var member_index: int = -1
var stat_bars: Dictionary = {}
var stat_values: Dictionary = {}
var _last_values: Array = []

func configure(index: int, member: PartyMemberState) -> void:
	member_index = index
	name = "PartyMember%d" % (index + 1)
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(264, 228)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 8)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	margin.add_child(column)
	var title := Label.new()
	title.text = "%s（%s）" % [member.definition["name"], member.definition["realm"]]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 19)
	column.add_child(title)
	var portrait := TextureRect.new()
	portrait.texture = load(member.definition["portrait"])
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size.y = 88
	portrait.modulate = [Color.WHITE, Color("b3cfde"), Color("dcc9a3")][index]
	column.add_child(portrait)
	var keys := ["hp", "stamina", "spirit"]
	var labels := ["气血", "体力", "灵力"]
	var colors := [Color("a7655f"), Color("62916c"), Color("598aab")]
	for stat_index in keys.size():
		var key: String = keys[stat_index]
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 6)
		column.add_child(row)
		var label := Label.new()
		label.text = labels[stat_index]
		label.add_theme_font_size_override("font_size", 17)
		row.add_child(label)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(BAR_WIDTH, 24)
		bar.show_percentage = false
		var base := StyleBoxFlat.new()
		base.bg_color = Color("172124")
		base.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("background", base)
		var fill := StyleBoxFlat.new()
		fill.bg_color = colors[stat_index]
		fill.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("fill", fill)
		row.add_child(bar)
		var value := Label.new()
		value.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value.add_theme_font_size_override("font_size", 16)
		value.add_theme_color_override("font_color", Color("fff9e9"))
		value.add_theme_color_override("font_shadow_color", Color("000000", 0.9))
		value.add_theme_constant_override("shadow_offset_y", 1)
		bar.add_child(value)
		stat_bars[key] = bar
		stat_values[key] = value
	_ignore_mouse(margin)
	refresh(member)

func refresh(member: PartyMemberState) -> void:
	var values := [member.hp, member.stamina, member.spirit]
	if values == _last_values:
		return
	_last_values = values
	var keys := ["hp", "stamina", "spirit"]
	for index in keys.size():
		var key: String = keys[index]
		var maximum := int(member.definition["max_" + key])
		stat_bars[key].max_value = maximum
		stat_bars[key].value = values[index]
		stat_values[key].text = "%d / %d" % [values[index], maximum]

func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)
