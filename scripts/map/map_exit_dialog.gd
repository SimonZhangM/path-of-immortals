class_name MapExitDialog
extends Control

signal confirmed
signal cancelled

const DESIGN_SIZE := Vector2(540, 363)
const FRAME_REGION := Rect2(25, 12, 894, 601)
const INNER_LEFT := 30.0
const INNER_WIDTH := 480.0
const CONTENT_OFFSET_X := -3.0
const ACTION_GAP := (INNER_WIDTH * 0.5 - MapRewardDialog.ACTION_SIZE.x) * 2.0 / 3.0
var canvas: Control
var heading: Label
var message: Label
var confirm_button: TextureButton
var cancel_button: TextureButton
var error_label: Label

func _init() -> void:
	name = "MapExitDialog"
	z_index = 40
	mouse_filter = MOUSE_FILTER_STOP
	texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	hide()
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.03, 0.65)
	shade.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	canvas = Control.new()
	canvas.size = DESIGN_SIZE
	canvas.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(canvas)
	var backing := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/UI-jiaohu-size0.webp")
	# Keep the original display footprint while aligning the new 940px artwork.
	# Only the upper frame is used; the source's lower canvas is not UI content.
	atlas.region = FRAME_REGION
	backing.texture = atlas
	backing.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backing.size = DESIGN_SIZE
	backing.mouse_filter = MOUSE_FILTER_IGNORE
	canvas.add_child(backing)
	heading = _label("", Rect2(70, 61, 400, 62), 32, Color("f9f8c8"))
	message = _label("确定离开这里吗？", Rect2(50, 159, 440, 58), 26, Color("f9f8c8"))
	confirm_button = _button("确定", "res://assets/button-queren.webp", 0)
	cancel_button = _button("取消", "res://assets/button-quxiao.webp", 1)
	confirm_button.pressed.connect(func(): confirmed.emit())
	cancel_button.pressed.connect(func(): cancelled.emit())
	error_label = _label("", Rect2(45, 205, 450, 30), 17, Color("ffb9a8"))
	resized.connect(_layout)

func _label(text: String, rect: Rect2, font_size: int, color: Color, parent: Control = null) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = MOUSE_FILTER_IGNORE
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["SimHei", "黑体", "Microsoft YaHei", "sans-serif"])
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	(canvas if parent == null else parent).add_child(label)
	return label

func _button(text: String, path: String, index: int) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = load(path)
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.size = MapRewardDialog.ACTION_SIZE
	var row_width := button.size.x * 2.0 + ACTION_GAP
	button.position = Vector2(INNER_LEFT + (INNER_WIDTH - row_width) * 0.5 + index * (button.size.x + ACTION_GAP) + CONTENT_OFFSET_X, DESIGN_SIZE.y - MapRewardDialog.ACTION_BOTTOM_GAP - button.size.y)
	button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	button.focus_mode = FOCUS_NONE
	canvas.add_child(button)
	var caption := _label(text, Rect2(Vector2.ZERO, button.size), 26, Color.WHITE, button)
	caption.name = "Caption"
	caption.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	return button

func present(title: String) -> void:
	heading.text = title
	error_label.text = ""
	set_busy(false)
	show()
	_layout()

func set_busy(busy: bool) -> void:
	confirm_button.disabled = busy
	cancel_button.disabled = busy

func _layout() -> void:
	# Center the seven Han characters; the trailing question mark hangs outside.
	var font := message.get_theme_font("font")
	var font_size := message.get_theme_font_size("font_size")
	var body_width := font.get_string_size(message.text.trim_suffix("？"), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	message.position.x = (DESIGN_SIZE.x - body_width) * 0.5 + CONTENT_OFFSET_X
	message.size.x = font.get_string_size(message.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	canvas.scale = Vector2.ONE * minf(size.x / 1920.0, size.y / 1080.0)
	canvas.position = (size - DESIGN_SIZE * canvas.scale) * 0.5

func _gui_input(_event: InputEvent) -> void:
	accept_event()
