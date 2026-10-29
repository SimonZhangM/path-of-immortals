extends Button
## Outer label capsule with an inset track and a sliding, smaller thumb.
const GOLD := Color("e8bc65")
const TRACK_SIZE := Vector2(82,42)
const THUMB_RADIUS := 16.5
var _motion: Tween
var _track := StyleBoxFlat.new()
var _knob_progress := 0.0:
	set(value):
		_knob_progress = value
		queue_redraw()

func _init() -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(180,56)
	alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_track.set_border_width_all(1)
	_track.set_corner_radius_all(21)
	toggled.connect(_on_toggled)

func _ready() -> void:
	set_value(button_pressed)

func set_value(value: bool) -> void:
	if _motion!=null: _motion.kill()
	set_pressed_no_signal(value)
	_knob_progress = 1.0 if value else 0.0
	refresh()

func _on_toggled(value: bool) -> void:
	refresh()
	if _motion!=null: _motion.kill()
	_motion = create_tween()
	_motion.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_motion.tween_property(self,"_knob_progress",1.0 if value else 0.0,0.18)

func refresh() -> void:
	text = "开启" if button_pressed else "关闭"
	for kind in ["normal","hover","pressed","hover_pressed","disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("d5aa5d") if button_pressed else Color("1d3445")
		if kind=="hover" or kind=="hover_pressed": style.bg_color = style.bg_color.lightened(0.13)
		style.border_color = GOLD if button_pressed else Color("929fac")
		style.set_border_width_all(2)
		style.set_corner_radius_all(28)
		style.content_margin_left = 100
		style.content_margin_right = 20
		add_theme_stylebox_override(kind,style)
	add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	for color_name in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color"]:
		add_theme_color_override(color_name,Color("181d24") if button_pressed else Color("d6dce0"))
	queue_redraw()

func _draw() -> void:
	var track_rect := Rect2(Vector2(12,(size.y-TRACK_SIZE.y)*0.5),TRACK_SIZE)
	_track.bg_color = Color("112635").lerp(Color("82602e"),_knob_progress)
	_track.border_color = Color("637785").lerp(Color("b98b42"),_knob_progress)
	draw_style_box(_track,track_rect)
	var center := Vector2(lerpf(track_rect.position.x+21,track_rect.end.x-21,_knob_progress),size.y*0.5)
	draw_circle(center+Vector2(1,2),THUMB_RADIUS+0.5,Color(0,0,0,0.5),true,-1,true)
	draw_circle(center,THUMB_RADIUS,Color("a6b3bd").lerp(Color("f5d78c"),_knob_progress),true,-1,true)
	draw_circle(center-Vector2(0.5,0.5),THUMB_RADIUS-2.5,Color("ced5db").lerp(Color("ffe7a8"),_knob_progress),true,-1,true)
