extends Control
## Reusable slot list/details view. The caller supplies load/save actions.
signal closed
signal slot_requested(path: String)
signal action_requested(path: String)
const Catalog = preload("res://scripts/entry/save_catalog.gd")
const CONFIG := "res://data/ui/save_browser.json"
var catalog := Catalog.new()
var in_game := false
var entries: Array[Dictionary] = []
var selected_index := -1
var canvas: Control
var list: ScrollContainer
var rows: VBoxContainer
var row_buttons: Array[Button] = []
var picture: TextureRect
var picture_frame: TextureRect
var chapter_label: Label
var calendar_label: Label
var detail_values: Array[Label] = []
var back_button: Button
var menu_back: Control
var menu_back_button: Button
var menu_back_label: Label
var load_button: Button
var cancel_button: Button
var message: Label
var busy := false
var _config: Dictionary
var _song := SystemFont.new()
var _bold := FontVariation.new()
var _detail_font: Font = preload("res://assets/fonts/HarmonyOS_Sans_SC_Regular.ttf")
var _images: Dictionary = {}

func _ready() -> void:
	name = "SaveBrowser"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_song.font_names = PackedStringArray(["SimSun","宋体","Noto Serif CJK SC","serif"])
	_bold.base_font = _song
	_bold.variation_embolden = 0.8
	_config = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	canvas = Control.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.size = Vector2(_config.source_size[0],_config.source_size[1])
	add_child(canvas)
	_image(load(_config.frame),Rect2(Vector2(0,float(_config.frame_offset_y)),canvas.size),canvas)
	list = ScrollContainer.new()
	list.position = _rect(_config.list_rect).position
	list.size = _rect(_config.list_rect).size
	list.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	canvas.add_child(list)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation",int(_config.row_gap))
	list.add_child(rows)
	picture = _image(null,_rect(_config.picture_rect),canvas)
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture_frame = _image(_texture(_config.picture_frame),_rect(_config.picture_frame_rect),canvas)
	picture_frame.name = "SavePictureFrame"
	chapter_label = _label("",_rect(_config.chapter_rect),int(_config.chapter_font_size),true,canvas)
	calendar_label = _label("",_rect(_config.calendar_rect),int(_config.calendar_font_size),true,canvas)
	for index in _config.detail_labels.size():
		var y := float(_config.detail_centers_y[index])-22
		var field := _label(_config.detail_labels[index],Rect2(_config.detail_label_x,y,125,44),25,false,canvas)
		field.name = "DetailLabel%d" % index
		field.add_theme_font_override("font",_detail_font)
		var value := _label("",Rect2(_config.detail_value_x,y,270,44),25,false,canvas)
		value.add_theme_font_override("font",_detail_font)
		if index == 4: value.add_theme_font_size_override("font_size",23)
		detail_values.append(value)
	if in_game:
		cancel_button = _button("取消",_rect(_config.game_button_cancel_rect))
		cancel_button.pressed.connect(func():
			if not busy: closed.emit())
	back_button = _button("存储" if in_game else "删除",_rect(_config.game_button_store_rect if in_game else _config.button_back_rect))
	back_button.pressed.connect(_request_action)
	load_button = _button("读取",_rect(_config.game_button_load_rect if in_game else _config.button_load_rect))
	load_button.pressed.connect(_request_slot)
	message = _label("",Rect2(140,383,800,170),27,false,canvas)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not in_game: _build_menu_back()
	resized.connect(_layout)
	_layout()
	refresh()

func _build_menu_back() -> void:
	menu_back = Control.new()
	menu_back.name = "MenuBack"
	menu_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(menu_back)
	menu_back_button = Button.new()
	menu_back_button.name = "ReturnToMainMenu"
	menu_back_button.position = _rect(_config.menu_back_button_rect).position
	menu_back_button.size = _rect(_config.menu_back_button_rect).size
	menu_back_button.flat = true
	menu_back_button.focus_mode = Control.FOCUS_NONE
	menu_back_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","disabled","focus"]:
		menu_back_button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	menu_back.add_child(menu_back_button)
	menu_back_button.pressed.connect(func():
		if not busy: closed.emit())
	_image(_texture(_config.menu_back_icon),_rect(_config.menu_back_icon_rect),menu_back)
	menu_back_label = _label("返回游戏" if in_game else "返回主菜单",_rect(_config.menu_back_label_rect),int(_config.chapter_font_size),true,menu_back)
	_image(_texture(_config.menu_back_line),_rect(_config.menu_back_line_rect),menu_back)

func _rect(value: Array) -> Rect2:
	return Rect2(value[0],value[1],value[2],value[3])

func _image(texture: Texture2D, rect: Rect2, parent: Node) -> TextureRect:
	var image := TextureRect.new()
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.position = rect.position
	image.size = rect.size
	parent.add_child(image)
	return image

