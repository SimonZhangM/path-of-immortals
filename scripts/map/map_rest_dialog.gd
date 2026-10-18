class_name MapRestDialog
extends Control

signal rest_requested
signal warehouse_requested
signal cancelled

# Same authored canvas and native-pixel typography as chest observation.
const FRAME := Rect2(32,32,1474,840)
const INK := Color("fbf4bf")
const GOLD := Color("ffda69")
const PICTURE_FRAME := preload("res://assets/tanchuang-huifu-picframe.webp")
const START_IDLE := preload("res://assets/tanchuang-huifu-kaishi1.webp")
const START_HOVER := preload("res://assets/tanchuang-huifu-kaishi2.webp")
const WAREHOUSE_IDLE := preload("res://assets/tanchuang-huifu-cangku1.webp")
const WAREHOUSE_HOVER := preload("res://assets/tanchuang-huifu-cangku2.webp")

var canvas: Control
var backing: TextureRect
var illustration: TextureRect
var picture_frame: TextureRect
var heading: Label
var description: Label
var location_kind: Label
var note: Label
var percentage: Label
var days: Label
var duration_caption: Label
var warning: Label
var start_button: TextureButton
var start_label: Label
var warehouse_button: TextureButton
var warehouse_label: Label
var later_button: Button
var later_arrow: Label
var error_label: Label
var food_button: Button
var food_icon: TextureRect
var food_plus: Label
var food_caption: Label
var food_effects: Label
var food_arrow: Label
var food_choice: MapFoodChoiceDialog
var selected_food_id := ""
var _food_state: MapLoadoutState
var _busy := false
var _geometry: Array[Control] = []
var _kai := SystemFont.new()
var _hei := SystemFont.new()
var _fangsong := FontVariation.new()
var _bold_kai := FontVariation.new()

func _init() -> void:
	name="MapRestDialog"
	z_index=42
	mouse_filter=MOUSE_FILTER_STOP
	texture_filter=TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	hide()
	_kai.font_names=PackedStringArray(["KaiTi","楷体","STKaiti","serif"])
	_hei.font_names=PackedStringArray(["SimHei","黑体","Microsoft YaHei","sans-serif"])
	_bold_kai.base_font=_kai
	_bold_kai.variation_embolden=0.8
	var font:=SystemFont.new()
	font.font_names=PackedStringArray(["FangSong","仿宋","STFangsong","serif"])
	_fangsong.base_font=font
	_fangsong.variation_embolden=0.8
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
	picture_frame=_image(picture_rect)
	picture_frame.texture=PICTURE_FRAME
	heading=_label("",Rect2(936,107,270,81),50)
	heading.add_theme_font_override("font",_hei)
	description=_label("",Rect2(850,221,562,119),26)
	description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	later_button=Button.new()
	later_button.focus_mode=FOCUS_NONE
	later_button.mouse_default_cursor_shape=CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","disabled","focus"]:
		later_button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	_place(later_button,Rect2(1216,122,204,55))
	later_button.pressed.connect(cancel)
	_label("稍后再说",Rect2(1235,128,167,43),27,true).add_theme_font_override("font",_hei)
	later_arrow=_label(">",Rect2(1379,128,18,43),27,true)
	later_arrow.add_theme_font_override("font",_hei)
	location_kind=_label("",Rect2(1026,339,211,42),24,true)
	location_kind.add_theme_font_override("font",_hei)
	_label("状态恢复",Rect2(1141,414,250,54),34).add_theme_font_override("font",_hei)
	_label("所有状态均恢复上限的",Rect2(1081,477,215,43),20)
	percentage=_label("",Rect2(1287,464,104,60),38)
	percentage.add_theme_font_override("font",_bold_kai)
	percentage.add_theme_color_override("font_color",GOLD)
	duration_caption=_label("耗时",Rect2(1119,530,54,27),15,true)
	days=_label("",Rect2(1121,554,31,33),23,true)
	days.add_theme_color_override("font_color",GOLD)
	_label("天",Rect2(1142,555,25,32),20,true)
	note=_label("",Rect2(1246,532,129,57),16)
	note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	warning=_label("状态不满可以休息，但恢复不会超过各上限值。",Rect2(984,622,440,36),18)
	var button_rect:=Rect2(944,684,376,127)
	start_button=TextureButton.new()
	start_button.texture_normal=START_IDLE
	start_button.texture_hover=START_HOVER
	start_button.texture_pressed=START_HOVER
	start_button.texture_disabled=START_IDLE
	start_button.ignore_texture_size=true
	start_button.stretch_mode=TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	start_button.focus_mode=FOCUS_NONE
	start_button.mouse_default_cursor_shape=CURSOR_POINTING_HAND
	_place(start_button,button_rect)
	start_label=_label("",button_rect,34,true)
	start_label.add_theme_font_override("font",_fangsong)
	start_label.add_theme_color_override("font_color",Color.WHITE)
	start_button.mouse_entered.connect(func():_set_hover(true))
	start_button.mouse_exited.connect(func():_set_hover(false))
	start_button.pressed.connect(request_rest)
	warehouse_button=TextureButton.new()
	warehouse_button.texture_normal=WAREHOUSE_IDLE
	warehouse_button.texture_hover=WAREHOUSE_HOVER
	warehouse_button.texture_pressed=WAREHOUSE_HOVER
	warehouse_button.texture_disabled=WAREHOUSE_IDLE
	warehouse_button.ignore_texture_size=true
	warehouse_button.stretch_mode=TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	warehouse_button.focus_mode=FOCUS_NONE
	warehouse_button.mouse_default_cursor_shape=CURSOR_POINTING_HAND
	var warehouse_rect:=Rect2(850,700,270,91)
	_place(warehouse_button,warehouse_rect)
	warehouse_label=_label("进入仓储",warehouse_rect,34,true)
	warehouse_label.add_theme_font_override("font",_fangsong)
	warehouse_button.mouse_entered.connect(func():_set_warehouse_hover(true))
	warehouse_button.mouse_exited.connect(func():_set_warehouse_hover(false))
	warehouse_button.pressed.connect(func():
		if visible and warehouse_button.visible and not _busy: warehouse_requested.emit()
	)
	error_label=_label("",Rect2(850,815,562,23),16,true)
	error_label.add_theme_color_override("font_color",Color("ffb9a8"))
	food_button=Button.new()
	food_button.focus_mode=FOCUS_NONE
	food_button.mouse_default_cursor_shape=CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","focus"]: food_button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	_place(food_button,Rect2(852,600,558,78))
	food_icon=_image(Rect2(879,605,68,68))
	food_plus=_label("+",Rect2(866,602,74,72),52,true)
	food_caption=_label("",Rect2(955,604,440,36),22)
	food_effects=_label("",Rect2(955,638,440,32),20)
	food_effects.add_theme_color_override("font_color",GOLD)
	food_arrow=_label(">",Rect2(1370,614,24,45),30,true)
	food_choice=MapFoodChoiceDialog.new()
	add_child(food_choice)
	food_choice.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	food_choice.food_chosen.connect(func(id: String): selected_food_id=id; _refresh_food())
	food_button.pressed.connect(func():
		if not _busy and _food_state!=null: food_choice.present_food(_food_state,selected_food_id)
	)
	visibility_changed.connect(func():
		if not visible: food_choice.close()
	)
	resized.connect(_layout)

