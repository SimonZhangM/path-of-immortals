extends Control
## Data-driven introduction pages; navigation never creates a character save.
signal continue_requested(next_page: int)
signal root_result_revealed(element_ids: Array[String])
signal preparation_requested(details: Dictionary)

const PREVIEW_SAVE := "user://entry_flow_preview.json"
const START_SCENE := "res://scenes/entry/start_menu.tscn"
const CONFIG := "res://data/ui/character_preparation.json"
const Draft = preload("res://scripts/entry/character_creation_draft.gd")
const IdentityForm = preload("res://scripts/entry/character_identity_form.gd")
const RootSelectionEffects = preload("res://scripts/entry/root_selection_effects.gd")
const RootSelectionSpin = preload("res://scripts/entry/root_selection_spin.gd")
const RootCatalog = preload("res://scripts/entry/character_root_catalog.gd")
const RootPanel = preload("res://scripts/entry/root_selection_panel.gd")
const PageTransition = preload("res://scripts/entry/entry_page_transition.gd")
var screen := 1
var current_page := 1
var highest_visited_page := 1
var creation_draft: Draft
var identity_form: IdentityForm
var preview_save_path := PREVIEW_SAVE
var background: TextureRect
var copy_shade: ColorRect
var root_selection_art: TextureRect
var root_selection_core: TextureRect
var root_selection_effects: RootSelectionEffects
var root_selection_spin: RootSelectionSpin
var root_panel: RootPanel
var root_catalog: RootCatalog
var _pending_root_result: Dictionary = {}
var title_art: TextureRect
var world_title: HBoxContainer
var description: VBoxContainer
var description_lines: Array[Label] = []
var terminal_marks: Array[Label] = []
var primary_button: TextureButton
var button_label: Label
var button_arrow: Label
var progress: HBoxContainer
var progress_dots: Array[Button] = []
var content_layer: Control
var page_transition: PageTransition
var _config: Dictionary
var _page: Dictionary
var _song := SystemFont.new()
var _bold_song := FontVariation.new()

func _ready() -> void:
	preload("res://scripts/entry/entry_music.gd").ensure_for(get_tree())
	preview_save_path = MapLoadoutStore.session_path(PREVIEW_SAVE)
	get_window().title = "苍澜界 · 测试踏入仙途"
	_config = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	_page = _page_config(current_page)
	_song.font_names = PackedStringArray(["SimSun", "宋体", "Noto Serif CJK SC", "serif"])
	_bold_song.base_font = _song
	_bold_song.variation_embolden = 0.8
	texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	background = _image("WorldBackground", load(_page.background))
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	copy_shade = ColorRect.new()
	copy_shade.name = "IntroductionShade"
	copy_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shade_material := ShaderMaterial.new()
	shade_material.shader = preload("res://scripts/entry/introduction_shade.gdshader")
	for key: String in _page.shade:
		shade_material.set_shader_parameter(key, _page.shade[key])
	copy_shade.material = shade_material
	add_child(copy_shade)
	copy_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_selection_art = _image("RootSelectionArt", null)
	root_selection_art.hide()
	root_selection_core = _image("RootSelectionCore", null, root_selection_art)
	root_selection_core.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_art = _image("IntroductionTitle", _atlas(_page.title, _page.title_region))
	_anchor_rect(title_art, _page.title_rect)
	world_title = HBoxContainer.new()
	world_title.name = "WorldTitle"
	world_title.alignment = BoxContainer.ALIGNMENT_CENTER
	world_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(world_title)
	_anchor_rect(world_title, _page.world_title_rect)
	for character in "苍澜界":
		var glyph := _label(character)
		glyph.add_theme_font_override("font", _bold_song)
		glyph.add_theme_color_override("font_color", Color("f5dda0"))
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		world_title.add_child(glyph)
	description = VBoxContainer.new()
	description.name = "IntroductionText"
	description.alignment = BoxContainer.ALIGNMENT_CENTER
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(description)
	_anchor_rect(description, _page.description_rect)
	_set_description()
	var pool: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_config.identity_form.name_pool))
	creation_draft = Draft.new(pool.names)
	identity_form = IdentityForm.new()
	add_child(identity_form)
	identity_form.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	identity_form.build(_config.identity_form, Vector2(_config.reference_size[0], _config.reference_size[1]), creation_draft, _song, _bold_song)
	identity_form.hide()
	root_catalog = RootCatalog.new()
	root_panel = RootPanel.new()
	add_child(root_panel)
	root_panel.build(_bold_song)
	root_panel.hide()
	root_panel.random_requested.connect(_randomize_roots)
	root_panel.enter_requested.connect(_request_preparation)
	primary_button = TextureButton.new()
	primary_button.name = "Continue"
	var button_material := ShaderMaterial.new()
	button_material.shader = preload("res://scripts/entry/disabled_button.gdshader")
	primary_button.material = button_material
	primary_button.texture_normal = _atlas(_page.button, _page.button_region)
	primary_button.ignore_texture_size = true
	primary_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	primary_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_child(primary_button)
	_anchor_rect(primary_button, _page.button_rect)
	button_label = _label(_page.button_text)
	button_label.name = "Caption"
	button_label.add_theme_font_override("font", _bold_song)
	button_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	primary_button.add_child(button_label)
	button_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button_arrow = _label(_page.button_arrow)
	button_arrow.name = "Arrow"
	button_arrow.add_theme_font_override("font", _bold_song)
	button_arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	primary_button.add_child(button_arrow)
	button_arrow.anchor_left = 0.5
	button_arrow.anchor_right = 0.5
	button_arrow.anchor_bottom = 1.0
	primary_button.pressed.connect(_continue)
	for event in [primary_button.mouse_entered, primary_button.mouse_exited, primary_button.focus_entered, primary_button.focus_exited, primary_button.button_down, primary_button.button_up]:
		event.connect(_button_feedback)
	progress = HBoxContainer.new()
	progress.name = "PageProgress"
	progress.alignment = BoxContainer.ALIGNMENT_CENTER
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(progress)
	_anchor_rect(progress, _page.progress_rect)
	for index in int(_config.page_count):
		var dot := Button.new()
		dot.name = "Page%d" % (index + 1)
		dot.pressed.connect(_revisit_page.bind(index + 1))
		progress.add_child(dot)
		progress_dots.append(dot)
	content_layer = Control.new()
	content_layer.name = "PageContent"
	content_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content_layer)
	content_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for control: Control in [root_selection_art, title_art, world_title, description,
			identity_form, root_panel, primary_button, progress]:
		control.reparent(content_layer, false)
	page_transition = PageTransition.new()
	add_child(page_transition)
	page_transition.configure(background, copy_shade, content_layer, Vector2(_config.reference_size[0], _config.reference_size[1]))
	resized.connect(_resize_content)
	identity_form.identity_changed.connect(_refresh_navigation)
	_resize_content()

