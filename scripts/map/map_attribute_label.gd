extends HBoxContainer

var attribute_name := ""
var meaning := ""

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_constant_override("separation", 7)

func _make_custom_tooltip(_text: String) -> Object:
	var tooltip := ItemTooltip.new()
	tooltip.configure_description(meaning, {attribute_name: ""})
	return tooltip
