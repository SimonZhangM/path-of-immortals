extends Control

signal open_requested
signal cancelled

# Source-art geometry; render labels at their final pixel size, not a scaled viewport.
const FRAME := Rect2(32, 32, 1474, 840)
const DISPLAY_SCALE := 0.9
const INK := Color("fbf4bf")
const BACKGROUND := preload("res://assets/tanchuang-baoxiang1.webp")
const RESULT_BACKGROUND := preload("res://assets/tanchuang-baoxiang2.webp")
const PICTURE_FRAME := preload("res://assets/tanchuang-baoxiang-picframe.webp")
const OPEN_IDLE := preload("res://assets/tanchuang-baoxiang-dakai1.webp")
const OPEN_HOVER := preload("res://assets/tanchuang-baoxiang-dakai2.webp")

var canvas: Control
var heading: Label
var location_description: Label
var chest_name: Label
var chest_description: Label
var location_illustration: TextureRect
var location_frame: TextureRect
var chest_image: TextureRect
var later_button: Button
var open_button: TextureButton
var open_label: Label
var error_label: Label
var _geometry: Array[Control] = []
var _kai_font := SystemFont.new()
var _title_font := SystemFont.new()
var _open_font := FontVariation.new()
var _busy := false

func _init(result_stage := false) -> void:
	name = "MapChestObservationDialog"
	z_index = 42
	mouse_filter = MOUSE_FILTER_STOP
	texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	hide()
	_kai_font.font_names = PackedStringArray(["KaiTi", "楷体", "STKaiti", "serif"])
	_title_font.font_names = PackedStringArray(["SimHei", "黑体", "Microsoft YaHei", "sans-serif"])
	var fangsong := SystemFont.new()
	fangsong.font_names = PackedStringArray(["FangSong", "仿宋", "STFangsong", "serif"])
	_open_font.base_font = fangsong
	_open_font.variation_embolden = 0.8
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.03, 0.65)
	shade.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	canvas = Control.new()
	canvas.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(canvas)
	var backing := _image(FRAME)
	var atlas := AtlasTexture.new()
	atlas.atlas = RESULT_BACKGROUND if result_stage else BACKGROUND
	atlas.region = FRAME
	backing.texture = atlas
	backing.stretch_mode = TextureRect.STRETCH_SCALE
	# Center the unmodified 693x694 border in the left-hand artwork area.
	var picture_rect := Rect2(Vector2(460, 451)-PICTURE_FRAME.get_size()*0.5, PICTURE_FRAME.get_size())
	location_illustration = _image(picture_rect.grow(-4))
	location_illustration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	location_illustration.clip_contents = true
	location_frame = _image(picture_rect)
	location_frame.texture = PICTURE_FRAME
	# Both stages share typography; align with each source's heading decoration.
	var header_offset := -14 if result_stage else 0
	heading = _label("", Rect2(936, 107+header_offset, 270, 81), 50)
	heading.add_theme_font_override("font", _title_font)
	location_description = _label("", Rect2(850, 207, 562, 88) if result_stage else Rect2(850, 221, 562, 139), 26 if result_stage else 28)
	location_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not result_stage:
		var chest_rect := Rect2(867, 406, 197, 178)
		chest_image = _image(Rect2(chest_rect.get_center()-chest_rect.size*0.45, chest_rect.size*0.9))
		chest_name = _label("", Rect2(1087, 394, 301, 53), 32)
		chest_name.add_theme_font_override("font", _title_font)
		chest_description = _label("", Rect2(1087, 460, 301, 127), 22)
		chest_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_label("寻幽探秘，或有收获。", Rect2(1026, 629, 211, 42), 19, true)
	later_button = Button.new()
	later_button.name = "Later"
	later_button.focus_mode = FOCUS_NONE
	later_button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		later_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_place(later_button, Rect2(1216, 122+header_offset, 204, 55))
	later_button.pressed.connect(cancel)
	# Same separate title-font labels and arrow as the gathering dialog.
	_label("稍后再说", Rect2(1235, 128+header_offset, 167, 43), 27, true).add_theme_font_override("font", _title_font)
	var later_chevron := _label(">", Rect2(1379, 128+header_offset, 18, 43), 27, true)
	later_chevron.name = "LaterChevron"
	later_chevron.add_theme_font_override("font", _title_font)
	open_button = TextureButton.new()
	open_button.name = "OpenChest"
	open_button.texture_normal = OPEN_IDLE
	open_button.texture_hover = OPEN_HOVER
	open_button.texture_pressed = OPEN_HOVER
	open_button.texture_disabled = OPEN_IDLE
	open_button.ignore_texture_size = true
	open_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	open_button.focus_mode = FOCUS_NONE
	open_button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	var button_rect := Rect2(944, 710, 376, 110) if result_stage else Rect2(944, 684, 376, 127)
	if result_stage:
		button_rect = Rect2(button_rect.get_center()-button_rect.size*0.45,button_rect.size*0.9)
	_place(open_button, button_rect)
	open_label = _label("打开宝匣", button_rect, 34, true)
	open_label.add_theme_font_override("font", _open_font)
	open_label.add_theme_color_override("font_color", Color.WHITE)
	open_button.mouse_entered.connect(func(): _set_hover(true))
	open_button.mouse_exited.connect(func(): _set_hover(false))
	open_button.pressed.connect(request_open)
	error_label = _label("", Rect2(850, 820, 562, 22) if result_stage else Rect2(850, 669, 562, 20), 16, true)
	error_label.add_theme_color_override("font_color", Color("ffb9a8"))
	resized.connect(_layout)

