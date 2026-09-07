class_name ItemFootprint
extends Control

var dimensions := Vector2i.ONE
var tint := Color("9bb6c4")

func _draw() -> void:
	var step := minf(size.x / maxi(dimensions.x, 2), size.y / maxi(dimensions.y, 2))
	for y in dimensions.y:
		for x in dimensions.x:
			var rect := Rect2(Vector2(x, y) * step, Vector2.ONE * step).grow(-1)
			draw_style_box(_box(), rect)

func _box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = tint
	box.set_corner_radius_all(2)
	return box
