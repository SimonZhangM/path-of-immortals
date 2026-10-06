class_name DefenseResourceRow
extends Control

const OUTLINE_RADIUS := 0.1875 # 0.25 native 2K screen px at 4/3 layout scale.
var bar: ResourceBar
var icon: TextureRect
var current_label: Label
var slash_label: Label
var maximum_label: Label
var caption := ""
var text: String:
	get: return caption + " " + current_label.text + " / " + maximum_label.text

func configure(title: String, icon_path: String, color: Color) -> void:
	caption = title
	name = "BarrierRow" if title == "灵盾" else "ArmorRow"
	custom_minimum_size = Vector2(154,32)
	mouse_filter = MOUSE_FILTER_IGNORE
	bar = ResourceBar.new()
	bar.tint = color
	bar.step = 0
	add_child(bar)
	icon = TextureRect.new()
	var source: Texture2D = load(icon_path)
	var trimmed := AtlasTexture.new()
	trimmed.atlas = source
	trimmed.region = source.get_image().get_used_rect()
	icon.texture = trimmed
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.mouse_filter = MOUSE_FILTER_IGNORE
	icon.size = Vector2(32,32)
	if title == "护甲":
		# Native 2K uses 4/3 of the authored layout: 1.125 units = 1.5 screen px.
		icon.position.x = 0.375
	add_child(icon)
	# Alpha silhouette only; leave the user's source pixels unchanged.
	for step in 16:
		var outline := TextureRect.new()
		outline.name = "Outline%d" % step
		outline.texture = trimmed
		outline.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		outline.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		outline.texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		outline.self_modulate = Color.BLACK
		outline.show_behind_parent = true
		outline.mouse_filter = MOUSE_FILTER_IGNORE
		icon.add_child(outline)
		outline.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		var offset := Vector2.from_angle(TAU * step / 16.0) * OUTLINE_RADIUS
		outline.position += offset
	current_label = _label(HORIZONTAL_ALIGNMENT_RIGHT)
	slash_label = _label(HORIZONTAL_ALIGNMENT_CENTER)
	maximum_label = _label(HORIZONTAL_ALIGNMENT_LEFT)
	slash_label.text = "/"
	resized.connect(_layout)
	_layout()

func _label(alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",16)
	label.add_theme_color_override("font_color",Color("fff9e9"))
	label.add_theme_color_override("font_shadow_color",Color("000000",.9))
	label.add_theme_constant_override("shadow_offset_y",1)
	label.mouse_filter = MOUSE_FILTER_IGNORE
	bar.add_child(label)
	return label

func _layout() -> void:
	# Match the upper resource bars' center axis. Visible left edge meets the
	# icon, and the right semicircle is the same distance from the slash.
	var axis := (17.0 + size.x) * .5
	bar.position = Vector2(icon.size.x,3)
	bar.size = Vector2(maxf(30,2*(axis-icon.size.x)),26)
	var half := bar.size.x * .5
	current_label.position = Vector2.ZERO
	current_label.size = Vector2(half-6,26)
	slash_label.position = Vector2(half-6,0)
	slash_label.size = Vector2(12,26)
	maximum_label.position = Vector2(half+6,0)
	maximum_label.size = Vector2(half-6,26)

func refresh(value: float, maximum: float, relevant: bool = true) -> void:
	visible = maximum > 0 and relevant
	bar.max_value = maxf(1,maximum)
	bar.value = value
	current_label.text = EffectSystem.number_text(value)
	maximum_label.text = EffectSystem.number_text(maximum)
