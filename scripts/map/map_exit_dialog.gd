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
var backing: TextureRect
var heading: Label
var message: Label
var confirm_button: TextureButton
var cancel_button: TextureButton
var error_label: Label
var _design_size := DESIGN_SIZE
var _compact_content: MarginContainer
var _notice_only := false

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
	backing = TextureRect.new()
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

func use_map_exit_art() -> void:
	# Scene exits retain their title and medium frame independently of board prompts.
	var source: Texture2D = load("res://assets/UI-jiaohu-size-m.webp")
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = preload("res://scripts/map/map_texture_metrics.gd").inspect(source).visible_rect
	backing.texture = atlas
	var factor := DESIGN_SIZE.y / atlas.get_height()
	backing.size = atlas.get_size()*factor
	backing.position = (DESIGN_SIZE-backing.size)*0.5
	# The new upper divider is at source y185. Center the old title in its new
	# header band, without moving the message or either existing action button.
	var title_center := backing.position.y+((38.0+185.0)*0.5-atlas.region.position.y)*factor
	heading.position.y = title_center-heading.size.y*0.5

func use_board_change_art() -> void:
	if _compact_content != null: return
	var source: Texture2D = load("res://assets/UI-jiaohu-size-tiny.webp")
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = preload("res://scripts/map/map_texture_metrics.gd").inspect(source).visible_rect
	backing.texture = atlas
	_design_size = atlas.get_size()
	canvas.size = _design_size
	backing.position = Vector2.ZERO
	backing.size = _design_size
	heading.hide()
	_compact_content = MarginContainer.new()
	_compact_content.name = "BoardChangeContent"
	_compact_content.mouse_filter = MOUSE_FILTER_IGNORE
	canvas.add_child(_compact_content)
	_compact_content.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["left", "right"]:
		_compact_content.add_theme_constant_override("margin_"+side, 32)
	for side in ["top", "bottom"]:
		# The revised tiny frame has a 270px visible height; keep the entire
		# message, optional note and button stack inside its inner border.
		_compact_content.add_theme_constant_override("margin_"+side, 36)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	column.mouse_filter = MOUSE_FILTER_IGNORE
	_compact_content.add_child(column)
	message.reparent(column)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.custom_minimum_size = Vector2(0, 52)
	error_label.reparent(column)
	error_label.custom_minimum_size = Vector2(0, 32)
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 32)
	actions.mouse_filter = MOUSE_FILTER_IGNORE
	column.add_child(actions)
	for button in [confirm_button, cancel_button]:
		button.reparent(actions)
		button.custom_minimum_size = MapRewardDialog.ACTION_SIZE
		button.size_flags_horizontal = SIZE_SHRINK_CENTER
		button.size_flags_vertical = SIZE_SHRINK_CENTER

func present_confirmation(text: String, note := "") -> void:
	use_board_change_art()
	_notice_only = false
	cancel_button.show()
	message.text = text
	confirm_button.get_node("Caption").text = "确认"
	present("")
	error_label.text = note
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.add_theme_font_size_override("font_size",22)
	error_label.add_theme_color_override("font_color",Color("f9f8c8"))

func present_notice(text: String) -> void:
	present_confirmation(text)
	_notice_only = true
	cancel_button.hide()

func handle_confirmation_input(event: InputEvent) -> bool:
	if not visible: return false
	if event is InputEventKey:
		if not _notice_only and event.pressed and not event.echo and event.is_action_pressed("ui_cancel"): cancelled.emit()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT:
		if not _notice_only and event.pressed: cancelled.emit()
		get_viewport().set_input_as_handled()
	return true

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
	if _compact_content == null:
		var font := message.get_theme_font("font")
		var font_size := message.get_theme_font_size("font_size")
		var body_width := font.get_string_size(message.text.trim_suffix("？"), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		message.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		message.position.x = (DESIGN_SIZE.x - body_width) * 0.5 + CONTENT_OFFSET_X
		message.size.x = font.get_string_size(message.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	canvas.scale = Vector2.ONE * minf(size.x / 1920.0, size.y / 1080.0)
	canvas.position = (size - _design_size * canvas.scale) * 0.5

func _gui_input(_event: InputEvent) -> void:
	accept_event()
