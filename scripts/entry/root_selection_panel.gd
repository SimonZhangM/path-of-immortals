extends Control
signal random_requested
signal enter_requested
const CONFIG := "res://data/ui/root_selection_panel.json"
var root_name: Label
var phrase: Label
var phrase_left: Label
var phrase_right: Label
var _phrase_text := ""
var description: Label
var hint: Label
var random_button: TextureButton
var enter_button: TextureButton
var _random_caption: Label
var _enter_caption: Label
var _config: Dictionary
var _source: Vector2
var _song: Font
var _strong_song := FontVariation.new()
var _name_song := FontVariation.new()
var _harmony: Font = preload("res://assets/fonts/HarmonyOS_Sans_SC_Regular.ttf")
var _busy := false
var _has_result := false
var _identity_complete := false
var root_orbs: Array[TextureRect] = []
var _orb_layer: Control
var _orb_textures: Dictionary = {}

func build(song: Font) -> void:
	_config = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	_source = Vector2(_config.source_size[0], _config.source_size[1])
	_song = song
	# Local weight increase: do not change the phrase or the other introduction pages.
	_strong_song.base_font = song.base_font if song is FontVariation else song
	_strong_song.variation_embolden = 0.85
	_name_song.base_font = _strong_song.base_font
	_name_song.variation_embolden = 0.8
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art := TextureRect.new()
	art.texture = load(_config.texture)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_orbs()
	var shade := ColorRect.new()
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shade_material := ShaderMaterial.new()
	shade_material.shader = preload("res://scripts/entry/root_panel_shade.gdshader")
	shade.material = shade_material
	add_child(shade)
	_place(shade, _config.shade_rect)
	root_name = _label(_config.name_rect, _name_song, true)
	phrase = _label(_config.phrase_rect, _song, true)
	var phrase_rect: Array = _config.phrase_rect
	var half: float = phrase_rect[2] * 0.5
	phrase_left = _label([phrase_rect[0], phrase_rect[1], half - 22, phrase_rect[3]], _song, true)
	phrase_left.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	phrase_right = _label([phrase_rect[0] + half + 22, phrase_rect[1], half - 22, phrase_rect[3]], _song, true)
	phrase_right.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	for label in [root_name, phrase, phrase_left, phrase_right]:
		label.add_theme_color_override("font_color", Color(_config.title_color))
	description = _label(_config.description_rect, _harmony)
	hint = _label(_config.hint_rect, _harmony)
	hint.text = _config.hint
	random_button = _button(_config.random_texture, _config.random_rect)
	enter_button = _button(_config.enter_texture, _config.enter_rect)
	_random_caption = _caption(random_button, "随机")
	_enter_caption = _caption(enter_button, "踏入仙途")
	random_button.pressed.connect(func(): random_requested.emit())
	enter_button.pressed.connect(func(): enter_requested.emit())
	resized.connect(_resize)
	show_result({})
	_resize()

func layout_in(viewport_size: Vector2, reference: Vector2) -> void:
	var rect: Array = _config.rect
	var factor := minf(viewport_size.x / reference.x, viewport_size.y / reference.y)
	size = Vector2(rect[2], rect[3]) * factor
	position = (viewport_size - reference * factor) * 0.5 + Vector2(rect[0], rect[1]) * factor

func show_result(result: Dictionary) -> void:
	_has_result = not result.is_empty()
	root_name.text = result.get("name", _config.empty_name)
	_phrase_text = result.get("phrase", _config.empty_phrase)
	var halves := _phrase_text.split("·", true, 1)
	phrase.text = "·"
	phrase_left.text = halves[0].strip_edges()
	phrase_right.text = halves[1].strip_edges() if halves.size() > 1 else ""
	description.text = result.get("description", _config.empty_description)
	_show_orbs(result)
	_update_buttons()

func _build_orbs() -> void:
	_orb_layer = Control.new()
	_orb_layer.name = "RootCombination"
	_orb_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_orb_layer)
	_place(_orb_layer, _config.orb_region)
	for key: String in _config.orb_textures:
		_orb_textures[key] = load(_config.orb_textures[key])
	for index in 5:
		var orb := TextureRect.new()
		orb.name = "RootOrb%d" % (index + 1)
		orb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		orb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		orb.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_orb_layer.add_child(orb)
		root_orbs.append(orb)

