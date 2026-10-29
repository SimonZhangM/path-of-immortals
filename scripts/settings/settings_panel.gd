extends Control
## Shared five-page view. Draft values are applied only through GameSettings.
signal closed
const Settings = preload("res://scripts/settings/game_settings.gd")
const Toggle = preload("res://scripts/settings/settings_toggle.gd")
const GOLD := Color("e5bd6e")
const INK := Color("101e2d")
var canvas: Control
var pages: Dictionary = {}
var tabs: Dictionary = {}
var widgets: Dictionary = {}
var heading_origins: Dictionary = {}
var first_rows: Dictionary = {}
var draft: Dictionary = {}
var current_page := "game"
var capture_action := ""
var message: Label
var reset_button: Button
var cancel_button: Button
var apply_button: Button
var _config: Dictionary
var _font := SystemFont.new()
var _tab_font := FontVariation.new()
var _dropdown_arrow: Texture2D
var _service: Node
var _finished := false
var _refreshing := false
var _key_buttons: Dictionary = {}

func _ready() -> void:
	name = "SystemSettings"
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 90
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_font.font_names = PackedStringArray(["SimSun","宋体","Noto Serif CJK SC","serif"])
	_tab_font.base_font = _font
	_tab_font.variation_embolden = 0.8
	var arrow_image := Image.new()
	arrow_image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="16" viewBox="0 0 24 16"><path d="M3 4 L12 12 L21 4" fill="none" stroke="white" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/></svg>')
	_dropdown_arrow = ImageTexture.create_from_image(arrow_image)
	_config = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/system_settings.json"))
	_service = get_node("/root/GameSettings")
	draft = Settings.values_snapshot().duplicate(true)
	var shade := ColorRect.new()
	shade.color = Color(0,0,0,0.6)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas = Control.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.size = Vector2(_config.source_size[0],_config.source_size[1])
	add_child(canvas)
	var art := TextureRect.new()
	art.texture = load(_config.frame)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.position.y = float(_config.frame_offset_y)
	_build_tabs()
	for tab: Dictionary in _config.tabs:
		var page := Control.new()
		page.name = tab.id
		page.mouse_filter = Control.MOUSE_FILTER_IGNORE
		page.position = Vector2(_config.content_rect[0],_config.content_rect[1])
		page.size = Vector2(_config.content_rect[2],_config.content_rect[3])
		canvas.add_child(page)
		pages[tab.id] = page
	_build_game()
	_build_controls()
	_build_display()
	_build_audio()
	_build_other()
	_line(canvas,Vector2(88,793),1496)
	reset_button = _button(canvas,"恢复默认",Rect2(108,824,230,58))
	cancel_button = _button(canvas,"取消",Rect2(1110,824,190,58))
	apply_button = _button(canvas,"应用并关闭",Rect2(1330,824,230,58))
	reset_button.pressed.connect(_reset_page)
	cancel_button.pressed.connect(cancel)
	apply_button.pressed.connect(apply)
	message = _label(canvas,"",Rect2(365,812,710,78),23)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_color_override("font_color",Color("edd29a"))
	resized.connect(_layout)
	_layout()
	_refresh_values()
	select_page("game")

func _build_tabs() -> void:
	var row := HBoxContainer.new()
	row.position = Vector2(104,72)
	row.size = Vector2(1464,72)
	row.add_theme_constant_override("separation",0)
	canvas.add_child(row)
	for tab: Dictionary in _config.tabs:
		var button := Button.new()
		button.name = "Tab_"+tab.id
		button.text = tab.label
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_override("font",_tab_font)
		button.add_theme_font_size_override("font_size",38)
		for kind in ["normal","hover","pressed","focus"]: button.add_theme_stylebox_override(kind,StyleBoxEmpty.new())
		button.add_theme_color_override("font_hover_color",GOLD)
		row.add_child(button)
		button.pressed.connect(select_page.bind(String(tab.id)))
		var underline := ColorRect.new()
		underline.name = "Selected"
		underline.color = GOLD
		underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(underline)
		underline.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		underline.offset_left = 52
		underline.offset_right = -52
		underline.offset_top = -4
		tabs[tab.id] = button
	_line(canvas,Vector2(88,157),1496)

