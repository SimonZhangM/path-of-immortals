extends Control

const LINE_WIDTH := 260.0

func _ready() -> void:
	custom_minimum_size.y = 12.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var center := size * 0.5
	var gold := Color("d9bb72", 0.65)
	var faded := Color("d9bb72", 0.0)
	for direction: float in [-1.0, 1.0]:
		var inner := center.x + direction * 6.0
		var outer := center.x + direction * LINE_WIDTH * 0.5
		draw_polygon(PackedVector2Array([
			Vector2(inner, center.y - 0.5), Vector2(outer, center.y - 0.5),
			Vector2(outer, center.y + 0.5), Vector2(inner, center.y + 0.5)
		]), PackedColorArray([gold, faded, faded, gold]))
	var diamond := PackedVector2Array([
		center + Vector2(0, -2.5), center + Vector2(2.0, 0),
		center + Vector2(0, 2.5), center + Vector2(-2.0, 0)
	])
	draw_colored_polygon(diamond, Color("f0dfac", 0.9))
	draw_polyline(diamond + PackedVector2Array([diamond[0]]), gold, 0.5, true)
