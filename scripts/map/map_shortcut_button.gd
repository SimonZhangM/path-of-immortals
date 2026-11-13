extends Button
## Texture-backed round entry; only the visible circle receives clicks.
var art: Texture2D
var red_dot: Texture2D
var unread := false
var toggle := false
var collapsed := false
var hover_amount := 0.0
var _hover_tween: Tween

func _ready() -> void:
	focus_mode=Control.FOCUS_NONE
	mouse_filter=Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for state in ["normal","hover","pressed","focus","disabled"]:
		add_theme_stylebox_override(state,StyleBoxEmpty.new())
	mouse_entered.connect(func(): _hover_to(1.0))
	mouse_exited.connect(func(): _hover_to(0.0))
	visibility_changed.connect(func():
		if not is_visible_in_tree():
			if _hover_tween!=null: _hover_tween.kill()
			hover_amount=0.0
			queue_redraw())

func _has_point(point: Vector2) -> bool:
	return point.distance_to(size*0.5)<=size.x*0.5+3.0

func _hover_to(value: float) -> void:
	if _hover_tween!=null: _hover_tween.kill()
	_hover_tween=create_tween()
	_hover_tween.tween_method(func(amount: float):
		hover_amount=amount
		queue_redraw(),hover_amount,value,0.14)

func _draw() -> void:
	var center := size*0.5
	var radius := size.x*0.5
	var gold := Color("f6d57f")
	if hover_amount>0.0:
		for i in range(8,0,-1):
			draw_arc(center,radius+float(i)*0.7,0,TAU,96,Color(gold,0.025*hover_amount*float(9-i)),1.5,true)
	if toggle:
		draw_circle(center,radius,Color("092329"))
		draw_arc(center,radius-1,0,TAU,64,Color("b99b51").lerp(gold,hover_amount),1.4,true)
		var direction := -1.0 if collapsed else 1.0
		var points := PackedVector2Array([center+Vector2(-5,-2*direction),center+Vector2(0,3*direction),center+Vector2(5,-2*direction)])
		draw_polyline(points,gold,2,true)
	elif art!=null:
		# Original 314px canvases use a 240px circle; the 627px breakthrough
		# canvas has the equivalent 480px circle and the same central registration.
		# Keep that original registration instead of shifting by differing alpha specks.
		var side := size.x*314.0/240.0
		draw_texture_rect(art,Rect2(center-Vector2.ONE*side*0.5,Vector2.ONE*side),false,Color.WHITE.lerp(Color(1.12,1.1,1.04),hover_amount))
		if hover_amount>0: draw_arc(center,radius,0,TAU,96,Color(gold,hover_amount*0.9),1.3,true)
		if unread and red_dot!=null:
			var dot_size := size.x*0.26
			draw_texture_rect(red_dot,Rect2(Vector2(size.x*0.76,-size.x*0.02),Vector2.ONE*dot_size),false)
