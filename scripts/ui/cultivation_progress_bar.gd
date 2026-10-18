class_name CultivationProgressBar
extends Control

var ratio := 0.0:
	set(value):
		ratio=clampf(value,0.0,1.0)
		queue_redraw()
var start_color := Color("167b46")
var end_color := Color("b4f7a5")

func _init() -> void:
	mouse_filter=MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var cut:=minf(4.0,size.y*0.25)
	var outline:=PackedVector2Array([Vector2(cut,0),Vector2(size.x-cut,0),Vector2(size.x,cut),Vector2(size.x,size.y-cut),Vector2(size.x-cut,size.y),Vector2(cut,size.y),Vector2(0,size.y-cut),Vector2(0,cut)])
	draw_colored_polygon(outline,Color("0d1b23"))
	outline.append(outline[0])
	draw_polyline(outline,Color("d9ba70"),1.0,true)
	var fill:=Rect2(Vector2(3,3),Vector2(maxf(0,size.x-6)*ratio,maxf(0,size.y-6)))
	if fill.size.x<=0: return
	# Endpoint colors are fixed; the gradient stretches across the filled width.
	draw_polygon(PackedVector2Array([fill.position,Vector2(fill.end.x,fill.position.y),fill.end,Vector2(fill.position.x,fill.end.y)]),PackedColorArray([start_color,end_color,end_color,start_color]))
	draw_line(fill.position,Vector2(fill.end.x,fill.position.y),end_color.lightened(0.2),1.0,true)
