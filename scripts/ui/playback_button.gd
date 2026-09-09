class_name PlaybackButton
extends Button

var symbol: String = "play"

func _draw() -> void:
	var color := Color("f1dca6") if not disabled else Color("776a54")
	draw_set_transform(Vector2.ZERO, 0, size / 25.0)
	var center := Vector2(12.5, 12.5)
	if symbol == "pause":
		color = Color("e7876c") if not disabled else color
		for x in [-4.0, 2.0]:
			draw_rect(Rect2(center + Vector2(x, -5), Vector2(3, 10)), color)
	elif symbol == "play":
		draw_colored_polygon(PackedVector2Array([center + Vector2(-4, -6), center + Vector2(6, 0), center + Vector2(-4, 6)]), color)
	elif symbol == "double":
		for x in [-7.0, 0.0]:
			draw_colored_polygon(PackedVector2Array([center + Vector2(x, -5), center + Vector2(x + 7, 0), center + Vector2(x, 5)]), color)
	elif symbol == "settings":
		# Solid geometry keeps teeth crisp at the actual button resolution.
		color = Color("f1dca6")
		for tooth in 8:
			var angle := tooth * TAU / 8.0
			var direction := Vector2.from_angle(angle)
			var tangent := direction.orthogonal() * 1.35
			draw_colored_polygon(PackedVector2Array([center + direction * 4.5 - tangent, center + direction * 7.2 - tangent, center + direction * 7.2 + tangent, center + direction * 4.5 + tangent]), color)
		draw_arc(center, 4.3, 0, TAU, 64, color, 2.5, true)
