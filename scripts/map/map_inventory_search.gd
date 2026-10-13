extends LineEdit
## Vector magnifiers stay crisp at the inventory canvas scale.
func _init() -> void:
	name = "ItemSearch"
	placeholder_text = "搜索物品名称..."
	custom_minimum_size = Vector2(200,30)
	size_flags_horizontal = SIZE_EXPAND_FILL
	resized.connect(queue_redraw)

func _draw() -> void:
	for x in [14.0,size.x-15.0]:
		var center := Vector2(x,size.y*0.5-1)
		draw_arc(center,5,0,TAU,32,Color("8a9da6"),1.5,true)
		draw_line(center+Vector2(3.5,3.5),center+Vector2(7,7),Color("8a9da6"),1.5,true)