func _place(control: Control, rect: Rect2) -> void:
	control.set_meta("source_rect",rect)
	control.set_meta("default_source_rect",rect)
	_geometry.append(control)
	canvas.add_child(control)

func _image(rect: Rect2) -> TextureRect:
	var art:=TextureRect.new()
	art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter=MOUSE_FILTER_IGNORE
	_place(art,rect)
	return art

func _label(text: String, rect: Rect2, font_size: int, centered:=false) -> Label:
	var label:=Label.new()
	label.text=text
	label.mouse_filter=MOUSE_FILTER_IGNORE
	label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_font_override("font",_kai)
	label.add_theme_color_override("font_color",INK)
	label.set_meta("source_font_size",font_size)
	_place(label,rect)
	return label

func present(event: Dictionary, needs_recovery: bool, state: MapLoadoutState = null) -> void:
	_food_state=state
	if state!=null:
		ItemTooltipHost.bind(food_button,func(_point: Vector2): return selected_food_id,func(_key: String):
			var tooltip := ItemTooltip.new()
			tooltip.configure(state.registry.get_item(selected_food_id),{},-1,0,true)
			return tooltip
		)
	selected_food_id=""
	food_choice.close()
	for control in _geometry: control.set_meta("source_rect",control.get_meta("default_source_rect"))
	var has_food: bool = event.get("allow_food",false)
	later_arrow.visible=not has_food # New artwork already contains its own arrow.
	for control: CanvasItem in [food_button,food_icon,food_plus,food_caption,food_effects,food_arrow]: control.visible=has_food
	if has_food:
		# The new recovery container moves up; the lower band is now the meal slot.
		for control in _geometry:
			var rect: Rect2=control.get_meta("source_rect")
			if rect.position.x>=1080 and rect.position.y>=414 and rect.position.y<=555:
				rect.position.y-=30
				control.set_meta("source_rect",rect)
		location_kind.set_meta("source_rect",Rect2(1026,317,211,42))
		# Same optical center between the header rule and section title on both pages.
		description.set_meta("source_rect",Rect2(850,199,562,123))
		var duration_rect: Rect2=duration_caption.get_meta("source_rect")
		duration_rect.position.y+=3
		duration_caption.set_meta("source_rect",duration_rect)
		warning.set_meta("source_rect",Rect2(902,687,236,74))
		_refresh_food()
	warning.text="状态不满也可以休息，\n但恢复不会超过各上限值。" if has_food else "状态不满可以休息，但恢复不会超过各上限值。"
	var atlas:=AtlasTexture.new()
	atlas.atlas=load(event.presentation.background)
	atlas.region=FRAME
	backing.texture=atlas
	illustration.texture=load(event.presentation.illustration)
	heading.text=event.title
	description.text=event.description
	note.text=event.note
	location_kind.text="室内休息点" if event.rest_kind=="indoor" else "室外休息点"
	percentage.text="%d%%" % int(event.recovery_percent)
	days.text=str(int(event.duration_days))
	start_label.text=event.action_label
	var has_warehouse:=not String(event.get("warehouse_id","")).is_empty()
	warehouse_button.visible=has_warehouse
	warehouse_label.visible=has_warehouse
	var start_rect:=Rect2(1142,700,270,91) if has_warehouse else Rect2(944,684,376,127)
	if has_food: start_rect=Rect2(1142,699,270,91)
	start_button.set_meta("source_rect",start_rect)
	start_label.set_meta("source_rect",start_rect)
	error_label.set_meta("source_rect",Rect2(850,792,562,23) if has_warehouse else Rect2(850,815,562,23))
	error_label.text="" if needs_recovery else "当前状态已满，休息仍会度过%d天。" % int(event.duration_days)
	set_busy(false)
	show()
	_layout()

