class_name ResourceBar
extends Range

var tint := Color.WHITE
var _surface: ColorRect
var _paint: ShaderMaterial

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_surface = ColorRect.new()
	_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_paint = ShaderMaterial.new()
	_paint.shader = preload("res://scripts/ui/resource_bar.gdshader")
	_surface.material = _paint
	add_child(_surface)
	move_child(_surface, 0)
	resized.connect(_refresh)
	value_changed.connect(func(_value): _refresh())
	_refresh()

func _refresh() -> void:
	_paint.set_shader_parameter("bar_size", size)
	_paint.set_shader_parameter("fill_ratio", ratio)
	_paint.set_shader_parameter("tint", tint)
