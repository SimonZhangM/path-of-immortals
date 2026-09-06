class_name PartyMemberCard
extends Button

const BAR_WIDTH := 200.0
const BASE_SIZE := Vector2(464, 216)
const COMPACT_SCALE := 0.66
var member_index: int = -1
var stat_bars: Dictionary = {}
var stat_values: Dictionary = {}
var _title: Label
var portrait: TextureRect
var _content: HBoxContainer
var _last_values: Array = []

func configure(index: int, member: PartyMemberState) -> void:
	member_index = index
	name = "PartyMember%d" % (index + 1)
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = BASE_SIZE
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for style in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		add_theme_stylebox_override(style, StyleBoxEmpty.new())
	_content = HBoxContainer.new()
	_content.custom_minimum_size = BASE_SIZE
	_content.size = BASE_SIZE
	_content.add_theme_constant_override("separation", 8)
	add_child(_content)
	portrait = TextureRect.new()
	portrait.texture = load(member.definition["portrait"])
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(216, 216)
	_content.add_child(portrait)
	var details := VBoxContainer.new()
	_content.add_child(details)
	var title := Label.new()
	_title = title
	title.text = "%s（%s）" % [member.definition["name"], member.definition["realm"]]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_font_size_override("font_size", 19)
	details.add_child(title)
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.add_child(space)
	var resources := VBoxContainer.new()
	resources.size_flags_vertical = Control.SIZE_SHRINK_END
	resources.add_theme_constant_override("separation", 7)
	details.add_child(resources)
	var keys := ["hp", "stamina", "spirit"]
	var labels := ["气血", "体力", "灵力"]
	var colors := [Color("af3549"), Color("8cd259"), Color("5598eb")]
	for stat_index in keys.size():
		var key: String = keys[stat_index]
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 6)
		resources.add_child(row)
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
	_ignore_mouse(_content)
	refresh(member)

func show_selected(selected: bool) -> void:
	set_pressed_no_signal(selected)
	var display_scale := 1.0 if selected else COMPACT_SCALE
	custom_minimum_size = BASE_SIZE * display_scale
	_content.scale = Vector2.ONE * display_scale
	_title.add_theme_color_override("font_color", Color("f4d48e") if selected else Color("ece4cd"))

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
