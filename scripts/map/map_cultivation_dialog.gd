class_name MapCultivationDialog
extends Control

signal cancelled
signal cultivation_requested(mode_id: String, duration_days: int)

const FRAME := Rect2(32,32,1474,840)
const INK := Color("fbf4bf")
const BLUE := Color("92c4d9")
const GOLD := Color("ffda69")
const PICTURE_FRAME := preload("res://assets/tanchuang-huifu-picframe.webp")
const METRICS := preload("res://scripts/map/map_texture_metrics.gd")
# Match the visible height of the original selected cultivation icon.
const MODE_IMAGE_HEIGHT := 84.0
const MODE_IMAGE_CENTER_Y := 379.0
var canvas: Control
var backing: TextureRect
var illustration: TextureRect
var heading: Label
var description: Label
var mode_heading: Label
var duration_heading: Label
var leave_button: Button
var start_button: TextureButton
var start_label: Label
var notice: Label
var mode_buttons: Array[Button]=[]
var mode_images: Array[TextureRect]=[]
var mode_names: Array[Label]=[]
var mode_notes: Array[Label]=[]
var duration_buttons: Array[Button]=[]
var selected_mode := ""
var selected_days := 10
var _event: Dictionary={}
var _geometry: Array[Control]=[]
var _kai:=SystemFont.new()
var _hei:=SystemFont.new()
var _harmony:=SystemFont.new()

func _init() -> void:
	name="MapCultivationDialog"
	z_index=42
	mouse_filter=MOUSE_FILTER_STOP
	texture_filter=TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	hide()
	_kai.font_names=PackedStringArray(["KaiTi","楷体","STKaiti","serif"])
	_hei.font_names=PackedStringArray(["SimHei","黑体","Microsoft YaHei","sans-serif"])
	_harmony.font_names=PackedStringArray(["HarmonyOS Sans SC","鸿蒙简体","sans-serif"])
	_harmony.font_weight=400
	var shade:=ColorRect.new()
	shade.color=Color(0.01,0.02,0.03,0.65)
	shade.mouse_filter=MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	canvas=Control.new()
	canvas.mouse_filter=MOUSE_FILTER_IGNORE
	add_child(canvas)
	backing=_image(FRAME)
	backing.stretch_mode=TextureRect.STRETCH_SCALE
	var picture_rect:=Rect2(Vector2(460,451)-PICTURE_FRAME.get_size()*0.5,PICTURE_FRAME.get_size())
	illustration=_image(picture_rect.grow(-4))
	illustration.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	illustration.clip_contents=true
	_image(picture_rect).texture=PICTURE_FRAME
	heading=_label("",Rect2(936,107,270,81),50)
	heading.add_theme_font_override("font",_hei)
	description=_label("",Rect2(850,200,562,70),21,HORIZONTAL_ALIGNMENT_LEFT)
	description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	leave_button=Button.new()
	leave_button.focus_mode=FOCUS_NONE
	leave_button.mouse_default_cursor_shape=CURSOR_POINTING_HAND
	leave_button.add_theme_font_override("font",_hei)
	leave_button.set_meta("source_font_size",27)
	for state in ["normal","hover","pressed","disabled","focus"]:
		var style:=StyleBoxEmpty.new()
		style.content_margin_right=26
		leave_button.add_theme_stylebox_override(state,style)
	for color in ["font_color","font_hover_color","font_pressed_color"]:
		leave_button.add_theme_color_override(color,INK)
	_place(leave_button,Rect2(1216,122,204,55))
	leave_button.pressed.connect(func(): cancelled.emit())
	mode_heading=_label("修炼方式",Rect2(1033,276,200,37),26,HORIZONTAL_ALIGNMENT_CENTER)
	mode_heading.add_theme_font_override("font",_harmony)
	for index in 3:
		var x: float=[872.0,1060.0,1244.0][index]
		var button:=_choice(Rect2(x,326,149,181))
		button.pressed.connect(func(): select_mode(str(_event.modes[index].id)))
		mode_buttons.append(button)
		mode_images.append(_image(Rect2(x+24,334,101,90)))
		mode_names.append(_label("",Rect2(x+1,425,147,29),23,HORIZONTAL_ALIGNMENT_CENTER))
		mode_notes.append(_label("",Rect2(x+4,463,141,39),16,HORIZONTAL_ALIGNMENT_CENTER))
	duration_heading=_label("修炼时间",Rect2(1033,546,200,37),26,HORIZONTAL_ALIGNMENT_CENTER)
	duration_heading.add_theme_font_override("font",_harmony)
	for index in 3:
		var button:=_choice(Rect2([872,1060,1244][index],597,149,43))
		button.add_theme_font_override("font",_kai)
		button.set_meta("source_font_size",25)
		button.pressed.connect(func(): select_days(int(_event.durations[index])))
		duration_buttons.append(button)
	_label("修炼期间将消耗时间，获得相应的修炼收益。",Rect2(866,647,540,28),17,HORIZONTAL_ALIGNMENT_CENTER)
	start_button=TextureButton.new()
	start_button.texture_normal=preload("res://assets/tanchuang-baoxiang-dakai1.webp")
	start_button.texture_hover=preload("res://assets/tanchuang-baoxiang-dakai2.webp")
	start_button.texture_pressed=start_button.texture_hover
	start_button.ignore_texture_size=true
	start_button.stretch_mode=TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	start_button.focus_mode=FOCUS_NONE
	start_button.mouse_default_cursor_shape=CURSOR_POINTING_HAND
	_place(start_button,Rect2(984,700,300,96))
	start_label=_label("进入修炼状态",Rect2(984,700,300,96),30,HORIZONTAL_ALIGNMENT_CENTER)
	start_label.add_theme_color_override("font_color",Color.WHITE)
	start_button.mouse_entered.connect(func(): _start_hover(true))
	start_button.mouse_exited.connect(func(): _start_hover(false))
	start_button.pressed.connect(func():
		if visible and not _event.is_empty(): cultivation_requested.emit(selected_mode,selected_days)
	)
	notice=_label("",Rect2(850,789,562,26),17,HORIZONTAL_ALIGNMENT_CENTER)
	resized.connect(_layout)

