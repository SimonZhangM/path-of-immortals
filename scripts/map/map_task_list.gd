extends Control
## List presentation only. Display entries never create accepted quests or save data.
signal task_selected(task_id: String)
const Tag = preload("res://scripts/map/map_task_category_tag.gd")
const HARMONY = preload("res://assets/fonts/HarmonyOS_Sans_SC_Regular.ttf")
const SORT_KEYS := ["accepted_at", "accepted_location", "updated_at"]
const NORMAL_FRAME := "res://assets/UI-task-mid-taskbar1.webp"
const SELECTED_FRAME := "res://assets/UI-task-mid-taskbar2.webp"
var definitions: Dictionary
var entries: Array = []
var category_id := "all"
var selected_task_id := ""
var sort_key := "accepted_at"
var sort_button: OptionButton
var rows: VBoxContainer
var cards: Dictionary = {}
var title_label: Label

func _init() -> void:
	name = "TaskList"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	definitions = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/task_list.json"))
	entries = definitions.display_entries.duplicate(true)
	var margins := MarginContainer.new()
	margins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for edge in ["left", "right", "top", "bottom"]:
		margins.add_theme_constant_override("margin_" + edge, 20)
	add_child(margins)
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 16)
	margins.add_child(column)
	var heading := HBoxContainer.new()
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_theme_constant_override("separation", 10)
	column.add_child(heading)
	var diamond := Control.new()
	diamond.name = "GoldDiamond"
	diamond.custom_minimum_size = Vector2(16, 40)
	diamond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_child(diamond)
	var outline := Line2D.new()
	outline.points = PackedVector2Array([Vector2(8,13),Vector2(14,20),Vector2(8,27),Vector2(2,20),Vector2(8,13)])
	outline.default_color = Color("e1bf77")
	outline.width = 2
	outline.antialiased = true
	diamond.add_child(outline)
	var heading_font := SystemFont.new()
	heading_font.font_names = PackedStringArray(["KaiTi", "楷体", "serif"])
	title_label = _label("任务列表", heading_font, 28, Color("e8c880"))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title_label)
	sort_button = OptionButton.new()
	sort_button.name = "TaskSort"
	sort_button.custom_minimum_size = Vector2(174, 40)
	sort_button.fit_to_longest_item = false
	sort_button.focus_mode = Control.FOCUS_NONE
	sort_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	sort_button.add_theme_font_override("font", HARMONY)
	sort_button.add_theme_font_size_override("font_size", 18)
	sort_button.add_theme_color_override("font_color", Color("c6d1db"))
	for state in ["normal", "hover", "pressed", "focus"]:
		var sort_box := _box(Color("0c202e"), Color("526472"), 4)
		sort_box.content_margin_left = 6
		sort_box.content_margin_right = 6
		sort_button.add_theme_stylebox_override(state, sort_box)
	for label in ["按接收时间排序", "按接收地点排序", "按更新时间排序"]:
		sort_button.add_item(label)
	var popup := sort_button.get_popup()
	popup.add_theme_font_override("font", HARMONY)
	popup.add_theme_font_size_override("font_size", 18)
	popup.add_theme_stylebox_override("panel", _box(Color("0d2232"), Color("607583"), 4))
	popup.add_theme_stylebox_override("hover", _box(Color("294252"), Color("a58b55"), 3))
	popup.add_theme_constant_override("v_separation", 16)
	sort_button.item_selected.connect(func(index: int): set_sort(SORT_KEYS[index]))
	heading.add_child(sort_button)
	var scroll := ScrollContainer.new()
	scroll.name = "TaskRowsScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	# Reserve space inside the scroll clip for the authored frame's outer edges.
	var frame_padding := MarginContainer.new()
	frame_padding.name = "FrameBleedPadding"
	frame_padding.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame_padding.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for edge in ["left", "right", "top", "bottom"]:
		frame_padding.add_theme_constant_override("margin_" + edge, 14)
	scroll.add_child(frame_padding)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 28)
	frame_padding.add_child(rows)
	_refresh_rows()

func set_category(id: String) -> void:
	category_id = id
	_refresh_rows()

func set_sort(key: String) -> void:
	if not SORT_KEYS.has(key): return
	sort_key = key
	sort_button.select(SORT_KEYS.find(key))
	_refresh_rows()

func set_entries(value: Array) -> void:
	entries = value.duplicate(true)
	_refresh_rows()

func ordered_entries() -> Array:
	var visible_entries := entries.filter(func(entry: Dictionary): return category_id == "all" or entry.category == category_id)
	visible_entries.sort_custom(_comes_before)
	return visible_entries

