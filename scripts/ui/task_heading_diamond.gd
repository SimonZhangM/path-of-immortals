extends Control
## Shared design-pixel geometry; source-canvas callers compensate their local scale.
const DIAGONAL := 14.0 * 0.85
const LINE_WIDTH := 2.0 * 0.85
var units_per_design_pixel := 1.0:
	set(value):
		if is_equal_approx(units_per_design_pixel,value): return
		units_per_design_pixel = value
		queue_redraw()
var color := Color("e1bf77")

func _init(footprint := Vector2(16,40), tint := Color("e1bf77")) -> void:
	name = "GoldDiamond"
	custom_minimum_size = footprint
	color = tint
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var center := size * 0.5
	var radius := DIAGONAL * units_per_design_pixel * 0.5
	var points := PackedVector2Array([
		center+Vector2(0,-radius),center+Vector2(radius,0),
		center+Vector2(0,radius),center+Vector2(-radius,0),center+Vector2(0,-radius)])
	draw_polyline(points,color,LINE_WIDTH*units_per_design_pixel,true)