func _refresh_food() -> void:
	var selected: Dictionary = _food_state.records.get(selected_food_id,{}) if _food_state!=null else {}
	food_icon.visible=not selected.is_empty()
	food_plus.visible=selected.is_empty()
	food_arrow.visible=not selected.is_empty()
	food_caption.text="如有，可选择本次进食菜品" if selected.is_empty() else "本次进食：%s ×1" % selected.name
	food_effects.text="可获得额外恢复效果，及特定辅助加成" if selected.is_empty() else MapFood.meal_summary(selected)
	food_effects.set_meta("source_rect",Rect2(955 if selected.is_empty() else 960,638,440 if selected.is_empty() else 400,32))
	# Keep the full recovery and auxiliary bonus on the second line, clear of the arrow.
	var available: float=440.0 if selected.is_empty() else 400.0
	var text_width:=_kai.get_string_size(food_effects.text,HORIZONTAL_ALIGNMENT_LEFT,-1,20).x
	food_effects.set_meta("source_font_size",mini(20,floori(20.0*available/maxf(text_width,1.0))))
	food_effects.add_theme_color_override("font_color",INK if selected.is_empty() else GOLD)
	if not selected.is_empty(): food_icon.texture=load(selected.icon)
	_layout()

func set_busy(value: bool) -> void:
	_busy=value
	start_button.disabled=value
	warehouse_button.disabled=value
	later_button.disabled=value
	food_button.disabled=value
	_set_hover(start_button.is_hovered())
	_set_warehouse_hover(warehouse_button.is_hovered())

func _set_warehouse_hover(hovered: bool) -> void:
	warehouse_label.add_theme_color_override("font_color",Color.BLACK if hovered and not warehouse_button.disabled else Color.WHITE)

func _set_hover(hovered: bool) -> void:
	start_label.add_theme_color_override("font_color",Color.BLACK if hovered and not start_button.disabled else Color.WHITE)

func request_rest() -> void:
	if not visible or start_button.disabled: return
	rest_requested.emit()

func cancel() -> void:
	if food_choice.visible:
		food_choice.close()
		return
	if visible and not _busy: cancelled.emit()

func _layout() -> void:
	if canvas==null: return
	var factor:=minf(size.x/1920.0,size.y/1080.0)*0.9
	canvas.size=(FRAME.size*factor).round()
	canvas.position=((size-canvas.size)*0.5).round()
	for control in _geometry:
		var rect: Rect2=control.get_meta("source_rect")
		if control.has_meta("source_font_size"):
			control.add_theme_font_size_override("font_size",maxi(1,roundi(float(control.get_meta("source_font_size"))*factor)))
		control.position=((rect.position-FRAME.position)*factor).round()
		control.size=(rect.size*factor).round()
	if warning.text.contains("\n"):
		# The baked warning icon is centered at source y=703; align the first line to it.
		var first_line_center:=warning.size.y*0.5-float(warning.get_line_height())*0.5
		warning.position.y=roundf((703.0-FRAME.position.y)*factor-first_line_center)

func _gui_input(_event: InputEvent) -> void:
	accept_event()