func _page_config(number: int) -> Dictionary:
	var result: Dictionary = _config.layout.duplicate(true)
	result.merge(_config.pages[number - 1], true)
	return result

func show_page(number: int) -> void:
	if number < 1 or number > _config.pages.size(): return
	if number != current_page and root_selection_spin != null:
		root_selection_spin.cancel()
		_pending_root_result.clear()
		root_panel.set_busy(false)
	current_page = number
	highest_visited_page = maxi(highest_visited_page, number)
	_page = _page_config(number)
	background.texture = load(_page.background)
	title_art.visible = not str(_page.title).is_empty()
	title_art.texture = _atlas(_page.title, _page.title_region) if title_art.visible else null
	_anchor_rect(title_art, _page.title_rect)
	world_title.visible = title_art.visible
	_anchor_rect(world_title, _page.world_title_rect)
	copy_shade.visible = _page.get("shade_enabled", true)
	for key: String in _page.shade:
		copy_shade.material.set_shader_parameter(key, _page.shade[key])
	_anchor_rect(description, _page.description_rect)
	_set_description()
	primary_button.visible = _page.get("show_continue", true)
	button_label.text = _page.button_text
	identity_form.visible = _page.get("identity_enabled", false)
	root_selection_art.visible = _page.has("root_selection_art")
	root_panel.visible = root_selection_art.visible
	if root_selection_art.visible:
		root_selection_art.texture = load(_page.root_selection_art.texture)
		root_selection_core.texture = load(_page.root_selection_art.core_texture)
		if root_selection_effects == null:
			root_selection_effects = RootSelectionEffects.new()
			root_selection_art.add_child(root_selection_effects)
			root_selection_effects.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			var effects_config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_page.root_selection_art.selection_effects))
			root_selection_effects.configure(effects_config)
			root_selection_spin = RootSelectionSpin.new()
			add_child(root_selection_spin)
			var pivot: Array = _page.root_selection_art.core_pivot
			root_selection_spin.configure(root_selection_core, root_selection_effects,
				Vector2(pivot[0], pivot[1]) / root_selection_core.texture.get_size())
			root_selection_spin.finished.connect(_finish_root_selection)
	_resize_content()
	_button_feedback()

## Future random-button hook. Root distribution/character assignment belongs to its caller.
func play_root_selection_result(element_ids: Array) -> bool:
	if page_transition.active: return false
	if current_page != 4 or root_selection_spin == null: return false
	if not root_selection_spin.start(element_ids): return false
	root_panel.set_busy(true)
	return true

