extends Control

# Spell content and artwork are registered by stable ID, shared across books.
var records: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/technique_spell_details.json"))
var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/technique_spell_detail_layout.json"))
var selected_spell_id := ""
var record: Dictionary = {}
var state: MapLoadoutState
var canvas: Control
var backdrop: Panel
var artwork: TextureRect
var spell_icon: TextureRect
var labels: Dictionary = {}
var progress_bar: ProgressBar
var condition_flags := Vector3.ZERO
var _font: SystemFont
var condition_icons: Array[TextureRect] = []
var learning_button: Button
var button_art: TextureRect
var _button_textures: Array[Texture2D] = []
var _button_hovered := false
var _button_scale := 1.0
var _button_tween: Tween
var current_book_id := ""
var detail_nodes: Array[CanvasItem] = []
var currency_icon: TextureRect
var category_count := 0
var core_count := 0
var summary_extra_height := 0.0
var body_scroll: ScrollContainer
var body_list: VBoxContainer
var body_labels: Array[Label] = []
var body_dots: Array[TextureRect] = []
var _body_spell_id := ""
const PracticeView := preload("res://scripts/map/map_technique_practice_view.gd")

func _init() -> void:
	name = "TechniqueSpellDetail"
	mouse_filter = MOUSE_FILTER_IGNORE
	clip_contents = true
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["KaiTi", "楷体", "STKaiti", "serif"])
	for entry: Dictionary in records.values():
		category_count = maxi(category_count, entry.categories.size())
		core_count = maxi(core_count, entry.core_points.size())
	backdrop = Panel.new()
	backdrop.mouse_filter = MOUSE_FILTER_IGNORE
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color("061321ed")
	backing.set_corner_radius_all(16)
	backdrop.add_theme_stylebox_override("panel", backing)
	add_child(backdrop)
	canvas = Control.new()
	canvas.mouse_filter = MOUSE_FILTER_IGNORE
	canvas.size = Vector2(layout.source_size[0], layout.source_size[1])
	add_child(canvas)
	artwork = _image("DetailFrame", layout.texture, Rect2(Vector2.ZERO, canvas.size))
	var source: Texture2D = artwork.texture
	var top := AtlasTexture.new()
	top.atlas = source
	top.region = Rect2(0, 0, canvas.size.x, 330)
	artwork.texture = top
	artwork.size.y = 330
	var bottom := _image("SpellDetailFrame", layout.texture, Rect2(0, 330, canvas.size.x, canvas.size.y - 330))
	var bottom_texture := AtlasTexture.new()
	bottom_texture.atlas = source
	bottom_texture.region = Rect2(0, 330, canvas.size.x, canvas.size.y - 330)
	bottom.texture = bottom_texture
	for index in 3:
		var center: Array = layout.tick_centers[index]
		var extent := Vector2(layout.condition_icon_size[0], layout.condition_icon_size[1])
		condition_icons.append(_image("ConditionIcon%d" % index, layout.condition_false_texture, Rect2(Vector2(center[0], center[1]) - extent * 0.5, extent)))
	_label("Practice", "", _rect(layout.progress_label_rect), 27)
	progress_bar = ProgressBar.new()
	progress_bar.name = "ActualPracticeProgress"
	progress_bar.mouse_filter = MOUSE_FILTER_IGNORE
	progress_bar.show_percentage = false
	progress_bar.position = _rect(layout.progress_bar_rect).position
	progress_bar.size = _rect(layout.progress_bar_rect).size
	var trough := StyleBoxFlat.new()
	trough.bg_color = Color("030b14")
	trough.border_color = Color("354a5a")
	trough.set_border_width_all(2)
	trough.set_corner_radius_all(9)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("35b7eb")
	fill.border_color = Color("83ddff")
	fill.set_border_width_all(2)
	fill.set_corner_radius_all(8)
	progress_bar.add_theme_stylebox_override("background", trough)
	progress_bar.add_theme_stylebox_override("fill", fill)
	canvas.add_child(progress_bar)
	for index in 3:
		var box := _rect(layout.progress_cards[index])
		var panel := Panel.new()
		panel.mouse_filter = MOUSE_FILTER_IGNORE
		panel.position = box.position
		panel.size = box.size
		var style := StyleBoxFlat.new()
		style.bg_color = Color("0b2031a6")
		style.border_color = Color("385466")
		style.set_border_width_all(2)
		style.set_corner_radius_all(5)
		panel.add_theme_stylebox_override("panel", style)
		canvas.add_child(panel)
		_label("ProgressCaption%d" % index, ["已领悟", "当前阶段", "下一阶段"][index], Rect2(box.position + Vector2(4, 10), Vector2(box.size.x - 8, 29)), 23, true, Color("c8c9b3"))
		_label("ProgressValue%d" % index, "", Rect2(box.position + Vector2(4, 48), Vector2(box.size.x - 8, 37)), 23, true)
	labels.ProgressCaption0.add_theme_color_override("font_color", Color("8bd7dd"))
	labels.ProgressValue1.add_theme_color_override("font_color", Color("f2cc62"))
	var rank_font := SystemFont.new()
	rank_font.font_names = PackedStringArray(["HarmonyOS Sans SC", "鸿蒙简体", "sans-serif"])
	rank_font.font_weight = 400
	labels.ProgressValue1.add_theme_font_override("font", rank_font)
	for index in 3:
		for key in ["ProgressCaption%d" % index, "ProgressValue%d" % index]:
			labels[key].horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			labels[key].vertical_alignment = VERTICAL_ALIGNMENT_TOP
	spell_icon = _image("SpellIcon", "res://assets/UI-water-hanyueningbingjue-effect-04-xuanbingqiang.webp", _rect(layout.spell_icon_rect))
	var icon_paint := ShaderMaterial.new()
	icon_paint.shader = preload("res://scripts/map/map_technique_icon.gdshader")
	icon_paint.set_shader_parameter("icon_size", spell_icon.size)
	icon_paint.set_shader_parameter("line_width", 2.0)
	icon_paint.set_shader_parameter("corner_radius", 4.0)
	icon_paint.set_shader_parameter("line_color", Color("d9bb72"))
	spell_icon.material = icon_paint
	_label("SpellName", "", Rect2(180, 434, 294, 48), 40)
	for index in category_count: _add_summary_category(index)
	var poem := _label("Poem", "", Rect2(180, 540, 294, 62), 23, false, Color("a7b8c5"))
	poem.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_label("Description", "", Rect2(30, 608, 444, 133), 25)
	for index in core_count:
		_image("CoreDot%d" % index, layout.dot_texture, Rect2(30, 760.5 + index * 40.5, 21, 21))
		_label("CorePoint%d" % index, "", Rect2(65, 749.5 + index * 40.5, 409, 43), 25)
	_label("LearningHeading", "学习条件", Rect2(190, 912, 122, 39), 28, true, Color("e4ce8d"))
	_label("Condition0", "", Rect2(152, 968, 326, 36), 23)
	_label("Condition1", "消耗灵石", Rect2(152, 1005, 104, 36), 23)
	currency_icon = _image("SpiritStone", "res://assets/player-status-coin.webp", Rect2(250, 1010, 18, 26))
	currency_icon.texture = BattleActionButton.trimmed_art("res://assets/player-status-coin.webp")
	currency_icon.stretch_mode = TextureRect.STRETCH_SCALE
	_label("LearningCost", "", Rect2(288, 1005, 100, 36), 23)
	_label("Condition2", "", Rect2(152, 1042, 326, 36), 21)
	_build_learning_button()
	body_scroll = ScrollContainer.new()
	body_scroll.name = "FullSpellBody"
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_scroll.position.y = 608
	canvas.add_child(body_scroll)
	body_list = VBoxContainer.new()
	body_list.size_flags_horizontal = SIZE_EXPAND_FILL
	body_scroll.add_child(body_list)
	for child: Control in canvas.get_children():
		var box: Rect2 = child.get_meta("source_rect", Rect2(child.position, child.size))
		if box.position.y >= 330:
			detail_nodes.append(child)
	resized.connect(_layout)
	set_notify_transform(true)
	hide()
	visibility_changed.connect(func():
		if not visible:
			_button_hovered = false
			if _button_tween: _button_tween.kill()
			_set_button_scale(1.0)
			_update_button_art()
	)

