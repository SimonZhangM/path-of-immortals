extends Control
## Fixed-size artwork shared by all map shortcut descriptions.
const SettingsInput = preload("res://scripts/settings/settings_input.gd")
const Settings = preload("res://scripts/settings/game_settings.gd")
const ART_SCALE := 0.8
const POINTER_CENTER := Vector2(1, 49) * ART_SCALE
var title_label: Label
var body_label: Label
var shortcut_label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 10
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var background := TextureRect.new()
	background.texture = load("res://assets/UI-map-icon-info.webp")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size = background.texture.get_size() * ART_SCALE
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 23)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.alignment = BoxContainer.ALIGNMENT_CENTER
	rows.add_theme_constant_override("separation", 4)
	margin.add_child(rows)
	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_theme_constant_override("separation", 10)
	rows.add_child(title_row)
	title_label = Label.new()
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["SimSun", "宋体"])
	serif.font_weight = 700
	title_label.add_theme_font_override("font", serif)
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color("f3dca1"))
	title_row.add_child(title_label)
	shortcut_label = Label.new()
	shortcut_label.add_theme_font_size_override("font_size", 14)
	shortcut_label.add_theme_color_override("font_color", Color("f3dca1"))
	shortcut_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	shortcut_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shortcut_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var key_style := StyleBoxFlat.new()
	key_style.bg_color = Color("071b26")
	key_style.border_color = Color("b99b51")
	key_style.set_border_width_all(1)
	key_style.set_corner_radius_all(3)
	key_style.content_margin_left = 5
	key_style.content_margin_right = 5
	shortcut_label.add_theme_stylebox_override("normal", key_style)
	title_row.add_child(shortcut_label)
	body_label = Label.new()
	body_label.add_theme_font_override("font", load("res://assets/fonts/HarmonyOS_Sans_SC_Regular.ttf"))
	body_label.add_theme_font_size_override("font_size", 15)
	body_label.add_theme_color_override("font_color", Color("b5c4c7"))
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(body_label)
	hide()

func present(entry: Dictionary) -> void:
	title_label.text = entry.title
	body_label.text = entry.description
	shortcut_label.text = SettingsInput.action_label(entry.action)
	shortcut_label.visible = bool(Settings.value("shortcut_hints", true)) and not shortcut_label.text.is_empty()
	show()
