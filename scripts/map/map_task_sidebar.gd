extends Control
## Presentation-only category selection; task data/state is not created here.
signal category_changed(category_id: String)

const TextureMetrics = preload("res://scripts/map/map_texture_metrics.gd")
const ROW_HEIGHT := 66.0
const ICON_SIZE := 37.8
const ICON_SLOT_SIZE := 42.0
const TEXT_COLOR := Color("d5dcd9")
const SELECTED_COLOR := Color("ffe4a0")
var selected_category_id := "all"
var buttons: Dictionary = {}
var highlights: Dictionary = {}
var captions: Dictionary = {}
var icons: Dictionary = {}
var title_art: TextureRect
var category_rows: VBoxContainer
var _group := ButtonGroup.new()
var _selected_texture: AtlasTexture
var _selected_border_y := Vector2.ZERO

func _init() -> void:
	name = "TaskSidebar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var definition: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/task_sidebar.json"))
	_selected_texture = _trimmed_texture(definition.selected_texture, true)
	_selected_border_y = Vector2(definition.selected_border_y[0], definition.selected_border_y[1])
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for edge in ["left", "right"]: margin.add_theme_constant_override("margin_" + edge, 10)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	var heading := MarginContainer.new()
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_theme_constant_override("margin_left", 6)
	heading.add_theme_constant_override("margin_right", 6)
	column.add_child(heading)
	# Retain the old slot and center; only the title artwork shrinks to 80%.
	var title_slot := Control.new()
	title_slot.name = "TaskTitleSlot"
	title_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_slot.custom_minimum_size.y = 62
	heading.add_child(title_slot)
	title_art = _picture(_trimmed_texture(definition.title_texture))
	title_art.name = "TaskTitle"
	title_slot.add_child(title_art)
	title_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_art.anchor_left = 0.1
	title_art.anchor_right = 0.9
	title_art.anchor_top = 0.1
	title_art.anchor_bottom = 0.9
	var rows_margin := MarginContainer.new()
	rows_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Keep the list's top edge fixed while taller rows extend downwards.
	rows_margin.add_theme_constant_override("margin_top", 4)
	column.add_child(rows_margin)
	category_rows = VBoxContainer.new()
	category_rows.name = "TaskCategories"
	category_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	category_rows.add_theme_constant_override("separation", 0)
	rows_margin.add_child(category_rows)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["KaiTi", "楷体", "STKaiti", "serif"])
	for index in definition.categories.size():
		_build_category(definition.categories[index], font, index < definition.categories.size() - 1)
	_refresh_selection()

func _build_category(entry: Dictionary, font: Font, has_divider: bool) -> void:
	var id := String(entry.id)
	var button := Button.new()
	button.name = "Category_" + id
	button.custom_minimum_size.y = ROW_HEIGHT
	button.toggle_mode = true
	button.button_group = _group
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	category_rows.add_child(button)
	buttons[id] = button
	var selected := _picture(_selected_texture)
	selected.name = "SelectedFrame"
	selected.stretch_mode = TextureRect.STRETCH_SCALE
	button.add_child(selected)
	button.resized.connect(_fit_selected_frame.bind(button, selected))
	highlights[id] = selected
	var padding := MarginContainer.new()
	padding.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padding.add_theme_constant_override("margin_left", 22)
	padding.add_theme_constant_override("margin_right", 12)
	button.add_child(padding)
	padding.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var content := HBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 16)
	padding.add_child(content)
	var icon_slot := Control.new()
	icon_slot.custom_minimum_size = Vector2.ONE * ICON_SLOT_SIZE
	icon_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(icon_slot)
	var icon := _picture(_trimmed_texture(entry.icon))
	icon.name = "CategoryIcon"
	icon.size = Vector2.ONE * ICON_SIZE
	icon.position = Vector2.ONE * (ICON_SLOT_SIZE - ICON_SIZE) * 0.5
	icon_slot.add_child(icon)
	icons[id] = icon
	var caption := Label.new()
	caption.name = "CategoryLabel"
	caption.text = entry.label
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_font_override("font", font)
	caption.add_theme_font_size_override("font_size", 26)
	caption.add_theme_color_override("font_outline_color", Color("081621b0"))
	caption.add_theme_constant_override("outline_size", 2)
	content.add_child(caption)
	captions[id] = caption
	if has_divider:
		var divider := TextureRect.new()
		divider.name = "CategoryDivider"
		divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0, 0.5, 1])
		gradient.colors = PackedColorArray([Color("ad996200"), Color("ad99626b"), Color("ad996200")])
		var line := GradientTexture2D.new()
		line.gradient = gradient
		line.width = 256
		line.height = 1
		divider.texture = line
		divider.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		button.add_child(divider)
		divider.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		divider.offset_left = 12
		divider.offset_right = -12
		divider.offset_top = -0.5
		divider.offset_bottom = 0.5
	button.pressed.connect(select_category.bind(id))

func _fit_selected_frame(button: Button, frame: TextureRect) -> void:
	# Align the actual horizontal gold strokes, excluding the exported glow.
	var factor := button.size.y / (_selected_border_y.y - _selected_border_y.x)
	frame.position = Vector2(0, (_selected_texture.region.position.y - _selected_border_y.x) * factor)
	frame.size = Vector2(button.size.x, _selected_texture.region.size.y * factor)

func select_category(id: String) -> void:
	if not buttons.has(id) or id == selected_category_id: return
	selected_category_id = id
	_refresh_selection()
	category_changed.emit(id)

func _refresh_selection() -> void:
	for id: String in buttons:
		var selected := id == selected_category_id
		buttons[id].set_pressed_no_signal(selected)
		highlights[id].visible = selected
		captions[id].add_theme_color_override("font_color", SELECTED_COLOR if selected else TEXT_COLOR)

func _picture(texture: Texture2D) -> TextureRect:
	var picture := TextureRect.new()
	picture.texture = texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return picture

func _trimmed_texture(path: String, solid := false) -> AtlasTexture:
	var source := load(path) as Texture2D
	var texture := AtlasTexture.new()
	texture.atlas = source
	texture.region = TextureMetrics.solid_rect(source) if solid else Rect2(TextureMetrics.inspect(source).visible_rect)
	return texture
