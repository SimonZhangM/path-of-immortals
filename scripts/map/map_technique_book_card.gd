class_name MapTechniqueBookCard
extends Button

var book_id := ""
var element_id := ""
var preview_art: TextureRect

func set_preview_texture(texture: Texture2D) -> void:
	preview_art.texture = texture

func configure(book: Dictionary, color: Color, group: ButtonGroup) -> void:
	book_id = book.id
	element_id = "base.element." + String(book.element)
	name = "Book_" + book_id.get_slice(".", 2)
	toggle_mode = true
	button_group = group
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var artwork := AtlasTexture.new()
	artwork.atlas = load("res://assets/UI-gongfa-left-selectbook.webp")
	# Visible frame bounds (alpha >0.1); exclude the source's faint outer halo.
	artwork.region = Rect2(18, 38, 684, 257)
	custom_minimum_size = Vector2(241, 94)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("081b28e6")
	normal.border_color = Color("304956")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	normal.set_content_margin_all(0)
	add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = Color(color, 0.65)
	add_theme_stylebox_override("hover", hover)
	var selected := StyleBoxTexture.new()
	selected.texture = artwork
	selected.set_content_margin_all(0)
	add_theme_stylebox_override("pressed", selected)
	add_theme_stylebox_override("hover_pressed", selected)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color(color, 0.7)
	focus.set_border_width_all(1)
	focus.set_corner_radius_all(6)
	focus.set_expand_margin_all(2)
	add_theme_stylebox_override("focus", focus)
	var margin := MarginContainer.new()
	margin.name = "BookContent"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 10)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	preview_art = TextureRect.new()
	preview_art.name = "BookPreview"
	preview_art.custom_minimum_size = Vector2(62, 74)
	preview_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	preview_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(preview_art)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_theme_constant_override("separation", 8)
	row.add_child(content)
	var title := Label.new()
	title.name = "BookName"
	title.text = book.name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var book_font := SystemFont.new()
	book_font.font_names = PackedStringArray(["KaiTi", "楷体", "STKaiti", "serif"])
	title.add_theme_font_override("font", book_font)
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(title)
	# Keep the user's display sample; learning state will be connected separately.
	var status := Label.new()
	status.name = "Comprehension"
	status.text = "已领悟"
	status.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.add_theme_font_override("font", ItemTooltip.summary_body_font())
	status.add_theme_font_size_override("font_size", 14)
	status.add_theme_color_override("font_color", Color("c6dfc8"))
	var badge := StyleBoxFlat.new()
	badge.bg_color = Color("183c3be8")
	badge.border_color = Color("729e91")
	badge.set_border_width_all(1)
	badge.set_corner_radius_all(4)
	badge.corner_detail = 1
	badge.content_margin_left = 8
	badge.content_margin_right = 8
	badge.content_margin_top = 3
	badge.content_margin_bottom = 3
	badge.shadow_color = Color("83bca72b")
	badge.shadow_size = 1
	status.add_theme_stylebox_override("normal", badge)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(status)
