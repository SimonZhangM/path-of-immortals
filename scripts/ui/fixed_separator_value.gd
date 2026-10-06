extends Control
## Keep the separator at a fixed visual axis, independent of number lengths.
var separator := "/"
var left_inset := 0.0
var gap := 5.0
var text := "":
	set(value):
		if text == value: return
		text = value
		queue_redraw()
var shadow := false

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func separator_center() -> float:
	return (size.x + left_inset) * .5

func text_right() -> float:
	var font := get_theme_font("font", "Label")
	var font_size := get_theme_font_size("font_size")
	return separator_center() + font.get_string_size(separator, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * .5 + gap + font.get_string_size(text.get_slice(separator, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

func _draw() -> void:
	var font := get_theme_font("font", "Label")
	var font_size := get_theme_font_size("font_size")
	var color := get_theme_color("font_color")
	var half := font.get_string_size(separator, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * .5
	var left := text.get_slice(separator, 0).strip_edges()
	var right := text.get_slice(separator, 1).strip_edges()
	var baseline := (size.y - font.get_height(font_size)) * .5 + font.get_ascent(font_size)
	var positions := [separator_center()-half-gap-font.get_string_size(left,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x, separator_center()-half, separator_center()+half+gap]
	var parts := [left, separator, right]
	for i in 3:
		var at := Vector2(positions[i],baseline)
		if shadow: draw_string(font,at+Vector2(0,1),parts[i],HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color(0,0,0,.9))
		draw_string(font,at,parts[i],HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