func _label(text: String, rect: Rect2, font_size: int, bold: bool, parent: Node) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font",_bold if bold else _song)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color("f2e5c4"))
	label.add_theme_color_override("font_shadow_color",Color(0,0,0,0.7))
	label.add_theme_constant_override("shadow_offset_y",1)
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(text: String, rect: Rect2) -> Button:
	var button := Button.new()
	button.position = rect.position
	button.size = rect.size
	button.text = text
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font",_bold)
	button.add_theme_font_size_override("font_size",int(_config.button_font_size))
	button.add_theme_color_override("font_color",Color.WHITE)
	button.add_theme_color_override("font_hover_color",Color.BLACK)
	button.add_theme_color_override("font_pressed_color",Color.BLACK)
	button.add_theme_color_override("font_hover_pressed_color",Color.BLACK)
	button.add_theme_color_override("font_disabled_color",Color("b0b0b0"))
	var normal := StyleBoxTexture.new()
	normal.texture = _texture(_config.game_button_normal if in_game else _config.button_normal)
	var hover := StyleBoxTexture.new()
	hover.texture = _texture(_config.button_hover)
	for kind in ["normal","disabled"]: button.add_theme_stylebox_override(kind,normal)
	for kind in ["hover","pressed","hover_pressed"]: button.add_theme_stylebox_override(kind,hover)
	button.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	canvas.add_child(button)
	return button

func _edge_fade(image: TextureRect) -> void:
	var fade := ShaderMaterial.new()
	fade.shader = preload("res://scripts/map/world_map_scene_fade.gdshader")
	fade.set_shader_parameter("edge_fraction",0.1)
	image.material = fade

func _texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path,"Texture2D"): return null
	if not _images.has(path): _images[path] = load(path)
	return _images[path]

func _set_title_kind(label: Label, badge: TextureRect, text: String, kind: String, rect: Rect2, font_size: int) -> void:
	var definition: Dictionary = _config.save_kind_badges[kind]
	var atlas := AtlasTexture.new()
	atlas.atlas = _texture(definition.texture)
	atlas.region = _rect(definition.frame_region)
	badge.texture = atlas
	# Crop transparent padding: the frame's top-to-bottom height equals title size.
	badge.size = Vector2(font_size*atlas.region.size.x/atlas.region.size.y*_config.save_kind_width_scale,font_size)
	var text_width := ceilf(_bold.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x)+1.0
	label.text = text
	label.position = rect.position
	label.size = Vector2(minf(text_width,rect.size.x-badge.size.x-_config.save_kind_gap),rect.size.y)
	badge.position = Vector2(label.position.x+label.size.x+_config.save_kind_gap,rect.position.y+(rect.size.y-badge.size.y)*0.5)

func refresh() -> void:
	var old_path := str(entries[selected_index].path) if selected_index >= 0 and selected_index < entries.size() else ""
	entries = catalog.entries(true)
	if in_game and catalog.error.is_empty():
		var vacant: Dictionary = catalog.next_manual_slot()
		var record: Dictionary = catalog.describe(vacant.path,int(vacant.slot))
		record.chapter = "空存档位"
		record.calendar = "存储当前进度"
		record.location = ""
		record.saved_at = ""
		record.duration = ""
		record.duration_note = "点击存储，创建一份独立手动存档。"
		record.empty_slot = true
		entries.append(record)
	for child in rows.get_children(): child.free()
	row_buttons.clear()
	for index in entries.size(): _add_row(index)
	message.text = catalog.error if not catalog.error.is_empty() else ("暂无可读取的存档" if entries.is_empty() else "")
	message.visible = not message.text.is_empty()
	selected_index = -1
	var next := -1
	for index in entries.size():
		if in_game and catalog.is_system(entries[index].path) and entries[index].path!=old_path: continue
		if next<0 or entries[index].path == old_path: next = index
	select(next if not entries.is_empty() else -1)

func _add_row(index: int) -> void:
	var record := entries[index]
	var button := Button.new()
	button.name = "SaveSlot%02d" % int(record.slot)
	button.custom_minimum_size = Vector2(_config.row_size[0],_config.row_size[1])
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_NONE
	button.clip_contents = true
	for kind in ["normal","hover","pressed","disabled","focus"]: button.add_theme_stylebox_override(kind,StyleBoxEmpty.new())
	rows.add_child(button)
	row_buttons.append(button)
	var art := AtlasTexture.new()
	art.atlas = _texture(_config.row_frame)
	art.region = _rect(_config.row_frame_region)
	_image(art,Rect2(Vector2.ZERO,button.custom_minimum_size),button)
	var selection := _image(art,Rect2(Vector2.ZERO,button.custom_minimum_size),button)
	selection.name = "Selection"
	var highlight := ShaderMaterial.new()
	highlight.shader = preload("res://scripts/entry/save_frame_highlight.gdshader")
	selection.material = highlight
	if record.get("empty_slot",false) or record.get("empty_system_slot",false):
		_add_empty_thumbnail(button,not record.get("empty_system_slot",false))
	else:
		var thumb := _image(_texture(record.picture),_rect(_config.row_picture_rect),button)
		thumb.name = "Thumbnail"
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_edge_fade(thumb)
	var number := _label("%02d" % int(record.slot),_rect(_config.row_number_rect),28,false,button)
	number.name = "SlotNumber"
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var row_title := _label("",_rect(_config.row_chapter_rect),27,true,button)
	row_title.name = "ChapterTitle"
	var badge := _image(null,Rect2(),button)
	badge.name = "SaveKindBadge"
	_set_title_kind(row_title,badge,record.chapter,record.save_kind,_rect(_config.row_chapter_rect),27)
	badge.visible = not record.get("empty_slot",false)
	var row_date := _label(record.calendar+("·"+record.location if not str(record.location).is_empty() else ""),_rect(_config.row_date_rect),22,true,button)
	row_date.name = "CalendarLocation"
	var saved := _label(record.saved_at,_rect(_config.row_saved_rect),20,false,button)
	saved.name = "SavedAt"
	saved.add_theme_font_override("font",_detail_font)
	saved.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var duration := _label("" if record.get("empty_slot",false) or record.get("empty_system_slot",false) else "游戏时长 "+record.duration,_rect(_config.row_duration_rect),20,false,button)
	duration.name = "Duration"
	duration.add_theme_font_override("font",_detail_font)
	duration.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if in_game and catalog.is_system(record.path) and not record.get("empty_system_slot",false): button.tooltip_text = "快速和自动存档可以读取，不能手动覆盖。"
	button.pressed.connect(select.bind(index))

