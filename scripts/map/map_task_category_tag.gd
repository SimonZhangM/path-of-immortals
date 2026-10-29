extends Control
## Straight chamfered corners, shared by task cards and the palette preview.
var definition: Dictionary
var caption: Label

func _init(style: Dictionary = {}) -> void:
	definition = style
	custom_minimum_size = Vector2(62, 28)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption = Label.new()
	caption.text = str(style.get("label", ""))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_font_override("font", preload("res://assets/fonts/HarmonyOS_Sans_SC_Regular.ttf"))
	caption.add_theme_font_size_override("font_size", 18)
	caption.add_theme_color_override("font_color", Color(style.get("text", "FFFFFF")))
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caption)
	caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)

func _draw() -> void:
	var r := Rect2(Vector2.ONE, size - Vector2.ONE * 2)
	var c := 6.0
	var points := PackedVector2Array([
		r.position + Vector2(c, 0), Vector2(r.end.x-c, r.position.y),
		Vector2(r.end.x, r.position.y+c), r.end-Vector2(0,c),
		r.end-Vector2(c,0), Vector2(r.position.x+c,r.end.y),
		Vector2(r.position.x,r.end.y-c), r.position+Vector2(0,c)])
	draw_colored_polygon(points, Color(definition.get("fill", "303843")))
	points.append(points[0])
	draw_polyline(points, Color(definition.get("color", "9DA9B8")), 1.5, true)