func _build_learning_button() -> void:
	var box := _rect(layout.learning_button_rect)
	for path in [layout.button_normal_texture, layout.button_hover_texture]:
		var texture := AtlasTexture.new()
		texture.atlas = load(path)
		texture.region = _rect(layout.button_texture_crop)
		_button_textures.append(texture)
	button_art = _image("LearningButtonArt", layout.button_normal_texture, box)
	button_art.texture = _button_textures[0]
	button_art.stretch_mode = TextureRect.STRETCH_SCALE
	button_art.pivot_offset = box.size * 0.5
	_label("LearningButtonCaption", "学习法术", box, 37, true, Color.WHITE)
	learning_button = Button.new()
	learning_button.name = "LearningButton"
	learning_button.position = box.position
	learning_button.size = box.size
	learning_button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	learning_button.focus_mode = FOCUS_NONE
	for style in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		learning_button.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	canvas.add_child(learning_button)
	learning_button.mouse_entered.connect(func(): _button_hovered = true; _update_button_art())
	learning_button.mouse_exited.connect(func(): _button_hovered = false; _update_button_art(); _animate_button(1.0))
	learning_button.button_down.connect(func(): _animate_button(float(layout.button_press_scale)))
	learning_button.button_up.connect(func(): _animate_button(1.0))
	# Visual feedback only; this button does not submit a learning transaction.

