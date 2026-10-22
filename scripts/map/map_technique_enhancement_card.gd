extends PanelContainer

signal choice_requested(branch_key: String)

class ChoiceMarker extends Control:
	var checked := false
	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.5 - 2
		draw_circle(center, radius, Color("061624"))
		draw_arc(center, radius, 0, TAU, 64, Color("eed17c") if checked else Color("81929e"), 2, true)
		if checked:
			var points := PackedVector2Array([center + Vector2(-0.50, 0.02) * radius, center + Vector2(-0.12, 0.38) * radius, center + Vector2(0.53, -0.38) * radius])
			draw_polyline(points, Color("fff0a3"), maxf(2, radius * 0.18), true)

var record: Dictionary
var config: Dictionary
var selected := false
var hovered := false
var ui_scale := 1.0
var theme_color := Color("69dcff")
var labels: Array[Label] = []
var separators: Array[BoxContainer] = []
var dots: Array[TextureRect] = []
var tags: Array[Label] = []
var icon: TextureRect
var marker: ChoiceMarker
var hit_button: Button
var flow: HFlowContainer
var content: VBoxContainer
var description_label: Label
var description_wrap: MarginContainer
var point_labels: Array[Label] = []
var point_wraps: Array[MarginContainer] = []
var dot_wraps: Array[MarginContainer] = []
const SpellDetail := preload("res://scripts/map/map_technique_spell_detail.gd")

func configure(entry: Dictionary, settings: Dictionary, font: Font, accent := Color("69dcff")) -> void:
	record = entry
	config = settings
	theme_color = accent
	name = "Enhancement_" + str(entry.branch_key)
	mouse_filter = MOUSE_FILTER_PASS
	size_flags_horizontal = SIZE_EXPAND_FILL
	content = VBoxContainer.new()
	content.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(content)
	separators.append(content)
	var header := HBoxContainer.new()
	header.mouse_filter = MOUSE_FILTER_IGNORE
	content.add_child(header)
	separators.append(header)
	icon = TextureRect.new()
	icon.texture = load(entry.icon)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = SIZE_SHRINK_END
	icon.mouse_filter = MOUSE_FILTER_IGNORE
	icon.texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var paint := ShaderMaterial.new()
	paint.shader = preload("res://scripts/map/map_technique_icon.gdshader")
	paint.set_shader_parameter("line_color", Color("d9bb72"))
	icon.material = paint
	header.add_child(icon)
	var header_text := VBoxContainer.new()
	header_text.size_flags_horizontal = SIZE_EXPAND_FILL
	header_text.mouse_filter = MOUSE_FILTER_IGNORE
	header.add_child(header_text)
	separators.append(header_text)
	var title_row := HBoxContainer.new()
	title_row.mouse_filter = MOUSE_FILTER_IGNORE
	header_text.add_child(title_row)
	var title := _text(entry.name, font, int(config.title_font_size))
	title.name = "ChoiceName"
	title.size_flags_vertical = SIZE_SHRINK_CENTER
	title_row.add_child(title)
	marker = ChoiceMarker.new()
	marker.name = "ChoiceCircle"
	marker.mouse_filter = MOUSE_FILTER_IGNORE
	marker.size_flags_vertical = SIZE_SHRINK_CENTER
	title_row.add_child(marker)
	flow = HFlowContainer.new()
	flow.mouse_filter = MOUSE_FILTER_IGNORE
	header_text.add_child(flow)
	var tag_font := SystemFont.new()
	tag_font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	for category: String in entry.categories:
		var tag := _text(category, tag_font, int(config.category_font_size), Color("a7b8c5"))
		tag.autowrap_mode = TextServer.AUTOWRAP_OFF
		tag.size_flags_horizontal = SIZE_SHRINK_BEGIN
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		flow.add_child(tag)
		tags.append(tag)
	var poem := _text("“%s”" % entry.poem, font, int(config.poem_font_size), Color("a7b8c5"))
	poem.name = "ChoicePoem"
	header_text.add_child(poem)
	description_label = _text(entry.description, font, int(config.body_font_size))
	description_label.name = "ChoiceDescription"
	description_wrap = MarginContainer.new()
	description_wrap.mouse_filter = MOUSE_FILTER_IGNORE
	content.add_child(description_wrap)
	description_wrap.add_child(description_label)
	for index in entry.core_points.size():
		var row := HBoxContainer.new()
		row.mouse_filter = MOUSE_FILTER_IGNORE
		content.add_child(row)
		separators.append(row)
		var dot := TextureRect.new()
		dot.texture = load("res://assets/UI-gongfa-right-dot.webp")
		dot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		dot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		dot.size_flags_vertical = SIZE_SHRINK_BEGIN
		dot.mouse_filter = MOUSE_FILTER_IGNORE
		var dot_wrap := MarginContainer.new()
		dot_wrap.mouse_filter = MOUSE_FILTER_IGNORE
		dot_wrap.size_flags_vertical = SIZE_SHRINK_BEGIN
		row.add_child(dot_wrap)
		dot_wrap.add_child(dot)
		dot_wraps.append(dot_wrap)
		dots.append(dot)
		var point := _text(entry.core_points[index], font, int(config.body_font_size))
		point.name = "CorePoint%d" % index
		var point_wrap := MarginContainer.new()
		point_wrap.mouse_filter = MOUSE_FILTER_IGNORE
		point_wrap.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(point_wrap)
		point_wrap.add_child(point)
		point_labels.append(point)
		point_wraps.append(point_wrap)
	hit_button = Button.new()
	hit_button.name = "SelectChoice"
	hit_button.focus_mode = Control.FOCUS_NONE
	# Stop left clicks before the ScrollContainer can treat them as a drag.
	# Control's scroll-event passthrough still lets the wheel scroll the cards.
	hit_button.mouse_filter = MOUSE_FILTER_STOP
	hit_button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	for style in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		hit_button.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	add_child(hit_button)
	hit_button.pressed.connect(func(): choice_requested.emit(str(record.branch_key)))
	hit_button.mouse_entered.connect(func(): hovered = true; _skin())
	hit_button.mouse_exited.connect(func(): hovered = false; _skin())
	update_pixels(1.0)

