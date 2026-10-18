class_name MapInnLodgingView
extends Control

signal confirmed(room_id: String)
const ORIGIN := Vector2(624,309)
const INK := Color("f8ecc8")
const GREEN := Color("86e79a")
var room_buttons: Array[Button] = []
var room_image: TextureRect
var room_description: Label
var room_title: Label
var bonus_label: Label
var fee_label: Label
var confirm_button: TextureButton
var confirm_label: Label
var message: Label
var selected_room := ""
var busy := false
var _state: MapLoadoutState
var _config: Dictionary = {}
var _kai := SystemFont.new()

func _init() -> void:
	name = "LodgingContent"
	mouse_filter = MOUSE_FILTER_IGNORE
	_kai.font_names = PackedStringArray(["KaiTi","楷体","STKaiti","serif"])
	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation",12)
	_place(choices,Rect2(644,326,348,35))
	for index in 2:
		var button := Button.new()
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		button.focus_mode = FOCUS_NONE
		button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
		button.add_theme_font_override("font",_kai)
		button.add_theme_font_size_override("font_size",24)
		for kind in ["normal","hover","pressed","focus"]: button.add_theme_stylebox_override(kind,StyleBoxEmpty.new())
		button.pressed.connect(func():
			if not busy and index<_config.get("rooms",[]).size(): select_room(_config.rooms[index].id)
		)
		choices.add_child(button)
		room_buttons.append(button)
	# Explicit clipped viewport keeps the picture inside the painted inner frame.
	var clip := Control.new()
	clip.name = "RoomImageClip"
	clip.clip_contents = true
	clip.mouse_filter = MOUSE_FILTER_IGNORE
	_place(clip,Rect2(651,378,336,265))
	room_image = TextureRect.new()
	room_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	room_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	room_image.mouse_filter = MOUSE_FILTER_IGNORE
	clip.add_child(room_image)
	room_image.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	room_description = _label("",Rect2(642,659,352,56),21)
	room_description.add_theme_constant_override("line_spacing",5)
	var available := _label("房况：有空房",Rect2(647,749,344,32),24)
	available.add_theme_color_override("font_color",GREEN)
	room_title = _label("",Rect2(1049,323.5,344,40),30)
	_label("二楼尚有空房，可安心歇息。",Rect2(1043,378,355,27),21)
	_label("住宿效果",Rect2(1093,420,270,30),25,HORIZONTAL_ALIGNMENT_LEFT)
	_label("歇息一晚后，恢复至最佳状态。",Rect2(1072,462,304,27),19)
	for index in 3:
		_label(["气血回满","体力回满","灵力回满"][index],Rect2(1276,495+index*32,111,28),20)
	bonus_label = _label("",Rect2(1058,652,330,28),20)
	bonus_label.add_theme_color_override("font_color",GREEN)
	_label("耗时：1天",Rect2(1114,606,114,27),20,HORIZONTAL_ALIGNMENT_LEFT)
	fee_label = _label("",Rect2(1258,606,128,27),20,HORIZONTAL_ALIGNMENT_LEFT)
	confirm_button = TextureButton.new()
	confirm_button.texture_normal = preload("res://assets/tanchuang-baoxiang-dakai1.webp")
	confirm_button.texture_hover = preload("res://assets/tanchuang-baoxiang-dakai2.webp")
	confirm_button.texture_pressed = confirm_button.texture_hover
	confirm_button.texture_disabled = confirm_button.texture_normal
	confirm_button.ignore_texture_size = true
	confirm_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	confirm_button.focus_mode = FOCUS_NONE
	confirm_button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	_place(confirm_button,Rect2(1068,682,308,86))
	confirm_label = _label("办理住宿",Rect2(1068,682,308,86),32)
	confirm_label.add_theme_color_override("font_color",Color.WHITE)
	confirm_button.mouse_entered.connect(func(): _hover(true))
	confirm_button.mouse_exited.connect(func(): _hover(false))
	confirm_button.pressed.connect(func():
		if not busy and not confirm_button.disabled: confirmed.emit(selected_room)
	)
	message = _label("",Rect2(1047,765,350,24),17)
	message.add_theme_color_override("font_color",Color("f3d58c"))

func _place(control: Control, rect: Rect2) -> void:
	add_child(control)
	control.position = rect.position-ORIGIN
	control.size = rect.size

func _label(text: String, rect: Rect2, font_size: int, alignment := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = alignment
	label.add_theme_font_override("font",_kai)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",INK)
	_place(label,rect)
	return label

func configure(config: Dictionary, state: MapLoadoutState) -> void:
	if _state!=null and _state.changed.is_connected(refresh): _state.changed.disconnect(refresh)
	_config = config
	_state = state
	if _state!=null: _state.changed.connect(refresh)
	selected_room = str(config.get("rooms",[{}])[0].get("id",""))
	busy = false
	refresh()

func select_room(id: String) -> void:
	if busy: return
	selected_room = id
	refresh()

func refresh(notice := "") -> void:
	if _state==null or _config.is_empty():
		confirm_button.disabled = true
		return
	var quote := MapInnLodging.preview(_state,_config,selected_room)
	if not quote.has("room"):
		message.text = quote.error
		confirm_button.disabled = true
		return
	var room: Dictionary = quote.room
	for index in room_buttons.size():
		var option: Dictionary = _config.rooms[index]
		var button := room_buttons[index]
		button.text = option.name
		button.disabled = busy
		var active: bool = selected_room==option.id
		var text_color := Color("fff4c9") if active else Color("e5dcc5")
		for key in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color","font_disabled_color"]:
			button.add_theme_color_override(key,text_color)
		var style := StyleBoxFlat.new()
		# Selected rooms match the main interaction tabs; both rooms retain a rim.
		style.bg_color = Color(0.92,0.73,0.35,0.28) if active else Color(0,0,0,0.1)
		style.border_color = Color("ffe4a1") if active else Color("d8bc79")
		style.set_border_width_all(2 if active else 1)
		style.set_corner_radius_all(5)
		style.shadow_color = Color(1.0,0.78,0.35,0.17)
		style.shadow_size = 5 if active else 0
		for key in ["normal","hover","pressed","hover_pressed","focus","disabled"]:
			button.add_theme_stylebox_override(key,style)
	room_image.texture = load(room.image)
	room_title.text = room.name
	room_description.text = room.description
	bonus_label.text = "修为收益 +%d%% · 持续%d天" % [room.bonus_percent,room.bonus_days]
	fee_label.text = "费用：%d灵石" % int(room.fee)
	confirm_button.disabled = busy or not quote.error.is_empty()
	confirm_button.modulate = Color(0.6,0.6,0.6,1) if confirm_button.disabled else Color.WHITE
	message.text = quote.error if not quote.error.is_empty() else (notice if not notice.is_empty() else "住宿后时间推进至次日")
	_hover(confirm_button.is_hovered())

func set_busy(value: bool) -> void:
	busy = value
	refresh()

func _hover(hovering: bool) -> void:
	confirm_label.add_theme_color_override("font_color",Color.BLACK if hovering and not confirm_button.disabled else Color.WHITE)
