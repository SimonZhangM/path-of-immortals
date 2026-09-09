class_name RetreatCountdown
extends Control

var number: Label
var display: TextureRect
var blur: ShaderMaterial
var progress: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 25
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	offset_left = -128
	offset_right = 128
	offset_top = -80
	offset_bottom = 80
	var canvas := SubViewport.new()
	canvas.size = Vector2i(256, 160)
	canvas.transparent_bg = true
	canvas.disable_3d = true
	add_child(canvas)
	number = Label.new()
	number.theme = theme
	number.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number.add_theme_font_size_override("font_size", 76)
	number.add_theme_color_override("font_color", Color("f1dca6"))
	number.add_theme_color_override("font_outline_color", Color("2d261f"))
	number.add_theme_constant_override("outline_size", 5)
	canvas.add_child(number)
	display = TextureRect.new()
	display.texture = canvas.get_texture()
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blur = ShaderMaterial.new()
	blur.shader = preload("res://scripts/ui/countdown_blur.gdshader")
	display.material = blur
	add_child(display)
	hide()

func update_remaining(remaining_usec: int) -> void:
	visible = remaining_usec > 0
	if not visible:
		return
	number.text = "%ds" % ceili(remaining_usec / 1_000_000.0)
	progress = (3_000_000 - remaining_usec) % 1_000_000 / 1_000_000.0
	display.pivot_offset = size * 0.5
	display.scale = Vector2.ONE * (1.0 + progress * 0.16)
	display.modulate.a = 1.0 - progress * 0.65
	blur.set_shader_parameter("blur_radius", progress * 4.0)
