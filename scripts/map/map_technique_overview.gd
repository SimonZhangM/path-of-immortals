extends Control

const Metrics := preload("res://scripts/map/map_texture_metrics.gd")
var records: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/technique_overviews.json"))
var selected_book_id := ""
var book_center_y := 0.0
var artwork: Dictionary = {}
var copy_box: VBoxContainer
var poem: Label
var origin: Label
var separator: HSeparator
var copy_shade: ColorRect
var _font: SystemFont

func _init() -> void:
	name = "TechniqueOverview"
	mouse_filter = MOUSE_FILTER_IGNORE
	clip_contents = true
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["KaiTi", "楷体", "STKaiti", "serif"])
	copy_shade = ColorRect.new()
	copy_shade.name = "CopyShade"
	copy_shade.mouse_filter = MOUSE_FILTER_IGNORE
	var shade_material := ShaderMaterial.new()
	shade_material.shader = preload("res://scripts/map/map_technique_copy_shade.gdshader")
	copy_shade.material = shade_material
	add_child(copy_shade)
	for key in ["title", "label", "book", "calligraphy"]:
		var art := TextureRect.new()
		art.name = String(key).capitalize() + "Artwork"
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		art.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(art)
		artwork[key] = art
	copy_box = VBoxContainer.new()
	copy_box.name = "OverviewCopy"
	copy_box.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(copy_box)
	poem = _copy("Poem", Color("f1ead6"))
	separator = HSeparator.new()
	separator.mouse_filter = MOUSE_FILTER_IGNORE
	copy_box.add_child(separator)
	origin = _copy("OriginAndCore", Color("f1ead6"))
	resized.connect(_layout)
	set_notify_transform(true)
	hide()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and is_inside_tree(): _layout_copy()

func _copy(node_name: String, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.texture_filter = TEXTURE_FILTER_LINEAR
	label.oversampling_with_scale = OVERSAMPLING_WITH_SCALE_DISABLED
	label.add_theme_font_override("font", _font)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color("08121ce6"))
	label.add_theme_constant_override("shadow_offset_y", 1)
	copy_box.add_child(label)
	return label

func show_book(book_id: String) -> void:
	visible = records.has(book_id)
	if not visible or selected_book_id == book_id: return
	selected_book_id = book_id
	var record: Dictionary = records[book_id]
	for key in artwork:
		var source: Texture2D = load(record[key])
		var atlas := AtlasTexture.new()
		atlas.atlas = source
		atlas.region = Metrics.solid_rect(source) if key in ["title", "label"] else Rect2(Metrics.inspect(source).used_rect)
		artwork[key].texture = atlas
		if key == "calligraphy":
			artwork[key].material = preload("res://scripts/map/map_calligraphy_ink.gd").material_for(source)
	poem.text = record.poem
	origin.text = record.origin
	_layout()

func _layout() -> void:
	if size.x <= 0 or size.y <= 0: return
	copy_shade.position = Vector2(2, 2)
	copy_shade.size = Vector2(minf(600, size.x * 0.50), size.y - 2)
	# The wider middle panel keeps the reference's text / book / calligraphy order.
	_fit_art("title", Rect2(34, 38, 330, 86))
	_fit_art("label", Rect2(34, 143, 350, 42))
	_fit_book(Rect2(size.x * 0.36, 10, size.x * 0.45, size.y - 22))
	_fit_art("calligraphy", Rect2(size.x * 0.84, 38, size.x * 0.14, 345))
	_layout_copy()

func _fit_book(box: Rect2) -> void:
	var art: TextureRect = artwork.book
	if art.texture == null: return
	var atlas := art.texture as AtlasTexture
	var metrics := Metrics.inspect(atlas.atlas)
	var original := Rect2(metrics.used_rect)
	var visible := Rect2(metrics.visible_rect)
	# Keep the previous physical scale and horizontal position of the book.
	# Only exclude near-transparent export specks from its centering bounds.
	var factor := minf(box.size.x / original.size.x, box.size.y / original.size.y)
	atlas.region = visible
	art.size = visible.size * factor
	art.position.x = box.position.x + (box.size.x - original.size.x * factor) * 0.5 + (visible.position.x - original.position.x) * factor
	art.position.y = book_center_y - art.size.y * 0.5

func _fit_art(key: String, box: Rect2) -> void:
	var art: TextureRect = artwork[key]
	if art.texture == null: return
	var source := art.texture.get_size()
	art.size = source * minf(box.size.x / source.x, box.size.y / source.y)
	art.position = box.position + (box.size - art.size) * 0.5

func _layout_copy() -> void:
	if not is_inside_tree() or copy_box == null: return
	var transform := get_global_transform_with_canvas()
	var display_scale := transform.get_scale()
	if display_scale.x <= 0 or display_scale.y <= 0: return
	copy_box.scale = Vector2.ONE / display_scale
	copy_box.position = transform.affine_inverse() * (transform * Vector2(36, 210)).round()
	var origin_font_size := roundi(18 * display_scale.x) + 2
	var record: Dictionary = records.get(selected_book_id, {})
	var width_sample := String(record.get("origin_width_sample", ""))
	var copy_width := roundf(365 * display_scale.x) if width_sample.is_empty() else ceilf(_font.get_string_size(width_sample, HORIZONTAL_ALIGNMENT_LEFT, -1, origin_font_size).x)
	copy_box.size = Vector2(copy_width, 0)
	copy_box.add_theme_constant_override("separation", roundi(22 * display_scale.y))
	poem.add_theme_font_size_override("font_size", roundi(24 * display_scale.x))
	origin.add_theme_font_size_override("font_size", origin_font_size)
	for label in [poem, origin]:
		label.add_theme_constant_override("line_spacing", roundi(6 * display_scale.y))
	var line := StyleBoxLine.new()
	line.color = Color("a8915866")
	line.thickness = 1
	separator.add_theme_stylebox_override("separator", line)
	separator.add_theme_constant_override("separation", 1)