func _heading(page: Control, title: String, x := 0.0, width := 660.0) -> void:
	var row := HBoxContainer.new()
	row.position = Vector2(x,0)
	row.size = Vector2(width,54)
	row.add_theme_constant_override("separation",12)
	page.add_child(row)
	var icon := TextureRect.new()
	icon.texture = load(_config.heading_icon)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(32,36)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var label := _label(row,title,Rect2(),34)
	label.custom_minimum_size = Vector2(210,54)
	var rule := HSeparator.new()
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.add_theme_stylebox_override("separator",_rule_style())
	row.add_child(rule)
	if x==0: heading_origins[String(page.name)] = row

func _row(page: Control, text: String, y: float, x := 44.0, width := 620.0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.position = Vector2(x,y)
	row.size = Vector2(width,60)
	row.add_theme_constant_override("separation",20)
	page.add_child(row)
	var label := _label(row,text,Rect2(),29)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size = Vector2(230,60)
	if is_equal_approx(y,float(_config.first_row_y)) and is_equal_approx(x,44.0): first_rows[String(page.name)] = row
	return row

func _build_game() -> void:
	var page: Control = pages.game
	_heading(page,"体验设置")
	_heading(page,"存档设置",780,660)
	var divider := ColorRect.new()
	divider.color = Color(0.9,0.73,0.4,0.45)
	divider.position = Vector2(732,10)
	divider.size = Vector2(1,540)
	page.add_child(divider)
	_choice(_row(page,"对话文字速度",90),"dialogue_speed",[["慢","slow"],["中","medium"],["快","fast"],["立即显示","instant"]],220)
	_toggle(_row(page,"对话自动播放",200),"dialogue_auto")
	_choice(_row(page,"默认战斗倍速",310),"battle_speed",[["0.5倍",0.5],["1倍",1.0],["2倍",2.0]],220)
	_toggle(_row(page,"后台自动暂停",420),"background_pause")
	_toggle(_row(page,"自动存档",90,824,600),"auto_save")
	_hint(page,"按设定间隔保存进度",Vector2(824,154))
	_choice(_row(page,"自动保存间隔",250,824,600),"auto_save_minutes",[["5分钟",5],["10分钟",10],["15分钟",15],["30分钟",30]],220)
	_toggle(_row(page,"快速存档",410,824,600),"quick_save")
	_hint(page,"动作完成或战斗前保存",Vector2(824,474))

func _build_controls() -> void:
	var page: Control = pages.controls
	_heading(page,"自定义按键",0,1420)
	_hint(page,"点击键位后按下新按键，Esc取消",Vector2(840,54))
	for index in _config.bindings.size():
		var spec: Dictionary = _config.bindings[index]
		var row := _row(page,spec.label,90+index*46,44,1380)
		row.size.y = 44
		(row.get_child(0) as Control).custom_minimum_size.y = 44
		# Keep the original key column and row centers; shrink its artwork and
		# lettering together instead of moving the whole column to the right.
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.custom_minimum_size = Vector2(190,44)
		row.add_child(holder)
		var button := _button(holder,"",Rect2(0,0,190,48))
		button.custom_minimum_size = Vector2(190,48)
		button.scale = Vector2(0.8,0.8)
		for kind in ["normal","disabled","hover","pressed","hover_pressed"]:
			button.get_theme_stylebox(kind).content_margin_top = 4
			button.get_theme_stylebox(kind).content_margin_bottom = 4
		holder.resized.connect(_center_key_button.bind(button,holder))
		button.resized.connect(_center_key_button.bind(button,holder))
		_center_key_button(button,holder)
		button.pressed.connect(_capture_key.bind(String(spec.action)))
		_key_buttons[spec.action] = button
		_line(page,Vector2(44,135+index*46),1380,0.16)
	_toggle(_row(page,"地图缩放滚轮反向",524,44,650),"invert_zoom")
	_toggle(_row(page,"快捷键提示",524,824,600),"shortcut_hints")

func _center_key_button(button: Control, holder: Control) -> void:
	button.pivot_offset = button.size*0.5
	button.position = (holder.size-button.size)*0.5

func _build_display() -> void:
	var page: Control = pages.display
	_heading(page,"显示设置",0,1420)
	_choice(_row(page,"显示模式",90,44,680),"display_mode",[["窗口","windowed"],["无边框全屏","borderless"]],400.0*2.0/3.0)
	var options := []
	for resolution: Vector2i in _service.available_resolutions(): options.append(["%d × %d" % [resolution.x,resolution.y],resolution])
	var native: Vector2i = _service.native_resolution()
	if not _service.available_resolutions().has(native): options.append(["%d × %d" % [native.x,native.y],native])
	_choice(_row(page,"分辨率",230,44,680),"resolution",options,400.0*2.0/3.0)
	var hint := _hint(page,"全屏使用显示器分辨率",Vector2(44,294))
	hint.name = "ResolutionHint"
	_choice(_row(page,"帧率上限",370,44,680),"fps_limit",[["30帧",30],["60帧",60]],400.0*2.0/3.0)
	_hint(page,"不影响战斗倍速",Vector2(44,434))

func _build_audio() -> void:
	var page: Control = pages.audio
	_heading(page,"音量设置",0,1420)
	_slider(_row(page,"总音量",90,44,1380),"volume_master")
	_slider(_row(page,"音乐音量",210,44,1380),"volume_music")
	_slider(_row(page,"音效音量",330,44,1380),"volume_effects")
	_hint(page,"包含战斗与界面操作声音",Vector2(44,394))
	_toggle(_row(page,"后台静音",470,44,1380),"background_mute")

func _build_other() -> void:
	var page: Control = pages.other
	_heading(page,"版本信息",0,1420)
	var row := _row(page,"当前版本",90,44,1380)
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/start_menu.json"))
	var version := _label(row,String(config.get("version","v0.1")).trim_prefix("版本 "),Rect2(),31)
	version.custom_minimum_size.x = 420
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.add_theme_color_override("font_color",GOLD)

func _toggle(row: Control, key: String) -> void:
	var button := Toggle.new()
	button.add_theme_font_override("font",_font)
	button.add_theme_font_size_override("font_size",29)
	row.add_child(button)
	button.toggled.connect(func(value: bool):
		if _refreshing: return
		draft[key] = value
		_refresh_dependencies())
	widgets[key] = button

func _choice(row: Control, key: String, options: Array, width: float) -> void:
	var button := OptionButton.new()
	button.custom_minimum_size = Vector2(width,56)
	button.focus_mode = Control.FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_style_button(button,String(_config.dropdown_normal))
	button.add_theme_icon_override("arrow",_dropdown_arrow)
	button.add_theme_constant_override("arrow_margin",18)
	button.add_theme_constant_override("modulate_arrow",1)
	for kind in ["normal","disabled","hover","pressed","hover_pressed"]:
		var style := button.get_theme_stylebox(kind) as StyleBoxTexture
		style.set_texture_margin_all(12)
		style.content_margin_left = 16 if width<300 else 20
		style.content_margin_right = 46 if width<300 else 50
	for option: Array in options:
		button.add_item(String(option[0]))
		button.set_item_metadata(button.item_count-1,option[1])
	var popup := button.get_popup()
	popup.add_theme_font_override("font",_font)
	popup.add_theme_font_size_override("font_size",27)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = INK
	panel_style.border_color = GOLD
	panel_style.set_border_width_all(2)
	panel_style.set_content_margin_all(14)
	popup.add_theme_stylebox_override("panel",panel_style)
	var selected := StyleBoxFlat.new()
	selected.bg_color = Color("4b402c")
	popup.add_theme_stylebox_override("hover",selected)
	popup.add_theme_color_override("font_color",Color("f3ebd4"))
	row.add_child(button)
	button.item_selected.connect(func(index: int):
		if _refreshing: return
		draft[key] = button.get_item_metadata(index)
		if key=="display_mode":
			var candidates: Array = _service.available_resolutions()
			if draft.display_mode=="borderless": draft.resolution = _service.native_resolution()
			elif not candidates.has(draft.resolution) and not candidates.is_empty(): draft.resolution = candidates.back()
			_refresh_values()
		_refresh_dependencies())
	widgets[key] = button

func _slider(row: Control, key: String) -> void:
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(730,56)
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.focus_mode = Control.FOCUS_NONE
	var track := StyleBoxFlat.new()
	track.bg_color = INK
	track.border_color = Color("766647")
	track.set_border_width_all(1)
	track.set_corner_radius_all(5)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	slider.add_theme_stylebox_override("slider",track)
	var filled := track.duplicate() as StyleBoxFlat
	filled.bg_color = GOLD
	slider.add_theme_stylebox_override("grabber_area",filled)
	slider.add_theme_stylebox_override("grabber_area_highlight",filled)
	var knob := GradientTexture2D.new()
	knob.width = 32
	knob.height = 32
	knob.fill = GradientTexture2D.FILL_RADIAL
	knob.fill_from = Vector2(0.5,0.5)
	knob.fill_to = Vector2(1,0.5)
	knob.gradient = Gradient.new()
	knob.gradient.offsets = PackedFloat32Array([0,0.75,0.87,0.94,1])
	knob.gradient.colors = PackedColorArray([Color("ffe8b3"),Color("f2c46d"),Color("fff0c7"),Color("c29245"),Color(0,0,0,0)])
	slider.add_theme_icon_override("grabber",knob)
	slider.add_theme_icon_override("grabber_highlight",knob)
	row.add_child(slider)
	var value := _label(row,"",Rect2(),29)
	value.custom_minimum_size = Vector2(110,56)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	slider.value_changed.connect(func(amount: float):
		value.text = "%d%%" % roundi(amount)
		if _refreshing: return
		draft[key] = amount/100.0
		_service.preview_audio(draft))
	slider.set_meta("value_label",value)
	widgets[key] = slider

func _button(parent: Control, text: String, rect: Rect2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.focus_mode = Control.FOCUS_NONE
	_style_button(button)
	parent.add_child(button)
	return button

func _style_button(button: Button, normal_texture := "") -> void:
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font",_font)
	button.add_theme_font_size_override("font_size",29)
	button.add_theme_color_override("font_color",Color("f3ebd4"))
	button.add_theme_color_override("font_hover_color",Color("171d24"))
	button.add_theme_color_override("font_pressed_color",Color("171d24"))
	button.add_theme_color_override("font_disabled_color",Color("69747b"))
	for kind in ["normal","disabled","hover","pressed","hover_pressed"]:
		var style := StyleBoxTexture.new()
		style.texture = load((_config.button_normal if normal_texture.is_empty() else normal_texture) if kind in ["normal","disabled"] else _config.button_hover)
		style.set_content_margin_all(10)
		button.add_theme_stylebox_override(kind,style)
	button.add_theme_stylebox_override("focus",StyleBoxEmpty.new())

func _label(parent: Node, text: String, rect: Rect2, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font",_font)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color("efe7d2"))
	parent.add_child(label)
	return label

func _hint(parent: Control, text: String, position: Vector2) -> Label:
	var label := _label(parent,text,Rect2(position,Vector2(650,36)),23)
	label.add_theme_color_override("font_color",Color("9aa6ad"))
	return label

func _rule_style() -> StyleBoxLine:
	var rule := StyleBoxLine.new()
	rule.color = Color(0.9,0.73,0.4,0.42)
	rule.thickness = 1
	return rule

func _line(parent: Control, position: Vector2, width: float, opacity := 0.65) -> void:
	var line := ColorRect.new()
	line.color = Color(GOLD,opacity)
	line.position = position
	line.size = Vector2(width,1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)

func _refresh_values() -> void:
	_refreshing = true
	for key: String in widgets:
		var widget: Control = widgets[key]
		if widget is OptionButton:
			for index in widget.item_count:
				if widget.get_item_metadata(index)==draft.get(key): widget.select(index)
		elif widget is HSlider:
			widget.value = float(draft.get(key,1.0))*100.0
			(widget.get_meta("value_label") as Label).text = "%d%%" % roundi(widget.value)
		else: widget.set_value(bool(draft.get(key,false)))
	for action: String in _key_buttons:
		_key_buttons[action].text = _key_name(int(draft.bindings.get(action,0)))
	_refreshing = false
	_refresh_dependencies()

func _refresh_dependencies() -> void:
	widgets.auto_save_minutes.disabled = not bool(draft.get("auto_save",true))
	widgets.resolution.disabled = draft.get("display_mode","borderless")!="windowed"
	pages.display.get_node("ResolutionHint").visible = widgets.resolution.disabled

func select_page(page: String) -> void:
	capture_action = ""
	current_page = page
	for id: String in pages: pages[id].visible = id==page
	for id: String in tabs:
		tabs[id].get_node("Selected").visible = id==page
		tabs[id].add_theme_color_override("font_color",GOLD if id==page else Color("efe7d2"))
	if reset_button!=null: reset_button.disabled = page=="other"
	if message!=null: message.text = ""
	_refresh_values()

func _reset_page() -> void:
	var defaults: Dictionary = _service.defaults_for_page(current_page)
	for key: String in defaults: draft[key] = defaults[key].duplicate(true) if defaults[key] is Dictionary else defaults[key]
	_refresh_values()
	if current_page=="audio": _service.preview_audio(draft)

func _capture_key(action: String) -> void:
	capture_action = action
	_key_buttons[action].text = "请按键…"
	message.text = "按下新的单个按键；Esc取消改键。"

func _key_name(code: int) -> String:
	return "空格" if code==KEY_SPACE else OS.get_keycode_string(code)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _finished or not event is InputEventKey: return
	if not event.pressed or event.echo: return
	if not capture_action.is_empty():
		get_viewport().set_input_as_handled()
		if event.keycode==KEY_ESCAPE:
			capture_action = ""
			message.text = ""
			_refresh_values()
			return
		var code: int = event.physical_keycode if event.physical_keycode!=0 else event.keycode
		if event.ctrl_pressed or event.alt_pressed or event.meta_pressed or event.shift_pressed or code in [KEY_SHIFT,KEY_CTRL,KEY_ALT,KEY_META]:
			message.text = "请使用一个普通按键，不使用组合键。"
			return
		var candidate: Dictionary = draft.bindings.duplicate(true)
		candidate[capture_action] = code
		var binding_error: String = Settings.validate_bindings(candidate)
		if not binding_error.is_empty():
			message.text = binding_error
			return
		draft.bindings = candidate
		capture_action = ""
		message.text = ""
		_refresh_values()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		cancel()

func apply() -> void:
	if not capture_action.is_empty():
		message.text = "请先完成或取消改键。"
		return
	var error: String = _service.apply_values(draft)
	if not error.is_empty():
		message.text = error
		return
	_finished = true
	closed.emit()

func cancel() -> void:
	_service.cancel_preview()
	_finished = true
	closed.emit()

func _exit_tree() -> void:
	if not _finished and is_instance_valid(_service): _service.cancel_preview()

func _layout() -> void:
	if canvas==null: return
	# Exactly the same fitting and screen-center rule as UI-start-saveload.
	var factor := minf(size.x*_config.viewport_fraction[0]/canvas.size.x,size.y*_config.viewport_fraction[1]/canvas.size.y)
	canvas.scale = Vector2.ONE*factor
	canvas.position = (size-canvas.size*factor)*0.5