func _randomize_roots() -> void:
	if page_transition.active: return
	if current_page != 4 or root_selection_spin.active: return
	var result := root_catalog.draw()
	if play_root_selection_result(result.elements):
		_pending_root_result = result

func _finish_root_selection(element_ids: Array[String]) -> void:
	var result := _pending_root_result if not _pending_root_result.is_empty() else root_catalog.describe(element_ids)
	creation_draft.root_selection = result.duplicate(true)
	_pending_root_result.clear()
	root_panel.show_result(creation_draft.root_selection)
	root_panel.set_busy(false)
	root_result_revealed.emit(element_ids)

func _request_preparation() -> void:
	if page_transition.active: return
	if root_panel.enter_button.disabled: return
	# Formal character creation will consume this draft; never overwrite an existing save here.
	preparation_requested.emit({
		"full_name": creation_draft.full_name, "surname": creation_draft.surname,
		"given_name": creation_draft.given_name, "gender": creation_draft.gender,
		"root_selection": creation_draft.root_selection.duplicate(true)
	})

func _revisit_page(number: int) -> void:
	if number >= 4 and not creation_draft.identity_complete(): return
	if number <= highest_visited_page: _turn_page(number)

func _continue() -> void:
	if current_page == 3 and not creation_draft.identity_complete(): return
	if current_page >= _config.pages.size(): return
	_turn_page(current_page + 1, true)

func _turn_page(number: int, notify_continue := false) -> void:
	if page_transition.active or number == current_page: return
	if number < 1 or number > _config.pages.size(): return
	# Cancel a pending roll as soon as departure starts; completed choices remain.
	if root_selection_spin != null:
		root_selection_spin.cancel()
		_pending_root_result.clear()
		root_panel.set_busy(false)
	var next_page := _page_config(number)
	page_transition.begin(load(next_page.background), next_page.shade,
		next_page.get("shade_enabled", true), signi(number - current_page), show_page.bind(number))
	if notify_continue:
		page_transition.finished.connect(func(): continue_requested.emit(number), CONNECT_ONE_SHOT)

func _set_description() -> void:
	for row in description.get_children():
		description.remove_child(row)
		row.queue_free()
	description_lines.clear()
	terminal_marks.clear()
	for text: String in _page.lines:
		var row := CenterContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		description.add_child(row)
		# Trailing punctuation hangs outside the centred sentence body.
		var ending := text.right(1) if text.ends_with("。") or text.ends_with("，") else ""
		var line := _label(text.trim_suffix(ending) if not ending.is_empty() else text)
		row.add_child(line)
		description_lines.append(line)
		var mark := _label(ending)
		line.add_child(mark)
		mark.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
		terminal_marks.append(mark)

func _image(node_name: String, texture: Texture2D, parent: Node = null) -> TextureRect:
	var image := TextureRect.new()
	image.name = node_name
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(self if parent == null else parent).add_child(image)
	return image

func _atlas(path: String, region: Array) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = load(path)
	atlas.region = Rect2(region[0], region[1], region[2], region[3])
	return atlas

func _anchor_rect(control: Control, rect: Array) -> void:
	var reference: Array = _config.reference_size
	control.anchor_left = float(rect[0]) / reference[0]
	control.anchor_top = float(rect[1]) / reference[1]
	control.anchor_right = float(rect[0] + rect[2]) / reference[0]
	control.anchor_bottom = float(rect[1] + rect[3]) / reference[1]
	control.offset_left = 0
	control.offset_top = 0
	control.offset_right = 0
	control.offset_bottom = 0

