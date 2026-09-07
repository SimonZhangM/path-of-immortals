class_name PartyMemberCard
extends Control

signal clicked(index: int)

const BAR_WIDTH := 200.0
const BASE_SIZE := Vector2(484, 236)
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
	custom_minimum_size = BASE_SIZE
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mouse_filter = Control.MOUSE_FILTER_STOP
	_content = HBoxContainer.new()
	_content.custom_minimum_size = BASE_SIZE
	_content.size = BASE_SIZE
	_content.add_theme_constant_override("separation", 8)
	add_child(_content)
	portrait = TextureRect.new()
	portrait.texture = load(member.definition["portrait"])
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(236, 236)
	_content.add_child(portrait)
	var details := VBoxContainer.new()
	_content.add_child(details)
	var title := Label.new()
	_title = title
	title.text = str(member.definition["name"])
	if not str(member.definition.get("realm", "")).is_empty():
		title.text += "（%s）" % member.definition["realm"]
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
		var bar := ResourceBar.new()
		bar.custom_minimum_size = Vector2(BAR_WIDTH, 24)
		bar.tint = colors[stat_index]
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

func set_primary(primary: bool) -> void:
	var display_scale := 1.0 if primary else COMPACT_SCALE
	custom_minimum_size = BASE_SIZE * display_scale
	_content.scale = Vector2.ONE * display_scale
	_title.add_theme_color_override("font_color", Color("f4d48e") if primary else Color("ece4cd"))

func refresh(member: PartyMemberState) -> void:
	var values := [member.hp, member.stamina, member.spirit]
	if values == _last_values:
		return
	_last_values = values
	portrait.modulate = Color(0.45, 0.45, 0.45) if member.hp <= 0 else Color.WHITE
	var keys := ["hp", "stamina", "spirit"]
	for index in keys.size():
		var key: String = keys[index]
		var maximum := int(member.definition["max_" + key])
		stat_bars[key].max_value = maxi(maximum, 1)
		stat_bars[key].value = values[index]
		stat_values[key].text = "%d / %d" % [values[index], maximum]

func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit(member_index)
		accept_event()
