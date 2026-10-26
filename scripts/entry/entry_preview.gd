extends Control
## Start-menu presentation. Preparation stays in its independent preview draft.
signal menu_requested(action: StringName)

const PREVIEW_SAVE := "user://entry_flow_preview.json"
const START_SCENE := "res://scenes/entry/start_menu.tscn"
const PREPARATION_SCENE := "res://scenes/entry/character_preparation.tscn"
const CONFIG := "res://data/ui/start_menu.json"
const BackgroundCycle = preload("res://scripts/entry/start_menu_background_cycle.gd")
const EntryMusic = preload("res://scripts/entry/entry_music.gd")
const Entrance = preload("res://scripts/entry/start_menu_entrance.gd")
const SceneCrossfade = preload("res://scripts/entry/entry_scene_crossfade.gd")
const LoadingOverlay = preload("res://scripts/entry/game_loading_overlay.gd")
var entrance: Entrance
var music: AudioStreamPlayer
const SaveSession = preload("res://scripts/entry/game_save_session.gd")
const GAME_SCENE := "res://scenes/maps/session_start.tscn"
var continue_fallback_path := MapLoadoutStore.DEFAULT_PATH
var screen := 0
var preview_save_path := PREVIEW_SAVE
var background: TextureRect
var left_shade: ColorRect
var logo: TextureRect
var tagline: HBoxContainer
var tagline_label: Label
var line_left: TextureRect
var line_right: TextureRect
var primary_button: TextureButton
var continue_button: TextureButton
var exit_button: TextureButton
var menu_buttons: Array[TextureButton] = []
var version_label: Label
var error_label: Label
var _config: Dictionary
var _navigating := false
var _song := SystemFont.new()
var _tagline_font := FontVariation.new()

func _ready() -> void:
	preview_save_path = MapLoadoutStore.session_path(PREVIEW_SAVE)
	get_window().title = "苍澜界 · 测试开始界面"
	_config = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	_config.background = BackgroundCycle.next_path(_config.get("backgrounds", [_config.background]))
	_song.font_names = PackedStringArray(["SimSun", "宋体", "Noto Serif CJK SC", "serif"])
	_tagline_font.base_font = _song
	texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	background = _image("Landscape", load(_config.background))
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	left_shade = ColorRect.new()
	left_shade.name = "LeftShade"
	left_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shade := ShaderMaterial.new()
	shade.shader = preload("res://scripts/entry/start_menu_shade.gdshader")
	for key: String in _config.shade:
		shade.set_shader_parameter(key, _config.shade[key])
	left_shade.material = shade
	add_child(left_shade)
	left_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	logo = _image("CanglanLogo", _atlas(_config.logo, _config.logo_region))
	_rect(logo, _config.logo_rect)
	tagline = HBoxContainer.new()
	tagline.name = "Tagline"
	tagline.alignment = BoxContainer.ALIGNMENT_CENTER
	tagline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tagline)
	_rect(tagline, _config.tagline_rect)
	line_left = _image("LeftOrnament", load(_config.line_left), tagline)
	tagline_label = _label(_config.tagline, tagline)
	tagline_label.add_theme_font_override("font", _tagline_font)
	tagline_label.add_theme_color_override("font_color", Color(_config.tagline_color))
	line_right = _image("RightOrnament", load(_config.line_right), tagline)
	continue_button = _art_button("ContinueCultivation", _config.continue)
	continue_button.visible = not SaveSession.resume_path(continue_fallback_path).is_empty()
	continue_button.pressed.connect(_continue_game)
	primary_button = _art_button("BeginJourney", _config.start)
	primary_button.pressed.connect(_begin_journey)
	var menu: Dictionary = _config.menu
	var menu_source: Texture2D = load(menu.texture)
	for row: Dictionary in menu.rows:
		var region := [menu.region[0], row.y, menu.region[2], row.height]
		var rect := [menu.rect[0], menu.rect[1] + (row.y - menu.region[1]) / menu.region[3] * menu.rect[3],
			menu.rect[2], row.height / menu.region[3] * menu.rect[3]]
		var button := _art_button(row.label, {"texture": menu.texture, "region": region, "rect": rect})
		var fade := ShaderMaterial.new()
		fade.shader = preload("res://scripts/entry/menu_edge_fade.gdshader")
		fade.set_shader_parameter("fade_start", menu.fade_start)
		fade.set_shader_parameter("fade_end", menu.fade_end)
		fade.set_shader_parameter("right_opacity", menu.right_opacity)
		fade.set_shader_parameter("source_x", Vector2(float(menu.region[0]) / menu_source.get_width(),
			float(menu.region[0] + menu.region[2]) / menu_source.get_width()))
		button.material = fade
		menu_buttons.append(button)
		if row.action == "exit":
			exit_button = button
			button.pressed.connect(_exit_game)
		else:
			button.pressed.connect(_request_menu.bind(StringName(row.action)))
	version_label = _label(_config.version, self)
	version_label.name = "Version"
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version_label.add_theme_color_override("font_color", Color("d9dfeb"))
	_rect(version_label, _config.version_rect)
	error_label = _label("", self)
	error_label.add_theme_color_override("font_color", Color("e5a299"))
	_rect(error_label, [160, 1280, 690, 48])
	error_label.hide()
	if not SaveSession.resume_error.is_empty():
		error_label.text = SaveSession.resume_error
		error_label.show()
		SaveSession.resume_error = ""
	resized.connect(_resize_content)
	_resize_content()
	entrance = Entrance.new()
	add_child(entrance)
	entrance.configure(self)
	_start_music()