func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", _song)
	label.add_theme_color_override("font_color", Color("f9f5ea"))
	label.add_theme_color_override("font_shadow_color", Color(0.015, 0.035, 0.06, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label

func _resize_content() -> void:
	if _page.is_empty(): return
	var factor := minf(size.x / _config.reference_size[0], size.y / _config.reference_size[1])
	_layout_root_selection_art()
	if root_panel != null:
		root_panel.layout_in(size, Vector2(_config.reference_size[0], _config.reference_size[1]))
		root_panel.set_identity_complete(creation_draft.identity_complete())
	world_title.add_theme_constant_override("separation", roundi(_page.world_title_gap * factor))
	for glyph: Label in world_title.get_children():
		glyph.add_theme_font_size_override("font_size", maxi(1, roundi(_page.world_title_font_size * factor)))
	for index in description_lines.size():
		var line := description_lines[index]
		var mark := terminal_marks[index]
		line.add_theme_font_size_override("font_size", maxi(1, roundi(_page.description_font_size * factor)))
		mark.add_theme_font_size_override("font_size", line.get_theme_font_size("font_size"))
		mark.offset_left = 0
		mark.offset_right = mark.get_minimum_size().x
	description.add_theme_constant_override("separation", roundi(_page.description_line_gap * factor))
	description.alignment = BoxContainer.ALIGNMENT_CENTER
	description.offset_top = 0
	if _page.get("description_align_first_line", false) and not description_lines.is_empty():
		# Keep the first baseline at the same height as the four-line introductions.
		var row_height := description_lines[0].get_combined_minimum_size().y
		var reference_height: float = _page.description_rect[3] * size.y / _config.reference_size[1]
		var reference_copy_height := row_height * 4 + description.get_theme_constant("separation") * 3
		description.alignment = BoxContainer.ALIGNMENT_BEGIN
		description.offset_top = maxf(0, (reference_height - reference_copy_height) * 0.5)
	var button_size := maxi(1, roundi(_page.button_font_size * factor))
	button_label.add_theme_font_size_override("font_size", button_size)
	button_arrow.add_theme_font_size_override("font_size", button_size)
	button_arrow.offset_left = _page.button_arrow_offset * factor - button_size * 0.5
	button_arrow.offset_right = _page.button_arrow_offset * factor + button_size * 0.5
	identity_form.resize_content(factor)
	progress.add_theme_constant_override("separation", roundi(_page.dot_gap * factor))
	for index in progress_dots.size():
		var dot: Button = progress_dots[index]
		dot.custom_minimum_size = Vector2.ONE * _page.dot_diameter * factor
		var active := index + 1 == current_page
		var style := StyleBoxFlat.new()
		style.bg_color = Color("f6c567") if active else Color(0.03, 0.05, 0.08, 0.2)
		style.border_color = Color("ffebaa") if active else Color("7d8590")
		style.set_border_width_all(maxi(1, roundi(2 * factor)))
		style.set_corner_radius_all(100)
		if active:
			style.shadow_color = Color(0.98, 0.68, 0.25, 0.4)
			style.shadow_size = roundi(10 * factor)
		dot.disabled = index + 1 > highest_visited_page or (index + 1 >= 4 and not creation_draft.identity_complete())
		dot.mouse_default_cursor_shape = Control.CURSOR_ARROW if dot.disabled else Control.CURSOR_POINTING_HAND
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			dot.add_theme_stylebox_override(state, style)
	_update_continue_state()

func _refresh_navigation() -> void:
	_resize_content()

func _layout_root_selection_art() -> void:
	if not root_selection_art.visible: return
	var layout: Dictionary = _page.root_selection_art
	# During a dissolve the live background already belongs to the incoming page.
	var source_size := (load(_page.background) as Texture2D).get_size()
	var cover_scale := maxf(size.x / source_size.x, size.y / source_size.y)
	var cover_offset := (size - source_size * cover_scale) * 0.5
	var background_anchor := Vector2(layout.background_anchor[0], layout.background_anchor[1])
	var art_anchor := Vector2(layout.art_anchor[0], layout.art_anchor[1])
	# Tie both light axes to the same point in the covered background image.
	var art_scale: float = layout.width / root_selection_art.texture.get_width() * source_size.x / _config.reference_size[0] * cover_scale
	root_selection_art.size = root_selection_art.texture.get_size() * art_scale
	root_selection_art.position = cover_offset + background_anchor * cover_scale - art_anchor * art_scale
	var base_center := root_selection_art.position + root_selection_art.size * 0.5
	root_selection_art.size *= float(layout.get("center_scale", 1.0))
	var offset: Array = layout.get("offset", [0, 0])
	var ui_scale := minf(size.x / _config.reference_size[0], size.y / _config.reference_size[1])
	root_selection_art.position = base_center - root_selection_art.size * 0.5 + Vector2(offset[0], offset[1]) * ui_scale

func _update_continue_state() -> void:
	primary_button.disabled = current_page == 3 and not creation_draft.identity_complete()
	primary_button.mouse_default_cursor_shape = Control.CURSOR_ARROW if primary_button.disabled else Control.CURSOR_POINTING_HAND
	primary_button.material.set_shader_parameter("disabled", primary_button.disabled)
	var caption_color := Color("a8a8a8") if primary_button.disabled else Color("f9f5ea")
	button_label.add_theme_color_override("font_color", caption_color)
	button_arrow.add_theme_color_override("font_color", caption_color)
	_button_feedback()

func _button_feedback() -> void:
	if primary_button.disabled:
		primary_button.self_modulate = Color.WHITE
		return
	primary_button.self_modulate = Color(0.85, 0.85, 0.85) if primary_button.is_pressed() else (Color(1.12, 1.12, 1.12) if primary_button.is_hovered() or primary_button.has_focus() else Color.WHITE)

func _unhandled_key_input(event: InputEvent) -> void:
	if page_transition.active: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file(START_SCENE)