func _place(control: Control, rect: Rect2) -> void:
	control.set_meta("source_rect",rect)
	_geometry.append(control)
	canvas.add_child(control)

func _image(rect: Rect2) -> TextureRect:
	var art:=TextureRect.new()
	art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter=MOUSE_FILTER_IGNORE
	_place(art,rect)
	return art

func _label(text: String, rect: Rect2, font_size: int, alignment:=HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label:=Label.new()
	label.text=text
	label.mouse_filter=MOUSE_FILTER_IGNORE
	label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment=alignment
	label.add_theme_font_override("font",_kai)
	label.add_theme_color_override("font_color",INK)
	label.set_meta("source_font_size",font_size)
	_place(label,rect)
	return label

func _choice(rect: Rect2) -> Button:
	var button:=Button.new()
	button.focus_mode=FOCUS_NONE
	button.mouse_default_cursor_shape=CURSOR_POINTING_HAND
	_place(button,rect)
	return button

func _style(button: Button, active: bool) -> void:
	var style:=StyleBoxFlat.new()
	style.bg_color=Color("34290c") if active else Color("0b1922")
	style.bg_color.a=0.86 if active else 0.72
	style.border_color=GOLD if active else BLUE
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.shadow_color=Color(1,0.75,0.2,0.25)
	style.shadow_size=5 if active else 0
	for state in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
		button.add_theme_stylebox_override(state,style)
	for color in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color"]:
		button.add_theme_color_override(color,INK if active else BLUE)

func present(event: Dictionary) -> void:
	_event=event.duplicate(true)
	var atlas:=AtlasTexture.new()
	atlas.atlas=load(event.presentation.background)
	atlas.region=FRAME
	backing.texture=atlas
	illustration.texture=load(event.presentation.illustration)
	heading.text=event.title
	description.text=event.description
	leave_button.text=event.leave_label
	selected_mode=event.default_mode
	selected_days=int(event.default_days)
	notice.text=""
	_refresh_choices()
	show()
	_layout()

func select_mode(id: String) -> void:
	if not _event.modes.any(func(mode): return mode.id==id): return
	selected_mode=id
	notice.text=""
	_refresh_choices()

func select_days(days: int) -> void:
	if not _event.durations.any(func(value): return int(value)==days): return
	selected_days=days
	notice.text=""
	_refresh_choices()

func _refresh_choices() -> void:
	for index in 3:
		var mode: Dictionary=_event.modes[index]
		var active: bool=mode.id==selected_mode
		_style(mode_buttons[index],active)
		var texture: Texture2D=load(mode.selected_image if active else mode.image)
		_set_mode_image(index,texture)
		mode_names[index].text=mode.name
		mode_names[index].add_theme_color_override("font_color",INK if active else BLUE)
		mode_notes[index].text=mode.description
		mode_notes[index].add_theme_color_override("font_color",INK if active else Color("bad1da"))
		duration_buttons[index].text="%d天" % int(_event.durations[index])
		_style(duration_buttons[index],int(_event.durations[index])==selected_days)
	_layout()

func _set_mode_image(index: int, texture: Texture2D) -> void:
	var metrics: Dictionary=METRICS.inspect(texture)
	var used:=Rect2(metrics.used_rect)
	var visible_rect:=Rect2(metrics.visible_rect)
	var art_scale:=MODE_IMAGE_HEIGHT/maxf(visible_rect.size.y,1.0)
	var card_rect: Rect2=mode_buttons[index].get_meta("source_rect")
	var center:=Vector2(card_rect.get_center().x,MODE_IMAGE_CENTER_Y)
	var mode: Dictionary=_event.modes[index]
	if mode.id=="technique": art_scale*=0.95
	# Both colors share the latest optical anchor; selection must not move it.
	if mode.id=="cultivation": center.y-=1.0
	elif mode.id=="technique": center.y+=1.0
	# Ignore near-transparent export specks when sizing/centering, but retain them
	# in the atlas so the original artwork is neither stretched nor clipped.
	var atlas:=AtlasTexture.new()
	atlas.atlas=texture
	atlas.region=used
	mode_images[index].texture=atlas
	# Geometry already preserves the texture aspect ratio. Avoid TextureRect's
	# aspect-centered integer fitting introducing another state-dependent offset.
	mode_images[index].stretch_mode=TextureRect.STRETCH_SCALE
	mode_images[index].set_meta("subpixel_art",true)
	mode_images[index].set_meta("source_rect",Rect2(center-(visible_rect.get_center()-used.position)*art_scale,used.size*art_scale))

func _start_hover(active: bool) -> void:
	start_label.add_theme_color_override("font_color",Color.BLACK if active else Color.WHITE)

func _layout() -> void:
	if canvas==null: return
	var factor:=minf(size.x/1920.0,size.y/1080.0)*0.9
	canvas.size=(FRAME.size*factor).round()
	canvas.position=((size-canvas.size)*0.5).round()
	for control in _geometry:
		var rect: Rect2=control.get_meta("source_rect")
		if control.has_meta("source_font_size"):
			control.add_theme_font_size_override("font_size",maxi(1,roundi(float(control.get_meta("source_font_size"))*factor)))
		var target_position: Vector2=(rect.position-FRAME.position)*factor
		var target_size: Vector2=rect.size*factor
		# State images have different transparent margins. Rounding each margin
		# independently would move their visible centers when the color changes.
		control.position=target_position if control.get_meta("subpixel_art",false) else target_position.round()
		control.size=target_size if control.get_meta("subpixel_art",false) else target_size.round()

func _gui_input(_event: InputEvent) -> void:
	accept_event()
