extends Control
## Presentation-only dice timing; the draft owns the shuffled name pool.
signal dice_face_changed(face: int)
signal roll_finished(full_name: String)
signal identity_changed
const Draft = preload("res://scripts/entry/character_creation_draft.gd")
var draft: Draft
var name_input: LineEdit
var dice_button: TextureButton
var gender_row: HBoxContainer
var gender_buttons: Array[TextureButton] = []
var labels: Array[Label] = []
var gender_captions: Array[Label] = []
var dice_face := 0
var is_rolling := false
var _elapsed := 0.0
var _roll_started_usec := 0
var _step := 0
var _config: Dictionary
var _reference: Vector2
var _font: Font
var _bold_font: Font
var _dice_textures: Array[Texture2D] = []
var _normal_selection: Texture2D
var _rng := RandomNumberGenerator.new()

func build(config: Dictionary, reference: Vector2, state: Draft, font: Font, bold_font: Font) -> void:
	_config = config
	_reference = reference
	draft = state
	_font = font
	_bold_font = bold_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()
	set_process(false)
	var name_art := TextureRect.new()
	name_art.texture = _atlas(config.name_texture, config.name_region)
	name_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	name_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	name_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(name_art)
	_rect(name_art, config.name_rect)
	name_input = LineEdit.new()
	name_input.placeholder_text = "请输入姓名"
	name_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_input.caret_blink = true
	name_input.add_theme_font_override("font", font)
	name_input.add_theme_color_override("font_color", Color("f9f5ea"))
	name_input.add_theme_color_override("font_placeholder_color", Color("969da6"))
	for style in ["normal", "focus", "read_only"]:
		name_input.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	add_child(name_input)
	var field: Array = config.name_rect
	_rect(name_input, [field[0] + 20, field[1] + 10, field[2] - 40, field[3] - 20])
	name_input.text_changed.connect(draft.set_manual_name)
	name_input.text_changed.connect(func(_value: String): identity_changed.emit())
	var name_label := _label("姓名", self, bold_font)
	_rect(name_label, config.name_label_rect)
	var gender_label := _label("性别", self, bold_font)
	_rect(gender_label, config.gender_label_rect)
	labels.assign([name_label, gender_label])
	for label in labels: label.add_theme_color_override("font_color", Color("f6df9f"))
	gender_row = HBoxContainer.new()
	gender_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(gender_row)
	_rect(gender_row, config.gender_rect)
	var group := ButtonGroup.new()
	var normal := _atlas(config.selection_default, config.selection_default_region)
	_normal_selection = normal
	var selected := _atlas(config.selection_selected, config.selection_selected_region)
	for index in 2:
		var button := TextureButton.new()
		button.texture_normal = normal
		button.texture_hover = normal
		button.texture_pressed = selected
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_SCALE
		button.toggle_mode = true
		button.button_group = group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		gender_row.add_child(button)
		gender_buttons.append(button)
		var caption := _label("男" if index == 0 else "女", button, font)
		caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		gender_captions.append(caption)
		button.pressed.connect(_select_gender.bind(index))
	for index in 6: _dice_textures.append(_atlas(config.dice_pattern % (index + 1), config.dice_region))
	dice_button = TextureButton.new()
	dice_button.texture_normal = _dice_textures[0]
	dice_button.ignore_texture_size = true
	dice_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	dice_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	dice_button.tooltip_text = "随机姓名"
	add_child(dice_button)
	_rect(dice_button, config.dice_rect)
	dice_button.pressed.connect(start_roll)

func resize_content(factor: float) -> void:
	name_input.add_theme_font_size_override("font_size", roundi(_config.font_size * factor))
	for label in labels: label.add_theme_font_size_override("font_size", roundi(_config.label_font_size * factor))
	for label in gender_captions: label.add_theme_font_size_override("font_size", roundi(_config.font_size * factor))
	gender_row.add_theme_constant_override("separation", roundi(_config.gender_gap * factor))

func _select_gender(index: int) -> void:
	draft.gender = "male" if index == 0 else "female"
	for number in 2:
		var button := gender_buttons[number]
		button.texture_normal = button.texture_pressed if number == index else _normal_selection
		button.texture_hover = button.texture_normal
		gender_captions[number].add_theme_color_override("font_color", Color("fff0c2") if number == index else Color("cfdfef"))
	identity_changed.emit()

func start_roll() -> void:
	if is_rolling: return
	is_rolling = true
	_elapsed = 0.0
	_roll_started_usec = Time.get_ticks_usec()
	_step = 0
	dice_button.disabled = true
	name_input.editable = false
	_next_face()
	set_process(true)

func _next_face() -> void:
	dice_face = (dice_face + _rng.randi_range(1, 5)) % 6
	dice_button.texture_normal = _dice_textures[dice_face]
	dice_face_changed.emit(dice_face)

func _process(_delta: float) -> void:
	# UI animation starts at activation, excluding time spent before the click.
	_elapsed = (Time.get_ticks_usec() - _roll_started_usec) / 1000000.0
	var last_step := roundi(_config.dice_fps * _config.dice_seconds) - 1
	var target := mini(last_step, floori(_elapsed * _config.dice_fps))
	while _step < target:
		_step += 1
		_next_face()
	if _elapsed < float(_config.dice_seconds): return
	set_process(false)
	is_rolling = false
	name_input.text = draft.draw_name()
	name_input.editable = true
	dice_button.disabled = false
	identity_changed.emit()
	roll_finished.emit(draft.full_name)

func _rect(control: Control, rect: Array) -> void:
	control.anchor_left = float(rect[0]) / _reference.x
	control.anchor_top = float(rect[1]) / _reference.y
	control.anchor_right = float(rect[0] + rect[2]) / _reference.x
	control.anchor_bottom = float(rect[1] + rect[3]) / _reference.y

func _atlas(path: String, region: Array) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = load(path)
	texture.region = Rect2(region[0], region[1], region[2], region[3])
	return texture

func _label(text: String, parent: Control, font: Font) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_color_override("font_color", Color("cfdfef"))
	parent.add_child(label)
	return label