func _comes_before(a: Dictionary, b: Dictionary) -> bool:
	var av: Variant = a.get(sort_key)
	var bv: Variant = b.get(sort_key)
	var a_missing: bool = av == null or (av is String and av.is_empty())
	var b_missing: bool = bv == null or (bv is String and bv.is_empty())
	if a_missing != b_missing: return not a_missing
	if not a_missing and av != bv:
		if sort_key == "accepted_location": return str(av).naturalnocasecmp_to(str(bv)) < 0
		return float(av) > float(bv)
	if sort_key == "accepted_location":
		var at := float(a.get("accepted_at") if a.get("accepted_at") != null else -1)
		var bt := float(b.get("accepted_at") if b.get("accepted_at") != null else -1)
		if at != bt: return at > bt
	return str(a.id) < str(b.id)

func _refresh_rows() -> void:
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	cards.clear()
	for entry: Dictionary in ordered_entries(): _build_card(entry)

func select_task(id: String) -> void:
	if not cards.has(id): return
	selected_task_id = id
	for key: String in cards:
		cards[key].set_pressed_no_signal(key == id)
		_refresh_card_frame(cards[key])
	task_selected.emit(id)

func _build_card(entry: Dictionary) -> void:
	var button := Button.new()
	button.name = "TaskCard"
	button.custom_minimum_size.y = 108
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var backing := _box(Color("0f1f2b"), Color.TRANSPARENT, 3)
	backing.set_border_width_all(0)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		button.add_theme_stylebox_override(state, backing)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	rows.add_child(button)
	cards[entry.id] = button
	button.set_pressed_no_signal(entry.id == selected_task_id)
	button.pressed.connect(select_task.bind(str(entry.id)))
	var padding := MarginContainer.new()
	padding.name = "TaskTextPadding"
	padding.z_index = 2
	padding.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for edge in ["left", "right", "top", "bottom"]: padding.add_theme_constant_override("margin_"+edge, 12)
	padding.add_theme_constant_override("margin_left", 0)
	button.add_child(padding)
	padding.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var content := HBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 10)
	padding.add_child(content)
	var thumbnail := TextureRect.new()
	thumbnail.name = "TaskThumbnail"
	thumbnail.z_index = 1
	thumbnail.texture = load(entry.image)
	thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumbnail.stretch_mode = TextureRect.STRETCH_SCALE
	thumbnail.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mask := ShaderMaterial.new()
	mask.shader = preload("res://scripts/map/map_task_thumbnail.gdshader")
	mask.set_shader_parameter("corner_radius", 3.0)
	mask.set_shader_parameter("image_opacity", 0.75)
	mask.set_shader_parameter("fade_start", 0.5)
	mask.set_shader_parameter("left_fade_fraction", 0.05)
	mask.set_shader_parameter("vertical_fade_fraction", 0.05)
	thumbnail.material = mask
	button.add_child(thumbnail)
	thumbnail.resized.connect(func(): mask.set_shader_parameter("panel_size", thumbnail.size))
	var frame := TextureRect.new()
	frame.name = "FrameArtwork"
	frame.z_index = 0
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	button.add_child(frame)
	_refresh_card_frame(button)
	button.resized.connect(func():
		# Keep the photo's left edge and vertical center fixed; scale by row height.
		thumbnail.size = thumbnail.texture.get_size() * (button.size.y / thumbnail.texture.get_height())
		thumbnail.position = Vector2(0, (button.size.y-thumbnail.size.y)*0.5)
		padding.add_theme_constant_override("margin_left", int(ceil(thumbnail.size.x+10.0)))
		var frame_scale := button.size / Vector2(795,140)
		frame.position = -Vector2(18,16) * frame_scale
		frame.size = frame.texture.get_size() * frame_scale)
	var text_column := VBoxContainer.new()
	text_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_column.add_theme_constant_override("separation", 8)
	content.add_child(text_column)
	var first_line := HBoxContainer.new()
	first_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	first_line.add_theme_constant_override("separation", 14)
	text_column.add_child(first_line)
	var title := _label(entry.title, HARMONY, 26, Color("f0e6ce"))
	title.name = "TaskName"
	first_line.add_child(title)
	var tag := Tag.new(definitions.category_tags[entry.category])
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	first_line.add_child(tag)
	var summary := _label(entry.summary, HARMONY, 18, Color("c5d0d7"))
	summary.name = "TaskSummary"
	summary.clip_text = true
	summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_column.add_child(summary)

func _refresh_card_frame(button: Button) -> void:
	var frame := button.get_node("FrameArtwork") as TextureRect
	frame.texture = load(SELECTED_FRAME if button.button_pressed else NORMAL_FRAME)

func _label(text: String, font: Font, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _box(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 12
	box.content_margin_right = 12
	return box