func _place(control: Control, rect: Rect2) -> void:
	control.set_meta("source_rect", rect)
	_geometry.append(control)
	canvas.add_child(control)

func _image(rect: Rect2) -> TextureRect:
	var art := TextureRect.new()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = MOUSE_FILTER_IGNORE
	_place(art, rect)
	return art

func _label(text: String, rect: Rect2, font_size: int, centered := false) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_font_override("font", _kai_font)
	label.add_theme_color_override("font_color", INK)
	label.set_meta("source_font_size", font_size)
	_place(label, rect)
	return label

func present(event: Dictionary) -> void:
	var copy: Dictionary = event.observation
	heading.text = copy.location_name
	location_description.text = copy.location_description
	chest_name.text = copy.chest_name
	chest_description.text = copy.description
	var location_path: String = event.presentation.get("illustration", "")
	var chest_path: String = event.presentation.get("chest_image", "")
	location_illustration.texture = null if location_path.is_empty() else load(location_path)
	chest_image.texture = null if chest_path.is_empty() else load(chest_path)
	error_label.text = ""
	set_busy(false)
	show()
	_layout()

func _set_hover(hovered: bool) -> void:
	open_label.add_theme_color_override("font_color", Color.BLACK if hovered and not _busy else Color.WHITE)

func set_busy(value: bool) -> void:
	_busy = value
	open_button.disabled = value
	later_button.disabled = value
	_set_hover(open_button.is_hovered())

func request_open() -> void:
	if _busy or not visible: return
	set_busy(true)
	open_requested.emit()

func cancel() -> void:
	if _busy or not visible: return
	cancelled.emit()

func _layout() -> void:
	if canvas == null: return
	var factor := minf(size.x / 1920.0, size.y / 1080.0) * DISPLAY_SCALE
	canvas.size = (FRAME.size * factor).round()
	canvas.position = ((size-canvas.size)*0.5).round()
	for control in _geometry:
		var rect: Rect2 = control.get_meta("source_rect")
		if control.has_meta("source_font_size"):
			control.add_theme_font_size_override("normal_font_size" if control is RichTextLabel else "font_size", maxi(1, roundi(float(control.get_meta("source_font_size"))*factor)))
		control.position = ((rect.position-FRAME.position)*factor).round()
		control.size = (rect.size*factor).round()

func _gui_input(_event: InputEvent) -> void:
	accept_event()