func select(index: int) -> void:
	if busy: return
	selected_index = index if index >= 0 and index < entries.size() else -1
	for number in row_buttons.size(): row_buttons[number].get_node("Selection").visible = number == selected_index
	load_button.disabled = selected_index < 0 or not entries[selected_index].readable
	load_button.modulate = Color(0.5,0.5,0.5,1.0) if load_button.disabled else Color.WHITE
	back_button.disabled = selected_index<0 or entries[selected_index].get("empty_system_slot",false) or (in_game and catalog.is_system(entries[selected_index].path))
	back_button.modulate = Color(0.5,0.5,0.5,1.0) if back_button.disabled else Color.WHITE
	if selected_index < 0:
		picture.texture = null
		chapter_label.text = ""
		calendar_label.text = ""
		for label in detail_values: label.text = "—"
		return
	var record := entries[selected_index]
	picture.texture = _texture(record.picture)
	chapter_label.text = record.chapter
	var title_width := _bold.get_string_size(chapter_label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,int(_config.chapter_font_size)).x
	chapter_label.size.x = ceilf(title_width)+1.0
	# Match the visible text gap between the first detail caption and its value.
	var caption: Label = canvas.get_node("DetailLabel0")
	var caption_width := _detail_font.get_string_size(caption.text,HORIZONTAL_ALIGNMENT_LEFT,-1,caption.get_theme_font_size("font_size")).x
	var text_gap := float(_config.detail_value_x)-float(_config.detail_label_x)-caption_width
	calendar_label.position.x = chapter_label.position.x+title_width+text_gap
	calendar_label.size.x = _rect(_config.calendar_rect).end.x-calendar_label.position.x
	calendar_label.text = record.calendar
	var values := [record.name,record.rank,record.location,record.duration,record.saved_at]
	for number in detail_values.size(): detail_values[number].text = values[number]
	if record.get("empty_slot",false) or record.get("empty_system_slot",false):
		calendar_label.text = ""
		for label in detail_values: label.text = "—"

func _add_empty_thumbnail(parent: Control, writable := true) -> void:
	var rect := _rect(_config.row_picture_rect).grow(-6.0)
	var frame := Panel.new()
	frame.name = "EmptyThumbnail"
	frame.position = rect.position
	frame.size = rect.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10,0.14,0.18,0.45)
	style.border_color = Color(0.48,0.53,0.55,0.5)
	style.set_border_width_all(1)
	frame.add_theme_stylebox_override("panel",style)
	parent.add_child(frame)
	if not writable: return
	# Draw the plus geometrically so its visible centre is independent of font metrics.
	for dimensions in [Vector2(42,4),Vector2(4,42)]:
		var stroke := ColorRect.new()
		stroke.color = Color(0.64,0.68,0.70,0.8)
		stroke.size = dimensions
		stroke.position = (rect.size-dimensions)*0.5
		stroke.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(stroke)

func _request_action() -> void:
	if busy or selected_index<0 or back_button.disabled: return
	action_requested.emit(entries[selected_index].path)

func show_error(text: String) -> void:
	message.text = text
	message.visible = not text.is_empty()

func _request_slot() -> void:
	if busy or selected_index < 0: return
	var record := catalog.describe(entries[selected_index].path,entries[selected_index].slot)
	if not record.readable:
		refresh()
		message.text = "该存档已不可读取，原文件未改动。"
		message.show()
		return
	slot_requested.emit(record.path)

func _layout() -> void:
	if canvas == null: return
	var factor := minf(size.x*_config.viewport_fraction[0]/canvas.size.x,size.y*_config.viewport_fraction[1]/canvas.size.y)
	canvas.scale = Vector2.ONE*factor
	canvas.position = (size-canvas.size*factor)*0.5
	if menu_back != null:
		menu_back.scale = Vector2.ONE*factor
		menu_back.position = Vector2(_config.menu_back_position[0],_config.menu_back_position[1])*factor

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or busy: return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
