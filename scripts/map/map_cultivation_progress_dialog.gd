class_name MapCultivationProgressDialog
extends Control

signal ended
signal pause_requested
signal board_requested
signal technique_requested

const FRAME := MapCultivationDialog.FRAME
const INK := MapCultivationDialog.INK
const PICTURE_FRAME := MapCultivationDialog.PICTURE_FRAME
# Source-image anchors: heading divider and cultivation-info outer frame top.
# Re-measure these two edges when the stage-two background is replaced.
const STATUS_DESCRIPTION_BAND := Vector2(194,273)
const STATUS_DESCRIPTION_OFFSET_Y := -5.0
const INFO_FRAME_RECTS := [Rect2(863,306,175,61),Rect2(1047,306,175,61),Rect2(1231,306,176,61)]
var canvas: Control
var backing: TextureRect
var illustration: TextureRect
var heading: Label
var description: Label
var location_label: Label
var mode_label: Label
var duration_label: Label
var info_frames: Array[Panel]=[]
var day_label: Label
var cultivation_caption: Label
var technique_caption: Label
var cultivation_percent: Label
var technique_percent: Label
var cultivation_status: Label
var technique_status: Label
var day_bar: CultivationProgressBar
var cultivation_bar: CultivationProgressBar
var technique_bar: CultivationProgressBar
var technique_slot: Button
var technique_slot_image: TextureRect
var technique_slot_plus: Label
var leave_button: Button
var board_button: Button
var pause_button: Button
var end_button: Button
var board_caption: Label
var pause_caption: Label
var end_caption: Label
var pause_note: Label
var technique_choice: MapTechniqueChoiceDialog
var session: MapCultivationSession
var _geometry: Array[Control]=[]
var _kai:=SystemFont.new()
var _hei:=SystemFont.new()
var _harmony:=SystemFont.new()

class TechniqueSlot extends Button:
	func _draw() -> void:
		var box:=Rect2(Vector2(1,1),size-Vector2(2,2))
		var points: Array[Vector2]=[box.position,Vector2(box.end.x,box.position.y),box.end,Vector2(box.position.x,box.end.y)]
		for index in 4:
			draw_dashed_line(points[index],points[(index+1)%4],Color("e2c16c"),1.5,7.0,true,true)

func _init() -> void:
	name="MapCultivationProgressDialog"
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
	heading=_label("修炼中",Rect2(936,107,270,81),50)
	heading.add_theme_font_override("font",_hei)
	description=_label("",Rect2(850,STATUS_DESCRIPTION_BAND.x+STATUS_DESCRIPTION_OFFSET_Y,562,STATUS_DESCRIPTION_BAND.y-STATUS_DESCRIPTION_BAND.x),21)
	leave_button=_button(Rect2(1216,122,204,55))
	var leave_caption:=_label("结束修炼",Rect2(1216,122,178,55),27,HORIZONTAL_ALIGNMENT_CENTER)
	leave_caption.add_theme_font_override("font",_hei)
	leave_button.pressed.connect(func(): ended.emit())
	for spec in [{"name":"修炼信息","y":255},{"name":"修炼进度","y":419}]:
		var label:=_label(spec.name,Rect2(1033,spec.y,200,37),26,HORIZONTAL_ALIGNMENT_CENTER)
		label.add_theme_font_override("font",_harmony)
	# The refreshed artwork omits the three inner outlines. Preserve their old
	# local geometry, translated down with the enclosing frame by 13 source px.
	for rect: Rect2 in INFO_FRAME_RECTS:
		var panel:=Panel.new()
		panel.mouse_filter=MOUSE_FILTER_IGNORE
		var style:=StyleBoxFlat.new()
		style.draw_center=false
		style.border_color=Color("899296")
		style.set_border_width_all(1)
		panel.add_theme_stylebox_override("panel",style)
		_place(panel,rect)
		info_frames.append(panel)
	location_label=_label("",Rect2(912,311,122,50),21,HORIZONTAL_ALIGNMENT_CENTER)
	mode_label=_label("",Rect2(1100,311,119,50),21,HORIZONTAL_ALIGNMENT_CENTER)
	duration_label=_label("",Rect2(1284,311,120,50),21,HORIZONTAL_ALIGNMENT_CENTER)
	_label("已修炼天数",Rect2(916,460,130,34),21)
	_label("修为进度",Rect2(916,525,130,34),22)
	_label("功法进度",Rect2(916,606,130,34),22)
	day_bar=_bar(Rect2(1050,470,284,17),Color("197747"),Color("b6f5a3"))
	cultivation_bar=_bar(Rect2(1050,534,284,17),Color("ac7612"),Color("fff0a2"))
	technique_bar=_bar(Rect2(1050,617,284,17),Color("087eb8"),Color("9deaff"))
	day_label=_label("",Rect2(1341,460,73,34),20,HORIZONTAL_ALIGNMENT_CENTER)
	cultivation_caption=_label("",Rect2(1050,504,284,26),19)
	cultivation_percent=_label("—",Rect2(1341,524,73,34),20,HORIZONTAL_ALIGNMENT_CENTER)
	cultivation_status=_label("",Rect2(1050,555,355,25),17)
	technique_caption=_label("未选择功法",Rect2(1050,587,284,26),19)
	technique_percent=_label("—",Rect2(1341,607,73,34),20,HORIZONTAL_ALIGNMENT_CENTER)
	technique_status=_label("",Rect2(1050,638,355,25),17)
	for status in [cultivation_status,technique_status]: status.add_theme_color_override("font_color",Color("bad1da"))
	technique_slot=TechniqueSlot.new()
	_style_button(technique_slot,true)
	_place(technique_slot,Rect2(404,400.5,112,112))
	technique_slot_plus=_label("+",Rect2(404,395.5,112,112),76,HORIZONTAL_ALIGNMENT_CENTER)
	technique_slot_plus.add_theme_color_override("font_color",Color("f4d47c"))
	technique_slot_image=_image(Rect2(412,408.5,96,96))
	technique_slot_image.hide()
	technique_slot.pressed.connect(func(): technique_requested.emit())
	board_button=_button(Rect2(833,697,197,98))
	pause_button=_button(Rect2(1037,697,197,98))
	end_button=_button(Rect2(1241,697,197,98))
	# Keep the captions aligned as a group; latest visual adjustment moves each
	# 6 source px right, leaving 11 px total optical clearance from center.
	board_caption=_label("阵盘调整",Rect2(844,708,197,41),25,HORIZONTAL_ALIGNMENT_CENTER)
	pause_caption=_label("暂停修炼",Rect2(1048,708,197,41),25,HORIZONTAL_ALIGNMENT_CENTER)
	end_caption=_label("结束修炼",Rect2(1252,708,197,41),25,HORIZONTAL_ALIGNMENT_CENTER)
	_label("调整阵盘与道具",Rect2(838,755,187,31),17,HORIZONTAL_ALIGNMENT_CENTER)
	pause_note=_label("暂歇片刻",Rect2(1042,755,187,31),17,HORIZONTAL_ALIGNMENT_CENTER)
	_label("结束本次修炼",Rect2(1246,755,187,31),17,HORIZONTAL_ALIGNMENT_CENTER)
	board_button.pressed.connect(func(): board_requested.emit())
	pause_button.pressed.connect(func(): pause_requested.emit())
	end_button.pressed.connect(func(): ended.emit())
	var book_view:=_button(Rect2(1050,587,284,26))
	book_view.pressed.connect(func():
		if session!=null: session.view_next_book()
	)
	technique_choice=MapTechniqueChoiceDialog.new()
	add_child(technique_choice)
	technique_choice.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
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