func _show_orbs(result: Dictionary) -> void:
	for orb in root_orbs:
		orb.hide()
		orb.texture = null
	var elements: Array = result.get("elements", [])
	var count := int(result.get("count", elements.size()))
	if not _config.orb_layouts.has(str(count)): return
	var keys: Array[String] = []
	if count >= 4:
		for index in count: keys.append("pseudo_four" if count == 4 else "pseudo_five")
	else:
		# Stable reading order regardless of how the result's element IDs were supplied.
		for id: String in _config.orb_element_order:
			if elements.has(id): keys.append(id)
	if keys.size() != count: return
	var layout: Dictionary = _config.orb_layouts[str(count)]
	var half: float = layout["size"] * 0.5
	for index in count:
		var orb := root_orbs[index]
		var center: Array = layout.centers[index]
		orb.anchor_left = center[0] - half
		orb.anchor_right = center[0] + half
		orb.anchor_top = center[1] - half
		orb.anchor_bottom = center[1] + half
		orb.texture = _orb_textures[keys[index]]
		orb.show()

func set_busy(value: bool) -> void:
	_busy = value
	_update_buttons()

func set_identity_complete(value: bool) -> void:
	_identity_complete = value
	_update_buttons()

func _update_buttons() -> void:
	random_button.disabled = _busy
	enter_button.disabled = _busy or not _has_result or not _identity_complete
	for button in [random_button, enter_button]:
		button.mouse_default_cursor_shape = Control.CURSOR_ARROW if button.disabled else Control.CURSOR_POINTING_HAND
		_feedback(button)

func _feedback(button: TextureButton) -> void:
	button.modulate = Color(0.6, 0.6, 0.6) if button.disabled else (Color(0.86, 0.86, 0.86) if button.is_pressed() else (Color(1.12, 1.12, 1.12) if button.is_hovered() else Color.WHITE))

func _resize() -> void:
	if _config.is_empty(): return
	var factor := size.x / _source.x
	var name_shift: float = _config.name_offset_y * size.x / _config.rect[2]
	root_name.offset_top = name_shift
	root_name.offset_bottom = name_shift
	var description_shift: Vector2 = Vector2(_config.description_offset[0], _config.description_offset[1]) * size.x / _config.rect[2]
	description.offset_left = description_shift.x
	description.offset_right = description_shift.x
	description.offset_top = description_shift.y
	description.offset_bottom = description_shift.y
	var labels := [root_name, phrase, phrase_left, phrase_right, description, hint, _random_caption, _enter_caption]
	var sizes := [_config.name_size, _config.phrase_size, _config.phrase_size, _config.phrase_size, _config.description_size, _config.hint_size, _config.random_size, _config.enter_size]
	for index in labels.size():
		labels[index].add_theme_font_size_override("font_size", maxi(1, roundi(sizes[index] * factor)))
	for label in [description, hint]:
		label.add_theme_constant_override("line_spacing", roundi(10 * factor))

func _place(control: Control, rect: Array) -> void:
	control.anchor_left = rect[0] / _source.x
	control.anchor_top = rect[1] / _source.y
	control.anchor_right = (rect[0] + rect[2]) / _source.x
	control.anchor_bottom = (rect[1] + rect[3]) / _source.y

func _label(rect: Array, font: Font, centered: bool = false) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_color_override("font_color", Color("e7e7e1"))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	label.autowrap_mode = TextServer.AUTOWRAP_OFF if centered else TextServer.AUTOWRAP_WORD_SMART
	add_child(label)
	_place(label, rect)
	return label

func _button(path: String, rect: Array) -> TextureButton:
	var button := TextureButton.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = load(path)
	atlas.region = Rect2(rect[0], rect[1], rect[2], rect[3])
	button.texture_normal = atlas
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	add_child(button)
	_place(button, rect)
	for event in [button.mouse_entered, button.mouse_exited, button.button_down, button.button_up]:
		event.connect(_feedback.bind(button))
	return button

func _caption(button: TextureButton, text: String) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", _strong_song)
	label.add_theme_color_override("font_color", Color("f9f5ea"))
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return label