func _start_music() -> void:
	music = EntryMusic.ensure_for(get_tree())

func _image(node_name: String, texture: Texture2D, parent: Node = null) -> TextureRect:
	var image := TextureRect.new()
	image.name = node_name
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(self if parent == null else parent).add_child(image)
	return image

func _label(text: String, parent: Node) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", _song)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	label.add_theme_constant_override("shadow_offset_y", 1)
	parent.add_child(label)
	return label

func _atlas(path: String, region: Array) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = load(path)
	texture.region = Rect2(region[0], region[1], region[2], region[3])
	return texture

func _art_button(node_name: String, config: Dictionary) -> TextureButton:
	var button := TextureButton.new()
	button.name = node_name
	button.texture_normal = _atlas(config.texture, config.region)
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_child(button)
	_rect(button, config.rect)
	for event in [button.mouse_entered, button.mouse_exited, button.focus_entered,
			button.focus_exited, button.button_down, button.button_up]:
		event.connect(_button_feedback.bind(button))
	return button

func _button_feedback(button: BaseButton) -> void:
	button.self_modulate = Color(0.85, 0.85, 0.85) if button.is_pressed() else (
		Color(1.12, 1.12, 1.12) if button.is_hovered() or button.has_focus() else Color.WHITE)

func _rect(control: Control, rect: Array) -> void:
	var reference: Array = _config.reference_size
	control.anchor_left = float(rect[0]) / reference[0]
	control.anchor_top = float(rect[1]) / reference[1]
	control.anchor_right = float(rect[0] + rect[2]) / reference[0]
	control.anchor_bottom = float(rect[1] + rect[3]) / reference[1]
	control.offset_left = 0
	control.offset_top = 0
	control.offset_right = 0
	control.offset_bottom = 0

func _resize_content() -> void:
	if _config.is_empty(): return
	var scale_factor := minf(size.x / _config.reference_size[0], size.y / _config.reference_size[1])
	_tagline_font.spacing_space = roundi(_config.tagline_space_adjust * scale_factor)
	tagline.add_theme_constant_override("separation", roundi(_config.tagline_gap * scale_factor))
	for line: TextureRect in [line_left, line_right]:
		line.custom_minimum_size = Vector2(_config.line_width * scale_factor, 0)
	tagline_label.add_theme_font_size_override("font_size", maxi(1, roundi(_config.tagline_font_size * scale_factor)))
	version_label.add_theme_font_size_override("font_size", maxi(1, roundi(_config.version_font_size * scale_factor)))
	error_label.add_theme_font_size_override("font_size", maxi(1, roundi(24 * scale_factor)))

func _request_menu(action: StringName) -> void:
	if not _allows_menu_input(): return
	# Save selection, settings and credits will attach here when their flows are designed.
	menu_requested.emit(action)

func _begin_journey() -> void:
	if not _allows_menu_input(): return
	_navigating = true
	SaveSession.clear_selection()
	var transition := SceneCrossfade.new()
	transition.name = "EntrySceneCrossfade"
	get_tree().root.add_child(transition)
	transition.begin(PREPARATION_SCENE, self)

func _allows_menu_input() -> bool:
	return not _navigating and (entrance == null or entrance.allows_input())

func _exit_game() -> void:
	if _allows_menu_input(): get_tree().quit()

func _continue_game() -> void:
	if not _allows_menu_input(): return
	_navigating = true
	var cover_image := ImageTexture.create_from_image(get_viewport().get_texture().get_image())
	var loading := LoadingOverlay.show_for(get_tree(), cover_image)
	await RenderingServer.frame_post_draw
	var path := SaveSession.resume_path(continue_fallback_path)
	if not SaveSession.begin_resume(path):
		loading.queue_free()
		_navigating = false
		continue_button.hide()
		error_label.text = "暂无可继续的存档。"
		error_label.show()
		return
	var result := get_tree().change_scene_to_file(GAME_SCENE)
	if result != OK:
		loading.queue_free()
		_navigating = false
		SaveSession.clear_selection()
		error_label.text = "页面打开失败，请检查场景文件。"
		error_label.show()

func _navigate(destination: String) -> void:
	if _navigating: return
	_navigating = true
	var result := get_tree().change_scene_to_file(destination)
	if result != OK:
		_navigating = false
		error_label.text = "页面打开失败，请检查场景文件。"
		error_label.show()