func _update_button_art() -> void:
	var hovered := _button_hovered and not learning_button.disabled
	button_art.texture = _button_textures[1 if hovered else 0]
	labels.LearningButtonCaption.add_theme_color_override("font_color", Color.BLACK if hovered else Color.WHITE)
	labels.LearningButtonCaption.add_theme_color_override("font_shadow_color", Color.TRANSPARENT if hovered else Color("06111bd9"))

func _animate_button(target: float) -> void:
	if _button_tween: _button_tween.kill()
	if learning_button.disabled:
		_set_button_scale(1.0)
		return
	_button_tween = create_tween()
	_button_tween.tween_method(_set_button_scale, _button_scale, target, 0.07 if target < 1.0 else 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _set_button_scale(value: float) -> void:
	_button_scale = value
	button_art.scale = Vector2.ONE * value
	var caption: Label = labels.LearningButtonCaption
	caption.pivot_offset = caption.size * 0.5
	caption.scale = caption.get_meta("native_scale", Vector2.ONE) * value

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and is_inside_tree(): _layout()

func _rect(values: Array) -> Rect2:
	return Rect2(values[0], values[1], values[2], values[3])

static func text_ink_x(label: Label) -> Vector2:
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var server := TextServerManager.get_primary_interface()
	var left := INF
	var right := -INF
	for index in label.text.length():
		var pen := font.get_string_size(label.text.left(index), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		for rid: RID in font.get_rids():
			var glyph := server.font_get_glyph_index(rid, font_size, label.text.unicode_at(index), 0)
			if glyph == 0: continue
			var offset := server.font_get_glyph_offset(rid, Vector2i(font_size, 0), glyph)
			var extent := server.font_get_glyph_size(rid, Vector2i(font_size, 0), glyph)
			if extent.x > 0:
				left = minf(left, pen + offset.x)
				right = maxf(right, pen + offset.x + extent.x)
			break
	return Vector2(left, right) if is_finite(left) else Vector2.ZERO

func _image(node_name: String, path: String, box: Rect2) -> TextureRect:
	var image := TextureRect.new()
	image.name = node_name
	image.texture = load(path)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	image.mouse_filter = MOUSE_FILTER_IGNORE
	image.position = box.position
	image.size = box.size
	canvas.add_child(image)
	return image

func _label(key: String, text: String, box: Rect2, font_size: int, centered := false, color := Color("f1ead6")) -> Label:
	var label := Label.new()
	label.name = key
	label.text = text
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.texture_filter = TEXTURE_FILTER_LINEAR
	label.oversampling_with_scale = OVERSAMPLING_WITH_SCALE_DISABLED
	label.add_theme_font_override("font", _font)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color("06111bd9"))
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.set_meta("source_rect", box)
	label.set_meta("source_font_size", font_size)
	canvas.add_child(label)
	labels[key] = label
	return label

func show_selection(book_id: String, rank: int, learning: MapLoadoutState) -> void:
	selected_spell_id = ""
	var book_record: Dictionary = {}
	for id: String in records:
		if records[id].book_id == book_id:
			book_record = records[id]
			if int(records[id].rank) == rank:
				selected_spell_id = id
	visible = not book_record.is_empty()
	if not visible: return
	current_book_id = book_id
	for child in detail_nodes: child.visible = not selected_spell_id.is_empty()
	state = learning
	record = book_record if selected_spell_id.is_empty() else records[selected_spell_id]
	_set_spell_summary(record, not selected_spell_id.is_empty())
	labels.Description.text = record.description
	for index in core_count:
		var point: Label = labels["CorePoint%d" % index]
		point.visible = not selected_spell_id.is_empty() and index < record.core_points.size()
		point.text = record.core_points[index] if index < record.core_points.size() else ""
		canvas.get_node("CoreDot%d" % index).visible = point.visible
	labels.Condition0.text = record.learning_conditions[0]
	labels.Condition2.text = record.learning_conditions[2]
	labels.LearningCost.text = str(int(record.learning_cost))
	_refresh_progress()
	_layout()

func _add_summary_category(index: int) -> void:
	var tag := _label("Category%d" % index, "", Rect2(181, 494, 88, 33), 20, true, Color("a7b8c5"))
	var tag_font := SystemFont.new()
	tag_font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	tag.add_theme_font_override("font", tag_font)
	tag.autowrap_mode = TextServer.AUTOWRAP_OFF
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1b242f")
	style.border_color = Color(Color("a7b8c5"), 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	tag.add_theme_stylebox_override("normal", style)

static func visible_spell_categories(summary: Dictionary) -> Array:
	# Hide element labels only on the technique page; shared copy and item
	# tooltip classification retain their authored element information.
	return summary.categories.filter(func(category): return category not in ["金属性", "木属性", "水属性", "火属性", "土属性", "风属性", "雷属性"])

func _set_spell_summary(summary: Dictionary, shown: bool) -> void:
	var categories := visible_spell_categories(summary)
	spell_icon.texture = load(summary.icon)
	spell_icon.visible = shown
	labels.SpellName.text = summary.name
	labels.SpellName.visible = shown
	labels.Poem.text = "“%s”" % summary.poem
	labels.Poem.visible = shown
	while category_count < categories.size():
		_add_summary_category(category_count)
		detail_nodes.append(labels["Category%d" % category_count])
		category_count += 1
	summary_extra_height = 0.0
	var widths: Array[float] = []
	var total: float = 10.0 * (categories.size() - 1)
	for category: String in categories:
		var width := 88.0 if category.length() == 3 else category.length() * 20.0 + 24.0
		widths.append(width)
		total += width
	# Keep the established water row; longer five-tag summaries wrap at full size.
	var wrap: bool = categories.size() > 4
	var trim: float = 0.0 if wrap else maxf(0, total - 293) / maxi(1, categories.size())
	var tag_x := 181.0
	for index in category_count:
		var tag: Label = labels["Category%d" % index]
		tag.visible = shown and index < categories.size()
		tag.text = categories[index] if index < categories.size() else ""
		if index < widths.size():
			var width: float = widths[index] - trim
			if wrap and tag_x + width > 474:
				tag_x = 181.0
				summary_extra_height += 43.0
			tag.set_meta("source_rect", Rect2(tag_x, 494 + summary_extra_height, width, 33))
			tag_x += width + 10

func _refresh_progress() -> void:
	var achieved := _refresh_book_progress()
	condition_flags = Vector3(
		1.0 if state != null and int(state.growth.get("realm", 0)) >= int(record.required_realm) else 0.0,
		1.0 if state != null and state.spirit_stones >= int(record.learning_cost) else 0.0,
		1.0 if achieved >= int(record.rank) else 0.0)
	for index in 3:
		condition_icons[index].texture = load(layout.condition_true_texture if condition_flags[index] > 0.5 else layout.condition_false_texture)
	labels.LearningButtonCaption.text = "已领悟" if achieved >= int(record.rank) else "学习法术"

func _refresh_book_progress() -> int:
	var book_progress := PracticeView.read(state, current_book_id)
	var achieved: int = book_progress.achieved
	var maximum: int = book_progress.maximum
	var target: float = book_progress.target
	var progress: float = book_progress.practice
	labels.Practice.text = "修炼度  %s / %d" % [CultivationGrowth.display(progress), int(target)]
	progress_bar.max_value = target
	progress_bar.value = clampf(progress, 0.0, target)
	labels.ProgressValue0.text = "%d / %d" % [achieved, maximum]
	labels.ProgressValue1.text = "已圆满" if book_progress.complete else "第%d重" % (achieved + 1)
	labels.ProgressValue2.text = "—" if book_progress.complete else "修炼度 %d" % int(target)
	return achieved

func _layout() -> void:
	if not is_inside_tree() or canvas == null or size.x <= 0 or size.y <= 0: return
	backdrop.position = Vector2(3, 3)
	backdrop.size = size - Vector2(6, 6)
	var factor := minf((size.x - 8) / canvas.size.x, (size.y - 8) / canvas.size.y)
	canvas.scale = Vector2.ONE * factor
	canvas.position = (size - canvas.size * factor) * 0.5
	var transform := canvas.get_global_transform_with_canvas()
	var screen_scale := transform.get_scale()
	if screen_scale.x <= 0 or screen_scale.y <= 0: return
	var inverse := transform.affine_inverse()
	for label: Label in labels.values():
		var box: Rect2 = label.get_meta("source_rect")
		label.scale = Vector2.ONE / screen_scale
		label.set_meta("native_scale", label.scale)
		label.position = inverse * (transform * box.position).round()
		label.add_theme_font_size_override("font_size", maxi(1, roundi(float(label.get_meta("source_font_size")) * screen_scale.x)))
		label.add_theme_constant_override("line_spacing", roundi(4 * screen_scale.y))
		label.size = (box.size * screen_scale).round()
	_center_progress_cards(transform)
	_layout_core_points(transform)
	# Keep the first poem line's visible ink on the icon's bottom, even when
	# future poems wrap to two lines. Labels remain at native pixel scale.
	var poem: Label = labels.Poem
	var poem_font := poem.get_theme_font("font")
	var poem_size := poem.get_theme_font_size("font_size")
	var ink := CooldownRing.ink_vertical_bounds(poem_font, poem.text.get_slice("\n", 0), poem_size)
	var icon_bottom := transform * Vector2(spell_icon.position.x, spell_icon.position.y + spell_icon.size.y + summary_extra_height)
	var poem_origin := transform * poem.position
	poem_origin.y = roundf(icon_bottom.y - poem_font.get_ascent(poem_size) - ink.y)
	poem.position = inverse * poem_origin
	_layout_body(transform)
	var currency_label: Label = labels.Condition1
	var text_width := text_ink_x(currency_label).y
	var gap := roundf(6 * screen_scale.x)
	var icon_left := (transform * currency_label.position).x + text_width + gap
	var icon_width := roundf(18 * screen_scale.x)
	currency_icon.position.x = (inverse * Vector2(icon_left, 0)).x
	currency_icon.size.x = icon_width / screen_scale.x
	labels.LearningCost.position.x = (inverse * Vector2(icon_left + icon_width + gap - text_ink_x(labels.LearningCost).x, 0)).x
	# Radius is four UI design pixels (the right art has a separate source scale).
	spell_icon.material.set_shader_parameter("corner_radius", 4.0 / factor)
	_set_button_scale(_button_scale)

func _layout_body(transform: Transform2D) -> void:
	if body_scroll == null: return
	body_scroll.hide()
	if record.is_empty() or selected_spell_id.is_empty(): return
	var factor := transform.get_scale()
	var description: Label = labels.Description
	var poem: Label = labels.Poem
	var font := poem.get_theme_font("font")
	var font_size := poem.get_theme_font_size("font_size")
	var ink := CooldownRing.ink_vertical_bounds(font, poem.text, font_size)
	var poem_bottom := (transform * poem.position).y + font.get_ascent(font_size) + ink.y + poem.get_minimum_size().y - font.get_height(font_size)
	var top := maxf((transform * Vector2(0, 608)).y, poem_bottom + roundf(12 * factor.y))
	var last: Label = labels["CorePoint%d" % (record.core_points.size() - 1)]
	var fits: bool = description.get_global_rect().end.y < labels.CorePoint0.get_global_rect().position.y + 1 and last.get_global_rect().end.y < labels.LearningHeading.get_global_rect().position.y and top <= description.global_position.y + 1
	if fits:
		description.show()
		for index in core_count:
			labels["CorePoint%d" % index].visible = index < record.core_points.size()
			canvas.get_node("CoreDot%d" % index).visible = index < record.core_points.size()
		return
	# Keep all approved prose legible when a long summary/body exceeds the
	# original fixed slots. Only this middle region scrolls; progress and learning
	# conditions retain the same positions as the water page.
	description.hide()
	for index in core_count:
		labels["CorePoint%d" % index].hide()
		canvas.get_node("CoreDot%d" % index).hide()
	if _body_spell_id != selected_spell_id:
		_body_spell_id = selected_spell_id
		for child in body_list.get_children():
			body_list.remove_child(child)
			child.queue_free()
		body_labels.clear()
		body_dots.clear()
		body_list.add_child(_body_text(record.description))
		for text: String in record.core_points:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", roundi(14 * factor.x))
			body_list.add_child(row)
			var dot := TextureRect.new()
			dot.texture = load(layout.dot_texture)
			dot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			dot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			dot.size_flags_vertical = SIZE_SHRINK_BEGIN
			row.add_child(dot)
			body_dots.append(dot)
			row.add_child(_body_text(text))
		body_scroll.scroll_vertical = 0
	body_scroll.scale = Vector2.ONE / factor
	var origin := Vector2((transform * Vector2(30, 0)).x, top).round()
	body_scroll.position = transform.affine_inverse() * origin
	body_scroll.size = Vector2(444 * factor.x, (transform * Vector2(0, 902)).y - top).round()
	body_list.add_theme_constant_override("separation", roundi(12 * factor.y))
	for label in body_labels:
		label.add_theme_font_size_override("font_size", maxi(1, roundi(25 * factor.x)))
		label.add_theme_constant_override("line_spacing", roundi(4 * factor.y))
	for dot in body_dots:
		dot.custom_minimum_size = Vector2.ONE * roundf(21 * factor.x)
		dot.get_parent().add_theme_constant_override("separation", roundi(14 * factor.x))
	body_scroll.show()

func _body_text(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.oversampling_with_scale = OVERSAMPLING_WITH_SCALE_DISABLED
	label.add_theme_font_override("font", _font)
	label.add_theme_color_override("font_color", Color("f1ead6"))
	label.add_theme_color_override("font_shadow_color", Color("06111bd9"))
	label.add_theme_constant_override("shadow_offset_y", 1)
	body_labels.append(label)
	return label

func _layout_core_points(transform: Transform2D) -> void:
	if record.is_empty(): return
	var scale_y := transform.get_scale().y
	var inverse := transform.affine_inverse()
	var first := transform * Vector2(65, 749.5)
	var available := (902.0 - 749.5) * scale_y
	var gap := roundf(10 * scale_y)
	var heights: Array[float] = []
	# Preserve the established single-line slots. Longer copy wraps as complete
	# paragraphs; reduce only this area's type if it would reach LearningHeading.
	for source_size in range(25, 18, -1):
		heights.clear()
		var total: float = gap * (record.core_points.size() - 1)
		var single_line := true
		for index in record.core_points.size():
			var point: Label = labels["CorePoint%d" % index]
			point.add_theme_font_size_override("font_size", maxi(1, roundi(source_size * scale_y)))
			var height := point.get_minimum_size().y
			heights.append(height)
			total += height
			single_line = single_line and point.get_line_count() == 1
		if single_line and source_size == 25:
			for index in record.core_points.size():
				labels["CorePoint%d" % index].vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				canvas.get_node("CoreDot%d" % index).position = Vector2(30, 760.5 + index * 40.5)
			return
		if total <= available: break
	var y := first.y
	for index in record.core_points.size():
		var point: Label = labels["CorePoint%d" % index]
		point.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		point.position = inverse * Vector2(first.x, roundf(y))
		point.size.y = heights[index]
		var dot: TextureRect = canvas.get_node("CoreDot%d" % index)
		var first_line_center := y + point.get_line_height(0) * 0.5
		dot.position.y = (inverse * Vector2(0, first_line_center)).y - dot.size.y * 0.5
		y += heights[index] + gap

func _center_progress_cards(transform: Transform2D) -> void:
	var inverse := transform.affine_inverse()
	var gap := roundf(16 * transform.get_scale().y)
	for index in 3:
		var caption: Label = labels["ProgressCaption%d" % index]
		var value: Label = labels["ProgressValue%d" % index]
		var rows: Array[Label] = [caption, value]
		var vertical: Array[Vector2] = []
		var height := gap
		for label in rows:
			var ink := CooldownRing.ink_vertical_bounds(label.get_theme_font("font"), label.text, label.get_theme_font_size("font_size"))
			vertical.append(ink)
			height += ink.y - ink.x
		var center := transform * _rect(layout.progress_cards[index]).get_center()
		var top := center.y - height * 0.5
		for row in 2:
			var label := rows[row]
			var horizontal := text_ink_x(label)
			var ascent := label.get_theme_font("font").get_ascent(label.get_theme_font_size("font_size"))
			label.position = inverse * Vector2(roundf(center.x - (horizontal.x + horizontal.y) * 0.5), roundf(top - ascent - vertical[row].x))
			top += vertical[row].y - vertical[row].x + gap
