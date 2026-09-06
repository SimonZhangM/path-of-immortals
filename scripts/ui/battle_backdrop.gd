extends Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("101d23"))
	draw_circle(size * Vector2(0.49, 0.34), size.y * 0.22, Color("b5ab79", 0.035))
	draw_circle(size * Vector2(0.49, 0.34), size.y * 0.13, Color("b5ab79", 0.045))
	for layer in range(3):
		var points := PackedVector2Array([Vector2(0, size.y)])
		for index in range(17):
			var x := float(index) / 16.0
			var ridge := 0.36 + layer * 0.18 + sin(index * 2.3 + layer) * 0.07 + sin(index * 0.8) * 0.08
			points.append(Vector2(x * size.x, ridge * size.y))
		points.append(size)
		draw_colored_polygon(points, [Color("203238"), Color("1a2a30"), Color("14232a")][layer])