func _style_button(button: Button, slot:=false) -> void:
	button.focus_mode=FOCUS_NONE
	button.mouse_default_cursor_shape=CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","disabled","focus"]:
		var style:=StyleBoxFlat.new()
		style.bg_color=Color(0.03,0.04,0.02,0.45 if slot else 0)
		if state=="hover": style.bg_color=Color(1,0.9,0.5,0.12)
		if state=="pressed": style.bg_color=Color(0,0,0,0.2)
		button.add_theme_stylebox_override(state,style)

func _button(rect: Rect2) -> Button:
	var button:=Button.new()
	_style_button(button)
	_place(button,rect)
	return button

func _bar(rect: Rect2, first: Color, last: Color) -> CultivationProgressBar:
	var bar:=CultivationProgressBar.new()
	bar.start_color=first
	bar.end_color=last
	_place(bar,rect)
	return bar

func present(value: MapCultivationSession) -> void:
	if session!=null and session.changed.is_connected(refresh): session.changed.disconnect(refresh)
	session=value
	session.changed.connect(refresh)
	var atlas:=AtlasTexture.new()
	atlas.atlas=load(session.event.stage_two.background)
	atlas.region=FRAME
	backing.texture=atlas
	illustration.texture=load(session.event.stage_two.illustration)
	description.text=session.event.stage_two.description
	location_label.text=session.event.title
	mode_label.text=session.mode_name
	duration_label.text="持续%d天" % session.duration_days
	refresh()
	show()
	_layout()

func refresh() -> void:
	if session==null: return
	var complete:=session.elapsed_days>=session.duration_days
	heading.text="修炼已满" if complete else ("准备修炼" if not session.started else ("修炼暂停" if session.paused else "修炼中"))
	day_label.text="%d/%d天" % [session.elapsed_days,session.duration_days]
	if session.loadout!=null: day_label.text="%s/%d天" % [CultivationGrowth.display(session.elapsed_days+int(session.loadout.growth.day_usec)/60000000.0),session.duration_days]
	day_bar.ratio=float(session.elapsed_days)/maxi(1,session.duration_days)
	if session.loadout!=null and not complete: day_bar.ratio+=(int(session.loadout.growth.day_usec)/60000000.0)/maxi(1,session.duration_days)
	cultivation_caption.text=session.cultivation_progress.get("caption","")
	cultivation_bar.ratio=session.cultivation_progress.get("ratio",0.0)
	cultivation_percent.text="＋"+CultivationGrowth.display(session.cultivation_gain/100.0)
	var technique:=session.selected_technique()
	technique_caption.text=technique.get("name","未选择功法")
	technique_bar.ratio=session.technique_progress().get("ratio",0.0)
	technique_percent.text="—" if technique.is_empty() else "＋"+CultivationGrowth.display(session.displayed_gain())
	cultivation_status.text=session.status("cultivation")
	technique_status.text=session.status("technique")
	pause_caption.text="开始修炼" if not session.started else ("继续修炼" if session.paused else "暂停修炼")
	pause_note.text="开始本次修行" if not session.started else ("接续当前修行" if session.paused else "暂歇片刻")
	pause_button.disabled=complete
	technique_slot_plus.visible=technique.is_empty()
	technique_slot_image.visible=not technique.is_empty()
	if not technique.is_empty(): technique_slot_image.texture=load(technique.icon)
	technique_caption.tooltip_text="点击书名切换查看本次并修的功法"

func _percentage(progress: Dictionary) -> String:
	if progress.is_empty(): return "—"
	var percent: float=progress.ratio*100.0
	return ("%d%%" % roundi(percent)) if is_equal_approx(percent,roundf(percent)) else ("%.1f%%" % percent)

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

func _gui_input(_event: InputEvent) -> void:
	accept_event()