func _text(value: String, font: Font, font_size: int, color := Color("f1ead6")) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.oversampling_with_scale = OVERSAMPLING_WITH_SCALE_DISABLED
	label.add_theme_font_override("font", font)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color("06111bd9"))
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.set_meta("source_font_size", font_size)
	labels.append(label)
	return label

func update_pixels(factor: float) -> void:
	ui_scale = factor
	for label in labels:
		label.add_theme_font_size_override("font_size", maxi(1, roundi(float(label.get_meta("source_font_size")) * factor)))
		label.add_theme_constant_override("line_spacing", roundi(4 * factor))
	for box in separators: box.add_theme_constant_override("separation", roundi(12 * factor))
	content.add_theme_constant_override("separation", roundi(float(config.point_gap) * factor))
	for tag in tags:
		var font := tag.get_theme_font("font")
		var font_size := tag.get_theme_font_size("font_size")
		var ink := CooldownRing.ink_vertical_bounds(font, tag.text, font_size)
		var offset_y := font.get_ascent(font_size) + (ink.x + ink.y) * 0.5 - font.get_height(font_size) * 0.5
		var horizontal := SpellDetail.text_ink_x(tag)
		var offset_x := (horizontal.x + horizontal.y - font.get_string_size(tag.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x) * 0.5
		var padding_y := maxf(roundf(3 * factor), ceilf(absf(offset_y)) + 1)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("1b242f")
		style.border_color = Color("607382")
		style.set_border_width_all(1)
		style.set_corner_radius_all(roundi(4 * factor))
		style.content_margin_left = roundf(7 * factor - offset_x)
		style.content_margin_right = roundf(7 * factor + offset_x)
		style.content_margin_top = roundf(padding_y - offset_y)
		style.content_margin_bottom = roundf(padding_y + offset_y)
		tag.add_theme_stylebox_override("normal", style)
	flow.add_theme_constant_override("h_separation", roundi(6 * factor))
	flow.add_theme_constant_override("v_separation", roundi(6 * factor))
	icon.custom_minimum_size = Vector2.ONE * roundf(float(config.card_icon_size) * factor)
	icon.material.set_shader_parameter("icon_size", icon.custom_minimum_size)
	icon.material.set_shader_parameter("corner_radius", 4.0 * factor)
	icon.material.set_shader_parameter("line_width", maxf(1, 1.5 * factor))
	marker.custom_minimum_size = Vector2.ONE * roundf(float(config.selection_size) * factor)
	_trim_body_padding(description_label, description_wrap)
	for dot in dots: dot.custom_minimum_size = Vector2.ONE * roundf(21 * factor)
	for index in point_labels.size():
		var point := point_labels[index]
		var ink := _trim_body_padding(point, point_wraps[index])
		dot_wraps[index].add_theme_constant_override("margin_top", roundi((ink.y - ink.x - dots[index].custom_minimum_size.y) * 0.5))
	_skin()

func _trim_body_padding(label: Label, wrapper: MarginContainer) -> Vector2:
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var ink := CooldownRing.ink_vertical_bounds(font, label.text, font_size)
	# Exclude invisible font padding so description and points share visible gaps.
	wrapper.add_theme_constant_override("margin_top", -roundi(font.get_ascent(font_size) + ink.x))
	wrapper.add_theme_constant_override("margin_bottom", -roundi(font.get_height(font_size) - font.get_ascent(font_size) - ink.y))
	return ink

func set_selected(value: bool) -> void:
	selected = value
	marker.checked = value
	marker.queue_redraw()
	_skin()

func _skin() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0b2940f0") if selected else Color("071521eb")
	style.border_color = Color("69dcff") if selected else Color("638da5") if hovered else Color("355064")
	style.set_border_width_all(maxi(1, roundi((2.0 if selected else 1.0) * ui_scale)))
	style.set_corner_radius_all(roundi(9 * ui_scale))
	style.shadow_color = Color("46cfff55") if selected else Color.TRANSPARENT
	if not theme_color.is_equal_approx(Color("69dcff")):
		style.bg_color = Color(Color("071521").lerp(theme_color, 0.12), 0.94) if selected else Color("071521eb")
		style.border_color = theme_color if selected else theme_color.darkened(0.35) if hovered else theme_color.darkened(0.65)
		style.shadow_color = Color(theme_color, 0.33) if selected else Color.TRANSPARENT
	style.shadow_size = roundi(6 * ui_scale) if selected else 0
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, roundf(float(config.point_gap if side == SIDE_BOTTOM else config.card_padding) * ui_scale))
	add_theme_stylebox_override("panel", style)
